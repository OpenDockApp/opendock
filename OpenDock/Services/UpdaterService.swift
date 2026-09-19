import AppKit
import Sparkle

/// In-app updates via Sparkle. The feed and EdDSA public key live in Info.plist
/// (`SUFeedURL`, `SUPublicEDKey`). Debug builds have no updates: they are not
/// what the feed ships, so the check is hidden and never runs.
final class UpdaterService {
    #if DEBUG
    static let isAvailable = false
    #else
    static let isAvailable = true
    #endif

    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: Self.isAvailable, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
