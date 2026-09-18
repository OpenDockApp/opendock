import Foundation
import Observation

/// Central catalog of every widget type the app can instantiate.
/// Native widgets register at launch. Script widgets (Phase 2) register when loaded.
@Observable
public final class WidgetRegistry {
    public static let shared = WidgetRegistry()

    public private(set) var widgets: [String: AnyDockWidget] = [:]

    public init() {}

    public func register<W: DockWidget>(_ type: W.Type) {
        let widget = AnyDockWidget(type)
        precondition(widgets[widget.id] == nil, "Duplicate widget id: \(widget.id)")
        widgets[widget.id] = widget
    }

    public func register(_ widget: AnyDockWidget) {
        widgets[widget.id] = widget
    }

    public func unregister(id: String) {
        widgets[id] = nil
    }

    public func widget(for id: String) -> AnyDockWidget? {
        widgets[id]
    }

    /// Descriptors sorted by category then name, for the library UI.
    public var descriptors: [WidgetDescriptor] {
        widgets.values.map(\.descriptor).sorted {
            ($0.category.rawValue, $0.name) < ($1.category.rawValue, $1.name)
        }
    }
}
