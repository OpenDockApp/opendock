import AppKit
import SwiftUI

/// Shows the onboarding flow on first launch and whenever the user asks for it again.
final class OnboardingWindowController {
    static let completedKey = "onboarding.completed"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    private var window: NSWindow?
    private let dock: DockPanelController
    private let permissions: PermissionCenter
    private let systemDock: SystemDockManager

    init(dock: DockPanelController, permissions: PermissionCenter, systemDock: SystemDockManager) {
        self.dock = dock
        self.permissions = permissions
        self.systemDock = systemDock
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let root = OnboardingView(dock: dock, permissions: permissions, systemDock: systemDock) { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.completedKey)
            self?.close()
        }
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func close() {
        window?.close()
        window = nil
    }
}
