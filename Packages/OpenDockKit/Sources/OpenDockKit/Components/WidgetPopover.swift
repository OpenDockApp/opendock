import SwiftUI

/// How a widget tells the host it is showing UI outside its tile, such as a popover.
/// The dock stays on screen while any widget is presenting, the same way it does in
/// edit mode. The host sets this in the environment; `widgetPopover` reports to it.
public struct WidgetPresentations {
    private let update: (UUID, Bool) -> Void

    public init(update: @escaping (UUID, Bool) -> Void) {
        self.update = update
    }

    public func set(_ id: UUID, presenting: Bool) {
        update(id, presenting)
    }
}

private struct WidgetPresentationsKey: EnvironmentKey {
    static let defaultValue = WidgetPresentations { _, _ in }
}

public extension EnvironmentValues {
    var widgetPresentations: WidgetPresentations {
        get { self[WidgetPresentationsKey.self] }
        set { self[WidgetPresentationsKey.self] = newValue }
    }
}

public extension View {
    /// A popover the dock stays open for. Use it instead of `.popover` in widgets.
    ///
    /// SwiftUI can show a popover a moment after `isPresented` flips, for example
    /// once a context menu has faded out. The host learns about it right away, so
    /// the dock does not auto-hide in between.
    func widgetPopover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> PopoverContent
    ) -> some View {
        modifier(WidgetPopoverModifier(isPresented: isPresented, popoverContent: content))
    }
}

private struct WidgetPopoverModifier<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let popoverContent: () -> PopoverContent

    @Environment(\.widgetPresentations) private var presentations
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isPresented, content: popoverContent)
            .onChange(of: isPresented, initial: true) { _, shown in
                presentations.set(id, presenting: shown)
            }
            .onDisappear { presentations.set(id, presenting: false) }
    }
}
