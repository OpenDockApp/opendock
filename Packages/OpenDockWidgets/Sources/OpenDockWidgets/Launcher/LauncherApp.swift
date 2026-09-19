import AppKit

/// An installed app the launcher can show, keyed by bundle ID so it survives moves and updates.
nonisolated struct LauncherApp: Identifiable, Hashable, Sendable {
    let bundleID: String
    let url: URL
    let name: String

    var id: String { bundleID }

    init(bundleID: String, url: URL) {
        self.bundleID = bundleID
        self.url = url
        let display = FileManager.default.displayName(atPath: url.path)
        name = display.hasSuffix(".app") ? String(display.dropLast(4)) : display
    }

    init?(url: URL) {
        guard url.pathExtension == "app", let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        self.init(bundleID: id, url: url)
    }

    /// Apps for the stored bundle IDs, in order. Uninstalled apps are skipped, not forgotten.
    @MainActor
    static func resolve(_ bundleIDs: [String]) -> [LauncherApp] {
        bundleIDs.compactMap { id in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { LauncherApp(bundleID: id, url: $0) }
        }
    }

    /// Apps in the standard application folders, sorted by name.
    static func installed() async -> [LauncherApp] {
        await Task.detached(priority: .userInitiated) { scanInstalled() }.value
    }

    private static func scanInstalled() -> [LauncherApp] {
        var roots = ["/Applications", "/System/Applications"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        // The sandbox home is the container, so ask for the real one.
        if let home = getpwuid(getuid())?.pointee.pw_dir {
            roots.append(URL(filePath: String(cString: home), directoryHint: .isDirectory)
                .appending(path: "Applications", directoryHint: .isDirectory))
        }

        var seen = Set<String>()
        var apps: [LauncherApp] = []
        func visit(_ directory: URL, depth: Int) {
            let items = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            )) ?? []
            for url in items {
                if let app = LauncherApp(url: url) {
                    if seen.insert(app.bundleID).inserted { apps.append(app) }
                } else if depth > 0, (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    // One level down covers Utilities and vendor folders.
                    visit(url, depth: depth - 1)
                }
            }
        }
        roots.forEach { visit($0, depth: 1) }
        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
