import Foundation

/// What a diagnostic found, as a value rather than a sentence (P6.09,
/// restructured in P6.11).
///
/// The sentences used to live here. That put ~24 user facing strings in
/// `Core`, where they were invisible to both the String Catalog and the
/// gate that scans for hard coded text — `gate-i18n` only ever looked at
/// `App/Sources`. Two dozen quiet violations of Y1 is what a blind spot in
/// a gate buys you.
///
/// So `Core` decides *what was found* and the application says it in the
/// user's language. Making these cases rather than strings means the
/// application's rendering switch is exhaustive: a new finding fails to
/// compile until somebody writes the words for it.
public enum DiagnosticFinding: Sendable, Hashable {
    case fanResponseNoData
    case fanResponseTracking(averageDeviation: Int)
    case fanResponseDeviating(averageDeviation: Int, worstDeviation: Int)

    case fanBalanceSingleFan
    case fanBalanceUnreadable
    case fanBalanceTogether(difference: Int)
    case fanBalanceApart(difference: Int)

    case sensorsUnreadable
    case sensorsHealthy(count: Int)
    case sensorsOutOfRange(names: [String])
    case sensorsStuck(names: [String])
    case sensorsOutOfRangeAndStuck(outOfRange: [String], stuck: [String])

    case thermalSessionTooShort
    case thermalCalm(peakCelsius: Double?)
    case thermalPressure(seriousSeconds: Int, criticalSeconds: Int, peakCelsius: Double?)
}

/// A possible explanation. Never one on its own — see `Diagnostic`.
public enum DiagnosticCause: Sendable, Hashable, CaseIterable {
    case dustInFanOrVents
    case loosenedConnection
    case firmwareOverriding
    case hardwareFault
    case fansCoolDifferentParts
    case obstructionOnSlowerFan
    case fanNotResponding
    case parkedCluster
    case sensorNotUnderstoodYet
    case sensorStoppedReporting
    case sustainedHeavyWork
    case restrictedAirflow
    case quieterCurveThanWorkload
}

/// Something the user could try. May be empty: inventing a step is its own
/// dishonesty.
public enum DiagnosticStep: Sendable, Hashable, CaseIterable {
    case checkVentsAreClear
    case watchWhetherDeviationChangesWithLoad
    case checkDifferencePersistsWhenIdle
    case compareUnderLoad
    case reportUnknownSensor
    case tryProfileThatEngagesEarlier
}

/// One diagnostic result.
///
/// **The honesty rule is enforced by the type.**
/// `docs/operations/diagnostics.md` says the application never states as
/// certain what it cannot know: it must not say "the fan is faulty", it
/// must say what it measured, what could explain it, and what to do next.
///
/// So there is no `faulty` case. The strongest verdict available is
/// `needsAttention`, and one cannot be constructed without at least one
/// possible cause — an accusation with no explanation beside it is exactly
/// what the rule forbids. A caller who tries gets `indeterminate`, which is
/// the honest answer to "something is odd and I cannot say why".
///
/// The reasoning: a false "faulty" sends someone to an unnecessary repair.
/// In this category a wrong diagnosis costs more than no diagnosis. The
/// *vocabulary* half of that rule is checked by `make gate-i18n`, over the
/// String Catalog, in every language — which is stronger than the Swift
/// test it replaced, because a translation can break a rule too.
public struct Diagnostic: Sendable, Hashable {

    public enum Verdict: String, Sendable, Hashable {
        /// Measured, and nothing is out of the ordinary.
        case healthy
        /// Something measurable is off. Never a diagnosis of the cause.
        case needsAttention
        /// Not enough evidence yet — the honest answer more often than
        /// anyone likes.
        case indeterminate
        /// Cannot apply to this Mac at all (no battery, one fan).
        case notApplicable
    }

    public let verdict: Verdict

    /// What was actually measured. Always present: a verdict with nothing
    /// behind it is an opinion.
    public let finding: DiagnosticFinding

    /// Possible explanations, never a single confident one. Empty for
    /// every verdict except `needsAttention`, where it cannot be.
    public let possibleCauses: [DiagnosticCause]

    public let nextSteps: [DiagnosticStep]

    private init(
        verdict: Verdict,
        finding: DiagnosticFinding,
        possibleCauses: [DiagnosticCause],
        nextSteps: [DiagnosticStep]
    ) {
        self.verdict = verdict
        self.finding = finding
        self.possibleCauses = possibleCauses
        self.nextSteps = nextSteps
    }

    public static func healthy(_ finding: DiagnosticFinding) -> Diagnostic {
        Diagnostic(verdict: .healthy, finding: finding, possibleCauses: [], nextSteps: [])
    }

    public static func indeterminate(_ finding: DiagnosticFinding) -> Diagnostic {
        Diagnostic(verdict: .indeterminate, finding: finding, possibleCauses: [], nextSteps: [])
    }

    public static func notApplicable(_ finding: DiagnosticFinding) -> Diagnostic {
        Diagnostic(verdict: .notApplicable, finding: finding, possibleCauses: [], nextSteps: [])
    }

    /// Degrades to `indeterminate` when no cause is offered. Not a silent
    /// downgrade: it is the rule. Saying "something is wrong" and stopping
    /// there is the shape of report that sends people to repair shops.
    public static func needsAttention(
        _ finding: DiagnosticFinding,
        possibleCauses: [DiagnosticCause],
        nextSteps: [DiagnosticStep] = []
    ) -> Diagnostic {
        guard !possibleCauses.isEmpty else {
            return .indeterminate(finding)
        }
        return Diagnostic(
            verdict: .needsAttention,
            finding: finding,
            possibleCauses: possibleCauses,
            nextSteps: nextSteps)
    }
}

/// The pure half of the diagnostic checks: measurements in, findings out.
///
/// Every function here is total and side-effect free, so the thresholds are
/// testable without a machine. The application layer gathers the numbers
/// and supplies the words.
public enum DiagnosticChecks {

    /// How far a fan may sit from its target before the deviation is worth
    /// mentioning. Wide, deliberately: the rate limiter means a fan is
    /// *supposed* to lag a changing target, and a check that fired on
    /// normal slew would train people to ignore it.
    public static let fanToleranceRPM = 400

    /// Below this many samples nothing is claimed at all.
    public static let minimumSamples = 5

    /// Fan response: does the hardware follow what it was told?
    ///
    /// Pairs are (target, actual) taken while the engine was driving. The
    /// check deliberately says nothing about *why* a fan does not follow.
    public static func fanResponse(samples: [(target: Int, actual: Int)]) -> Diagnostic {
        guard samples.count >= minimumSamples else {
            return .indeterminate(.fanResponseNoData)
        }

        let deviations = samples.map { abs($0.actual - $0.target) }
        let worst = deviations.max() ?? 0
        let typical = deviations.reduce(0, +) / deviations.count

        if typical <= fanToleranceRPM {
            return .healthy(.fanResponseTracking(averageDeviation: typical))
        }

        return .needsAttention(
            .fanResponseDeviating(averageDeviation: typical, worstDeviation: worst),
            possibleCauses: [
                .dustInFanOrVents, .loosenedConnection, .firmwareOverriding, .hardwareFault,
            ],
            nextSteps: [.checkVentsAreClear, .watchWhetherDeviationChangesWithLoad])
    }

    /// Fan balance: on a machine with more than one fan, do they run
    /// together?
    public static func fanBalance(speeds: [Int]) -> Diagnostic {
        guard speeds.count > 1 else {
            return .notApplicable(.fanBalanceSingleFan)
        }
        guard let lowest = speeds.min(), let highest = speeds.max() else {
            return .indeterminate(.fanBalanceUnreadable)
        }

        let difference = highest - lowest
        // A fifth of the spread, or the flat tolerance, whichever is larger:
        // fans idle at similar speeds and diverge under load, and a fixed
        // number would cry wolf at one end or say nothing at the other.
        let allowed = Swift.max(fanToleranceRPM, highest / 5)
        if difference <= allowed {
            return .healthy(.fanBalanceTogether(difference: difference))
        }
        return .needsAttention(
            .fanBalanceApart(difference: difference),
            possibleCauses: [.fansCoolDifferentParts, .obstructionOnSlowerFan, .fanNotResponding],
            nextSteps: [.checkDifferencePersistsWhenIdle])
    }

    /// Sensor validity: readings out of range, or stuck at one value for a
    /// whole session.
    ///
    /// `stuck` is the interesting one and the easiest to get wrong: Apple
    /// Silicon parks unused clusters, and a parked sensor legitimately
    /// reports the same number for hours. So a stuck reading is reported as
    /// something to look at, never as a broken sensor.
    public static func sensorValidity(
        outOfRange: [String],
        stuck: [String],
        totalSensors: Int
    ) -> Diagnostic {
        guard totalSensors > 0 else {
            return .indeterminate(.sensorsUnreadable)
        }
        guard !outOfRange.isEmpty || !stuck.isEmpty else {
            return .healthy(.sensorsHealthy(count: totalSensors))
        }

        let finding: DiagnosticFinding
        if outOfRange.isEmpty {
            finding = .sensorsStuck(names: stuck)
        } else if stuck.isEmpty {
            finding = .sensorsOutOfRange(names: outOfRange)
        } else {
            finding = .sensorsOutOfRangeAndStuck(outOfRange: outOfRange, stuck: stuck)
        }

        return .needsAttention(
            finding,
            // A parked cluster first: on Apple Silicon it is the likeliest
            // explanation by a distance.
            possibleCauses: [.parkedCluster, .sensorNotUnderstoodYet, .sensorStoppedReporting],
            nextSteps: [.compareUnderLoad, .reportUnknownSensor])
    }

    /// Thermal history: how long the system itself reported pressure.
    ///
    /// This one reports the system's own verdict rather than inferring
    /// anything, which is why it can afford to be plain.
    public static func thermalHistory(
        seriousSeconds: Double,
        criticalSeconds: Double,
        sessionSeconds: Double,
        peakCelsius: Double?
    ) -> Diagnostic {
        guard sessionSeconds >= 60 else {
            return .indeterminate(.thermalSessionTooShort)
        }
        guard seriousSeconds + criticalSeconds > 0 else {
            return .healthy(.thermalCalm(peakCelsius: peakCelsius))
        }
        return .needsAttention(
            .thermalPressure(
                seriousSeconds: Int(seriousSeconds),
                criticalSeconds: Int(criticalSeconds),
                peakCelsius: peakCelsius),
            possibleCauses: [.sustainedHeavyWork, .restrictedAirflow, .quieterCurveThanWorkload],
            nextSteps: [.checkVentsAreClear, .tryProfileThatEngagesEarlier])
    }
}
