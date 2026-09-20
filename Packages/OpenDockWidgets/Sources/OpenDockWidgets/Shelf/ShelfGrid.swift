import SwiftUI
import AppKit
import OpenDockKit

/// Popover for working with the whole shelf: a grid of previews, click, shift-click,
/// command-click or drag to select, then share, zip, copy or remove the selection.
struct ShelfGrid: View {
    @Environment(\.dockTheme) private var theme
    let shelf: ShelfService
    let entries: [ShelfEntry]
    let remove: ([ShelfItem]) -> Void
    let add: (ShelfItem) -> Void
    let clear: () -> Void
    let addFiles: () -> Void

    private static let space = "shelfGrid"

    @State private var selection: Set<UUID> = []
    @State private var anchor: UUID?
    @State private var frames: [UUID: CGRect] = [:]
    @State private var marquee: CGRect?
    @State private var archiving = false
    @State private var failure: String?

    private var selected: [ShelfEntry] {
        entries.filter { selection.contains($0.id) }
    }

    private var selectedURLs: [URL] {
        selected.compactMap(\.url)
    }

    var body: some View {
        WidgetDetails(title: "Shelf", symbol: "tray.full", width: 360) {
            if entries.isEmpty {
                Text("Nothing here yet. Drag files, folders or links onto the shelf, or add some below.")
                    .font(theme.captionFont)
                    .foregroundStyle(.secondary)
            } else {
                grid
                status
            }
            actions
        }
    }

    // MARK: Grid

    private var grid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: theme.scaled(6)),
            count: 4
        )
        return ScrollView {
            ZStack(alignment: .topLeading) {
                // Behind the cells, so a drag that starts on a cell drags the file
                // out and a drag that starts on empty space sweeps a selection.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selection = [] }
                    .gesture(marqueeGesture)

                LazyVGrid(columns: columns, spacing: theme.scaled(6)) {
                    ForEach(entries) { cell($0) }
                }

                if let marquee {
                    RoundedRectangle(cornerRadius: theme.scaled(3), style: .continuous)
                        .fill(theme.accent.opacity(0.15))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.scaled(3), style: .continuous)
                                .strokeBorder(theme.accent.opacity(0.7), lineWidth: 1)
                        }
                        .frame(width: marquee.width, height: marquee.height)
                        .offset(x: marquee.minX, y: marquee.minY)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(.named(Self.space))
            .onPreferenceChange(ShelfCellFrames.self) { frames = $0 }
        }
        .frame(height: theme.scaled(entries.count > 8 ? 240 : 160))
    }

    private var marqueeGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let rect = CGRect(origin: value.startLocation, size: .zero)
                    .union(CGRect(origin: value.location, size: .zero))
                marquee = rect
                selection = Set(frames.filter { $0.value.intersects(rect) }.keys)
            }
            .onEnded { _ in
                marquee = nil
                anchor = nil
            }
    }

    private func cell(_ entry: ShelfEntry) -> some View {
        let isSelected = selection.contains(entry.id)
        let shape = RoundedRectangle(cornerRadius: theme.scaled(8), style: .continuous)
        return VStack(spacing: theme.scaled(4)) {
            ShelfThumbnail(shelf: shelf, entry: entry, side: theme.scaled(38))
            Text(entry.item.name)
                .font(theme.captionFont)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, theme.scaled(6))
        .padding(.horizontal, theme.scaled(3))
        .opacity(entry.isAvailable ? 1 : 0.5)
        .background { if isSelected { shape.fill(theme.accent.opacity(0.25)) } }
        .overlay { if isSelected { shape.strokeBorder(theme.accent.opacity(0.6), lineWidth: 1) } }
        .contentShape(shape)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ShelfCellFrames.self,
                    value: [entry.id: geometry.frame(in: .named(Self.space))]
                )
            }
        }
        .onTapGesture(count: 2) { open(entry) }
        .onTapGesture { click(entry) }
        .modifier(ShelfDraggable(url: entry.url))
        .help(entry.isAvailable ? entry.item.name : "\(entry.item.name) (missing)")
        .contextMenu {
            shelfItemMenu(entry) { remove([entry.item]) }
        }
    }

    // MARK: Selection

    /// Reading the flags at click time keeps one tap gesture instead of three
    /// competing ones, which is what modifier-scoped taps turn into here.
    private func click(_ entry: ShelfEntry) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selection.contains(entry.id) {
                selection.remove(entry.id)
            } else {
                selection.insert(entry.id)
                anchor = entry.id
            }
        } else if flags.contains(.shift), let anchor,
                  let start = entries.firstIndex(where: { $0.id == anchor }),
                  let end = entries.firstIndex(where: { $0.id == entry.id }) {
            let range = start <= end ? start...end : end...start
            selection.formUnion(entries[range].map(\.id))
        } else {
            selection = [entry.id]
            anchor = entry.id
        }
    }

    private func open(_ entry: ShelfEntry) {
        guard let url = entry.url else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Actions

    private var status: some View {
        HStack(spacing: theme.scaled(4)) {
            if archiving {
                ProgressView().controlSize(.small)
                Text("Zipping…")
            } else if let failure {
                Text(failure).foregroundStyle(.red).lineLimit(1)
            } else if selection.isEmpty {
                Text("Drag across the grid to select. Double-click to open.")
            } else {
                Text("\(selection.count) selected")
            }
            Spacer(minLength: 0)
        }
        .font(theme.captionFont)
        .foregroundStyle(.secondary)
    }

    private var actions: some View {
        HStack(spacing: theme.scaled(6)) {
            ShareLink(items: selectedURLs) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(selectedURLs.isEmpty)
            .help("Share or AirDrop the selection")

            Button(action: zipSelection) {
                Label("Zip", systemImage: "doc.zipper")
            }
            .disabled(zippable.isEmpty || archiving)
            .help("Zip the selection onto the shelf")

            Button {
                shelf.copyToPasteboard(selected.map(\.item))
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(selectedURLs.isEmpty)
            .help("Copy the selection")

            Button(role: .destructive) {
                remove(selected.map(\.item))
                selection = []
            } label: {
                Label("Remove", systemImage: "minus.circle")
            }
            .disabled(selection.isEmpty)
            .help("Take the selection off the shelf")

            Spacer(minLength: 0)

            Menu {
                Button("Add Files…", action: addFiles)
                Button("Select All") { selection = Set(entries.map(\.id)) }
                    .disabled(entries.isEmpty)
                Divider()
                Button("Clear Shelf", role: .destructive) {
                    clear()
                    selection = []
                }
                .disabled(entries.isEmpty)
            } label: {
                Label("More", systemImage: "ellipsis")
            }
            .menuStyle(.button)
            .fixedSize()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .controlSize(.small)
    }

    /// Links have no file to put in an archive.
    private var zippable: [ShelfItem] {
        selected.filter { $0.isAvailable && !$0.item.isLink }.map(\.item)
    }

    private func zipSelection() {
        let items = zippable
        guard !items.isEmpty else { return }
        let name = items.count == 1
            ? (items[0].name as NSString).deletingPathExtension
            : "Shelf Items"
        archiving = true
        failure = nil
        Task {
            do {
                let archive = try await shelf.archive(items, named: name)
                add(archive)
                selection = [archive.id]
            } catch {
                failure = "Could not zip: \(error.localizedDescription)"
            }
            archiving = false
        }
    }
}

/// Cell frames in the grid's coordinate space, for the selection marquee.
struct ShelfCellFrames: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// File icon first, replaced by a Quick Look preview once one arrives.
struct ShelfThumbnail: View {
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
