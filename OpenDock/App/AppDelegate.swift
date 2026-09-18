import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dockController = DockPanelController()
    let permissions = PermissionCenter()
    private(set) lazy var onboarding = OnboardingWindowController(dock: dockController, permissions: permissions)

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
