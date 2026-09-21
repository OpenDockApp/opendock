import SwiftUI
import OpenDockKit

struct NetworkWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.network",
        name: "Network",
        summary: "Download and upload throughput across all interfaces.",
        symbol: "arrow.up.arrow.down",
        category: .system,
        supportedSizes: [.small, .medium],
        defaultSize: .medium
    )

    func body(context: WidgetContext) -> some View { NetworkView(context: context) }
}

private struct NetworkView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    let context: WidgetContext
    private var stats: SystemStatsService { context.services.systemStats }
    private let down = Color.blue
    private let up = Color.green

    var body: some View {
        Button { expanded.toggle() } label: {
            Group {
                if context.size == .small {
                    VStack(alignment: .leading, spacing: theme.scaled(4)) {
                        rate(ByteFormat.rate(stats.network.down), symbol: "arrow.down", tint: down)
                        rate(ByteFormat.rate(stats.network.up), symbol: "arrow.up", tint: up)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(theme.contentPadding)
                } else {
                    VStack(alignment: .leading, spacing: theme.scaled(2)) {
                        HStack(spacing: theme.scaled(8)) {
                            rate(ByteFormat.rate(stats.network.down), symbol: "arrow.down", tint: down)
                            rate(ByteFormat.rate(stats.network.up), symbol: "arrow.up", tint: up)
                            Spacer(minLength: 0)
                        }
                        SparklineView(values: stats.downHistory, tint: down)
                    }
                    .padding(theme.contentPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetPopover(isPresented: $expanded) {
            WidgetDetails(title: "Network", symbol: "arrow.up.arrow.down") {
                Text(ByteFormat.rate(stats.network.down)).font(theme.heroFont).foregroundStyle(down)
                Text("down, \(ByteFormat.rate(stats.network.up)) up").foregroundStyle(.secondary)
                SparklineView(values: stats.downHistory, tint: down)
                    .frame(height: theme.scaled(40))
                Grid(alignment: .leading, horizontalSpacing: theme.scaled(12), verticalSpacing: theme.scaled(4)) {
                    GridRow {
                        Text("Received").foregroundStyle(.secondary)
                        Text(ByteFormat.size(stats.network.totalIn)).monospacedDigit().gridColumnAlignment(.trailing)
                    }
                    GridRow {
                        Text("Sent").foregroundStyle(.secondary)
                        Text(ByteFormat.size(stats.network.totalOut)).monospacedDigit().gridColumnAlignment(.trailing)
                    }
                }
                Text("Totals are counted since the Mac last booted.")
                    .font(theme.captionFont)
                    .foregroundStyle(.secondary)
            }
            .environment(\.dockTheme, theme)
        }
        .task {
            while !Task.isCancelled {
                stats.sampleNetwork()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    private func rate(_ value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: theme.scaled(3)) {
            Image(systemName: symbol)
                .font(.system(size: theme.scaled(8), weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(theme.captionFont.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
