import AppKit
import SwiftUI

/// Standard macOS settings window: a preference-style toolbar with an icon and label
/// per pane, and a window that resizes to each pane. Panes are SwiftUI views.
final class SettingsWindowController {
    private var window: NSWindow?
    private let dock: DockPanelController
    private let systemDock: SystemDockManager
    private let updater: UpdaterService

    init(dock: DockPanelController, systemDock: SystemDockManager, updater: UpdaterService) {
        self.dock = dock
        self.systemDock = systemDock
        self.updater = updater
    }

    func show() {
        if window == nil {
            window = makeWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeWindow() -> NSWindow {
        let tabs = InstantResizeTabViewController()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = []
        tabs.canPropagateSelectedChildViewControllerTitle = true

        tabs.addTabViewItem(pane("General", symbol: "gearshape", GeneralSettingsPane()))
        tabs.addTabViewItem(pane("Widgets", symbol: "square.grid.2x2", WidgetsSettingsPane()))
        tabs.addTabViewItem(pane("About", symbol: "info.circle", AboutSettingsPane(checkForUpdates: { [updater] in updater.checkForUpdates() })))

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

/// Switches panes with no crossfade and snaps the window to the new pane's height
/// before it appears, instead of AppKit's slow animated resize.
private final class InstantResizeTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let window = view.window, let pane = tabViewItem?.viewController {
            let size = pane.preferredContentSize == .zero ? pane.view.fittingSize : pane.preferredContentSize
            var frame = window.frameRect(forContentRect: CGRect(origin: .zero, size: size))
            // Keep the top edge fixed, as macOS settings windows do.
            frame.origin = CGPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
            window.setFrame(frame, display: true, animate: false)
        }
        super.tabView(tabView, willSelect: tabViewItem)
    }
}
