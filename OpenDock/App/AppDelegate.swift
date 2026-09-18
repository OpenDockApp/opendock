import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dockController = DockPanelController()
    let permissions = PermissionCenter()
    let systemDock = SystemDockManager()

    private(set) lazy var onboarding = OnboardingWindowController(
        dock: dockController, permissions: permissions, systemDock: systemDock
    )
    private(set) lazy var settings = SettingsWindowController(
        dock: dockController, systemDock: systemDock
    )
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenuController(
            dock: dockController,
            showSettings: { [unowned self] in settings.show() },
            showOnboarding: { [unowned self] in onboarding.show() }
        )
        dockController.show()
        if !OnboardingWindowController.hasCompleted {
            onboarding.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
