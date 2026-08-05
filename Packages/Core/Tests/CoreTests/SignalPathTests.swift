import Foundation
import Testing

@testable import Core

@Suite("EWMA smoothing (engine stage 1)")
struct EWMATests {

    @Test("the boundary values behave exactly as stated")
    func boundaries() {
        // α = 1: no smoothing, the sample passes through.
        #expect(EWMA(alpha: 1).smooth(previous: 50, sample: 80) == 80)
        // α = 0: frozen at the previous value forever.
        #expect(EWMA(alpha: 0).smooth(previous: 50, sample: 80) == 50)
    }

    @Test("a step of the default alpha moves 30 percent of the distance")
    func standardStep() {
        let smoothed = EWMA.standard.smooth(previous: 50, sample: 60)
        #expect(abs(smoothed - 53) < 0.0001)
    }

    @Test("the first sample passes through and bad inputs cannot poison the stream")
    func firstSampleAndBadInputs() {
        let ewma = EWMA.standard
        #expect(ewma.smooth(previous: nil, sample: 61.5) == 61.5)
        // A NaN sample keeps the previous value instead of spreading.
        #expect(ewma.smooth(previous: 50, sample: .nan) == 50)
        // A poisoned previous value is discarded, not averaged with.
        #expect(ewma.smooth(previous: .nan, sample: 61.5) == 61.5)
        // An ambiguous alpha means no smoothing, not a crash.
        #expect(EWMA(alpha: .nan).alpha == 1)
        #expect(EWMA(alpha: 7).alpha == 1)
        #expect(EWMA(alpha: -1).alpha == 0)
    }
}

@Suite("Hysteresis (engine stage 2, dual curve with a direction lock)")
struct HysteresisTests {

    private let curve = try? Curve(points: [
        CurvePoint(celsius: 35, duty: Duty(0.00)),
        CurvePoint(celsius: 50, duty: Duty(0.20)),
        CurvePoint(celsius: 65, duty: Duty(0.45)),
        CurvePoint(celsius: 78, duty: Duty(0.75)),
        CurvePoint(celsius: 88, duty: Duty(1.00)),
    ])

    @Test("oscillation smaller than the band produces a constant output")
    func noOscillationInsideTheBand() throws {
        let curve = try #require(curve)
        let hysteresis = Hysteresis.standard  // 3 °C band

        // Rise to 66, then bounce between 64 and 66 — a 2 °C wobble around
        // a steep part of the curve. Without hysteresis the duty would
        // follow every bounce; with it, the output must not move at all.
        var state: Hysteresis.State?
        var result = hysteresis.evaluate(curve: curve, celsius: 66, state: state)
        state = result.state
        let locked = result.duty

        for celsius in [64.0, 65.5, 64.2, 66.0, 64.8, 65.9, 64.1] {
            result = hysteresis.evaluate(curve: curve, celsius: celsius, state: state)
            state = result.state
            #expect(result.duty == locked, "moved at \(celsius)")
        }
    }

    @Test("the branch handoff is continuous in both directions")
    func handoffIsContinuous() throws {
        let curve = try #require(curve)
        let hysteresis = Hysteresis.standard

        // Rising to 70, then falling straight through the band edge.
        var state: Hysteresis.State?
        var result = hysteresis.evaluate(curve: curve, celsius: 70, state: state)
        state = result.state
        let atPeak = result.duty

        // Exactly at the edge (70 − 3): still locked at the peak value.
        result = hysteresis.evaluate(curve: curve, celsius: 67.01, state: state)
        #expect(result.duty == atPeak)
        state = result.state

        // Just past the edge: the falling curve takes over, and its value
        // at (peak − band) equals the base curve at the peak — no step.
        result = hysteresis.evaluate(curve: curve, celsius: 66.99, state: state)
        #expect(abs(result.duty.value - atPeak.value) < 0.002)
        #expect(result.state.branch == .falling)
        state = result.state

        // Falling to 60, then rising back through the band: same rule,
        // mirrored. falling(60) == base(63); rising resumes at base(63.01).
        result = hysteresis.evaluate(curve: curve, celsius: 60, state: state)
        state = result.state
        let atTrough = result.duty
        result = hysteresis.evaluate(curve: curve, celsius: 63.01, state: state)
        #expect(abs(result.duty.value - atTrough.value) < 0.002)
        #expect(result.state.branch == .rising)
    }

    @Test("while falling, the shifted curve keeps the fans faster than the base curve would")
    func fallingBranchBiasesHot() throws {
        let curve = try #require(curve)
        let hysteresis = Hysteresis.standard

        var state: Hysteresis.State?
        state = hysteresis.evaluate(curve: curve, celsius: 75, state: state).state
        // Fall well past the band so the falling branch is active.
        let result = hysteresis.evaluate(curve: curve, celsius: 60, state: state)
        #expect(result.state.branch == .falling)
        #expect(result.duty > curve.duty(at: 60))
        #expect(result.duty == curve.duty(at: 63))
    }
}

@Suite("Rate limit (engine stage 3, asymmetric)")
struct RateLimitTests {

    @Test("rise and fall are limited independently")
    func asymmetry() {
        let limit = RateLimit.standard  // 600 up, 150 down

        // A 2000 rpm demand upward covers 600 in one second…
        #expect(limit.limit(previousRPM: 1000, targetRPM: 3000, elapsedSeconds: 1) == 1600)
        // …while the same demand downward covers only 150.
        #expect(limit.limit(previousRPM: 3000, targetRPM: 1000, elapsedSeconds: 1) == 2850)
    }

    @Test("the step scales with elapsed time and never overshoots the target")
    func timeScalingAndNoOvershoot() {
        let limit = RateLimit.standard
        #expect(limit.limit(previousRPM: 1000, targetRPM: 3000, elapsedSeconds: 0.5) == 1300)
        // Close to the target, the limiter lands exactly on it.
        #expect(limit.limit(previousRPM: 2990, targetRPM: 3000, elapsedSeconds: 1) == 3000)
        #expect(limit.limit(previousRPM: 1010, targetRPM: 1000, elapsedSeconds: 1) == 1000)
    }

    @Test("the first evaluation passes through; zero elapsed time holds")
    func firstAndZeroDt() {
        let limit = RateLimit.standard
        #expect(limit.limit(previousRPM: nil, targetRPM: 2500, elapsedSeconds: 1) == 2500)
        #expect(limit.limit(previousRPM: 2000, targetRPM: 3000, elapsedSeconds: 0) == 2000)
    }
}

@Suite("Sensor aggregator (max / mean / p95)")
struct SensorAggregateTests {

    @Test("max is the default safety bias; mean averages; p95 shrugs off one outlier")
    func semantics() {
        let readings = [60.0, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 105]

        #expect(SensorAggregate.max.value(of: readings) == 105)
        // Sum of 60…78 is 1311, plus the 105 outlier: 1416 over 20 readings.
        let mean = SensorAggregate.mean.value(of: readings)
        #expect(abs((mean ?? 0) - 70.8) < 0.0001)
        // Nearest rank over 20 readings: the 19th sorted value — the outlier
        // at 105 does not decide, the hot cluster at 78 does.
        #expect(SensorAggregate.p95.value(of: readings) == 78)
    }

    @Test("empty input is nil, and non-finite readings are dropped first")
    func emptinessAndPoison() {
        for aggregate in SensorAggregate.allCases {
            #expect(aggregate.value(of: []) == nil)
            #expect(aggregate.value(of: [.nan, .infinity]) == nil)
            #expect(aggregate.value(of: [.nan, 55]) == 55)
        }
    }
}
