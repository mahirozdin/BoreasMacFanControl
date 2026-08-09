import Foundation
import Testing

@testable import Core

@Suite("Curve editing (the constraint holds by clamping, not by refusing)")
struct CurveEditingTests {

    private let curve =
        (try? Curve(points: [
            CurvePoint(celsius: 35, duty: Duty(0.00)),
            CurvePoint(celsius: 50, duty: Duty(0.20)),
            CurvePoint(celsius: 65, duty: Duty(0.45)),
            CurvePoint(celsius: 78, duty: Duty(0.75)),
            CurvePoint(celsius: 88, duty: Duty(1.00)),
        ])) ?? Curve.fullSpeedFallback

    // MARK: - Dragging

    @Test("a point dragged past its right neighbour is clamped, never reordered")
    func clampedAgainstRightNeighbour() {
        let moved = curve.moving(pointAt: 1, toCelsius: 200, duty: Duty(0.2))
        #expect(moved.points[1].celsius <= 65 - Curve.minimumSeparation)
        #expect(moved.points[1].celsius > moved.points[0].celsius)
        // Order is preserved: point 1 is still between points 0 and 2.
        #expect(moved.points.map(\.celsius) == moved.points.map(\.celsius).sorted())
    }

    @Test("a point dragged below its left neighbour's duty is clamped")
    func clampedAgainstLeftDuty() {
        // Point 2 sits at 0.45 with 0.20 to its left: dragging it to zero
        // would make the curve fall, which the model forbids outright.
        let moved = curve.moving(pointAt: 2, toCelsius: 65, duty: Duty(0))
        #expect(moved.points[2].duty == Duty(0.20))
        for (earlier, later) in zip(moved.points, moved.points.dropFirst()) {
            #expect(later.duty >= earlier.duty)
        }
    }

    @Test("the end points stay inside the published temperature range")
    func endsStayInRange() {
        let low = curve.moving(pointAt: 0, toCelsius: -400, duty: Duty(0))
        #expect(low.points[0].celsius == Curve.temperatureRange.lowerBound)

        let high = curve.moving(pointAt: 4, toCelsius: 900, duty: Duty(1))
        #expect(high.points[4].celsius == Curve.temperatureRange.upperBound)
    }

    @Test("a nonsense drag leaves the curve exactly as it was")
    func nonsenseDragsIgnored() {
        #expect(curve.moving(pointAt: 99, toCelsius: 50, duty: Duty(0.5)) == curve)
        #expect(curve.moving(pointAt: -1, toCelsius: 50, duty: Duty(0.5)) == curve)
        #expect(curve.moving(pointAt: 2, toCelsius: .nan, duty: Duty(0.5)) == curve)
    }

    // MARK: - Adding and removing

    @Test("adding a point does not change what the curve does")
    func insertingPreservesShape() {
        // The point is a handle, not an edit: "add a point here" must not
        // move the fans.
        let widened = curve.inserting(atCelsius: 58)
        #expect(widened.points.count == curve.points.count + 1)
        for probe in stride(from: 20.0, through: 100.0, by: 0.25) {
            let before = curve.duty(at: probe).value
            let after = widened.duty(at: probe).value
            #expect(abs(before - after) < 1e-9, "shape moved at \(probe) °C")
        }
    }

    @Test("adding is refused when it would be meaningless or illegal")
    func insertingRefused() {
        // On top of an existing point.
        #expect(curve.inserting(atCelsius: 50.2) == curve)
        // Outside the published range, and not a number.
        #expect(curve.inserting(atCelsius: 500) == curve)
        #expect(curve.inserting(atCelsius: .nan) == curve)

        // At the ceiling of sixteen points.
        var full = curve
        var celsius = 20.0
        while full.points.count < Curve.maximumPoints {
            full = full.inserting(atCelsius: celsius)
            celsius += 2
        }
        #expect(full.points.count == Curve.maximumPoints)
        #expect(full.inserting(atCelsius: 100) == full)
    }

    @Test("removing stops at two points — fewer is not a transfer function")
    func removingRefusedAtMinimum() {
        var thinned = curve
        while thinned.points.count > Curve.minimumPoints {
            thinned = thinned.removing(at: 0)
        }
        #expect(thinned.points.count == Curve.minimumPoints)
        #expect(thinned.removing(at: 0) == thinned)
        #expect(curve.removing(at: 99) == curve)
    }

    // MARK: - The acceptance criterion, fuzzed

    @Test("no sequence of edits can produce an invalid curve")
    func editingCannotBreakTheCurve() {
        // The P6 acceptance criterion says the editor enforces the
        // monotonicity constraint. Proving that by clicking is proving one
        // path; here ten thousand hostile edits are thrown at it, including
        // drags far outside the plot and duties in the wrong order.
        var generator = SmallGenerator(seed: 20_260_805)
        var edited = curve

        for step in 0..<10_000 {
            let index = Int(generator.next() % 20) - 2
            let celsius = Double(generator.next() % 400) - 100
            let duty = Duty(Double(generator.next() % 300) / 100 - 1)

            switch step % 4 {
            case 0: edited = edited.moving(pointAt: index, toCelsius: celsius, duty: duty)
            case 1: edited = edited.inserting(atCelsius: celsius)
            case 2: edited = edited.removing(at: index)
            default: edited = edited.moving(pointAt: index, toCelsius: celsius, duty: duty)
            }

            // Reconstructing through the validating initialiser is the
            // check: if it would throw, the editor produced something the
            // engine could never be given.
            #expect(
                (try? Curve(points: edited.points)) != nil,
                "editing produced an invalid curve at step \(step)")
            #expect(edited.points.count >= Curve.minimumPoints)
            #expect(edited.points.count <= Curve.maximumPoints)
        }
    }

    // MARK: - Hit testing

    @Test("the nearest point is found within the pick radius and not outside it")
    func nearestPoint() {
        #expect(curve.nearestPoint(toCelsius: 51, duty: Duty(0.21)) == 1)
        // Same temperature, far away vertically: not a hit.
        #expect(curve.nearestPoint(toCelsius: 50, duty: Duty(0.95)) == nil)
    }
}

/// A tiny deterministic generator. `Math.random` would make a failure
/// impossible to reproduce, and a failing fuzz case nobody can re-run is a
/// failure nobody can fix.
private struct SmallGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 33
    }
}
