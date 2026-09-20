import AppKit
import CoreLocation
import EventKit
import Observation
import OpenDockKit

/// Tracks and requests the optional system permissions that some widgets need.
/// Nothing in the core dock requires any of these.
@Observable
final class PermissionCenter: NSObject {
    enum Kind: String, CaseIterable, Identifiable {
        case calendars, reminders, location

        var id: String { rawValue }

        var title: String {
            switch self {
            case .calendars: "Calendars"
            case .reminders: "Reminders"
            case .location: "Location"
            }
        }

        var reason: String {
            switch self {
            case .calendars: "Show upcoming events in calendar widgets."
            case .reminders: "Show and check off tasks in reminders widgets."
            case .location: "Get local forecasts for weather widgets."
            }
        }

        var symbol: String {
            switch self {
            case .calendars: "calendar"
            case .reminders: "checklist"
            case .location: "location.fill"
            }
        }

        var tint: NSColor {
            switch self {
            case .calendars: .systemRed
            case .reminders: .systemOrange
            case .location: .systemBlue
            }
        }

        /// Deep link into the matching Privacy & Security pane.
        var settingsURL: URL {
            let anchor = switch self {
            case .calendars: "Privacy_Calendars"
            case .reminders: "Privacy_Reminders"
            case .location: "Privacy_LocationServices"
            }
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        }
    }

    enum Status {
        case notDetermined, granted, denied

        var label: String {
            switch self {
            case .notDetermined: "Not set"
            case .granted: "Allowed"
            case .denied: "Denied"
            }
        }
    }

    private(set) var statuses: [Kind: Status] = [:]

    private let eventStore = EKEventStore()
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        refresh()
    }

    func status(_ kind: Kind) -> Status {
        statuses[kind] ?? .notDetermined
    }

    func refresh() {
        statuses[.calendars] = Self.map(EKEventStore.authorizationStatus(for: .event))
        statuses[.reminders] = Self.map(EKEventStore.authorizationStatus(for: .reminder))
        statuses[.location] = Self.map(locationManager.authorizationStatus)
    }

    /// Asks the system for access, or opens System Settings if the user already declined.
    func request(_ kind: Kind) {
        if status(kind) == .denied {
            NSWorkspace.shared.open(kind.settingsURL)
            return
        }
        switch kind {
        case .calendars:
            Task {
                _ = try? await eventStore.requestFullAccessToEvents()
                refresh()
            }
        case .reminders:
            Task {
                _ = try? await eventStore.requestFullAccessToReminders()
                refresh()
            }
        case .location:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private static func map(_ status: EKAuthorizationStatus) -> Status {
        switch status {
        case .fullAccess, .writeOnly: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private static func map(_ status: CLAuthorizationStatus) -> Status {
        switch status {
        case .authorizedAlways, .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}

extension PermissionCenter: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated { refresh() }
    }
}
