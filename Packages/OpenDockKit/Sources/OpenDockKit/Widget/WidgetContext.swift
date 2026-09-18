import SwiftUI

/// Everything a widget receives from the host when it renders.
public struct WidgetContext {
    /// The size the user picked for this instance.
    public let size: WidgetSize
    /// Stable per-instance identifier. Use it to key persisted state.
    public let instanceID: UUID
    public let theme: DockTheme
    public let isEditing: Bool
    public let services: HostServices

    public init(
        size: WidgetSize,
        instanceID: UUID,
        theme: DockTheme = .standard,
        isEditing: Bool = false,
        services: HostServices
    ) {
        self.size = size
        self.instanceID = instanceID
        self.theme = theme
        self.isEditing = isEditing
        self.services = services
    }

    /// Pixel size of the tile for the current `size`.
    public var frame: CGSize {
        theme.frame(for: size)
    }
}
