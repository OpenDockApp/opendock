import SwiftUI
import OpenDockKit

struct CPUWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.cpu",
        name: "CPU",
        summary: "Live processor usage as a ring or a graph.",
        symbol: "cpu",
        category: .system,
        supportedSizes: [.small, .medium]
    )

    func body(context: WidgetContext) -> some View {
        CPUView(size: context.size)
    }
}

private struct CPUView: View {
    @Environment(\.dockTheme) private var theme
    @State private var sampler = CPUSampler()
    let size: WidgetSize

    var body: some View {
        Group {
            if size == .small {
                RingView(progress: sampler.usage, label: "\(Int(sampler.usage * 100))", symbol: "cpu", tint: .blue)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("CPU", systemImage: "cpu")
                            .font(theme.captionFont)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(sampler.usage * 100))%")
                            .font(theme.titleFont.monospacedDigit())
                    }
                    SparklineView(values: sampler.history, tint: .blue)
                }
                .padding(14)
            }
        }
        .task { await sampler.run() }
    }
}

/// Samples host CPU load via Mach. Works inside the App Sandbox.
@Observable
private final class CPUSampler {
    private(set) var usage: Double = 0
    private(set) var history: [Double] = Array(repeating: 0, count: 30)
    private var previous: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    func run() async {
        while !Task.isCancelled {
            sample()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func sample() {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let ticks = info.cpu_ticks
        let current = (user: ticks.0, system: ticks.1, idle: ticks.2, nice: ticks.3)
        defer { previous = current }
        guard let previous else { return }
        let user = Double(current.user &- previous.user)
        let system = Double(current.system &- previous.system)
        let idle = Double(current.idle &- previous.idle)
        let nice = Double(current.nice &- previous.nice)
        let total = user + system + idle + nice
        guard total > 0 else { return }
        usage = (user + system + nice) / total
        history.removeFirst()
        history.append(usage)
    }
}
