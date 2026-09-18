import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let dockController = DockPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        dockController.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
