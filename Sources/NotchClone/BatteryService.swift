import Foundation
import IOKit.ps
import Observation

@MainActor
@Observable
final class BatteryService {
    var percent: Int?
    var isCharging = false
    var isPluggedIn = false

    func refresh() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            percent = nil
            return
        }
        for source in list {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            percent = current * 100 / max
            isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            isPluggedIn = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return
        }
        percent = nil
    }
}
