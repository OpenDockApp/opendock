import AppKit

/// Borderless, non-activating panel that floats above every window on every Space.
final class DockPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        // The window shadow traces the transparent window's outline as a dark stroke
        // around the whole content. Liquid Glass draws its own shadow instead.
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .utilityWindow
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
