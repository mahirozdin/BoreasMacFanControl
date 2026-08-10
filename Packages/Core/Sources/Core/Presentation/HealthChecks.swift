import Foundation

/// The battery and storage checks (P7.03).
///
/// Split from `Diagnostics.swift` because that file reached its length budget —
/// and the seam is a real one: these two checks read *hardware facts the
/// application does not otherwise use*, while the four in the other file
/// interpret data the monitor already collects.
///
/// **What is readable here was established by probing, not assumed**, and the
/// answers differ per field. See `LiveHealthSource` for the measurements; the
/// short version is that battery figures are published in the IO registry,
/// drive capacity is a documented API, and drive **wear** is neither — which is
/// why `storageSmart` exists to say so out loud rather than leave the gap to be
/// inferred.
extension DiagnosticChecks {

    // MARK: - Battery health (P7.03)

    /// A battery reading as the system reports it, or the absence of one.
    ///
    /// A value type rather than the check taking six arguments: the caller reads
    /// IOKit, this decides what the numbers mean, and neither has to know how
    /// the other works.
    public struct BatteryReading: Sendable, Hashable {
        /// False on a desktop. **Definite, not unknown** — `AppleSmartBattery`
        /// answers on desktops too.
        public let isInstalled: Bool
        public let cycleCount: Int
        /// Full-charge capacity as a fraction of the design capacity.
        public let capacityFraction: Double?
        public let celsius: Double?

        public init(
            isInstalled: Bool, cycleCount: Int, capacityFraction: Double?, celsius: Double?
        ) {
            self.isInstalled = isInstalled
            self.cycleCount = cycleCount
            self.capacityFraction = capacityFraction
            self.celsius = celsius
        }
    }

    /// Below this fraction of its design capacity a battery is described as worn.
    ///
    /// 80% is the figure Apple's own service documentation uses as the end of a
    /// battery's rated life, so it is the one number here a user might already
    /// have seen elsewhere — and a *different* threshold would be this project
    /// inventing a standard.
    public static let batteryWornCapacityFraction = 0.80

    /// A battery above this is warm enough to mention. Batteries age faster hot,
    /// and unlike a die temperature this is not something a fan can fix — so it
    /// is information, never a reason to raise fan speed.
    public static let batteryWarmCelsius = 35.0

    public static func batteryHealth(_ reading: BatteryReading?) -> Diagnostic {
        guard let reading else { return .indeterminate(.batteryUnreadable) }
        guard reading.isInstalled else {
            // Not applicable, not a concern: a Mac mini has no battery and being
            // told so is the correct, complete answer.
            return .notApplicable(.batteryAbsent)
        }
        guard let capacityFraction = reading.capacityFraction, capacityFraction > 0 else {
            return .indeterminate(.batteryUnreadable)
        }
        let capacityPercent = Int((capacityFraction * 100).rounded())

        if let celsius = reading.celsius, celsius >= batteryWarmCelsius {
            return .needsAttention(
                .batteryWarm(
                    celsius: celsius, cycleCount: reading.cycleCount,
                    capacityPercent: capacityPercent),
                possibleCauses: [.batteryChargedHotOrCold, .sustainedHeavyWork],
                nextSteps: [.avoidChargingInHeat, .checkBatteryInSystemSettings])
        }
        guard capacityFraction < batteryWornCapacityFraction else {
            return .healthy(
                .batteryHealthy(
                    cycleCount: reading.cycleCount, capacityPercent: capacityPercent))
        }
        // Worn is not broken. A battery at 70% of design capacity after 900
        // cycles has done exactly what a battery does, and the wording says so —
        // the causes offered lead with normal ageing.
        return .needsAttention(
            .batteryWorn(cycleCount: reading.cycleCount, capacityPercent: capacityPercent),
            possibleCauses: [.batteryAgedNormally, .batteryNeedsServiceCheck],
            nextSteps: [.checkBatteryInSystemSettings])
    }

    // MARK: - Storage health (P7.03)

    /// What can be read about the drive without privileges.
    ///
    /// **SMART values are deliberately absent.** The drive advertises
    /// `NVMe SMART Capable = 1` and its user client even opens unprivileged, but
    /// the values are not published in the IO registry — reading them needs an
    /// undocumented user-client protocol whose selectors would have to be
    /// guessed at. For an informational summary that is the wrong trade, and it
    /// would not justify widening the helper's four-method surface (M4). So this
    /// carries what is real and `storageSmartUnavailable` says the rest out loud.
    public struct StorageReading: Sendable, Hashable {
        public let totalBytes: Int64
        public let freeBytes: Int64
        /// The hottest storage-group sensor, when the machine reports one.
        public let nandCelsius: Double?
        public let advertisesSmart: Bool

        public init(
            totalBytes: Int64, freeBytes: Int64, nandCelsius: Double?, advertisesSmart: Bool
        ) {
            self.totalBytes = totalBytes
            self.freeBytes = freeBytes
            self.nandCelsius = nandCelsius
            self.advertisesSmart = advertisesSmart
        }

        public var freeFraction: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(freeBytes) / Double(totalBytes)
        }
    }

    /// Below this much free space a drive is worth mentioning.
    ///
    /// 10% is where sustained write throughput on a full flash drive starts to
    /// fall measurably, which is a thermal observation as much as a capacity one:
    /// the controller works harder and the NAND runs warmer.
    public static let storageLowFreeFraction = 0.10

    public static func storageHealth(_ reading: StorageReading?) -> Diagnostic {
        guard let reading, reading.totalBytes > 0 else {
            return .indeterminate(.storageUnreadable)
        }
        let freePercent = Int((reading.freeFraction * 100).rounded())
        guard reading.freeFraction >= storageLowFreeFraction else {
            return .needsAttention(
                .storageNearlyFull(freePercent: freePercent, nandCelsius: reading.nandCelsius),
                possibleCauses: [
                    .diskAlmostFull, .largeFilesOrSnapshots, .sustainedWritesWarmTheDrive,
                ],
                nextSteps: [.freeUpDiskSpace, .reviewSnapshotsAndBackups])
        }
        return .healthy(
            .storageHealthy(freePercent: freePercent, nandCelsius: reading.nandCelsius))
    }

    /// The companion finding that names what was **not** measured.
    ///
    /// Returned alongside `storageHealth` rather than folded into it, because a
    /// healthy verdict about capacity must not be read as a healthy verdict about
    /// the drive's wear — which is exactly what a single combined sentence would
    /// invite.
    public static func storageSmart(_ reading: StorageReading?) -> Diagnostic? {
        guard let reading, reading.advertisesSmart else { return nil }
        return .indeterminate(.storageSmartUnavailable)
    }
}
