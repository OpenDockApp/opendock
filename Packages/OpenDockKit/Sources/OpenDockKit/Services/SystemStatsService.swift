import Darwin
import Foundation
import Observation

/// Physical memory split the way Activity Monitor reports it.
public struct MemoryUsage: Equatable, Sendable {
    public var total: UInt64
    public var app: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var cached: UInt64

    public init(total: UInt64, app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64) {
        self.total = total
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
    }

    public var used: UInt64 { app + wired + compressed }
    public var free: UInt64 { total > used ? total - used : 0 }
    public var fraction: Double { total > 0 ? min(1, Double(used) / Double(total)) : 0 }
}

/// Capacity of a mounted volume.
public struct DiskUsage: Equatable, Sendable {
    public var name: String
    public var total: UInt64
    public var free: UInt64

    public init(name: String, total: UInt64, free: UInt64) {
        self.name = name
        self.total = total
        self.free = free
    }

    public var used: UInt64 { total > free ? total - free : 0 }
    public var fraction: Double { total > 0 ? min(1, Double(used) / Double(total)) : 0 }
}

/// Bytes per second across every physical interface, plus the counters they came from.
public struct NetworkThroughput: Equatable, Sendable {
    public var down: Double
    public var up: Double
    public var totalIn: UInt64
    public var totalOut: UInt64

    public init(down: Double = 0, up: Double = 0, totalIn: UInt64 = 0, totalOut: UInt64 = 0) {
        self.down = down
        self.up = up
        self.totalIn = totalIn
        self.totalOut = totalOut
    }

    /// Rate between two counter readings. Interface counters reset when an
    /// interface goes down, so a counter that moved backwards reads as zero.
    public static func between(
        previous: (inBytes: UInt64, outBytes: UInt64),
        current: (inBytes: UInt64, outBytes: UInt64),
        elapsed: TimeInterval
    ) -> NetworkThroughput {
        guard elapsed > 0 else { return NetworkThroughput(totalIn: current.inBytes, totalOut: current.outBytes) }
        let down = current.inBytes >= previous.inBytes ? Double(current.inBytes - previous.inBytes) / elapsed : 0
        let up = current.outBytes >= previous.outBytes ? Double(current.outBytes - previous.outBytes) / elapsed : 0
        return NetworkThroughput(down: down, up: up, totalIn: current.inBytes, totalOut: current.outBytes)
    }
}

/// Memory, disk, and network sampling for the system widgets. All three read
/// counters that are available inside the App Sandbox.
@Observable
public final class SystemStatsService {
    public static let shared = SystemStatsService()

    /// Number of samples kept for the sparklines.
    public static let historyLength = 30

    public private(set) var memory: MemoryUsage?
    public private(set) var memoryHistory = [Double](repeating: 0, count: SystemStatsService.historyLength)
    public private(set) var disk: DiskUsage?
    public private(set) var network = NetworkThroughput()
    public private(set) var downHistory = [Double](repeating: 0, count: SystemStatsService.historyLength)
    public private(set) var upHistory = [Double](repeating: 0, count: SystemStatsService.historyLength)

    private var lastCounters: (inBytes: UInt64, outBytes: UInt64)?
    private var lastSample: Date?

    public init() {}

    // MARK: - Memory

    public func refreshMemory() {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var info = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        var page: vm_size_t = 4096
        host_page_size(mach_host_self(), &page)
        let pageSize = UInt64(page)
        let internalPages = UInt64(info.internal_page_count)
        let purgeable = UInt64(info.purgeable_count)
        memory = MemoryUsage(
            total: ProcessInfo.processInfo.physicalMemory,
            app: (internalPages > purgeable ? internalPages - purgeable : 0) * pageSize,
            wired: UInt64(info.wire_count) * pageSize,
            compressed: UInt64(info.compressor_page_count) * pageSize,
            cached: UInt64(info.external_page_count) * pageSize
        )
        append(memory?.fraction ?? 0, to: &memoryHistory)
    }

    // MARK: - Disk

    /// Capacity of the volume holding the boot drive. `volumeAvailableCapacityForImportantUsage`
    /// counts space macOS would reclaim from purgeable caches, which is what Finder shows.
    public func refreshDisk(path: String = "/") {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [
            .volumeNameKey, .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys), let total = values.volumeTotalCapacity else { return }
        let available = values.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) }
            ?? UInt64(max(0, values.volumeAvailableCapacity ?? 0))
        disk = DiskUsage(name: values.volumeName ?? "Macintosh HD", total: UInt64(max(0, total)), free: available)
    }

    // MARK: - Network

    /// Sums byte counters across every non-loopback interface and turns the
    /// delta since the previous call into a rate. The first call only seeds.
    public func sampleNetwork(now: Date = .now) {
        guard let counters = interfaceCounters() else { return }
        defer {
            lastCounters = counters
            lastSample = now
        }
        guard let lastCounters, let lastSample else {
            network = NetworkThroughput(totalIn: counters.inBytes, totalOut: counters.outBytes)
            return
        }
        network = .between(previous: lastCounters, current: counters, elapsed: now.timeIntervalSince(lastSample))
        append(network.down, to: &downHistory)
        append(network.up, to: &upHistory)
    }

    private func interfaceCounters() -> (inBytes: UInt64, outBytes: UInt64)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let head else { return nil }
        defer { freeifaddrs(head) }
        var inBytes: UInt64 = 0
        var outBytes: UInt64 = 0
        for pointer in sequence(first: head, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  interface.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            inBytes += UInt64(data.pointee.ifi_ibytes)
            outBytes += UInt64(data.pointee.ifi_obytes)
        }
        return (inBytes, outBytes)
    }

    private func append(_ value: Double, to history: inout [Double]) {
        history.removeFirst()
        history.append(value)
    }
}

public enum ByteFormat {
    /// Compact size for a tile, e.g. "12.4 GB".
    public static func size(_ bytes: UInt64) -> String {
        Int64(bytes).formatted(.byteCount(style: .memory).locale(.current))
    }

    /// Transfer rate for a tile, e.g. "1.2 MB/s".
    public static func rate(_ bytesPerSecond: Double) -> String {
        "\(size(UInt64(max(0, bytesPerSecond.rounded()))))/s"
    }
}
