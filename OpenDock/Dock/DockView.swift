import SwiftUI
import UniformTypeIdentifiers
import OpenDockKit

/// The glass bar. Lays out widget tiles in a single row on the size grid.
struct DockView: View {
    let controller: DockPanelController

    private var layout: DockLayoutStore { controller.layout }
    private var theme: DockTheme { controller.theme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.barCornerRadius, style: .continuous)
        HStack(alignment: .top, spacing: theme.spacing) {
            ForEach(layout.items) { item in
                DockTileView(item: item, layout: layout, theme: theme)
            }
            if layout.items.isEmpty {
                emptyState
            }
        }
        .padding(theme.padding)
        .glassEffect(.regular, in: shape)
        .padding(20) // room for the panel shadow
        .environment(\.dockTheme, theme)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            controller.contentSizeChanged(size)
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: layout.items)
        .animation(.easeInOut(duration: 0.2), value: layout.isEditing)
    }

    private var emptyState: some View {
        Label("Add widgets from the menu bar", systemImage: "plus.circle")
            .font(theme.titleFont)
            .foregroundStyle(.secondary)
            .frame(width: theme.cellSize * 3, height: theme.cellSize)
    }
}

/// One tile with edit-mode chrome (remove button, drag to reorder).
private struct DockTileView: View {
    let item: DockItem
    let layout: DockLayoutStore
    let theme: DockTheme

    @State private var isDropTarget = false

    var body: some View {
        WidgetTile(size: item.size) {
            widgetBody
        }
        .overlay(alignment: .topLeading) {
            if layout.isEditing {
                Button {
                    layout.remove(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.red))
                }
                .buttonStyle(.plain)
                .offset(x: -5, y: -5)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: theme.tileCornerRadius, style: .continuous)
                    .strokeBorder(theme.accent, lineWidth: 2)
            }
        }
        .contextMenu {
            if let descriptor = WidgetRegistry.shared.widget(for: item.widgetID)?.descriptor,
               descriptor.supportedSizes.count > 1 {
                Picker("Size", selection: Binding(
                    get: { item.size },
                    set: { layout.resize(item.id, to: $0) }
                )) {
                    ForEach(descriptor.supportedSizes, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
            }
            Button("Remove", role: .destructive) { layout.remove(item.id) }
        }
        .modifier(EditModeWiggle(active: layout.isEditing))
        .draggable(item.id.uuidString)
        .dropDestination(for: String.self) { ids, _ in
            guard let raw = ids.first, let id = UUID(uuidString: raw) else { return false }
            layout.move(id, before: item.id)
            return true
        } isTargeted: { isDropTarget = $0 }
    }

    @ViewBuilder
    private var widgetBody: some View {
        if let widget = WidgetRegistry.shared.widget(for: item.widgetID) {
            widget.view(context: WidgetContext(
                size: item.size,
                instanceID: item.id,
                theme: theme,
                isEditing: layout.isEditing,
                services: .live
            ))
            .allowsHitTesting(!layout.isEditing)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "questionmark.square.dashed")
                    .font(.title2)
                Text("Missing widget")
                    .font(theme.captionFont)
            }
            .foregroundStyle(.secondary)
        }
    }
}

/// Subtle scale pulse in edit mode so the user knows tiles are movable.
private struct EditModeWiggle: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 0.96 : 1)
    }
}
