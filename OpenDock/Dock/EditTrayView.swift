import SwiftUI
import OpenDockKit

/// Glass tray shown above the dock in edit mode. Lists every widget as a live preview
/// to drag into the dock, accepts tiles dragged back to remove them, and holds the
/// Cancel and OK buttons.
struct EditTrayView: View {
    let layout: DockLayoutStore
    let theme: DockTheme

    @State private var isRemoveTarget = false
    private let registry = WidgetRegistry.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.barCornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            header
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(registry.descriptors) { descriptor in
                        TrayItem(descriptor: descriptor, theme: theme) {
                            layout.add(descriptor)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .frame(width: 520)
        .overlay {
            if isRemoveTarget {
                shape
                    .strokeBorder(.red, lineWidth: 2)
                    .overlay {
                        Label("Drop to remove", systemImage: "trash")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.red, in: Capsule())
                            .foregroundStyle(.white)
                    }
            }
        }
        .glassEffect(.regular, in: shape)
        .dropDestination(for: String.self) { strings, _ in
            guard let raw = strings.first, case .placedItem(let id)? = DockDragPayload(raw) else { return false }
            layout.remove(id)
            return true
        } isTargeted: { isRemoveTarget = $0 }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Edit Dock")
                    .font(.headline)
                Text("Drag widgets into the dock. Drag a tile here to remove it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Cancel") { layout.cancelEditing() }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
            Button("OK") { layout.commitEditing() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}

/// A live, non-interactive preview of one widget type. Drag it into the dock, or click to add at the end.
private struct TrayItem: View {
    let descriptor: WidgetDescriptor
    let theme: DockTheme
    let onAdd: () -> Void

    @State private var previewID = UUID()

    var body: some View {
        VStack(spacing: 6) {
            preview
            Text(descriptor.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onAdd)
        .draggable(DockDragPayload.newWidget(id: descriptor.id).encoded) {
            preview
        }
        .help(descriptor.summary)
    }

    private var preview: some View {
        WidgetTile(size: descriptor.defaultSize) {
            if let widget = WidgetRegistry.shared.widget(for: descriptor.id) {
                widget.view(context: WidgetContext(
                    size: descriptor.defaultSize,
                    instanceID: previewID,
                    theme: theme,
                    isEditing: true,
                    services: .live
                ))
                .allowsHitTesting(false)
            }
        }
        .environment(\.dockTheme, theme)
    }
}
