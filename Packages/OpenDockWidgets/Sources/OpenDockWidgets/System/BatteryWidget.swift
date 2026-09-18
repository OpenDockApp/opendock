import SwiftUI
import OpenDockKit

struct BatteryWidget: DockWidget {
    static let descriptor = WidgetDescriptor(id: "dev.opendock.battery", name: "Battery",
        summary: "Battery charge, power source, and estimated time remaining.",
        symbol: "battery.75percent", category: .system, supportedSizes: [.small, .medium], defaultSize: .medium)
    func body(context: WidgetContext) -> some View { BatteryView(context: context) }
}

private struct BatteryView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    let context: WidgetContext
    private var service: BatteryService { context.services.battery }
    private var tint: Color { service.charging ? .green : (service.percentage ?? 100) <= 20 ? .orange : theme.accent }
    private var symbol: String { service.percentage == nil ? "powerplug.fill" : service.charging ? "bolt.fill" : "battery.75percent" }
    private var status: String {
        guard service.available else { return "Unavailable" }
        guard service.percentage != nil else { return "AC power" }
        return service.charging ? "Charging" : service.pluggedIn ? "Plugged in" : "On battery"
    }

    var body: some View {
        Button { expanded.toggle() } label: {
            Group {
                if context.size == .small {
                    RingView(progress: Double(service.percentage ?? 0) / 100,
                             label: service.percentage.map { "\($0)%" } ?? "AC", symbol: symbol, tint: tint)
                } else {
                    HStack(spacing: theme.scaled(8)) {
                        Image(systemName: symbol).font(theme.statFont).foregroundStyle(tint)
                        VStack(alignment: .leading, spacing: theme.scaled(2)) {
                            Text(service.percentage.map { "\($0)%" } ?? (service.available ? "AC power" : "—")).font(theme.statFont)
                            Text(status).font(theme.captionFont).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }.padding(theme.contentPadding)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .popover(isPresented: $expanded) {
            WidgetDetails(title: "Battery", symbol: symbol) {
                if let percentage = service.percentage {
                    Text("\(percentage)%").font(theme.heroFont).foregroundStyle(tint)
                    ProgressView(value: Double(percentage), total: 100).tint(tint)
                }
                Text(status).foregroundStyle(.secondary)
                if let minutes = service.minutesRemaining {
                    Text("About \(minutes / 60)h \(minutes % 60)m \(service.charging ? "until full" : "remaining")")
                } else if service.percentage != nil && !service.pluggedIn {
                    Text("Time remaining is being estimated.").foregroundStyle(.secondary)
                }
                Button("Battery Settings") {
                    context.services.openURL(URL(string: "x-apple.systempreferences:com.apple.preference.battery")!)
                    expanded = false
                }.buttonStyle(.glass)
            }.environment(\.dockTheme, theme)
        }
        .task {
            while !Task.isCancelled {
                service.refresh()
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
            }
        }
    }
}
