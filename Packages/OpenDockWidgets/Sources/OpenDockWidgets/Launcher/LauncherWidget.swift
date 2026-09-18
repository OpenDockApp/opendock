import SwiftUI
import AppKit
import OpenDockKit

struct LauncherWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.launcher",
        name: "App Launcher",
        summary: "A grid of your favorite apps.",
        symbol: "square.grid.2x2",
        category: .utilities,
        supportedSizes: [.small, .medium]
    )

    func body(context: WidgetContext) -> some View {
        LauncherView(context: context)
    }
}

private struct LauncherView: View {
    let context: WidgetContext

    private static let defaultBundleIDs = [
        "com.apple.Safari", "com.apple.Music", "com.apple.Notes", "com.apple.finder",
        "com.apple.mail", "com.apple.iCal", "com.apple.systempreferences", "com.apple.Terminal",
    ]

    private var apps: [URL] {
        let ids = context.services.storage.get("bundleIDs", instance: context.instanceID, as: [String].self)
            ?? Self.defaultBundleIDs
        let count = context.size == .small ? 4 : 8
        return ids.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.prefix(count).map { $0 }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: context.size == .small ? 2 : 4)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(apps, id: \.self) { url in
                Button {
                    context.services.openApplication(url)
                } label: {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .help(url.deletingPathExtension().lastPathComponent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
