import Foundation

/// The size grid every widget snaps to. One cell is `DockTheme.cellSize` points.
public enum WidgetSize: String, Codable, CaseIterable, Sendable, Hashable {
    case small   // 1x1
    case medium  // 2x1
    case large   // 2x2
    case wide    // 3x1

    public var columns: Int {
        switch self {
        case .small: 1
        case .medium, .large: 2
        case .wide: 3
        }
    }

    public var rows: Int {
        self == .large ? 2 : 1
    }

    public var displayName: String {
        rawValue.capitalized
    }
}
