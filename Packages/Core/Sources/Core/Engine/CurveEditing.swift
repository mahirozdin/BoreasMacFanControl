import Foundation

/// Editing operations for the curve editor (P6.06).
///
/// **Every operation is total: it returns a valid `Curve`, always.** The
/// blueprint asks that a dragged point "does not go to an invalid
/// position", and that phrasing is the design: the constraint is enforced
/// by *clamping the input*, not by rejecting the result. An editor that
/// validated after the fact would have to decide what to show while the
/// finger is still down, and every answer to that is worse than not
/// letting the point leave the legal region in the first place.
///
/// The operations live here, beside the constraint they preserve, so they
/// can be fuzzed in `Core`'s tests. The view contributes the gesture and
/// nothing else.
extension Curve {

    /// The closest two control points may sit. Not an invariant of the type
    /// — the validating initialiser only demands strictly increasing
    /// temperatures — but an editing courtesy: two points a thousandth of a
    /// degree apart are indistinguishable on screen and describe no
    /// behaviour anyone meant.
    public static let minimumSeparation: Double = 0.5

    /// Moves one control point, clamped into the region its neighbours
    /// leave it. An out-of-range index, a non-finite temperature, or any
    /// result that would still fail validation leaves the curve untouched.
    public func moving(pointAt index: Int, toCelsius celsius: Double, duty: Duty) -> Curve {
        guard points.indices.contains(index) else { return self }
        guard celsius.isFinite else { return self }

        let lowerCelsius =
            index > 0
            ? points[index - 1].celsius + Self.minimumSeparation
            : Self.temperatureRange.lowerBound
        let upperCelsius =
            index < points.count - 1
            ? points[index + 1].celsius - Self.minimumSeparation
            : Self.temperatureRange.upperBound

        let lowerDuty = index > 0 ? points[index - 1].duty : Duty.minimum
        let upperDuty = index < points.count - 1 ? points[index + 1].duty : Duty.maximum

        // With neighbours closer together than the separation these ranges
        // invert; the clamp then produces something the validator refuses,
        // and the `try?` below keeps the old curve. Cheaper than a special
        // case, and it cannot produce a wrong answer.
        let clampedCelsius = Swift.min(Swift.max(celsius, lowerCelsius), upperCelsius)
        let clampedDuty = Duty(Swift.min(Swift.max(duty.value, lowerDuty.value), upperDuty.value))

        var edited = points
        edited[index] = CurvePoint(celsius: clampedCelsius, duty: clampedDuty)
        return (try? Curve(points: edited)) ?? self
    }

    /// Adds a control point at a temperature, taking the duty the curve
    /// already has there.
    ///
    /// Adding a point does not change what the curve does — it only gives
    /// the user something to grab. A new point that moved the curve would
    /// make "add a point here" a destructive act.
    public func inserting(atCelsius celsius: Double) -> Curve {
        guard points.count < Self.maximumPoints else { return self }
        guard celsius.isFinite, Self.temperatureRange.contains(celsius) else { return self }
        guard points.allSatisfy({ abs($0.celsius - celsius) >= Self.minimumSeparation }) else {
            return self
        }

        let inserted = CurvePoint(celsius: celsius, duty: duty(at: celsius))
        var edited = points
        let position = edited.firstIndex { $0.celsius > celsius } ?? edited.count
        edited.insert(inserted, at: position)
        return (try? Curve(points: edited)) ?? self
    }

    /// Removes a control point, refusing to go below the minimum. A curve
    /// with fewer than two points is not a transfer function.
    public func removing(at index: Int) -> Curve {
        guard points.count > Self.minimumPoints else { return self }
        guard points.indices.contains(index) else { return self }

        var edited = points
        edited.remove(at: index)
        return (try? Curve(points: edited)) ?? self
    }

    /// The index of the point nearest a position in curve coordinates,
    /// within a pick radius, or `nil`. Distance is measured on the
    /// normalised axes so a hit test does not depend on how many degrees
    /// happen to fit across the view.
    public func nearestPoint(
        toCelsius celsius: Double,
        duty: Duty,
        within radius: Double = 0.06
    ) -> Int? {
        let temperatureSpan = Self.temperatureRange.upperBound - Self.temperatureRange.lowerBound
        var best: (index: Int, distance: Double)?
        for (index, point) in points.enumerated() {
            let deltaX = (point.celsius - celsius) / temperatureSpan
            let deltaY = point.duty.value - duty.value
            let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()
            if distance <= radius, best == nil || distance < (best?.distance ?? .infinity) {
                best = (index, distance)
            }
        }
        return best?.index
    }
}
