import SwiftUI
import OpenDockKit

struct MemoryWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.memory",
        name: "Memory",
        summary: "Physical memory in use, with the app, wired, and compressed split.",
        symbol: "memorychip",
        category: .system,
        supportedSizes: [.small, .medium]
    )

    func body(context: WidgetContext) -> some View { MemoryView(context: context) }
}

private struct MemoryView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    let context: WidgetContext
    private var stats: SystemStatsService { context.services.systemStats }
    private var tint: Color { (stats.memory?.fraction ?? 0) >= 0.9 ? .orange : .purple }

    var body: some View {
        Button { expanded.toggle() } label: {
            Group {
                if context.size == .small {
                    RingView(progress: stats.memory?.fraction ?? 0,
                             label: "\(Int((stats.memory?.fraction ?? 0) * 100))",
                             symbol: "memorychip", tint: tint)
                } else {
                    VStack(alignment: .leading, spacing: theme.scaled(2)) {
                        HStack {
                            Label("Memory", systemImage: "memorychip")
                                .font(theme.captionFont)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(stats.memory.map { ByteFormat.size($0.used) } ?? "—")
                                .font(theme.titleFont.monospacedDigit())
                        }
                        SparklineView(values: stats.memoryHistory, tint: tint)
                    }
                    .padding(theme.contentPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetPopover(isPresented: $expanded) {
            WidgetDetails(title: "Memory", symbol: "memorychip") {
                if let memory = stats.memory {
                    Text("\(ByteFormat.size(memory.used)) of \(ByteFormat.size(memory.total))")
                        .font(theme.heroFont)
                        .foregroundStyle(tint)
                    ProgressView(value: memory.fraction).tint(tint)
                    Grid(alignment: .leading, horizontalSpacing: theme.scaled(12), verticalSpacing: theme.scaled(4)) {
                        row("App", memory.app)
                        row("Wired", memory.wired)
                        row("Compressed", memory.compressed)
                        row("Cached files", memory.cached)
                    }
                } else {
                    Text("Memory statistics are unavailable.").foregroundStyle(.secondary)
                }
            }
            .environment(\.dockTheme, theme)
        }
        .task {
            while !Task.isCancelled {
                stats.refreshMemory()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            }
        }
    }

    private func row(_ label: String, _ bytes: UInt64) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(ByteFormat.size(bytes)).monospacedDigit().gridColumnAlignment(.trailing)
        }
    }
}
