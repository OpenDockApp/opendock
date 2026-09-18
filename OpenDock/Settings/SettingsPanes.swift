import SwiftUI
import OpenDockKit

private let paneWidth: CGFloat = 540

// MARK: - General

struct GeneralSettingsPane: View {
    @Environment(DockPanelController.self) private var controller
    @Environment(SystemDockManager.self) private var systemDock
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var edge: SystemDockManager.Edge = .left

    var body: some View {
        @Bindable var controller = controller
        Form {
            Section("Dock") {
                Toggle("Automatically hide and show the dock", isOn: $controller.autoHide)
                LabeledContent("Distance from bottom") {
                    HStack(spacing: 10) {
                        Slider(value: $controller.bottomGap, in: DockPanelController.bottomGapRange, step: 1)
                            .frame(width: 180)
                        Text("\(Int(controller.bottomGap)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch OpenDock at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
            }

            Section {
                if systemDock.isTuckedAway {
                    LabeledContent("Moved to the side and auto-hidden") {
                        Button("Restore") { systemDock.restore() }
                    }
                } else {
                    LabeledContent("Move to") {
                        HStack {
                            Picker("Move to", selection: $edge) {
                                Text("Left").tag(SystemDockManager.Edge.left)
                                Text("Right").tag(SystemDockManager.Edge.right)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .fixedSize()
                            Button("Move Aside") { systemDock.tuckAway(to: edge) }
                        }
                    }
                }
                if let error = systemDock.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("System Dock")
            } footer: {
                Text("The system Dock also appears at the bottom edge. Moving it to a side keeps the two from overlapping.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: paneWidth, height: 430)
    }
}

// MARK: - Widgets

struct WidgetsSettingsPane: View {
    @Environment(DockLayoutStore.self) private var layout
    private let registry = WidgetRegistry.shared

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(registry.descriptors) { descriptor in
                        WidgetCard(descriptor: descriptor, count: count(of: descriptor))
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Text("\(layout.items.count) widgets in the dock")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to Defaults") { layout.reset() }
                Button("Edit Dock…") { layout.beginEditing() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: paneWidth, height: 420)
    }

    private func count(of descriptor: WidgetDescriptor) -> Int {
        layout.items.filter { $0.widgetID == descriptor.id }.count
    }
}

private struct WidgetCard: View {
    let descriptor: WidgetDescriptor
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: descriptor.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 38, height: 38)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
                if count > 0 {
                    Text(count == 1 ? "In dock" : "\(count) in dock")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.18), in: Capsule())
                        .foregroundStyle(.green)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.name)
                    .font(.headline)
                Text(descriptor.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
            Text(descriptor.supportedSizes.map(\.displayName).joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - About

struct AboutSettingsPane: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            Text("OpenDock")
                .font(.title.bold())
            Text(version)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("An open-source widget dock for macOS.")
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Link("github.com/mxvsh/OpenDock", destination: URL(string: "https://github.com/mxvsh/OpenDock")!)
                .padding(.top, 4)
        }
        .frame(width: paneWidth, height: 280)
    }
}
