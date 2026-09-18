import AppKit
import SwiftUI

/// Standard macOS settings window: a preference-style toolbar with an icon and label
/// per pane, and a window that resizes to each pane. Panes are SwiftUI views.
final class SettingsWindowController {
    private var window: NSWindow?
    private let dock: DockPanelController
    private let systemDock: SystemDockManager

    init(dock: DockPanelController, systemDock: SystemDockManager) {
        self.dock = dock
        self.systemDock = systemDock
    }

    func show() {
        if window == nil {
            window = makeWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.crossfade, .allowUserInteraction]
        tabs.canPropagateSelectedChildViewControllerTitle = true

        tabs.addTabViewItem(pane("General", symbol: "gearshape", GeneralSettingsPane()))
        tabs.addTabViewItem(pane("Widgets", symbol: "square.grid.2x2", WidgetsSettingsPane()))
        tabs.addTabViewItem(pane("About", symbol: "info.circle", AboutSettingsPane()))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func pane<Content: View>(_ title: String, symbol: String, _ content: Content) -> NSTabViewItem {
        let root = content
            .environment(dock.layout)
            .environment(dock)
            .environment(systemDock)
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title

        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
