import SwiftUI
import OpenDockKit

/// Consistent popover typography and spacing for first-party widgets.
struct WidgetDetails<Content: View>: View {
    @Environment(\.dockTheme) private var theme
    let title: String
    let symbol: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: theme.scaled(12)) {
            Label(title, systemImage: symbol).font(theme.statFont)
            content()
        }
        .font(theme.titleFont)
        .padding(theme.scaled(18))
        .frame(width: theme.scaled(280))
    }
}
