import SwiftUI
import UniformTypeIdentifiers
import OpenDockKit

/// The glass bar. Lays out widget tiles in a single row on the size grid.
struct DockView: View {
    /// Transparent room around the bar so the panel shadow is not clipped.
    /// The controller offsets the panel by this amount so it does not add to the gap.
    static let shadowMargin: CGFloat = 12

    let controller: DockPanelController

    private var layout: DockLayoutStore { controller.layout }
    private var theme: DockTheme { controller.theme }

    var body: some View {
        VStack(spacing: 10) {
            if layout.isEditing {
                EditTrayView(layout: layout, theme: theme)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            bar
        }
        .padding(Self.shadowMargin)
        .environment(\.dockTheme, theme)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            controller.contentSizeChanged(size)
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: layout.items)
        .animation(.easeInOut(duration: 0.2), value: layout.isEditing)
    }

    private var bar: some View {
        let shape = RoundedRectangle(cornerRadius: theme.barCornerRadius, style: .continuous)
        return HStack(alignment: .top, spacing: theme.spacing) {
            ForEach(layout.items) { item in
                DockTileView(item: item, layout: layout, theme: theme, isLive: controller.isLive)
            }
            if layout.items.isEmpty {
                emptyState
            }
        }
        .padding(theme.padding)
        .overlay {
            if isBarDropTarget {
                shape.strokeBorder(theme.accent.opacity(0.8), lineWidth: 2)
            }
        }
        .glassEffect(.regular, in: shape)
        // Drops that land on the bar but not on a tile go to the end.
        .dropDestination(for: String.self) { strings, _ in
            layout.handleDrop(strings, before: nil)
        } isTargeted: { isBarDropTarget = $0 }
    }

    @State private var isBarDropTarget = false

    private var emptyState: some View {
        Button {
            layout.beginEditing()
        } label: {
            Label(layout.isEditing ? "Drag widgets here" : "Add Widgets", systemImage: "plus.circle")
                .font(theme.titleFont)
                .foregroundStyle(.secondary)
                .frame(width: theme.cellSize * 3, height: theme.cellSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(layout.isEditing)
    }
}

/// One tile with edit-mode chrome (remove button, drag to reorder).
private struct DockTileView: View {
    let item: DockItem
    let layout: DockLayoutStore
    let theme: DockTheme
    /// False while the dock is off screen; widget views are torn down to stop updates.
    let isLive: Bool

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
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.red))
                }
                .buttonStyle(.plain)
                .offset(x: -4, y: -4)
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
            if !layout.isEditing {
                Button("Edit Widgets…") { layout.beginEditing() }
            }
            Divider()
            Button("Remove", role: .destructive) {
                // Outside edit mode a removal is saved immediately.
                layout.remove(item.id)
            }
        }
        .modifier(EditModeWiggle(active: layout.isEditing))
        .draggable(DockDragPayload.placedItem(id: item.id).encoded) {
            WidgetTile(size: item.size) { widgetBody }
                .environment(\.dockTheme, theme)
        }
        .dropDestination(for: String.self) { strings, _ in
            layout.handleDrop(strings, before: item.id)
        } isTargeted: { isDropTarget = $0 }
    }

    @ViewBuilder
    private var widgetBody: some View {
        if !isLive {
            Color.clear
        } else {
            liveWidgetBody
        }
    }

    @ViewBuilder
    private var liveWidgetBody: some View {
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
