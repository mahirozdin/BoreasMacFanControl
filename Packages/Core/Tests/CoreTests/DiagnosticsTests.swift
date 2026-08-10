import Foundation
import Testing

@testable import Core

@Suite("Diagnostics (the honesty rule, enforced rather than intended)")
struct DiagnosticsTests {

    /// Every finding the checks can produce, across every branch. The
    /// wording rules below are asserted over this whole set rather than
    /// over one example, so a new branch cannot quietly break them.
    private var allFindings: [Diagnostic] {
        [
            DiagnosticChecks.fanResponse(samples: []),
            DiagnosticChecks.fanResponse(
                samples: Array(repeating: (target: 2_000, actual: 2_050), count: 10)),
            DiagnosticChecks.fanResponse(
                samples: Array(repeating: (target: 3_000, actual: 1_100), count: 10)),
            DiagnosticChecks.fanBalance(speeds: [1_800]),
            DiagnosticChecks.fanBalance(speeds: []),
            DiagnosticChecks.fanBalance(speeds: [1_800, 1_850]),
            DiagnosticChecks.fanBalance(speeds: [1_200, 4_000]),
            DiagnosticChecks.sensorValidity(outOfRange: [], stuck: [], totalSensors: 0),
            DiagnosticChecks.sensorValidity(outOfRange: [], stuck: [], totalSensors: 12),
            DiagnosticChecks.sensorValidity(outOfRange: ["PMU tdie9"], stuck: [], totalSensors: 12),
            DiagnosticChecks.sensorValidity(outOfRange: [], stuck: ["GPU tdie1"], totalSensors: 12),
            DiagnosticChecks.thermalHistory(
                seriousSeconds: 0, criticalSeconds: 0, sessionSeconds: 10, peakCelsius: 60),
            DiagnosticChecks.thermalHistory(
                seriousSeconds: 0, criticalSeconds: 0, sessionSeconds: 3_600, peakCelsius: 60),
            DiagnosticChecks.thermalHistory(
                seriousSeconds: 40, criticalSeconds: 5, sessionSeconds: 3_600, peakCelsius: 96),
            // P7.03. Added here rather than tested only in isolation, so the
            // honesty rules below apply to them for free — which is the whole
            // point of keeping one list.
            DiagnosticChecks.batteryHealth(nil),
            DiagnosticChecks.batteryHealth(Self.battery(installed: false)),
            DiagnosticChecks.batteryHealth(Self.battery(capacity: 0.94)),
            DiagnosticChecks.batteryHealth(Self.battery(capacity: 0.71, cycles: 940)),
            DiagnosticChecks.batteryHealth(Self.battery(capacity: 0.92, celsius: 38)),
            DiagnosticChecks.storageHealth(nil),
            DiagnosticChecks.storageHealth(Self.storage(freeFraction: 0.42)),
            DiagnosticChecks.storageHealth(Self.storage(freeFraction: 0.03)),
        ] + [DiagnosticChecks.storageSmart(Self.storage(freeFraction: 0.42))].compactMap { $0 }
    }

    // MARK: - P7.03 fixtures

    private static func battery(
        installed: Bool = true, capacity: Double? = 0.9, cycles: Int = 120,
        celsius: Double? = 28
    ) -> DiagnosticChecks.BatteryReading {
        DiagnosticChecks.BatteryReading(
            isInstalled: installed, cycleCount: cycles, capacityFraction: capacity,
            celsius: celsius)
    }

    private static func storage(
        freeFraction: Double, nandCelsius: Double? = 41.5, advertisesSmart: Bool = true
    ) -> DiagnosticChecks.StorageReading {
        let total: Int64 = 494_384_795_648
        return DiagnosticChecks.StorageReading(
            totalBytes: total, freeBytes: Int64(Double(total) * freeFraction),
            nandCelsius: nandCelsius, advertisesSmart: advertisesSmart)
    }

    // MARK: - The rule itself

    @Test("an accusation is never made without an explanation beside it")
    func attentionAlwaysCarriesCauses() {
        for finding in allFindings where finding.verdict == .needsAttention {
            #expect(!finding.possibleCauses.isEmpty)
            // More than one, always: a single "cause" reads as a diagnosis.
            #expect(finding.possibleCauses.count > 1, "one cause reads as certainty")
        }
    }

    @Test("needsAttention without a cause degrades to indeterminate")
    func causelessAttentionDegrades() {
        let refused = Diagnostic.needsAttention(.fanBalanceUnreadable, possibleCauses: [])
        #expect(refused.verdict == .indeterminate)
        #expect(refused.possibleCauses.isEmpty)
    }

    @Test("only needsAttention carries causes or steps")
    func onlyAttentionCarriesCauses() {
        for finding in allFindings where finding.verdict != .needsAttention {
            #expect(finding.possibleCauses.isEmpty)
            #expect(finding.nextSteps.isEmpty)
        }
    }

    @Test("a raised concern always suggests something to try")
    func attentionCarriesSteps() {
        for finding in allFindings where finding.verdict == .needsAttention {
            #expect(!finding.nextSteps.isEmpty)
        }
    }

    // The vocabulary half of the honesty rule — that no wording ever names
    // a fault — moved to `make gate-i18n` in P6.11, where it runs over the
    // String Catalog in **every** language. A Swift test could only ever
    // have checked the English, and a translation can break the rule too.

    // MARK: - The checks

    @Test("fan response says nothing until it has seen enough")
    func fanResponseNeedsEvidence() {
        let few = Array(repeating: (target: 2_000, actual: 900), count: 3)
        #expect(DiagnosticChecks.fanResponse(samples: few).verdict == .indeterminate)
    }

    @Test("a fan tracking its target is healthy; one far from it is not")
    func fanResponseVerdicts() {
        let tracking = Array(repeating: (target: 2_000, actual: 2_050), count: 10)
        #expect(DiagnosticChecks.fanResponse(samples: tracking).verdict == .healthy)

        let lagging = Array(repeating: (target: 3_000, actual: 1_100), count: 10)
        #expect(DiagnosticChecks.fanResponse(samples: lagging).verdict == .needsAttention)
    }

    @Test("normal slew does not trip the fan response check")
    func slewIsNotAFault() {
        // A fan ramping under the standard rate limit sits behind its
        // target by design. A check that fired on that would be a check
        // people learn to ignore.
        let ramping = (0..<10).map { step in
            (target: 4_000, actual: 3_700 + step * 30)
        }
        #expect(DiagnosticChecks.fanResponse(samples: ramping).verdict == .healthy)
    }

    @Test("a single fan cannot be out of balance with itself")
    func balanceNeedsTwoFans() {
        let finding = DiagnosticChecks.fanBalance(speeds: [1_800])
        #expect(finding.verdict == .notApplicable)
        // The coverage limit stated rather than hidden (R8).
        #expect(finding.finding == .fanBalanceSingleFan)
    }

    @Test("sensor validity distinguishes nothing-to-say from something-to-say")
    func sensorValidityVerdicts() {
        #expect(
            DiagnosticChecks.sensorValidity(outOfRange: [], stuck: [], totalSensors: 0).verdict
                == .indeterminate)
        #expect(
            DiagnosticChecks.sensorValidity(outOfRange: [], stuck: [], totalSensors: 12).verdict
                == .healthy)

        let stuck = DiagnosticChecks.sensorValidity(
            outOfRange: [], stuck: ["GPU tdie1"], totalSensors: 12)
        #expect(stuck.verdict == .needsAttention)
        // A parked cluster is the *first* explanation offered, because on
        // Apple Silicon it is the most likely one.
        #expect(stuck.possibleCauses.first == .parkedCluster)
    }

    @Test("thermal history reports the system's own verdict, and only after a minute")
    func thermalHistoryVerdicts() {
        #expect(
            DiagnosticChecks.thermalHistory(
                seriousSeconds: 0, criticalSeconds: 0, sessionSeconds: 10, peakCelsius: 60
            ).verdict == .indeterminate)

        #expect(
            DiagnosticChecks.thermalHistory(
                seriousSeconds: 0, criticalSeconds: 0, sessionSeconds: 3_600, peakCelsius: 60
            ).verdict == .healthy)

        #expect(
            DiagnosticChecks.thermalHistory(
                seriousSeconds: 40, criticalSeconds: 5, sessionSeconds: 3_600, peakCelsius: 96
            ).verdict == .needsAttention)
    }

    // MARK: - Battery (P7.03)

    @Test("a Mac with no battery is told so definitely, not left unknown")
    func absentBatteryIsDefinite() {
        // The distinction the probe made possible: `AppleSmartBattery` answers on
        // desktops too and reports `BatteryInstalled = 0`, so "this Mac has no
        // battery" and "the battery could not be read" are different facts and
        // must not share a sentence.
        let absent = DiagnosticChecks.batteryHealth(Self.battery(installed: false))
        #expect(absent.verdict == .notApplicable)
        #expect(absent.finding == .batteryAbsent)

        let unreadable = DiagnosticChecks.batteryHealth(nil)
        #expect(unreadable.verdict == .indeterminate)
        #expect(unreadable.finding == .batteryUnreadable)
        #expect(absent.finding != unreadable.finding)
    }

    @Test("a worn battery is described as aged, never as failing")
    func wornBatteryLeadsWithNormalAgeing() {
        // 71% after 940 cycles is a battery that has done exactly what a battery
        // does. The first cause offered has to say so, or the notice reads as an
        // accusation against the hardware.
        let worn = DiagnosticChecks.batteryHealth(Self.battery(capacity: 0.71, cycles: 940))
        #expect(worn.verdict == .needsAttention)
        #expect(worn.possibleCauses.first == .batteryAgedNormally)
    }

    @Test("the worn threshold is the published one, not an invented one")
    func wornThresholdIsTheServiceFigure() {
        // 80% is the figure Apple's own service documentation uses for the end of
        // a battery's rated life, so it is the one number here a user may already
        // have seen. A different threshold would be this project inventing a
        // standard.
        #expect(DiagnosticChecks.batteryWornCapacityFraction == 0.80)
        #expect(
            DiagnosticChecks.batteryHealth(Self.battery(capacity: 0.81)).verdict == .healthy)
        #expect(
            DiagnosticChecks.batteryHealth(Self.battery(capacity: 0.79)).verdict
                == .needsAttention)
    }

    @Test("a warm battery is reported without asking the fans to do anything")
    func warmBatteryIsInformationOnly() {
        // A battery temperature is not something a fan can fix, so this is
        // information and must never read as a reason to raise fan speed.
        let warm = DiagnosticChecks.batteryHealth(Self.battery(capacity: 0.92, celsius: 38))
        #expect(warm.verdict == .needsAttention)
        #expect(warm.nextSteps.contains(.avoidChargingInHeat))
        #expect(!warm.nextSteps.contains(.tryProfileThatEngagesEarlier))
    }

    @Test("a capacity of zero reads as unreadable rather than as a dead battery")
    func zeroCapacityIsUnreadable() {
        // The honesty rule at its sharpest: a battery reporting 0% design
        // capacity is almost certainly a read failure, and calling it a failed
        // battery would be the exact false positive the rule exists to prevent.
        let zero = DiagnosticChecks.batteryHealth(Self.battery(capacity: 0))
        #expect(zero.verdict == .indeterminate)
        #expect(zero.finding == .batteryUnreadable)
    }

    // MARK: - Storage (P7.03)

    @Test("a nearly full drive is a thermal observation as well as a capacity one")
    func nearlyFullMentionsWarming() {
        let full = DiagnosticChecks.storageHealth(Self.storage(freeFraction: 0.03))
        #expect(full.verdict == .needsAttention)
        #expect(full.possibleCauses.contains(.sustainedWritesWarmTheDrive))
        #expect(full.finding == .storageNearlyFull(freePercent: 3, nandCelsius: 41.5))
    }

    @Test("a healthy capacity verdict never implies a healthy drive")
    func smartIsAlwaysItsOwnFinding() {
        // Kept apart deliberately: a single combined sentence would invite
        // reading "42% free" as "the drive is fine", and the drive's wear is
        // exactly what this build cannot measure.
        let reading = Self.storage(freeFraction: 0.42)
        #expect(DiagnosticChecks.storageHealth(reading).verdict == .healthy)
        let smart = DiagnosticChecks.storageSmart(reading)
        #expect(smart?.verdict == .indeterminate)
        #expect(smart?.finding == .storageSmartUnavailable)
    }

    @Test("a drive that does not advertise SMART produces no unmeasured claim")
    func noSmartClaimWithoutSmart() {
        let noSmart = Self.storage(freeFraction: 0.42, advertisesSmart: false)
        #expect(DiagnosticChecks.storageSmart(noSmart) == nil)
    }

    @Test("an unreadable drive is indeterminate, never healthy")
    func unreadableStorageIsIndeterminate() {
        #expect(DiagnosticChecks.storageHealth(nil).verdict == .indeterminate)
        let empty = DiagnosticChecks.StorageReading(
            totalBytes: 0, freeBytes: 0, nandCelsius: nil, advertisesSmart: false)
        #expect(DiagnosticChecks.storageHealth(empty).verdict == .indeterminate)
    }
}
