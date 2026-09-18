import Foundation
import Observation
import OpenDockKit

/// The ordered list of widgets in the dock, persisted as JSON in Application Support.
@Observable
final class DockLayoutStore {
    private(set) var items: [DockItem] = []
    var isEditing = false

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
    }

    // MARK: Mutations

    func add(_ descriptor: WidgetDescriptor, size: WidgetSize? = nil) {
        items.append(DockItem(widgetID: descriptor.id, size: size ?? descriptor.defaultSize))
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
            .appending(path: "OpenDock", directoryHint: .isDirectory)
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

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
