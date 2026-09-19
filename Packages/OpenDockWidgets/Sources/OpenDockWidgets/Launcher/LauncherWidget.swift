import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OpenDockKit

struct LauncherWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.launcher",
        name: "App Launcher",
        summary: "A grid of your favorite apps. Drop apps on it to add them.",
        symbol: "square.grid.2x2",
        category: .utilities,
        supportedSizes: [.small, .medium, .wide, .large]
    )

    func body(context: WidgetContext) -> some View {
        LauncherView(context: context)
    }
}

extension WidgetSize {
    /// Two icon columns and two icon rows per cell.
    fileprivate var launcherColumns: Int { columns * 2 }
    fileprivate var launcherCapacity: Int { columns * rows * 4 }
}

private struct LauncherView: View {
    let context: WidgetContext

    static let storageKey = "bundleIDs"
    static let defaultBundleIDs = [
        "com.apple.Safari", "com.apple.Music", "com.apple.Notes", "com.apple.finder",
        "com.apple.mail", "com.apple.iCal", "com.apple.systempreferences", "com.apple.Terminal",
        "com.apple.MobileSMS", "com.apple.Photos", "com.apple.Maps", "com.apple.reminders",
        "com.apple.AppStore", "com.apple.FaceTime", "com.apple.podcasts", "com.apple.Preview",
    ]

    @State private var bundleIDs: [String] = []
    @State private var restored = false
    @State private var showingEditor = false
    @State private var isDropTarget = false
    @State private var fullNotice = 0

    private var theme: DockTheme { context.theme }
    private var capacity: Int { context.size.launcherCapacity }
    private var iconSize: CGFloat { theme.scaled(22) }

    var body: some View {
        let apps = LauncherApp.resolve(bundleIDs)
        let visible = Array(apps.prefix(capacity))
        let gap = theme.scaled(4)
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: context.size.launcherColumns)
        LazyVGrid(columns: columns, spacing: gap) {
            ForEach(0..<capacity, id: \.self) { index in
                if index < visible.count {
                    appButton(visible[index], position: index, total: apps.count)
                } else if index == visible.count, restored {
                    addButton
                } else {
                    Color.clear.frame(width: iconSize, height: iconSize)
                }
            }
        }
        .padding(theme.scaled(7))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: theme.tileCornerRadius, style: .continuous)
                    .strokeBorder(theme.accent, lineWidth: 2)
            }
        }
        .overlay { if fullNotice > 0 { fullNoticeView } }
        .dropDestination(for: URL.self) { urls, _ in
            addDropped(urls)
        } isTargeted: { isDropTarget = $0 }
        .popover(isPresented: $showingEditor) {
            LauncherEditor(
                bundleIDs: Binding(get: { bundleIDs }, set: { update($0) }),
                capacity: capacity,
                defaults: Self.defaultBundleIDs,
                chooseOther: chooseOther
            )
            .environment(\.dockTheme, theme)
        }
        .task(id: fullNotice) {
            guard fullNotice > 0 else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            withAnimation { fullNotice = 0 }
        }
        .onAppear {
            guard !restored else { return }
            bundleIDs = context.services.storage.get(Self.storageKey, instance: context.instanceID, as: [String].self)
                ?? Self.defaultBundleIDs
            restored = true
        }
    }

    private func appButton(_ app: LauncherApp, position: Int, total: Int) -> some View {
        Button {
            context.services.openApplication(app.url)
        } label: {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
        }
        .buttonStyle(.plain)
        .help(app.name)
        .contextMenu {
            Button("Edit Launcher…") { showingEditor = true }
            Divider()
            Button("Move Left") { move(app, by: -1) }.disabled(position == 0)
            Button("Move Right") { move(app, by: 1) }.disabled(position >= total - 1)
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
            Divider()
            Button("Remove from Launcher", role: .destructive) {
                update(bundleIDs.filter { $0 != app.bundleID })
            }
        }
    }

    private var addButton: some View {
        Button {
            showingEditor = true
        } label: {
            Image(systemName: "plus")
                .font(theme.titleFont)
                .foregroundStyle(.secondary)
                .frame(width: iconSize, height: iconSize)
                .background {
                    RoundedRectangle(cornerRadius: theme.scaled(6), style: .continuous)
                        .strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add Apps")
    }

    private var fullNoticeView: some View {
        VStack(spacing: theme.scaled(2)) {
            Text("Launcher is full").font(theme.titleFont)
            Text("Resize it or remove an app").font(theme.captionFont).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(theme.scaled(4))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: theme.tileCornerRadius, style: .continuous))
        .transition(.opacity)
        .onTapGesture { fullNotice = 0 }
    }

    // MARK: Changes

    private func update(_ ids: [String]) {
        bundleIDs = ids
        context.services.storage.set(ids, for: Self.storageKey, instance: context.instanceID)
    }

    /// Swaps with the neighbouring installed app, leaving uninstalled entries in place.
    private func move(_ app: LauncherApp, by offset: Int) {
        let order = LauncherApp.resolve(bundleIDs).map(\.bundleID)
        guard let position = order.firstIndex(of: app.bundleID), order.indices.contains(position + offset),
              let from = bundleIDs.firstIndex(of: app.bundleID),
              let to = bundleIDs.firstIndex(of: order[position + offset]) else { return }
        var ids = bundleIDs
        ids.swapAt(from, to)
        update(ids)
    }

    private func addDropped(_ urls: [URL]) -> Bool {
        let dropped = urls.compactMap(LauncherApp.init(url:))
        guard !dropped.isEmpty else { return false }
        var added: [String] = []
        for app in dropped where !bundleIDs.contains(app.bundleID) && !added.contains(app.bundleID) {
            added.append(app.bundleID)
        }
        // Everything dropped is already here.
        guard !added.isEmpty else { return true }
        let room = capacity - LauncherApp.resolve(bundleIDs).count
        if added.count > room { withAnimation { fullNotice += 1 } }
        guard room > 0 else { return false }
        update(bundleIDs + added.prefix(room))
        return true
    }

    private func chooseOther() {
        showingEditor = false
        // Let the popover close before the modal panel takes over the run loop.
        Task { runOpenPanel() }
    }

    private func runOpenPanel() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Add"
        panel.message = "Choose apps to add to the launcher."
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap(LauncherApp.init(url:)).map(\.bundleID)
        update(bundleIDs + ids.filter { !bundleIDs.contains($0) })
    }
}
