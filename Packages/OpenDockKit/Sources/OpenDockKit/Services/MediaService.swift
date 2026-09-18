import AppKit
import Foundation
import Carbon

public enum MediaSource: String, CaseIterable, Codable, Sendable {
    case music, spotify
    public nonisolated var name: String { self == .music ? "Music" : "Spotify" }
    public nonisolated var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
}

public struct MediaSnapshot: Sendable {
    public enum State: Sendable { case closed, needsPermission, denied, idle, track, unavailable }
    public let state: State
    public var title = ""
    public var artist = ""
    public var playing = false
    public var artwork: Data?
}

/// All system communication is owned by the host, not the widget's view.
public final class MediaService {
    public static let shared = MediaService()
    public enum Command: String, Sendable { case toggle = "playpause", next = "next track", previous = "previous track" }
    private let worker = MediaWorker()
    public init() {}

    public enum Permission: Sendable { case notDetermined, granted, denied }
    public func permission(for source: MediaSource) async -> Permission {
        let status = await worker.permission(source, ask: false)
        return status == noErr ? .granted : status == -1743 ? .denied : .notDetermined
    }
    public func connect(_ source: MediaSource) async -> MediaSnapshot {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else {
            return MediaSnapshot(state: .closed)
        }
        do { _ = try await NSWorkspace.shared.openApplication(at: url, configuration: .init()) }
        catch { return MediaSnapshot(state: .unavailable) }
        return await snapshot(for: source, requestPermission: true)
    }

    public func snapshot(for source: MediaSource, requestPermission: Bool = false) async -> MediaSnapshot {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty == false else {
            return MediaSnapshot(state: .closed)
        }
        return await worker.snapshot(source, requestPermission: requestPermission)
    }
    public func command(_ command: Command, source: MediaSource) async -> Bool {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleID).isEmpty else { return false }
        return await worker.command(command, source: source)
    }
    public func open(_ source: MediaSource) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) else { return false }
        NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
        return true
    }
}

/// Serializes automation away from the UI thread. No private MediaRemote APIs.
private actor MediaWorker {
    private var artworkCache: [String: Data] = [:]

    func permission(_ source: MediaSource, ask: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: source.bundleID)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, ask)
    }

    func snapshot(_ source: MediaSource, requestPermission: Bool) async -> MediaSnapshot {
        let status = permission(source, ask: requestPermission)
        guard status == noErr else {
            return MediaSnapshot(state: status == -1744 ? .needsPermission : status == -1743 ? .denied : .unavailable)
        }
        // The interpolated target and commands are enums; calendar/media text is
        // never executable script input. A stopped player has no current track.
        let script = """
        with timeout of 2 seconds
            tell application id "\(source.bundleID)"
                if player state is stopped then return {"", "", false, ""}
                return {name of current track, artist of current track, player state is playing, album of current track}
            end tell
        end timeout
        """
        guard let result = execute(script), result.numberOfItems == 4 else { return MediaSnapshot(state: .unavailable) }
        let title = result.atIndex(1)?.stringValue ?? ""
        guard !title.isEmpty else { return MediaSnapshot(state: .idle) }
        let artist = result.atIndex(2)?.stringValue ?? ""
        let album = result.atIndex(4)?.stringValue ?? ""
        let key = "\(source.rawValue)|\(artist)|\(album)|\(title)"
        var snapshot = MediaSnapshot(state: .track, title: title, artist: artist, playing: result.atIndex(3)?.booleanValue ?? false)
        if let cached = artworkCache[key] { snapshot.artwork = cached; return snapshot }
        let artworkProperty = source == .music ? "raw data of artwork 1 of current track" : "artwork url of current track"
        if let art = execute("""
        with timeout of 2 seconds
            tell application id "\(source.bundleID)"
                try
                    return \(artworkProperty)
                on error
                    return ""
                end try
            end tell
        end timeout
        """) {
            if source == .music, art.descriptorType != typeUnicodeText, art.data.count <= 5_000_000 {
                snapshot.artwork = art.data
            } else if source == .spotify, let value = art.stringValue, let url = URL(string: value),
                      url.scheme == "https", let host = url.host, host == "i.scdn.co" || host.hasSuffix(".scdn.co") {
                if let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 5)),
                   (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 5_000_000 {
                    snapshot.artwork = data
                }
            }
        }
        if let data = snapshot.artwork {
            if artworkCache.count >= 8 { artworkCache.removeAll() }
            artworkCache[key] = data
        }
        return snapshot
    }

    func command(_ command: MediaService.Command, source: MediaSource) -> Bool {
        guard permission(source, ask: false) == noErr else { return false }
        return execute("""
        with timeout of 2 seconds
            tell application id "\(source.bundleID)" to \(command.rawValue)
        end timeout
        """) != nil
    }

    private func execute(_ source: String) -> NSAppleEventDescriptor? {
        autoreleasepool {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            return error == nil ? result : nil
        }
    }
}
