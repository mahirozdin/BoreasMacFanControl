import Foundation
import Testing

@testable import Core

/// The undeletable invariant tests of ARCHITECTURE.md §7 for the engine-side
/// safety layers (G1, G2, K1–K3).
@Suite("Safety chain (K1-K3, invariants G1/G2)")
struct SafetyChainTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 10_000)

    // MARK: - G1: layers only raise

    @Test("no safety layer can lower the output")
    func noLayerLowersOutput() {
        // A grid over every layer combination: requested duty × thermal
        // state × sensor temperature × lock state. The one property that
        // must hold everywhere: output ≥ input.
        let duties = [0.0, 0.1, 0.4, 0.55, 0.56, 0.8, 1.0].map { Duty($0) }
        let thermals = ThermalPressure.allCases
        let temperatures: [Double?] = [nil, 20, 94.9, 95, 95.1, 120]
        let locks = [PanicLock.released, PanicLock(until: t0.addingTimeInterval(10))]

        for duty in duties {
            for thermal in thermals {
                for temperature in temperatures {
                    for lock in locks {
                        let verdict = SafetyChain.govern(
                            requested: duty, thermal: thermal,
                            hottestCelsius: temperature, lock: lock, now: t0)
                        #expect(
                            verdict.duty >= duty,
                            "lowered: \(duty.value) -> \(verdict.duty.value) (\(thermal))")
                    }
                }
            }
        }
    }

    // MARK: - K2

    @Test("thermalState .critical forces 100 percent regardless of the user curve")
    func criticalForcesFullSpeed() {
        for requested in [0.0, 0.3, 0.99, 1.0] {
            let verdict = SafetyChain.govern(
                requested: Duty(requested), thermal: .critical,
                hottestCelsius: 30, now: t0)
            #expect(verdict.duty == Duty(1))
            #expect(verdict.activeLayer == .thermalCritical)
        }
    }

    @Test("serious floors at 55 percent but never lowers a higher request")
    func seriousIsAFloorNotAValue() {
        let raised = SafetyChain.govern(
            requested: Duty(0.2), thermal: .serious, hottestCelsius: 40, now: t0)
        #expect(raised.duty == SafetyChain.seriousFloor)
        #expect(raised.activeLayer == .thermalSerious)

        let untouched = SafetyChain.govern(
            requested: Duty(0.8), thermal: .serious, hottestCelsius: 40, now: t0)
        #expect(untouched.duty == Duty(0.8))
        #expect(untouched.activeLayer == nil)
    }

    @Test("an unknown thermal state reads as critical")
    func unknownThermalStateIsCritical() {
        // The mirror enum maps every known case; the compiler forces the
        // @unknown default, and its choice is pinned here: worst case.
        #expect(ThermalPressure(.nominal) == .nominal)
        #expect(ThermalPressure(.serious) == .serious)
        #expect(ThermalPressure(.critical) == .critical)
    }

    // MARK: - K3

    @Test("a sensor above the panic threshold forces 100 percent and locks for 30 seconds")
    func panicTriggersAndHolds() {
        let hot = SafetyChain.govern(
            requested: Duty(0.1), thermal: .nominal, hottestCelsius: 96, now: t0)
        #expect(hot.duty == Duty(1))
        #expect(hot.activeLayer == .panic)
        #expect(hot.lock.isActive(at: t0))

        // The temperature recovers immediately — the output must not.
        let recovered = SafetyChain.govern(
            requested: Duty(0.1), thermal: .nominal, hottestCelsius: 60,
            lock: hot.lock, now: t0.addingTimeInterval(29))
        #expect(recovered.duty == Duty(1))
        #expect(recovered.activeLayer == .panic)

        // Past the hold, control returns to the curve.
        let released = SafetyChain.govern(
            requested: Duty(0.1), thermal: .nominal, hottestCelsius: 60,
            lock: hot.lock, now: t0.addingTimeInterval(31))
        #expect(released.duty == Duty(0.1))
        #expect(released.activeLayer == nil)
        #expect(!released.lock.isActive(at: t0.addingTimeInterval(31)))
    }

    @Test("staying hot re-arms the hold; it expires 30 seconds after the last excursion")
    func holdMeasuresFromLastExcursion() {
        let first = SafetyChain.govern(
            requested: Duty(0), thermal: .nominal, hottestCelsius: 96, now: t0)
        let still = SafetyChain.govern(
            requested: Duty(0), thermal: .nominal, hottestCelsius: 96,
            lock: first.lock, now: t0.addingTimeInterval(20))

        // 20 s in and still hot: the lock now reaches t0+50, not t0+30.
        let at45 = t0.addingTimeInterval(45)
        #expect(still.lock.isActive(at: at45))
    }

    @Test("exactly the threshold does not panic; strictly above does")
    func thresholdBoundary() {
        let atThreshold = SafetyChain.govern(
            requested: Duty(0.2), thermal: .nominal,
            hottestCelsius: PanicThreshold.defaultCelsius, now: t0)
        #expect(atThreshold.activeLayer == nil)

        let above = SafetyChain.govern(
            requested: Duty(0.2), thermal: .nominal,
            hottestCelsius: PanicThreshold.defaultCelsius + 0.1, now: t0)
        #expect(above.activeLayer == .panic)
    }

    @Test("no sensor reading never triggers a panic by itself")
    func missingSensorDoesNotPanic() {
        // Sensor loss is a degradation the monitoring layer reports; the
        // panic layer acts on measured heat, not on the absence of data.
        // K2 still covers the machine through the official thermal state.
        let verdict = SafetyChain.govern(
            requested: Duty(0.3), thermal: .nominal, hottestCelsius: nil, now: t0)
        #expect(verdict.duty == Duty(0.3))
        #expect(verdict.activeLayer == nil)
    }

    // MARK: - G2: the threshold can only be lowered

    @Test("the panic threshold cannot be raised above the default")
    func thresholdOnlyLowerable() {
        #expect(PanicThreshold(celsius: 105).celsius == PanicThreshold.defaultCelsius)
        #expect(PanicThreshold(celsius: 96).celsius == PanicThreshold.defaultCelsius)
        #expect(PanicThreshold(celsius: 95).celsius == 95)
        #expect(PanicThreshold(celsius: 85).celsius == 85)
        #expect(PanicThreshold(celsius: 500).celsius == PanicThreshold.defaultCelsius)
        #expect(PanicThreshold(celsius: .infinity).celsius == PanicThreshold.defaultCelsius)
    }

    @Test("the panic threshold has a floor, and ambiguity resolves down")
    func thresholdFloorAndAmbiguity() {
        #expect(PanicThreshold(celsius: 10).celsius == PanicThreshold.floorCelsius)
        // NaN resolves DOWN for a trigger threshold: panicking sooner is the
        // safe direction, mirroring how an ambiguous Duty resolves UP.
        #expect(PanicThreshold(celsius: .nan).celsius == PanicThreshold.floorCelsius)
    }

    // MARK: - K1: the fan floor is structural

    @Test("output rpm never goes below the hardware minimum")
    func rpmNeverBelowHardwareMinimum() {
        let fan = FanState(
            id: 0, name: "Fan 1", currentRPM: 1200,
            minimumRPM: 1000, maximumRPM: 4900, isPoweredOff: false)

        // Adversarial raw inputs included: Duty's own clamp is part of K1.
        for raw in [-1.0, 0.0, 0.5, 1.0, 2.0, -.infinity, .infinity, .nan] {
            let rpm = Duty(raw).rpm(for: fan)
            #expect(rpm >= fan.minimumRPM)
            #expect(rpm <= fan.maximumRPM)
        }
    }
}
