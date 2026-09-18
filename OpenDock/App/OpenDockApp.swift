import SwiftUI
import OpenDockKit
import OpenDockWidgets

@main
struct OpenDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        OpenDockWidgets.registerAll()
    }

    var body: some Scene {
        MenuBarExtra("OpenDock", systemImage: "dock.rectangle") {
            MenuBarMenu(controller: delegate.dockController)
        }

        Settings {
            SettingsView()
                .environment(delegate.dockController.layout)
                .environment(delegate.dockController)
        }
    }
}

private struct MenuBarMenu: View {
    @Environment(\.openSettings) private var openSettings
    let controller: DockPanelController

    var body: some View {
        Button(controller.isVisible ? "Hide Dock" : "Show Dock") {
            controller.toggleVisibility()
        }
        .keyboardShortcut("d", modifiers: [.command, .option])

        Toggle("Automatically Hide Dock", isOn: Binding(
            get: { controller.autoHide },
            set: { controller.autoHide = $0 }
        ))

        Button(controller.layout.isEditing ? "Done Editing" : "Edit Widgets") {
            controller.layout.isEditing.toggle()
        }
        .keyboardShortcut("e", modifiers: [.command, .option])

        Menu("Add Widget") {
            ForEach(WidgetRegistry.shared.descriptors) { descriptor in
                Button(descriptor.name) {
                    controller.layout.add(descriptor)
                }
            }
        }

        Divider()

        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Quit OpenDock") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
