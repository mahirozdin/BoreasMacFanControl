import Core
import Foundation
import IOKit.ps

/// Reads the power source through the public IOKit power sources API.
public struct LivePowerSource: PowerSource {

    public let identifier = "iokit-ps"

    public init() {}

    public func current() -> PowerContext {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
            let first = sources.first,
            let description = IOPSGetPowerSourceDescription(snapshot, first)?
                .takeUnretainedValue() as? [String: Any]
        else {
            // No battery to report means mains power. This is the answer for
            // every desktop Mac, and it is correct rather than missing.
            return .desktop
        }

        let state = description[kIOPSPowerSourceStateKey] as? String
        let onBattery = state == kIOPSBatteryPowerValue

        var percentage: Int?
        if let current = description[kIOPSCurrentCapacityKey] as? Int,
            let maximum = description[kIOPSMaxCapacityKey] as? Int,
            maximum > 0
        {
            percentage = Int((Double(current) / Double(maximum) * 100).rounded())
        }

        return PowerContext(
            source: onBattery ? .battery : .adapter,
            batteryPercentage: percentage
        )
    }
}
