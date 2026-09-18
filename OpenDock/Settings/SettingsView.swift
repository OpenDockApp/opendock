import SwiftUI
import OpenDockKit

struct SettingsView: View {
    @Environment(DockLayoutStore.self) private var layout

    var body: some View {
        TabView {
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
                Toggle("Edit mode", isOn: $layout.isEditing)
                Button("Reset to defaults") { layout.reset() }
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
