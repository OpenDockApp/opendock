import AppKit
import OpenDockWidgets

/// Entry point. OpenDock runs on the AppKit lifecycle; SwiftUI is used inside windows
/// only. This keeps the status menu a plain NSMenu, because SwiftUI's MenuBarExtra
/// menus lag on hover.
@main
enum OpenDockMain {
    /// NSApplication holds its delegate weakly, so keep it alive here.
    private static var delegate: AppDelegate?

    static func main() {
        OpenDockWidgets.registerAll()

        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
