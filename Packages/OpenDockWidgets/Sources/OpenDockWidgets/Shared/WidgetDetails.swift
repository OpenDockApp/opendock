import SwiftUI
import OpenDockKit

/// Consistent popover typography and spacing for first-party widgets.
struct WidgetDetails<Content: View>: View {
    @Environment(\.dockTheme) private var theme
    let title: String
    let symbol: String
    /// Reference width, scaled by the theme. Wider for grids of content.
    var width: CGFloat = 280
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: theme.scaled(12)) {
            Label(title, systemImage: symbol).font(theme.statFont)
            content()
        }
        .font(theme.titleFont)
        .padding(theme.scaled(18))
        .frame(width: theme.scaled(width))
    }
}
