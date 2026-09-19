import SwiftUI
import AppKit
import OpenDockKit

/// Popover for choosing, ordering and removing launcher apps.
struct LauncherEditor: View {
    @Environment(\.dockTheme) private var theme
    @Binding var bundleIDs: [String]
    let capacity: Int
    let defaults: [String]
    let chooseOther: () -> Void

    @State private var query = ""
    @State private var installed: [LauncherApp] = []
    @State private var running: Set<String> = []
    @State private var loading = true

    var body: some View {
        let current = LauncherApp.resolve(bundleIDs)
        WidgetDetails(title: "App Launcher", symbol: "square.grid.2x2") {
            currentApps(current)
            Divider()
            TextField("Search apps", text: $query)
                .textFieldStyle(.roundedBorder)
            appList
            HStack {
                Button("Choose Another App…", action: chooseOther)
                Spacer()
                Button("Reset") { bundleIDs = defaults }
                    .disabled(bundleIDs == defaults)
            }
            .buttonStyle(.glass)
        }
        .task {
            running = Set(NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\.bundleIdentifier))
            installed = await LauncherApp.installed()
            loading = false
        }
    }

    // MARK: Current apps

    @ViewBuilder
    private func currentApps(_ current: [LauncherApp]) -> some View {
        if current.isEmpty {
            Text("No apps yet. Pick some below, or drag apps from Finder onto the launcher.")
                .font(theme.captionFont)
                .foregroundStyle(.secondary)
        } else {
            List {
                ForEach(Array(current.enumerated()), id: \.element.id) { index, app in
                    row(app) {
                        Button {
                            bundleIDs.removeAll { $0 == app.bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(app.name)")
                    }
                    // Apps past the visible slots are dimmed.
                    .foregroundStyle(index < capacity ? .primary : .secondary)
                }
                .onMove { source, destination in
                    var order = current
                    order.move(fromOffsets: source, toOffset: destination)
                    let shown = Set(order.map(\.bundleID))
                    bundleIDs = order.map(\.bundleID) + bundleIDs.filter { !shown.contains($0) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: rowHeight * CGFloat(min(current.count, 5)))
            Text(current.count > capacity
                 ? "Only the first \(capacity) fit at this size. Drag to reorder, or make the widget bigger."
                 : "Drag to reorder. You can also drop apps from Finder onto the launcher.")
                .font(theme.captionFont)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: All apps

    private var appList: some View {
        let term = query.trimmingCharacters(in: .whitespaces)
        let matches = term.isEmpty ? installed : installed.filter { $0.name.localizedStandardContains(term) }
        let open = term.isEmpty ? matches.filter { running.contains($0.bundleID) } : []
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.scaled(2)) {
                if loading {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                } else if matches.isEmpty {
                    Text(term.isEmpty ? "No apps found. Use Choose Another App…" : "No apps match “\(term)”.")
                        .font(theme.captionFont)
                        .foregroundStyle(.secondary)
                }
                if !open.isEmpty {
                    sectionHeader("Open Now")
                    ForEach(open) { toggleRow($0) }
                    sectionHeader("All Apps")
                }
                ForEach(matches) { toggleRow($0) }
            }
        }
        .frame(height: theme.scaled(200))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(theme.captionFont)
            .foregroundStyle(.secondary)
            .padding(.top, theme.scaled(4))
    }

    private func toggleRow(_ app: LauncherApp) -> some View {
        let added = bundleIDs.contains(app.bundleID)
        return Button {
            if added {
                bundleIDs.removeAll { $0 == app.bundleID }
            } else {
                bundleIDs.append(app.bundleID)
            }
        } label: {
            row(app) {
                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(added ? theme.accent : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(added ? "Remove from Launcher" : "Add to Launcher")
    }

    // MARK: Rows

    private var rowHeight: CGFloat { theme.scaled(28) }

    private func row(_ app: LauncherApp, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: theme.scaled(8)) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .frame(width: theme.scaled(20), height: theme.scaled(20))
            Text(app.name).lineLimit(1)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: theme.scaled(24))
    }
}
