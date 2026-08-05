import Foundation

/// The composed control engine: one pure step from sensor readings to fan
/// targets, through every stage in its documented order —
/// aggregate → smooth → hysteresis/curve → safety chain → rate limit.
///
/// The golden scenarios of P5.12 run against exactly this function, and the
/// application loop calls it with live data. There is no second pipeline to
/// drift from this one.
public enum Engine {

    /// Everything the engine remembers between steps. A value, handed back
    /// on every step: the caller owns time and persistence.
    public struct State: Sendable, Hashable {
        public var smoothedByGroup: [SensorGroup: Double]
        public var hysteresisByFan: [Int: Hysteresis.State]
        public var panicLock: PanicLock
        public var previousRPMByFan: [Int: Int]

        public static let initial = State(
            smoothedByGroup: [:], hysteresisByFan: [:],
            panicLock: .released, previousRPMByFan: [:])
    }

    public struct Cycle: Sendable, Hashable {
        public let targets: [FanTarget]
        public let activeLayer: SafetyLayer?
        public let state: State
    }

    /// Everything one cycle reads. `readingsByGroup` carries every sensor
    /// reading keyed by group — the safety chain's panic input is the
    /// hottest reading across **all** groups, not only the bound one.
    public struct Input: Sendable {
        public var profile: Profile
        public var fans: [FanState]
        public var readingsByGroup: [SensorGroup: [Double]]
        public var thermal: ThermalPressure
        public var panicThreshold: PanicThreshold
        public var now: Date
        /// Wall time since the previous step, for the slew limiter.
        public var elapsedSeconds: Double

        public init(
            profile: Profile,
            fans: [FanState],
            readingsByGroup: [SensorGroup: [Double]],
            thermal: ThermalPressure,
            panicThreshold: PanicThreshold = .standard,
            now: Date,
            elapsedSeconds: Double
        ) {
            self.profile = profile
            self.fans = fans
            self.readingsByGroup = readingsByGroup
            self.thermal = thermal
            self.panicThreshold = panicThreshold
            self.now = now
            self.elapsedSeconds = elapsedSeconds
        }
    }

    /// One control cycle.
    public static func step(_ input: Input, state: State) -> Cycle {
        let profile = input.profile
        let fans = input.fans
        let readingsByGroup = input.readingsByGroup
        let thermal = input.thermal
        let panicThreshold = input.panicThreshold
        let now = input.now
        let elapsedSeconds = input.elapsedSeconds

        guard !profile.enginePaused, !fans.isEmpty else {
            // The System profile: the firmware keeps the fans. No targets,
            // and the per-fan memory resets so a later engage starts clean.
            var idle = state
            idle.hysteresisByFan = [:]
            idle.previousRPMByFan = [:]
            return Cycle(targets: [], activeLayer: nil, state: idle)
        }

        var next = state
        let hottestOverall = readingsByGroup.values.flatMap { $0 }
            .filter(\.isFinite).max()

        var targets: [FanTarget] = []
        var reportedLayer: SafetyLayer?

        for fan in fans {
            let binding = profile.binding(forFan: fan.id)

            // 1. Aggregate the bound group…
            let aggregated = binding.input.aggregate.value(
                of: readingsByGroup[binding.input.group] ?? [])

            // 2. …smooth it. With no reading at all the previous smoothed
            // value carries; with no history either, the curve's NaN rule
            // (reads hot) takes over downstream.
            let smoothed: Double
            if let aggregated {
                smoothed = profile.smoothing.smooth(
                    previous: next.smoothedByGroup[binding.input.group],
                    sample: aggregated)
                next.smoothedByGroup[binding.input.group] = smoothed
            } else {
                smoothed = next.smoothedByGroup[binding.input.group] ?? .nan
            }

            // 3. Hysteresis picks the branch and the curve answers.
            let evaluated = profile.hysteresis.evaluate(
                curve: binding.curve, celsius: smoothed,
                state: next.hysteresisByFan[fan.id])
            next.hysteresisByFan[fan.id] = evaluated.state

            // 4. The safety chain — always in the path, never rate limited.
            let verdict = SafetyChain.govern(
                requested: evaluated.duty,
                thermal: thermal,
                hottestCelsius: hottestOverall,
                threshold: panicThreshold,
                lock: next.panicLock,
                now: now)
            next.panicLock = verdict.lock
            if let layer = verdict.activeLayer { reportedLayer = layer }

            // 5. The slew limiter shapes the engine's own requests only:
            // when a safety layer is the reason, the target jumps.
            let unlimited = verdict.duty.rpm(for: fan)
            let limited: Int
            if verdict.activeLayer == nil {
                limited = profile.slew.limit(
                    previousRPM: next.previousRPMByFan[fan.id],
                    targetRPM: unlimited,
                    elapsedSeconds: elapsedSeconds)
            } else {
                limited = unlimited
            }
            next.previousRPMByFan[fan.id] = limited

            targets.append(FanTarget(fanID: fan.id, rpm: limited))
        }

        return Cycle(targets: targets, activeLayer: reportedLayer, state: next)
    }
}
