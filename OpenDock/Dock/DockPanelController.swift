import AppKit
import SwiftUI
import OpenDockKit

/// Owns the panel, hosts the SwiftUI dock, and keeps the panel sized and anchored
/// to the bottom center of the main screen.
@Observable
final class DockPanelController {
    let layout = DockLayoutStore()
    let theme = DockTheme.standard
    private(set) var isVisible = false

    private let panel = DockPanel()
    private var hostingView: NSHostingView<DockView>?
    private var observers: [NSObjectProtocol] = []

    init() {
        let view = DockView(controller: self)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = [.preferredContentSize]
        panel.contentView = host
        hostingView = host

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        })
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel.orderOut(nil)
        isVisible = false
    }

    func toggleVisibility() {
        isVisible ? hide() : show()
    }

    /// Called by the dock view whenever its content size changes.
    func contentSizeChanged(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        reposition(contentSize: size)
    }

    private func reposition(contentSize: CGSize? = nil) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = contentSize ?? hostingView?.fittingSize ?? panel.frame.size
        let visible = screen.visibleFrame
        let origin = CGPoint(
            x: visible.midX - size.width / 2,
            y: screen.frame.minY + 14
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true, animate: false)
    }
}
