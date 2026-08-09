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
        ]
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
}
