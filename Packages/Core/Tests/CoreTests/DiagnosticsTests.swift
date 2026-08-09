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

    @Test("no finding ever names a fault")
    func neverNamesAFault() {
        // The words the honesty rule exists to keep out of the product.
        // `docs/operations/diagnostics.md`: a false "faulty" sends someone
        // to an unnecessary repair, and in this category a wrong diagnosis
        // costs more than no diagnosis.
        let forbidden = ["faulty", "broken", "defective", "failed", "damaged", "dead"]
        for finding in allFindings {
            let text =
                ([finding.observation] + finding.possibleCauses + finding.nextSteps)
                .joined(separator: " ")
                .lowercased()
            for word in forbidden {
                #expect(!text.contains(word), "\"\(word)\" appears in: \(finding.observation)")
            }
        }
    }

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
        let refused = Diagnostic.needsAttention("Something is odd.", possibleCauses: [])
        #expect(refused.verdict == .indeterminate)
        #expect(refused.possibleCauses.isEmpty)
    }

    @Test("every finding says what was measured")
    func everyFindingObserves() {
        for finding in allFindings {
            #expect(!finding.observation.isEmpty)
        }
    }

    @Test("only needsAttention carries causes")
    func onlyAttentionCarriesCauses() {
        for finding in allFindings where finding.verdict != .needsAttention {
            #expect(finding.possibleCauses.isEmpty)
        }
    }

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
        #expect(finding.observation.contains("single fan"))
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
        #expect(stuck.possibleCauses.first?.contains("parked") == true)
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
