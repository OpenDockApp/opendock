import AppKit
import Observation

/// Moves the system Dock out of OpenDock's way and puts it back.
///
/// A sandboxed app cannot disable the system Dock, but System Events can change
/// its screen edge and auto-hide. Moving it to a side edge stops it from popping
/// up when the pointer reaches the bottom of the screen. The first use asks for
/// Automation permission.
@Observable
final class SystemDockManager {
    enum Edge: String, CaseIterable, Identifiable {
        case left, right, bottom
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    private struct Snapshot: Codable {
        var autohide: Bool
        var edge: String
    }

    private(set) var isTuckedAway: Bool = UserDefaults.standard.data(forKey: Keys.snapshot) != nil
    private(set) var lastError: String?

    private enum Keys {
        static let snapshot = "systemDock.snapshot"
    }

    /// Auto-hide the system Dock and move it to a side edge. Remembers the old settings.
    func tuckAway(to edge: Edge = .left) {
        guard let current = readCurrent() else { return }
        if !isTuckedAway, let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: Keys.snapshot)
        }
        guard apply(autohide: true, edge: edge.rawValue) else { return }
        isTuckedAway = true
    }

    /// Restore the system Dock to how it was before `tuckAway`.
    func restore() {
        guard let data = UserDefaults.standard.data(forKey: Keys.snapshot),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            isTuckedAway = false
            return
        }
        guard apply(autohide: snapshot.autohide, edge: snapshot.edge) else { return }
        UserDefaults.standard.removeObject(forKey: Keys.snapshot)
        isTuckedAway = false
    }

    // MARK: AppleScript

    private func readCurrent() -> Snapshot? {
        let source = """
        tell application "System Events" to tell dock preferences
            return {autohide, screen edge as text}
        end tell
        """
        guard let result = run(source), result.numberOfItems == 2,
              let edge = result.atIndex(2)?.stringValue else { return nil }
        let autohide = result.atIndex(1)?.booleanValue ?? false
        // `screen edge as text` returns "left", "right" or "bottom".
        return Snapshot(autohide: autohide, edge: edge)
    }

    private func apply(autohide: Bool, edge: String) -> Bool {
        guard Edge(rawValue: edge) != nil else { return false }
        let source = """
        tell application "System Events" to tell dock preferences
            set autohide to \(autohide)
            set screen edge to \(edge)
        end tell
        """
        return run(source) != nil
    }

    @discardableResult
    private func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int
            lastError = code == -1743
                ? "OpenDock needs Automation access to System Events. Allow it in System Settings › Privacy & Security › Automation."
                : (error[NSAppleScript.errorMessage] as? String ?? "Could not change the system Dock.")
            return nil
        }
        lastError = nil
        return result
    }
}
