import Foundation
import Testing

@testable import Core

@Suite("Curve (type-level monotonicity, interpolation, ADR 0010)")
struct CurveTests {

    private let blueprint = try? Curve(points: [
        CurvePoint(celsius: 35, duty: Duty(0.00)),
        CurvePoint(celsius: 50, duty: Duty(0.20)),
        CurvePoint(celsius: 65, duty: Duty(0.45)),
        CurvePoint(celsius: 78, duty: Duty(0.75)),
        CurvePoint(celsius: 88, duty: Duty(1.00)),
    ])

    // MARK: - The constraints live in the type

    @Test("an invalid curve cannot be constructed")
    func invalidCurvesAreUnrepresentable() {
        #expect(throws: Curve.ValidationError.tooFewPoints(1)) {
            try Curve(points: [CurvePoint(celsius: 40, duty: Duty(0.5))])
        }
        #expect(throws: Curve.ValidationError.temperaturesNotStrictlyIncreasing(at: 1)) {
            try Curve(points: [
                CurvePoint(celsius: 50, duty: Duty(0.2)),
                CurvePoint(celsius: 50, duty: Duty(0.4)),
            ])
        }
        #expect(throws: Curve.ValidationError.dutyDecreases(at: 1)) {
            try Curve(points: [
                CurvePoint(celsius: 40, duty: Duty(0.5)),
                CurvePoint(celsius: 60, duty: Duty(0.3)),
            ])
        }
        #expect(throws: Curve.ValidationError.temperatureNotFinite(at: 0)) {
            try Curve(points: [
                CurvePoint(celsius: .nan, duty: Duty(0.2)),
                CurvePoint(celsius: 60, duty: Duty(0.4)),
            ])
        }
        let seventeen = (0..<17).map { CurvePoint(celsius: Double($0), duty: Duty(0.5)) }
        #expect(throws: Curve.ValidationError.tooManyPoints(17)) {
            try Curve(points: seventeen)
        }
    }

    @Test("interpolation hits the control points and the midpoints")
    func interpolationIsLinear() throws {
        let curve = try #require(blueprint)
        #expect(curve.duty(at: 50) == Duty(0.20))
        #expect(curve.duty(at: 88) == Duty(1.00))
        // Midway between (50, 0.20) and (65, 0.45).
        #expect(abs(curve.duty(at: 57.5).value - 0.325) < 0.0001)
    }

    @Test("beyond the ends the curve clamps, and NaN reads hot")
    func endsClampAndNaNReadsHot() throws {
        let curve = try #require(blueprint)
        #expect(curve.duty(at: -40) == Duty(0.00))
        #expect(curve.duty(at: 200) == Duty(1.00))
        #expect(curve.duty(at: .nan) == Duty(1.00))
    }

    // MARK: - P5.02 property tests (undeletable, ARCHITECTURE §7)

    @Test("a monotonically increasing curve produces a monotonically increasing output")
    func monotoneCurveMonotoneOutput() throws {
        let curve = try #require(blueprint)
        var previous = curve.duty(at: -10)
        var celsius = -10.0
        while celsius <= 120 {
            let duty = curve.duty(at: celsius)
            #expect(duty >= previous, "output fell at \(celsius)")
            previous = duty
            celsius += 0.25
        }
    }

    @Test("output always lies within the fan's minimum and maximum")
    func outputAlwaysInsideFanLimits() throws {
        let curve = try #require(blueprint)
        let fan = FanState(
            id: 0, name: "Fan 1", currentRPM: 1200,
            minimumRPM: 1000, maximumRPM: 4900, isPoweredOff: false)
        for celsius in stride(from: -40.0, through: 150.0, by: 1.0) {
            let rpm = curve.duty(at: celsius).rpm(for: fan)
            #expect(rpm >= fan.minimumRPM && rpm <= fan.maximumRPM, "at \(celsius)")
        }
    }

    // MARK: - P5.09: the comparison that keeps ADR 0010 alive in code

    @Test("a discrete step model jumps at its threshold; the continuous curve does not")
    func continuousBeatsSteps() throws {
        let curve = try #require(blueprint)

        // The rejected alternative, built here so the difference stays
        // measurable: three bands with hard edges.
        func stepModel(_ celsius: Double) -> Double {
            if celsius < 55 { return 0.20 }
            if celsius < 75 { return 0.55 }
            return 1.00
        }

        let threshold = 55.0
        let epsilon = 0.1

        let stepJump = abs(stepModel(threshold + epsilon) - stepModel(threshold - epsilon))
        let curveJump = abs(
            curve.duty(at: threshold + epsilon).value
                - curve.duty(at: threshold - epsilon).value)

        // Crossing the band edge by 0.1 °C jumps the step model by 35
        // duty-points — an audible gear change. The continuous curve moves
        // by its local slope only.
        #expect(stepJump >= 0.35)
        #expect(curveJump < 0.01)
    }

    @Test("shifting left preserves the shape and biases hot")
    func shiftedLeftReadsHotter() throws {
        let curve = try #require(blueprint)
        let shifted = curve.shiftedLeft(by: 3)
        for celsius in stride(from: 30.0, through: 100.0, by: 2.5) {
            #expect(shifted.duty(at: celsius) == curve.duty(at: celsius + 3))
        }
    }
}
