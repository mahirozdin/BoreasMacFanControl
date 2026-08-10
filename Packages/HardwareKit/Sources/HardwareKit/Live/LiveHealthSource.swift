import Core
import Foundation
import IOKit
import os

/// Battery and drive readings from IOKit, **unprivileged** (P7.03).
///
/// What is readable and what is not was established by probing rather than
/// assumed, and the answers differ by field:
///
/// - **Battery**: `AppleSmartBattery` publishes `BatteryInstalled`, `CycleCount`,
///   `MaxCapacity`, `DesignCapacity` and `Temperature` in the IO registry. It
///   answers on desktops too, reporting `BatteryInstalled = 0` — which is why
///   "no battery" is a definite answer here and not a failed read.
/// - **Drive capacity**: `URLResourceKey` volume values, documented and
///   unprivileged.
/// - **Drive SMART**: **not readable.** The drive advertises `NVMe SMART Capable
///   = 1` and its user client even opens without privileges, but the values are
///   not published in the registry — getting them needs an undocumented
///   user-client protocol whose selectors would have to be guessed at. For an
///   informational summary that is the wrong trade, and it is nowhere near
///   enough to justify widening the helper's four-method surface (M4). The check
///   reports the capability and says the values are unavailable, which is what
///   the honesty rule asks for.
///
/// Nothing here throws: every reader answers with `nil` on failure and the check
/// turns that into `indeterminate`. That is the one place §6.3's "throw, do not
/// swallow" gives way — a diagnostic that cannot read a field has *learned
/// something* (that the field is unreadable) rather than failed, and it has to be
/// able to say so.
public struct LiveHealthSource: HealthSource {

    public let identifier = "iokit-health"

    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "sensor")

    public init() {}

    // MARK: - Battery

    public func battery() -> DiagnosticChecks.BatteryReading? {
        guard let properties = registryProperties(ofClass: "AppleSmartBattery") else {
            return nil
        }
        // Absent is an answer. `BatteryInstalled` is published on desktops as 0,
        // so this is a fact about the machine rather than a gap in the read.
        let installed = (properties["BatteryInstalled"] as? Int ?? 0) == 1
        guard installed else {
            return DiagnosticChecks.BatteryReading(
                isInstalled: false, cycleCount: 0, capacityFraction: nil, celsius: nil)
        }

        let cycles = properties["CycleCount"] as? Int ?? 0
        let design = properties["DesignCapacity"] as? Int
        let maximum =
            properties["AppleRawMaxCapacity"] as? Int ?? properties["MaxCapacity"] as? Int
        let fraction: Double? = {
            guard let design, design > 0, let maximum, maximum > 0 else { return nil }
            return Double(maximum) / Double(design)
        }()

        // Reported in hundredths of a degree, as `AppleSmartBattery` does. A
        // value outside anything physical is discarded rather than shown: the
        // same rule the sensor stack applies to a parked cluster.
        let celsius: Double? = {
            guard let raw = properties["Temperature"] as? Int, raw != 0 else { return nil }
            let value = Double(raw) / 100
            return (-20...100).contains(value) ? value : nil
        }()

        return DiagnosticChecks.BatteryReading(
            isInstalled: true, cycleCount: cycles, capacityFraction: fraction, celsius: celsius)
    }

    // MARK: - Storage

    public func storage(nandCelsius: Double?) -> DiagnosticChecks.StorageReading? {
        let target = URL(fileURLWithPath: "/", isDirectory: true)
        guard
            let values = try? target.resourceValues(forKeys: [
                .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            ]),
            let total = values.volumeTotalCapacity
        else {
            logger.error("volume capacity unreadable")
            return nil
        }
        // `forImportantUsage` rather than the plain available capacity: it is what
        // the system will actually let a write have, once purgeable space is
        // accounted for. The plain figure reads higher and would understate how
        // full the drive really is.
        let free = values.volumeAvailableCapacityForImportantUsage ?? Int64(0)

        return DiagnosticChecks.StorageReading(
            totalBytes: Int64(total),
            freeBytes: free,
            nandCelsius: nandCelsius,
            advertisesSmart: driveAdvertisesSmart())
    }

    /// Whether the drive says it is SMART capable.
    ///
    /// Read so the check can say "this drive has wear data and this build cannot
    /// read it" rather than staying silent about a field somebody might expect.
    private func driveAdvertisesSmart() -> Bool {
        for className in ["IONVMeBlockStorageDevice", "IONVMeController"] {
            if let properties = registryProperties(ofClass: className),
                let capable = properties["NVMe SMART Capable"] as? Int, capable == 1
            {
                return true
            }
        }
        return false
    }

    // MARK: - Registry

    /// The first matching service's properties, or `nil`.
    ///
    /// Deliberately read-only: this opens no user client and calls no method, so
    /// it cannot change anything about the machine — which is what makes it safe
    /// to run on every diagnostics refresh.
    private func registryProperties(ofClass className: String) -> [String: Any]? {
        guard let matching = IOServiceMatching(className) else { return nil }
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
                == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
                == KERN_SUCCESS,
                let properties = unmanaged?.takeRetainedValue() as? [String: Any]
            {
                return properties
            }
        }
        return nil
    }
}
