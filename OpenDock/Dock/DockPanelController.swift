import AppKit
import SwiftUI
import OpenDockKit

/// Owns the panel, hosts the SwiftUI dock, anchors it to the bottom center of the
/// primary screen, and drives auto-hide.
@Observable
final class DockPanelController {
    let layout = DockLayoutStore()
    let theme = DockTheme.standard

    /// The user has the dock turned on (menu bar Show/Hide).
    private(set) var isVisible = false

    /// Slide the dock off screen until the pointer touches the bottom edge.
    var autoHide: Bool = UserDefaults.standard.object(forKey: Keys.autoHide) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(autoHide, forKey: Keys.autoHide)
            autoHide ? scheduleHide(after: Timing.hideDelay) : reveal()
        }
    }

    /// Visible gap in points between the bar and the bottom of the screen.
    var bottomGap: Double = UserDefaults.standard.object(forKey: Keys.bottomGap) as? Double ?? DockPanelController.defaultBottomGap {
        didSet {
            UserDefaults.standard.set(bottomGap, forKey: Keys.bottomGap)
            applyFrame(animated: false)
        }
    }

    static let defaultBottomGap: Double = 4
    static let bottomGapRange: ClosedRange<Double> = 0...40

    /// Whether the dock is currently slid in (only meaningful when auto-hide is on).
    private(set) var isRevealed = true

    /// Whether widgets should render and update. False while the dock is off screen,
    /// so clocks, animations and samplers stop instead of burning main-thread time.
    private(set) var isLive = true

    private let panel = DockPanel()
    private var hostingView: NSHostingView<DockView>?
    private var contentSize: CGSize = .zero
    private var hideTask: Task<Void, Never>?
    private var isMenuTracking = false
    private var mouseMonitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var tracker: HoverTracker?
    /// The app that was frontmost when editing began, so keyboard focus can go back to it.
    private var appBeforeEditing: NSRunningApplication?

    private enum Keys {
        static let autoHide = "dock.autoHide"
        static let bottomGap = "dock.bottomGap"
    }

    private enum Timing {
        static let slide: TimeInterval = 0.25
        static let hideDelay: Duration = .milliseconds(400)
        static let revealGrace: Duration = .milliseconds(1200)
    }

    /// How close to the bottom edge the pointer must be to reveal the dock.
    private let revealZone: CGFloat = 2

    init() {
        let host = NSHostingView(rootView: DockView(controller: self))
        host.sizingOptions = [.preferredContentSize]
        panel.contentView = host
        panel.acceptsMouseMovedEvents = true
        hostingView = host

        tracker = HoverTracker(view: host) { [weak self] inside in
            guard let self else { return }
            inside ? self.cancelHide() : self.scheduleHide(after: Timing.hideDelay)
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyFrame(animated: false) }
        })
        observers.append(center.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isMenuTracking = true
                self?.cancelHide()
            }
        })
        observers.append(center.addObserver(
            forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isMenuTracking = false
                self?.scheduleHide(after: Timing.hideDelay)
            }
        })

        installMouseMonitors()
        observeEditing()
    }

    // MARK: Visibility

    func show() {
        isVisible = true
        isRevealed = !autoHide
        applyFrame(animated: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        isVisible = false
        isLive = false
        cancelHide()
        panel.orderOut(nil)
    }

    func toggleVisibility() {
        isVisible ? hide() : show()
    }

    /// Called by the dock view whenever its content size changes.
    func contentSizeChanged(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        contentSize = size
        applyFrame(animated: false)
    }

    // MARK: Auto-hide

    private func reveal() {
        cancelHide()
        guard isVisible, !isRevealed else { return }
        isRevealed = true
        applyFrame(animated: true)
        // If the pointer never moves onto the dock, tuck it away again.
        scheduleHide(after: Timing.revealGrace)
    }

    private func conceal() {
        guard autoHide, isRevealed else { return }
        isRevealed = false
        applyFrame(animated: true)
    }

    private func cancelHide() {
        hideTask?.cancel()
        hideTask = nil
    }

    private func scheduleHide(after delay: Duration) {
        guard autoHide, isRevealed else { return }
        cancelHide()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            if self.shouldStayRevealed {
                self.scheduleHide(after: Timing.hideDelay)
            } else {
                self.conceal()
            }
        }
    }

    private var shouldStayRevealed: Bool {
        layout.isEditing
            || isMenuTracking
            || NSEvent.pressedMouseButtons != 0
            || panel.frame.contains(NSEvent.mouseLocation)
    }

    private func installMouseMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved(to: NSEvent.mouseLocation) }
        }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handler(event)
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    private func mouseMoved(to point: CGPoint) {
        guard autoHide, isVisible, !isRevealed, let screen = dockScreen else { return }
        let rest = restingFrame(on: screen)
        let atBottomEdge = point.y <= screen.frame.minY + revealZone
        let underDock = point.x >= rest.minX && point.x <= rest.maxX
        if atBottomEdge && underDock {
            reveal()
        }
    }

    /// Keep the dock out while editing, tuck it away when editing ends.
    private func observeEditing() {
        layout.onEditingChanged = { [weak self] editing in
            guard let self else { return }
            // While editing, any click on the panel makes it key again (without
            // activating the app) so OK keeps its accent color and Return and Escape
            // reach the buttons. Outside edit mode, clicking a widget leaves focus alone.
            self.panel.becomesKeyOnlyIfNeeded = !editing
            if editing {
                self.reveal()
                self.appBeforeEditing = NSWorkspace.shared.frontmostApplication
                self.panel.makeKey()
            } else {
                if let app = self.appBeforeEditing, app != NSRunningApplication.current {
                    app.activate()
                }
                self.appBeforeEditing = nil
                self.scheduleHide(after: Timing.hideDelay)
            }
        }
    }

    // MARK: Geometry

    /// The dock lives on the screen with the menu bar, like the system Dock's default.
    private var dockScreen: NSScreen? {
        NSScreen.screens.first
    }

    private var currentSize: CGSize {
        contentSize == .zero ? (hostingView?.fittingSize ?? panel.frame.size) : contentSize
    }

    private func restingFrame(on screen: NSScreen) -> CGRect {
        let size = currentSize
        return CGRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.minY + CGFloat(bottomGap) - DockView.shadowMargin,
            width: size.width,
            height: size.height
        )
    }

    private func hiddenFrame(on screen: NSScreen) -> CGRect {
        var frame = restingFrame(on: screen)
        frame.origin.y = screen.frame.minY - frame.height
        return frame
    }

    private func applyFrame(animated: Bool) {
        guard let screen = dockScreen else { return }
        let shown = !autoHide || isRevealed
        let target = shown ? restingFrame(on: screen) : hiddenFrame(on: screen)
        let alpha: CGFloat = shown ? 1 : 0

        // Go live before sliding in; stop only after sliding out finishes.
        if shown { isLive = isVisible }

        guard animated else {
            panel.setFrame(target, display: true)
            panel.alphaValue = alpha
            if !shown { isLive = false }
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Timing.slide
            context.timingFunction = CAMediaTimingFunction(name: shown ? .easeOut : .easeIn)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = alpha
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // Skip if the dock was revealed again while sliding out.
                guard let self, !shown, self.autoHide, !self.isRevealed else { return }
                self.isLive = false
            }
        }
    }
}

/// Reports pointer enter/exit on a view even when the app is not active.
private final class HoverTracker: NSResponder {
    private let onChange: (Bool) -> Void

    init(view: NSView, onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init()
        view.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func mouseEntered(with event: NSEvent) { onChange(true) }
    override func mouseExited(with event: NSEvent) { onChange(false) }
}
