import Foundation
import ServiceManagement

/// Registers the app as a login item using the modern SMAppService API.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("OpenDock: launch at login change failed: \(error.localizedDescription)")
        }
    }
}
