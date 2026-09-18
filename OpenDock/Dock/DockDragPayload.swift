import Foundation
import OpenDockKit

/// What is being dragged in edit mode, encoded as a plain string so it works with
/// SwiftUI's `draggable` / `dropDestination` for `String`.
enum DockDragPayload: Equatable {
    /// A widget type from the tray, not yet in the dock.
    case newWidget(id: String)
    /// A tile already placed in the dock.
    case placedItem(id: UUID)

    private static let widgetPrefix = "opendock.widget:"
    private static let itemPrefix = "opendock.item:"

    var encoded: String {
        switch self {
        case .newWidget(let id): Self.widgetPrefix + id
        case .placedItem(let id): Self.itemPrefix + id.uuidString
        }
    }

    init?(_ string: String) {
        if string.hasPrefix(Self.widgetPrefix) {
            self = .newWidget(id: String(string.dropFirst(Self.widgetPrefix.count)))
        } else if string.hasPrefix(Self.itemPrefix),
                  let id = UUID(uuidString: String(string.dropFirst(Self.itemPrefix.count))) {
            self = .placedItem(id: id)
        } else {
            return nil
        }
    }
}

extension DockLayoutStore {
    /// Applies a drop onto a tile (`targetID`) or onto the end of the bar (`nil`).
    @discardableResult
    func handleDrop(_ strings: [String], before targetID: UUID?) -> Bool {
        guard let raw = strings.first, let payload = DockDragPayload(raw) else { return false }
        switch payload {
        case .newWidget(let widgetID):
            guard let descriptor = WidgetRegistry.shared.widget(for: widgetID)?.descriptor else { return false }
            insert(descriptor, before: targetID)
        case .placedItem(let id):
            if let targetID {
                move(id, before: targetID)
            } else {
                moveToEnd(id)
            }
        }
        return true
    }
}
