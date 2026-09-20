import SwiftUI
import AppKit
import OpenDockKit

/// Popover listing everything on the shelf, with Quick Look previews.
struct ShelfList: View {
    @Environment(\.dockTheme) private var theme
    let shelf: ShelfService
    let entries: [ShelfEntry]
    let remove: (ShelfItem) -> Void
    let clear: () -> Void
    let addFiles: () -> Void

    var body: some View {
        WidgetDetails(title: "Shelf", symbol: "tray.full") {
            if entries.isEmpty {
                Text("Nothing here yet. Drag files, folders or links onto the shelf, or add some below.")
                    .font(theme.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.scaled(2)) {
                        ForEach(entries) { row($0) }
                    }
                }
                .frame(height: theme.scaled(min(CGFloat(entries.count) * 40, 240)))
            }
            HStack {
                Button("Add Files…", action: addFiles)
                Spacer()
                Button("Clear", action: clear).disabled(entries.isEmpty)
            }
            .buttonStyle(.glass)
        }
    }

    private func row(_ entry: ShelfEntry) -> some View {
        HStack(spacing: theme.scaled(8)) {
            ShelfThumbnail(shelf: shelf, entry: entry, side: theme.scaled(26))
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.item.name)
                    .font(theme.titleFont)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle(entry))
                    .font(theme.captionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
            Button {
                remove(entry.item)
            } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove \(entry.item.name)")
        }
        .padding(.vertical, theme.scaled(3))
        .opacity(entry.isAvailable ? 1 : 0.5)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = entry.url { NSWorkspace.shared.open(url) }
        }
        .modifier(ShelfDraggable(url: entry.url))
        .contextMenu { shelfItemMenu(entry) { remove(entry.item) } }
    }

    private func subtitle(_ entry: ShelfEntry) -> String {
        guard let url = entry.url else { return "Missing" }
        if entry.item.isLink { return url.absoluteString }
        return url.deletingLastPathComponent().path(percentEncoded: false)
    }
}

/// File icon first, replaced by a Quick Look preview once one arrives.
private struct ShelfThumbnail: View {
    @Environment(\.dockTheme) private var theme
    let shelf: ShelfService
    let entry: ShelfEntry
    let side: CGFloat

    @State private var preview: NSImage?

    var body: some View {
        Image(nsImage: preview ?? entry.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: side, height: side)
            .task(id: entry.id) {
                preview = await shelf.thumbnail(
                    for: entry.item,
                    size: side,
                    scale: NSScreen.main?.backingScaleFactor ?? 2
                )
            }
    }
}
