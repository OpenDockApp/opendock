import AppKit

/// The menu bar item. A plain AppKit NSMenu, rebuilt each time it opens so titles
/// and checkmarks reflect the current state.
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let dock: DockPanelController
    private let showSettings: () -> Void
    private let showOnboarding: () -> Void

    init(dock: DockPanelController, showSettings: @escaping () -> Void, showOnboarding: @escaping () -> Void) {
        self.dock = dock
        self.showSettings = showSettings
        self.showOnboarding = showOnboarding
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "OpenDock")
            button.image?.isTemplate = true
        }
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let layout = dock.layout

        menu.addItem(item(dock.isVisible ? "Hide Dock" : "Show Dock", key: "d", modifiers: [.command, .option]) { [dock] in
            dock.toggleVisibility()
        })

        let autoHide = item("Automatically Hide Dock") { [dock] in
            dock.autoHide.toggle()
        }
        autoHide.state = dock.autoHide ? .on : .off
        menu.addItem(autoHide)

        if layout.isEditing {
            menu.addItem(item("Save Changes") { layout.commitEditing() })
            menu.addItem(item("Discard Changes") { layout.cancelEditing() })
        } else {
            menu.addItem(item("Edit Widgets…", key: "e", modifiers: [.command, .option]) {
                layout.beginEditing()
            })
        }

        menu.addItem(.separator())
        menu.addItem(item("Welcome Guide…") { [showOnboarding] in showOnboarding() })
        menu.addItem(item("Settings…", key: ",") { [showSettings] in showSettings() })
        menu.addItem(item("Quit OpenDock", key: "q") { NSApp.terminate(nil) })
    }

    // MARK: Helpers

    private func item(
        _ title: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = .command,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, keyEquivalent: key, action: action)
        if !key.isEmpty { item.keyEquivalentModifierMask = modifiers }
        return item
    }
}

/// NSMenuItem that runs a closure, so menu actions don't need @objc selectors.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func run() { handler() }
}
