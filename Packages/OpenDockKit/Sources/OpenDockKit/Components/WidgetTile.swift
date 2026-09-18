import SwiftUI

/// The container every widget sits in. The dock bar is Liquid Glass; tiles are a
/// subtle inset surface on top of it so content stays legible and glass never
/// samples glass.
public struct WidgetTile<Content: View>: View {
    @Environment(\.dockTheme) private var theme
    @Environment(\.colorScheme) private var scheme

    private let size: WidgetSize
    private let content: Content

    public init(size: WidgetSize, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    public var body: some View {
        let frame = theme.frame(for: size)
        let shape = RoundedRectangle(cornerRadius: theme.tileCornerRadius, style: .continuous)
        content
            .frame(width: frame.width, height: frame.height)
            .background {
                shape.fill(scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05))
            }
            .overlay {
                shape.strokeBorder(
                    scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
                    lineWidth: 0.5
                )
            }
            .clipShape(shape)
            .contentShape(shape)
    }
}
