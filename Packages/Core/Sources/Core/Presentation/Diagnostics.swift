import Foundation

/// One diagnostic result (P6.09).
///
/// **The honesty rule is enforced by the type, not by the wording.**
/// `docs/operations/diagnostics.md` says the application never states as
/// certain what it cannot know: it must not say "the fan is faulty", it
/// must say what it measured, what could explain it, and what to do next.
///
/// So there is no `faulty` case. The strongest verdict available is
/// `needsAttention`, and one cannot be constructed without at least one
/// possible cause — an accusation with no explanation offered beside it is
/// exactly what the rule forbids. A caller who tries gets `indeterminate`,
/// which is the honest answer to "something is odd and I cannot say why".
///
/// The reasoning behind the rule: a false "faulty" sends someone to an
/// unnecessary repair. In this category a wrong diagnosis costs more than
/// no diagnosis.
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

    /// What was actually measured, in plain words. Always present: a
    /// verdict with nothing behind it is an opinion.
    public let observation: String

    /// Possible explanations, never a single confident one. Empty for
    /// every verdict except `needsAttention`, where it cannot be.
    public let possibleCauses: [String]

    /// What the user could do next. May be empty when there is nothing
    /// useful to suggest — inventing a step is its own dishonesty.
    public let nextSteps: [String]

    private init(
        verdict: Verdict,
        observation: String,
        possibleCauses: [String],
        nextSteps: [String]
    ) {
        self.verdict = verdict
        self.observation = observation
        self.possibleCauses = possibleCauses
        self.nextSteps = nextSteps
    }

    public static func healthy(_ observation: String) -> Diagnostic {
        Diagnostic(
            verdict: .healthy, observation: observation, possibleCauses: [], nextSteps: [])
    }

    public static func indeterminate(_ observation: String) -> Diagnostic {
        Diagnostic(
            verdict: .indeterminate, observation: observation, possibleCauses: [], nextSteps: [])
    }

    public static func notApplicable(_ observation: String) -> Diagnostic {
        Diagnostic(
            verdict: .notApplicable, observation: observation, possibleCauses: [], nextSteps: [])
    }

    /// Degrades to `indeterminate` when no cause is offered. Not a silent
    /// downgrade: it is the rule. Saying "something is wrong" and stopping
    /// there is the shape of report that sends people to repair shops.
    public static func needsAttention(
        _ observation: String,
        possibleCauses: [String],
        nextSteps: [String] = []
    ) -> Diagnostic {
        guard !possibleCauses.isEmpty else {
            return .indeterminate(observation)
        }
        return Diagnostic(
            verdict: .needsAttention,
            observation: observation,
            possibleCauses: possibleCauses,
            nextSteps: nextSteps)
    }
}

/// The pure half of the diagnostic checks: measurements in, findings out.
///
/// Every function here is total and side-effect free, so the wording and
/// the thresholds are both testable. The application layer only gathers
/// the numbers.
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
            return .indeterminate(
                "The fans have not been driven long enough this session to judge how they respond."
            )
        }

        let deviations = samples.map { abs($0.actual - $0.target) }
        let worst = deviations.max() ?? 0
        let typical = deviations.reduce(0, +) / deviations.count

        if typical <= fanToleranceRPM {
            return .healthy(
                "The fans followed their targets to within \(typical) rpm on average.")
        }

        // Everything below is phrased as an observation plus possibilities.
        // None of it names a fault.
        return .needsAttention(
            "The fans sat \(typical) rpm from their target on average, "
                + "and as much as \(worst) rpm away.",
            possibleCauses: [
                "Dust in the fan or the vents, which makes a fan slower than its command",
                "A fan or cable that is not connected as firmly as it was",
                "The firmware overriding the requested speed for its own reasons",
                "A hardware fault",
            ],
            nextSteps: [
                "Check that the vents are clear",
                "Watch whether the deviation changes with load or stays constant",
            ])
    }

    /// Fan balance: on a machine with more than one fan, do they run
    /// together?
    public static func fanBalance(speeds: [Int]) -> Diagnostic {
        guard speeds.count > 1 else {
            return .notApplicable(
                "This Mac has a single fan, so there is nothing to compare it against.")
        }
        guard let lowest = speeds.min(), let highest = speeds.max() else {
            return .indeterminate("No fan speeds were readable.")
        }

        let difference = highest - lowest
        // A fifth of the spread, or the flat tolerance, whichever is larger:
        // fans idle at similar speeds and diverge under load, and a fixed
        // number would cry wolf at one end or say nothing at the other.
        let allowed = Swift.max(fanToleranceRPM, highest / 5)
        if difference <= allowed {
            return .healthy("The fans are within \(difference) rpm of each other.")
        }
        return .needsAttention(
            "One fan is running \(difference) rpm faster than another.",
            possibleCauses: [
                "The fans are cooling different parts of the machine and are meant to differ",
                "Dust or an obstruction on the slower fan",
                "A fan that is not responding to its command",
            ],
            nextSteps: ["Check whether the difference persists when the machine is idle"])
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
            return .indeterminate("No sensor is being read right now.")
        }
        guard !outOfRange.isEmpty || !stuck.isEmpty else {
            return .healthy("All \(totalSensors) sensors are reporting plausible, changing values.")
        }

        var parts: [String] = []
        if !outOfRange.isEmpty {
            parts.append("outside anything physical: \(outOfRange.joined(separator: ", "))")
        }
        if !stuck.isEmpty {
            parts.append("unchanged all session: \(stuck.joined(separator: ", "))")
        }

        return .needsAttention(
            "Some sensors are reporting oddly — " + parts.joined(separator: "; ") + ".",
            possibleCauses: [
                "A cluster the system has parked, which reports a fixed value by design",
                "A sensor this build does not understand yet",
                "A sensor that has stopped reporting",
            ],
            nextSteps: [
                "Compare with the machine under load, when parked clusters wake up",
                "Report the sensor with the unknown-sensor issue template",
            ])
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
            return .indeterminate("The session is too short to say anything about thermal history.")
        }

        let peak = peakCelsius.map { String(format: "%.1f °C", $0) } ?? "not recorded"
        guard seriousSeconds + criticalSeconds > 0 else {
            return .healthy(
                "The system reported no thermal pressure this session. Peak temperature: \(peak).")
        }

        return .needsAttention(
            "The system reported serious pressure for \(Int(seriousSeconds)) s and critical "
                + "pressure for \(Int(criticalSeconds)) s this session. Peak temperature: \(peak).",
            possibleCauses: [
                "Sustained heavy work, which is the ordinary reason",
                "Restricted airflow around the machine",
                "A fan curve that is quieter than this workload wants",
            ],
            nextSteps: [
                "Check that the vents are unobstructed",
                "Try a profile that engages the fans earlier",
            ])
    }
}
