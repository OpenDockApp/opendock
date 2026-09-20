import SwiftUI
import OpenDockKit

/// Glass tray shown above the dock in edit mode. A searchable grid of every widget as a
/// live preview to drag into the dock. It accepts tiles dragged back to remove them, and
/// holds the Cancel and OK buttons.
///
/// The tray keeps a fixed size while searching or filtering, since the panel resizes to
/// fit its content and a changing height would make the dock jump.
struct EditTrayView: View {
    let layout: DockLayoutStore
    let theme: DockTheme

    @State private var isRemoveTarget = false
    @State private var query = ""
    @State private var category: WidgetCategory?
    @FocusState private var searchFocused: Bool
    @State private var fades = EdgeFades()
    private let registry = WidgetRegistry.shared

    private static let columnCount = 4
    private static let gridSpacing: CGFloat = 10

    /// One card slot: room for a medium tile plus the card inset. Larger widgets scale down into it.
    private var slot: CGSize {
        let inset = TrayItem.inset(theme) * 2
        return CGSize(width: theme.frame(for: .medium).width + inset, height: theme.cellSize * 1.25 + inset)
    }

    private var gridWidth: CGFloat {
        slot.width * CGFloat(Self.columnCount) + Self.gridSpacing * CGFloat(Self.columnCount - 1)
    }

    /// Categories that have at least one widget, in their declared order.
    private var categories: [WidgetCategory] {
        let used = Set(registry.descriptors.map(\.category))
        return WidgetCategory.allCases.filter(used.contains)
    }

    private var results: [WidgetDescriptor] {
        let terms = query.split(separator: " ").map(String.init)
        return registry.descriptors.filter { descriptor in
            guard category == nil || descriptor.category == category else { return false }
            let text = "\(descriptor.name) \(descriptor.summary) \(descriptor.category.displayName)"
            return terms.allSatisfy { text.localizedStandardContains($0) }
        }
    }

    /// Sections only help while browsing everything; a search or filter is a flat list.
    private var isBrowsingAll: Bool { query.isEmpty && category == nil }

    /// While searching, Escape and Return belong to the search field, not Cancel and OK.
    private var searchOwnsKeys: Bool { searchFocused || !query.isEmpty }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.barCornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            header
            filters
            grid
        }
        .frame(width: gridWidth)
        // No bottom padding: the grid scrolls to the tray's edge and fades out there.
        .padding([.top, .horizontal], 14)
        .clipShape(shape)
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
                Text("Drag widgets into the dock, or click to add. Drag a tile here to remove it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button("Cancel") { layout.cancelEditing() }
                .buttonStyle(.glass)
                .keyboardShortcut(searchOwnsKeys ? nil : .cancelAction)
            Button("OK") { layout.commitEditing() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(searchOwnsKeys ? nil : .defaultAction)
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
            searchField
            Spacer(minLength: 0)
            // Chips when they fit, otherwise a menu, so the row never scrolls sideways.
            ViewThatFits(in: .horizontal) {
                GlassEffectContainer {
                    HStack(spacing: 6) {
                        chip("All", selected: category == nil) { category = nil }
                        ForEach(categories, id: \.self) { item in
                            chip(item.displayName, selected: category == item) {
                                category = category == item ? nil : item
                            }
                        }
                    }
                }
                .fixedSize()
                Picker("Category", selection: $category) {
                    Text("All Categories").tag(WidgetCategory?.none)
                    Divider()
                    ForEach(categories, id: \.self) { item in
                        Text(item.displayName).tag(Optional(item))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search widgets", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onKeyPress(.escape) {
                    if query.isEmpty { searchFocused = false } else { query = "" }
                    return .handled
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.callout)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .frame(width: 190)
        .background(.quaternary.opacity(0.6), in: Capsule())
    }

    @ViewBuilder
    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        let button = Button(title, action: action).font(.callout).controlSize(.small)
        if selected {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var grid: some View {
        ScrollView(.vertical) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(slot.width), spacing: Self.gridSpacing), count: Self.columnCount),
                alignment: .leading,
                spacing: Self.gridSpacing
            ) {
                if isBrowsingAll {
                    ForEach(categories, id: \.self) { item in
                        Section {
                            cards(registry.descriptors.filter { $0.category == item })
                        } header: {
                            sectionHeader(item.displayName)
                        }
                    }
                } else {
                    cards(results)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.automatic)
        // Soft edges instead of a hard cut, only where there is more to scroll.
        .onScrollGeometryChange(for: EdgeFades.self) { geometry in
            let offset = geometry.contentOffset.y + geometry.contentInsets.top
            return EdgeFades(
                top: offset > 1,
                bottom: offset + geometry.containerSize.height < geometry.contentSize.height - 1
            )
        } action: { _, value in
            fades = value
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: fades.top ? 20 : 0)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: fades.bottom ? 36 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: fades)
        }
        // A little over two rows, so a cut-off row shows there is more to scroll.
        .frame(height: slot.height * 2.6 + 104)
        .overlay {
            if !isBrowsingAll && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func cards(_ descriptors: [WidgetDescriptor]) -> some View {
        ForEach(descriptors) { descriptor in
            TrayItem(descriptor: descriptor, theme: theme, slot: slot) {
                layout.add(descriptor)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

/// Which edges of the grid have more content beyond them.
private struct EdgeFades: Equatable {
    var top = false
    var bottom = false
}

/// A live, non-interactive preview of one widget type, scaled into a uniform card slot.
/// Drag it into the dock, or click to add it at the end.
private struct TrayItem: View {
    let descriptor: WidgetDescriptor
    let theme: DockTheme
    let slot: CGSize
    let onAdd: () -> Void

    @State private var previewID = UUID()
    @State private var hovering = false

    /// Space between the card's edge and the preview inside it.
    static func inset(_ theme: DockTheme) -> CGFloat { theme.scaled(8) }

    private var previewScale: CGFloat {
        let frame = theme.frame(for: descriptor.defaultSize)
        let inset = Self.inset(theme) * 2
        return min(1, (slot.width - inset) / frame.width, (slot.height - inset) / frame.height)
    }

    var body: some View {
        let frame = theme.frame(for: descriptor.defaultSize)
        // Every card is the same size, so the grid lines up whatever the widget's size.
        let card = RoundedRectangle(cornerRadius: theme.tileCornerRadius + Self.inset(theme), style: .continuous)
        VStack(spacing: 6) {
            preview
                .scaleEffect(previewScale)
                .frame(width: frame.width * previewScale, height: frame.height * previewScale)
                .frame(width: slot.width, height: slot.height)
                .background(Color.primary.opacity(hovering ? 0.08 : 0.04), in: card)
                .overlay(alignment: .topTrailing) {
                    if hovering {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, theme.accent)
                            .padding(4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            Text(descriptor.name)
                .font(.caption)
                .foregroundStyle(hovering ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: slot.width)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onTapGesture(perform: onAdd)
        .draggable(DockDragPayload.newWidget(id: descriptor.id).encoded) {
            preview
        }
        .help(descriptor.summary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(descriptor.name)
        .accessibilityHint(descriptor.summary)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Add to Dock", onAdd)
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
