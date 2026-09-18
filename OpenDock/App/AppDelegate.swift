import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dockController = DockPanelController()
    let permissions = PermissionCenter()
    let systemDock = SystemDockManager()
    private(set) lazy var onboarding = OnboardingWindowController(
        dock: dockController, permissions: permissions, systemDock: systemDock
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        dockController.show()
        if !OnboardingWindowController.hasCompleted {
            onboarding.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
