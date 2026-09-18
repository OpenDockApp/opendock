import Foundation
import OpenDockKit

/// One placed widget in the dock.
struct DockItem: Identifiable, Codable, Hashable {
    var id: UUID
    var widgetID: String
    var size: WidgetSize

    init(id: UUID = UUID(), widgetID: String, size: WidgetSize) {
        self.id = id
        self.widgetID = widgetID
        self.size = size
    }
}
