import AppKit
import Foundation

/// Capabilities the host exposes to widgets. Keeps widgets free of AppKit and file APIs.
public struct HostServices {
    public var openURL: (URL) -> Void
    public var openApplication: (URL) -> Void
    public var storage: WidgetStorage
    public var meetings: MeetingService

    public init(
        openURL: @escaping (URL) -> Void,
        openApplication: @escaping (URL) -> Void,
        storage: WidgetStorage,
        meetings: MeetingService = .shared
    ) {
        self.openURL = openURL
        self.openApplication = openApplication
        self.storage = storage
        self.meetings = meetings
    }

    /// Default implementation backed by NSWorkspace and UserDefaults.
    public static let live = HostServices(
        openURL: { NSWorkspace.shared.open($0) },
        openApplication: { url in
            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
        },
        storage: UserDefaultsWidgetStorage()
    )
}

/// Small key-value store scoped per widget instance.
public protocol WidgetStorage {
    func get<T: Codable>(_ key: String, instance: UUID, as type: T.Type) -> T?
    func set<T: Codable>(_ value: T?, for key: String, instance: UUID)
}

public struct UserDefaultsWidgetStorage: WidgetStorage {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func fullKey(_ key: String, _ instance: UUID) -> String {
        "widget.\(instance.uuidString).\(key)"
    }

    public func get<T: Codable>(_ key: String, instance: UUID, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: fullKey(key, instance)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func set<T: Codable>(_ value: T?, for key: String, instance: UUID) {
        let full = fullKey(key, instance)
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: full)
            return
        }
        defaults.set(data, forKey: full)
    }
}
