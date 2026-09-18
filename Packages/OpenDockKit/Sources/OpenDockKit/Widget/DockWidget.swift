import SwiftUI

/// A native widget. Conform, register with `WidgetRegistry`, and the dock can show it.
///
/// ```swift
/// struct ClockWidget: DockWidget {
///     static let descriptor = WidgetDescriptor(id: "dev.opendock.clock", ...)
///     func body(context: WidgetContext) -> some View { ... }
/// }
/// ```
///
/// Keep per-instance state inside the returned view using `@State`.
/// The struct itself is recreated freely by the host.
public protocol DockWidget {
    static var descriptor: WidgetDescriptor { get }
    associatedtype Body: View
    init()
    @ViewBuilder func body(context: WidgetContext) -> Body
}

/// Type-erased widget factory stored in the registry.
public struct AnyDockWidget: Identifiable {
    public let descriptor: WidgetDescriptor
    private let make: (WidgetContext) -> AnyView

    public var id: String { descriptor.id }

    public init<W: DockWidget>(_ type: W.Type) {
        descriptor = W.descriptor
        make = { context in AnyView(W().body(context: context)) }
    }

    public func view(context: WidgetContext) -> AnyView {
        make(context)
    }
}
