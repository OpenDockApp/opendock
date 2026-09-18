import SwiftUI
import OpenDockKit

struct OnboardingView: View {
    let dock: DockPanelController
    let permissions: PermissionCenter
    let onFinish: () -> Void

    @State private var step: Step = .welcome

    enum Step: Int, CaseIterable {
        case welcome, permissions, setup
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: WelcomeStep()
                case .permissions: PermissionsStep(permissions: permissions)
                case .setup: SetupStep(dock: dock)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(step)

            footer
        }
        .frame(width: 560, height: 520)
        .background(backdrop)
        .animation(.smooth(duration: 0.35), value: step)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s == step ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: s == step ? 18 : 6, height: 6)
                }
            }
            Spacer()
            if step != .welcome {
                Button("Back") { move(-1) }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
            Button(step == .setup ? "Get Started" : "Continue") {
                step == .setup ? onFinish() : move(1)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var backdrop: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [.blue.opacity(0.25), .purple.opacity(0.18), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private func move(_ delta: Int) {
        if let next = Step(rawValue: step.rawValue + delta) {
            step = next
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            DockPreview()
            VStack(spacing: 8) {
                Text("Welcome to OpenDock")
                    .font(.system(size: 30, weight: .bold))
                Text("A glass dock for live widgets. Clock, apps, system stats,\nand anything the community builds.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(32)
    }
}

/// A static miniature of the dock rendered with real widgets.
private struct DockPreview: View {
    private let theme = DockTheme.standard
    private let items: [(String, WidgetSize)] = [
        ("dev.opendock.clock", .medium),
        ("dev.opendock.date", .small),
        ("dev.opendock.launcher", .small),
        ("dev.opendock.cpu", .small),
    ]

    var body: some View {
        HStack(spacing: theme.spacing) {
            ForEach(items, id: \.0) { id, size in
                if let widget = WidgetRegistry.shared.widget(for: id) {
                    WidgetTile(size: size) {
                        widget.view(context: WidgetContext(size: size, instanceID: UUID(), theme: theme, services: .live))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(theme.padding)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: theme.barCornerRadius, style: .continuous))
        .environment(\.dockTheme, theme)
    }
}

private struct PermissionsStep: View {
    let permissions: PermissionCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                symbol: "hand.raised.fill",
                title: "Permissions",
                subtitle: "All optional. Only widgets that need them will ask for data, and you can change this later in System Settings."
            )
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(PermissionCenter.Kind.allCases) { kind in
                        PermissionRow(kind: kind, status: permissions.status(kind)) {
                            permissions.request(kind)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }
}

private struct PermissionRow: View {
    let kind: PermissionCenter.Kind
    let status: PermissionCenter.Status
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(nsColor: kind.tint)))
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.headline)
                Text(kind.reason).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            switch status {
            case .granted:
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))
            case .denied:
                Button("Open Settings", action: action)
                    .buttonStyle(.glass)
            case .notDetermined:
                Button("Allow", action: action)
                    .buttonStyle(.glass)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SetupStep: View {
    let dock: DockPanelController
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        @Bindable var dock = dock
        VStack(alignment: .leading, spacing: 20) {
            StepHeader(
                symbol: "slider.horizontal.3",
                title: "Make it yours",
                subtitle: "A few defaults. Everything here is also in Settings."
            )
            VStack(spacing: 10) {
                SettingRow(symbol: "power", title: "Launch at login", detail: "Start OpenDock when you log in.") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                }
                SettingRow(symbol: "rectangle.bottomthird.inset.filled", title: "Auto-hide", detail: "Slide the dock away until the pointer touches the bottom edge.") {
                    Toggle("", isOn: $dock.autoHide)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                SettingRow(symbol: "dock.rectangle", title: "System Dock", detail: "Turn on \u{201C}Automatically hide and show the Dock\u{201D} so the two don\u{2019}t overlap.") {
                    Button("Open") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!)
                    }
                    .buttonStyle(.glass)
                }
            }
            Spacer()
        }
        .padding(32)
    }
}

// MARK: - Shared pieces

private struct StepHeader: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.tint)
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }
}

private struct SettingRow<Accessory: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.quaternary))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            accessory
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.background.opacity(0.5)))
    }
}
