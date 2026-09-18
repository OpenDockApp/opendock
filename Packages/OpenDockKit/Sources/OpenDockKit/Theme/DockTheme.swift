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
        cellSize: CGFloat = 64,
        spacing: CGFloat = 6,
        padding: CGFloat = 6,
        barCornerRadius: CGFloat = 22,
        tileCornerRadius: CGFloat = 16,
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

    /// Multiplier relative to the 64pt reference cell. Widgets scale sizes by this
    /// so the whole dock grows or shrinks from `cellSize` alone.
    public var scale: CGFloat { cellSize / 64 }

    /// Inner padding for widget content.
    public var contentPadding: CGFloat { 8 * scale }

    public func scaled(_ value: CGFloat) -> CGFloat { value * scale }

    // Typography presets used across widgets so numbers and captions match.
    public var heroFont: Font { .system(size: 26 * scale, weight: .semibold, design: .rounded).monospacedDigit() }
    public var statFont: Font { .system(size: 18 * scale, weight: .semibold, design: .rounded).monospacedDigit() }
    public var titleFont: Font { .system(size: 11 * scale, weight: .semibold) }
    public var captionFont: Font { .system(size: 9 * scale, weight: .medium) }
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
