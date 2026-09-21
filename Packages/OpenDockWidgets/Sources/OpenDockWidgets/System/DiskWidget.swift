import SwiftUI
import OpenDockKit

struct DiskWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.disk",
        name: "Disk",
        summary: "Used and free space on the startup volume.",
        symbol: "internaldrive",
        category: .system,
        supportedSizes: [.small, .medium],
        defaultSize: .medium
    )

    func body(context: WidgetContext) -> some View { DiskView(context: context) }
}

private struct DiskView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    let context: WidgetContext
    private var stats: SystemStatsService { context.services.systemStats }
    private var tint: Color { (stats.disk?.fraction ?? 0) >= 0.9 ? .orange : .teal }

    var body: some View {
        Button { expanded.toggle() } label: {
            Group {
                if context.size == .small {
                    RingView(progress: stats.disk?.fraction ?? 0,
                             label: "\(Int((stats.disk?.fraction ?? 0) * 100))",
                             symbol: "internaldrive", tint: tint)
                } else {
                    VStack(alignment: .leading, spacing: theme.scaled(4)) {
                        HStack {
                            Label(stats.disk?.name ?? "Disk", systemImage: "internaldrive")
                                .font(theme.captionFont)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        Text(stats.disk.map { ByteFormat.size($0.free) } ?? "—")
                            .font(theme.statFont)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("free").font(theme.captionFont).foregroundStyle(.secondary)
                        ProgressView(value: stats.disk?.fraction ?? 0).tint(tint)
                    }
                    .padding(theme.contentPadding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .widgetPopover(isPresented: $expanded) {
            WidgetDetails(title: stats.disk?.name ?? "Disk", symbol: "internaldrive") {
                if let disk = stats.disk {
                    Text(ByteFormat.size(disk.free)).font(theme.heroFont).foregroundStyle(tint)
                    Text("free of \(ByteFormat.size(disk.total))").foregroundStyle(.secondary)
                    ProgressView(value: disk.fraction).tint(tint)
                    Text("\(ByteFormat.size(disk.used)) used")
                    Button("Storage Settings") {
                        context.services.openURL(URL(string: "x-apple.systempreferences:com.apple.settings.Storage")!)
                        expanded = false
                    }
                    .buttonStyle(.glass)
                } else {
                    Text("Volume capacity is unavailable.").foregroundStyle(.secondary)
                }
            }
            .environment(\.dockTheme, theme)
        }
        .task {
            while !Task.isCancelled {
                stats.refreshDisk()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }
}
