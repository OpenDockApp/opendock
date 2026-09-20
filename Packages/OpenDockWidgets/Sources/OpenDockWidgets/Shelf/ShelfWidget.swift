import SwiftUI
import AppKit
import OpenDockKit

struct ShelfWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.shelf",
        name: "Shelf",
        summary: "A parking spot for files and links. Drop things on it, drag them back out.",
        symbol: "tray.full",
        category: .utilities,
        supportedSizes: [.small, .medium, .wide, .large],
        defaultSize: .medium
    )

    func body(context: WidgetContext) -> some View {
        ShelfView(context: context)
    }
}

extension WidgetSize {
    /// Two icon columns and two icon rows per cell, matching the launcher grid.
    fileprivate var shelfColumns: Int { columns * 2 }
    fileprivate var shelfCapacity: Int { columns * rows * 4 }
}

/// A shelf item with everything the view needs, resolved once per change instead
/// of on every render: resolving a bookmark touches the file system.
struct ShelfEntry: Identifiable {
    let item: ShelfItem
    let url: URL?
    let icon: NSImage
    var id: UUID { item.id }
    var isAvailable: Bool { url != nil }
}

private struct ShelfView: View {
    let context: WidgetContext

    static let storageKey = "items"

    @State private var items: [ShelfItem] = []
    @State private var entries: [ShelfEntry] = []
    @State private var restored = false
    @State private var showingList = false
    @State private var isDropTarget = false

    private var theme: DockTheme { context.theme }
    private var shelf: ShelfService { context.services.shelf }
    private var capacity: Int { context.size.shelfCapacity }
    private var iconSize: CGFloat { theme.scaled(22) }

    var body: some View {
        let overflowing = entries.count > capacity
        let shown = overflowing ? Array(entries.prefix(capacity - 1)) : entries
        let gap = theme.scaled(4)
        let columns = Array(repeating: GridItem(.flexible(), spacing: gap), count: context.size.shelfColumns)

        Group {
            if restored, entries.isEmpty {
                emptyShelf
            } else {
                LazyVGrid(columns: columns, spacing: gap) {
                    ForEach(shown) { entry in
                        itemButton(entry)
                    }
                    if overflowing {
                        overflowButton(count: entries.count - shown.count)
                    }
                    ForEach(shown.count + (overflowing ? 1 : 0)..<capacity, id: \.self) { _ in
                        Color.clear.frame(width: iconSize, height: iconSize)
                    }
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
        .dropDestination(for: URL.self) { urls, _ in
            add(urls)
        } isTargeted: { isDropTarget = $0 }
        .contextMenu {
            Button("Open Shelf…") { showingList = true }
            Button("Add Files…") { addFiles() }
            Divider()
            Button("Clear Shelf", role: .destructive) { update([]) }
                .disabled(items.isEmpty)
        }
        .widgetPopover(isPresented: $showingList) {
            ShelfList(
                shelf: shelf,
                entries: entries,
                remove: remove,
                clear: { update([]) },
                addFiles: {
                    showingList = false
                    addFiles()
                }
            )
            .environment(\.dockTheme, theme)
        }
        .onAppear {
            guard !restored else { return }
            items = context.services.storage.get(Self.storageKey, instance: context.instanceID, as: [ShelfItem].self) ?? []
            // A file that moved since last launch gets a fresh bookmark.
            if let refreshed = shelf.refreshing(items) {
                update(refreshed)
            }
            restored = true
        }
        .task(id: items) {
            entries = items.map { item in
                let resolution = shelf.resolve(item)
                let url = resolution.flatMap { $0.isMissing ? nil : $0.url }
                return ShelfEntry(item: item, url: url, icon: shelf.icon(for: item))
            }
        }
    }

    // MARK: Pieces

    private func itemButton(_ entry: ShelfEntry) -> some View {
        Button {
            if let url = entry.url { context.services.openURL(url) }
        } label: {
            Image(nsImage: entry.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .opacity(entry.isAvailable ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!entry.isAvailable)
        .help(entry.isAvailable ? entry.item.name : "\(entry.item.name) (missing)")
        .modifier(ShelfDraggable(url: entry.url))
        .contextMenu {
            shelfItemMenu(entry, remove: { remove(entry.item) })
            Divider()
            Button("Open Shelf…") { showingList = true }
        }
    }

    private func overflowButton(count: Int) -> some View {
        Button {
            showingList = true
        } label: {
            Text("+\(count)")
                .font(theme.captionFont)
                .foregroundStyle(.secondary)
                .frame(width: iconSize, height: iconSize)
                .background {
                    RoundedRectangle(cornerRadius: theme.scaled(6), style: .continuous)
                        .fill(.secondary.opacity(0.15))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show all \(entries.count) items")
    }

    private var emptyShelf: some View {
        Button {
            showingList = true
        } label: {
            VStack(spacing: theme.scaled(3)) {
                Image(systemName: "tray.and.arrow.down")
                    .font(theme.statFont)
                    .foregroundStyle(.secondary)
                Text("Drop files here")
                    .font(theme.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: theme.scaled(10), style: .continuous)
                    .strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Changes

    private func update(_ newItems: [ShelfItem]) {
        items = newItems
        context.services.storage.set(newItems, for: Self.storageKey, instance: context.instanceID)
    }

    private func remove(_ item: ShelfItem) {
        shelf.forget(item)
        update(items.filter { $0.id != item.id })
    }

    /// Newest first, so the last thing dropped is the easiest to grab.
    private func add(_ urls: [URL]) -> Bool {
        let added = urls.compactMap { shelf.item(for: $0) }
        guard !added.isEmpty else { return false }
        update(added.reversed() + items)
        return true
    }

    private func addFiles() {
        // Let any popover or menu close before the modal panel takes the run loop.
        Task {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = true
            panel.prompt = "Add"
            panel.message = "Choose files or folders to put on the shelf."
            NSApp.activate()
            guard panel.runModal() == .OK else { return }
            _ = add(panel.urls)
        }
    }
}

/// Drags an item back out to Finder, Mail or a browser. Missing items stay put.
struct ShelfDraggable: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            content.draggable(url)
        } else {
            content
        }
    }
}

/// Menu entries shared by the tile and the popover list.
@ViewBuilder
func shelfItemMenu(_ entry: ShelfEntry, remove: @escaping () -> Void) -> some View {
    if let url = entry.url {
        Button("Open") { NSWorkspace.shared.open(url) }
        if !entry.item.isLink {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        Button(entry.item.isLink ? "Copy Link" : "Copy") {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSURL])
        }
        Divider()
    }
    Button("Remove from Shelf", role: .destructive, action: remove)
}
