import Foundation
import IOKit.ps
import Observation

@Observable
public final class BatteryService {
    public static let shared = BatteryService()
    public private(set) var percentage: Int?
    public private(set) var charging = false
    public private(set) var pluggedIn = false
    public private(set) var minutesRemaining: Int?
    public private(set) var available = false
    public init() {}

    public func refresh() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            available = false; percentage = nil; return
        }
        available = true
        percentage = nil; charging = false; pluggedIn = true; minutesRemaining = nil
        for source in sources {
            guard let values = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  values[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  values[kIOPSIsPresentKey] as? Bool != false,
                  let current = values[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = values[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            percentage = min(100, max(0, Int((Double(current) / Double(maximum) * 100).rounded())))
            charging = values[kIOPSIsChargingKey] as? Bool ?? false
            pluggedIn = values[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let minutes = values[charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int
            minutesRemaining = minutes.flatMap { $0 > 0 ? $0 : nil }
            return
        }
    }
}
