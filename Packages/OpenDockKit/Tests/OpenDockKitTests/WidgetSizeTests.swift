import Testing
@testable import OpenDockKit

@Suite struct WidgetSizeTests {
    @Test func gridDimensions() {
        #expect(WidgetSize.small.columns == 1 && WidgetSize.small.rows == 1)
        #expect(WidgetSize.medium.columns == 2 && WidgetSize.medium.rows == 1)
        #expect(WidgetSize.large.columns == 2 && WidgetSize.large.rows == 2)
        #expect(WidgetSize.wide.columns == 3 && WidgetSize.wide.rows == 1)
    }

    @Test func themeFrameIncludesSpacing() {
        let theme = DockTheme(cellSize: 100, spacing: 10)
        #expect(theme.frame(for: .wide) == CGSize(width: 320, height: 100))
        #expect(theme.frame(for: .large) == CGSize(width: 210, height: 210))
    }

    @Test func registryRoundTrip() {
        struct Dummy: DockWidget {
            static let descriptor = WidgetDescriptor(id: "test.dummy", name: "Dummy", summary: "", symbol: "circle", category: .utilities, supportedSizes: [.small])
            func body(context: WidgetContext) -> some View { EmptyView() }
        }
        let registry = WidgetRegistry()
        registry.register(Dummy.self)
        #expect(registry.widget(for: "test.dummy")?.descriptor.name == "Dummy")
        #expect(registry.descriptors.count == 1)
    }
}
import SwiftUI
