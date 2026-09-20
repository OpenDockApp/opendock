import AppKit
import Foundation
import Observation

public struct MediaSnapshot: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var playing: Bool
    /// The app that owns the session, such as Music, Spotify or a browser.
    public var appName: String?
    public var bundleID: String?
}

/// Follows whatever app macOS reports as Now Playing, the same source as Control Center.
///
/// MediaRemote only answers Apple-signed processes, so the host runs the bundled
/// `libMediaRemoteBridge.dylib` inside `/usr/bin/perl` and reads its JSON lines.
@Observable
public final class MediaService {
    public static let shared = MediaService()
    public enum Command: String, Sendable { case toggle, next, previous }

    /// The current session, or nil when nothing is playing.
    public private(set) var nowPlaying: MediaSnapshot?
    /// False once the bridge could not be started, so the widget can say so.
    public private(set) var available = true

    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var failures = 0
    private var pendingClear: DispatchWorkItem?

    /// Loads the bridge, then calls its entry point once loading has finished.
    private static let loader = """
        my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
        my $run = DynaLoader::dl_find_symbol($lib, "OpenDockMediaBridgeRun") or die DynaLoader::dl_error();
        DynaLoader::dl_install_xsub("main::run", $run);
        run();
        """

    public init() {}

    /// Starts the bridge if it is not running. Safe to call from every widget instance.
    public func start() {
        guard process == nil, available else { return }
        guard let bridge = Bundle.main.privateFrameworksURL?.appendingPathComponent("libMediaRemoteBridge.dylib"),
              FileManager.default.fileExists(atPath: bridge.path) else {
            available = false
            return
        }
        // A write to a bridge that just died must fail, not kill the app.
        signal(SIGPIPE, SIG_IGN)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-MDynaLoader", "-e", Self.loader, bridge.path]
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.receive(data) } }
        }
        process.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.bridgeEnded(ended) } }
        }
        do {
            try process.run()
            self.process = process
            input = stdin.fileHandleForWriting
        } catch {
            available = false
        }
    }

    public func send(_ command: Command) {
        guard let input else { return }
        try? input.write(contentsOf: Data("\(command.rawValue)\n".utf8))
        if command == .toggle { nowPlaying?.playing.toggle() }
    }

    /// Brings the app that owns the session to the front.
    public func openPlayer() {
        guard let bundleID = nowPlaying?.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let message = try? JSONDecoder().decode(BridgeMessage.self, from: line) {
                failures = 0
                update(snapshot(from: message))
            }
        }
    }

    /// Players report nothing for a moment between tracks, so an empty session only
    /// clears the widget if no new track arrives shortly after.
    private func update(_ snapshot: MediaSnapshot?) {
        pendingClear?.cancel()
        pendingClear = nil
        if let snapshot {
            nowPlaying = snapshot
            return
        }
        let clear = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.nowPlaying = nil } }
        pendingClear = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: clear)
    }

    private func snapshot(from message: BridgeMessage) -> MediaSnapshot? {
        guard let title = message.title, !title.isEmpty else { return nil }
        let app = message.pid.flatMap { NSRunningApplication(processIdentifier: pid_t($0)) }
        return MediaSnapshot(title: title, artist: message.artist ?? "", album: message.album ?? "",
                             playing: message.playing ?? false, appName: app?.localizedName, bundleID: app?.bundleIdentifier)
    }

    private func bridgeEnded(_ ended: Process) {
        guard ended === process else { return }
        (ended.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        process = nil
        input = nil
        buffer.removeAll()
        pendingClear?.cancel()
        nowPlaying = nil
        failures += 1
        // Restart after a crash, but stop trying if the bridge cannot run on this system.
        guard failures < 5 else { available = false; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(failures * 2)) { [weak self] in
            MainActor.assumeIsolated { self?.start() }
        }
    }
}

private struct BridgeMessage: Decodable {
    var title: String?
    var artist: String?
    var album: String?
    var playing: Bool?
    var pid: Int?
}
