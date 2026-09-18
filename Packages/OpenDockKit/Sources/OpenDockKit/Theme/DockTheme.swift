import SwiftUI

/// Layout and color tokens shared by the dock and every widget.
public struct DockTheme: Sendable {
    public var cellSize: CGFloat
    public var spacing: CGFloat
    public var padding: CGFloat
    public var barCornerRadius: CGFloat
    public var tileCornerRadius: CGFloat
    public var accent: Color

    public init(
        cellSize: CGFloat = 108,
        spacing: CGFloat = 10,
        padding: CGFloat = 12,
        barCornerRadius: CGFloat = 34,
        tileCornerRadius: CGFloat = 22,
        accent: Color = .accentColor
    ) {
        self.cellSize = cellSize
        self.spacing = spacing
        self.padding = padding
        self.barCornerRadius = barCornerRadius
        self.tileCornerRadius = tileCornerRadius
        self.accent = accent
    }

    public static let standard = DockTheme()

    public func frame(for size: WidgetSize) -> CGSize {
        CGSize(
            width: cellSize * CGFloat(size.columns) + spacing * CGFloat(size.columns - 1),
            height: cellSize * CGFloat(size.rows) + spacing * CGFloat(size.rows - 1)
        )
    }

    // Typography presets used across widgets so numbers and captions match.
    public var statFont: Font { .system(size: 30, weight: .semibold, design: .rounded) }
    public var titleFont: Font { .system(size: 14, weight: .semibold) }
    public var captionFont: Font { .system(size: 11, weight: .medium) }
    public var monoFont: Font { .system(size: 28, weight: .semibold, design: .rounded).monospacedDigit() }
}

private struct DockThemeKey: EnvironmentKey {
    static let defaultValue = DockTheme.standard
}

public extension EnvironmentValues {
    var dockTheme: DockTheme {
        get { self[DockThemeKey.self] }
        set { self[DockThemeKey.self] = newValue }
    }
}
