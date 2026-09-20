// Now Playing bridge for OpenDock.
//
// macOS only answers MediaRemote now-playing queries from Apple-signed processes, so
// OpenDock loads this library into /usr/bin/perl instead of calling MediaRemote itself,
// then calls OpenDockMediaBridgeRun as a perl XSUB (see MediaService.swift).
//
// The entry point must not be a load constructor: dyld holds its loader lock while
// constructors run, and MediaRemote stops answering once it needs that lock.
//
// OpenDockMediaBridgeRun never returns. It writes one JSON object per line to stdout
// whenever playback changes, and reads commands (toggle, next, previous) from stdin, one
// per line. It exits when stdin closes, so it never outlives OpenDock.

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdlib.h>

typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*RegisterFn)(dispatch_queue_t);
typedef Boolean (*SendCommandFn)(int, NSDictionary *);

static GetInfoFn getInfo;
static GetPIDFn getPID;
static SendCommandFn sendCommand;
static NSString *lastLine;

static void emit(void) {
    getInfo(dispatch_get_main_queue(), ^(NSDictionary *info) {
        getPID(dispatch_get_main_queue(), ^(int pid) {
            NSMutableDictionary *out = [NSMutableDictionary dictionary];
            NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
            if (title.length > 0) {
                out[@"title"] = title;
                out[@"artist"] = info[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"";
                out[@"album"] = info[@"kMRMediaRemoteNowPlayingInfoAlbum"] ?: @"";
                out[@"playing"] = @((BOOL)([info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] doubleValue] > 0));
                out[@"pid"] = @(pid);
            }
            NSData *json = [NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingSortedKeys error:nil];
            NSString *line = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
            if (line == nil || [line isEqualToString:lastLine]) return;
            lastLine = line;
            printf("%s\n", line.UTF8String);
            fflush(stdout);
        });
    });
}

static void readCommands(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        char buffer[64];
        while (fgets(buffer, sizeof buffer, stdin) != NULL) {
            NSString *command = [[NSString stringWithUTF8String:buffer]
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            // MRMediaRemoteCommand values: 2 toggle play/pause, 4 next track, 5 previous track.
            int code = [command isEqualToString:@"toggle"] ? 2
                : [command isEqualToString:@"next"] ? 4
                : [command isEqualToString:@"previous"] ? 5 : -1;
            if (code >= 0) sendCommand(code, nil);
        }
        exit(0);
    });
}

// Called by perl as an XSUB, so it receives perl's interpreter and CV pointers; both are unused.
__attribute__((visibility("default"))) void OpenDockMediaBridgeRun(void *interpreter, void *cv) {
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    getInfo = handle ? (GetInfoFn)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") : NULL;
    getPID = handle ? (GetPIDFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") : NULL;
    sendCommand = handle ? (SendCommandFn)dlsym(handle, "MRMediaRemoteSendCommand") : NULL;
    RegisterFn registerForNotifications = handle ? (RegisterFn)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") : NULL;
    if (!getInfo || !getPID || !sendCommand || !registerForNotifications) {
        fprintf(stderr, "MediaRemote is unavailable\n");
        exit(1);
    }
    signal(SIGPIPE, SIG_DFL);

    registerForNotifications(dispatch_get_main_queue());
    for (NSString *name in @[@"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                             @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
                             @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"]) {
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil
                                                    usingBlock:^(NSNotification *note) { emit(); }];
    }
    // Some players change state without a notification; a slow poll catches those.
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC, NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{ emit(); });
    dispatch_resume(timer);

    readCommands();
    CFRunLoopRun();
    exit(0);
}
