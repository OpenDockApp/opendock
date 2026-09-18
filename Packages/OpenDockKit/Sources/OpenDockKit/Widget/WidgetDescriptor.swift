import Foundation

/// Static metadata describing a widget type. Used by the library, settings, and marketplace.
public struct WidgetDescriptor: Identifiable, Hashable, Sendable {
    /// Reverse-DNS identifier, e.g. `dev.opendock.clock`. Must be stable across releases.
    public let id: String
    public let name: String
    public let summary: String
    /// SF Symbol name shown in the widget library.
    public let symbol: String
    public let category: WidgetCategory
    public let supportedSizes: [WidgetSize]
    public let defaultSize: WidgetSize

    public init(
        id: String,
        name: String,
        summary: String,
        symbol: String,
        category: WidgetCategory,
        supportedSizes: [WidgetSize],
        defaultSize: WidgetSize? = nil
    ) {
        precondition(!supportedSizes.isEmpty, "A widget must support at least one size")
        self.id = id
        self.name = name
        self.summary = summary
        self.symbol = symbol
        self.category = category
        self.supportedSizes = supportedSizes
        self.defaultSize = defaultSize ?? supportedSizes[0]
    }
}

public enum WidgetCategory: String, Codable, CaseIterable, Sendable {
    case time, system, productivity, media, weather, finance, social, utilities, developer

    public var displayName: String { rawValue.capitalized }
}
