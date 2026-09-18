import SwiftUI
import OpenDockKit

struct SettingsView: View {
    @Environment(DockLayoutStore.self) private var layout

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
            Tab("Widgets", systemImage: "square.grid.2x2") {
                WidgetLibraryView()
            }
            Tab("About", systemImage: "info.circle") {
                AboutView()
            }
        }
        .frame(width: 480, height: 400)
    }
}

/// Lists every registered widget with an add button and shows what is in the dock.
private struct WidgetLibraryView: View {
    @Environment(DockLayoutStore.self) private var layout
    private let registry = WidgetRegistry.shared

    var body: some View {
        @Bindable var layout = layout
        Form {
            Section("Library") {
                ForEach(registry.descriptors) { descriptor in
                    HStack {
                        Image(systemName: descriptor.symbol)
                            .frame(width: 22)
                        VStack(alignment: .leading) {
                            Text(descriptor.name)
                            Text(descriptor.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Add") { layout.add(descriptor) }
                    }
                }
            }
            Section("In the dock") {
                if layout.items.isEmpty {
                    Text("No widgets yet.").foregroundStyle(.secondary)
                }
                ForEach(layout.items) { item in
                    HStack {
                        Text(registry.widget(for: item.widgetID)?.descriptor.name ?? item.widgetID)
                        Spacer()
                        Text(item.size.displayName)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            layout.remove(item.id)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Edit Dock…") { layout.beginEditing() }
                Button("Reset to defaults") { layout.reset() }
            }
        }
        .formStyle(.grouped)
    }
}

private struct GeneralSettingsView: View {
    @Environment(DockPanelController.self) private var controller
    @Environment(SystemDockManager.self) private var systemDock
    @State private var edge: SystemDockManager.Edge = .left

    var body: some View {
        @Bindable var controller = controller
        Form {
            Toggle("Automatically hide and show the dock", isOn: $controller.autoHide)
            LabeledContent("Distance from bottom") {
                HStack {
                    Slider(value: $controller.bottomGap, in: DockPanelController.bottomGapRange, step: 1)
                        .frame(width: 180)
                    Text("\(Int(controller.bottomGap)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            Section {
                if systemDock.isTuckedAway {
                    LabeledContent("System Dock is moved aside") {
                        Button("Restore") { systemDock.restore() }
                    }
                } else {
                    Picker("Move system Dock to", selection: $edge) {
                        Text("Left").tag(SystemDockManager.Edge.left)
                        Text("Right").tag(SystemDockManager.Edge.right)
                    }
                    Button("Move Aside and Auto-hide") { systemDock.tuckAway(to: edge) }
                }
                if let error = systemDock.lastError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            } header: {
                Text("System Dock")
            } footer: {
                Text("The system Dock also appears when the pointer reaches the bottom edge. Moving it to a side stops the two from overlapping.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dock.rectangle")
                .font(.system(size: 48))
            Text("OpenDock")
                .font(.title.bold())
            Text("An open-source widget dock for macOS.")
                .foregroundStyle(.secondary)
            Link("github.com/mxvsh/OpenDock", destination: URL(string: "https://github.com/mxvsh/OpenDock")!)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
