import AppKit
import SwiftUI

/// Hosts the SwiftUI settings view in a regular AppKit window.
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
            let root = SettingsView()
                .environment(dock.layout)
                .environment(dock)
                .environment(systemDock)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            window.title = "OpenDock Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
