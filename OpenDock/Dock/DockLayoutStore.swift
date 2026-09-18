import Foundation
import Observation
import OpenDockKit

/// The ordered list of widgets in the dock, persisted as JSON in Application Support.
///
/// Edit mode works on a draft: `beginEditing` snapshots the layout, changes are held in
/// memory, `commitEditing` saves them and `cancelEditing` restores the snapshot.
@Observable
final class DockLayoutStore {
    private(set) var items: [DockItem] = []
    private(set) var isEditing = false {
        didSet {
            if isEditing != oldValue { onEditingChanged?(isEditing) }
        }
    }

    /// Layout before edit mode started, used by Cancel.
    @ObservationIgnored private var snapshot: [DockItem]?

    /// Lets the panel controller react to edit mode without observation plumbing.
    @ObservationIgnored var onEditingChanged: ((Bool) -> Void)?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
    }

    // MARK: Edit mode

    func beginEditing() {
        guard !isEditing else { return }
        snapshot = items
        isEditing = true
    }

    func commitEditing() {
        guard isEditing else { return }
        snapshot = nil
        isEditing = false
        save()
    }

    func cancelEditing() {
        guard isEditing else { return }
        if let snapshot { items = snapshot }
        snapshot = nil
        isEditing = false
    }

    // MARK: Mutations

    func add(_ descriptor: WidgetDescriptor, size: WidgetSize? = nil) {
        insert(descriptor, before: nil, size: size)
    }

    /// Inserts a new widget before `targetID`, or at the end when `targetID` is nil.
    func insert(_ descriptor: WidgetDescriptor, before targetID: UUID?, size: WidgetSize? = nil) {
        let item = DockItem(widgetID: descriptor.id, size: size ?? descriptor.defaultSize)
        if let targetID, let index = items.firstIndex(where: { $0.id == targetID }) {
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
        save()
    }

    func moveToEnd(_ id: UUID) {
        guard let from = items.firstIndex(where: { $0.id == id }) else { return }
        items.append(items.remove(at: from))
        save()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func move(_ id: UUID, before targetID: UUID) {
        guard id != targetID,
              let from = items.firstIndex(where: { $0.id == id }),
              let to = items.firstIndex(where: { $0.id == targetID }) else { return }
        let item = items.remove(at: from)
        items.insert(item, at: to > from ? to - 1 : to)
        save()
    }

    func resize(_ id: UUID, to size: WidgetSize) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].size = size
        save()
    }

    func reset() {
        items = Self.defaultItems
        save()
    }

    // MARK: Persistence

    private static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: Bundle.main.bundleIdentifier ?? "OpenDock", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "layout.json")
    }

    private static var defaultItems: [DockItem] {
        [
            DockItem(widgetID: "dev.opendock.clock", size: .medium),
            DockItem(widgetID: "dev.opendock.date", size: .small),
            DockItem(widgetID: "dev.opendock.launcher", size: .small),
            DockItem(widgetID: "dev.opendock.cpu", size: .small),
        ]
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DockItem].self, from: data) else {
            items = Self.defaultItems
            return
        }
        items = decoded
    }

    /// Writes to disk, except while editing: the draft is saved on commit.
    private func save() {
        guard !isEditing else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
