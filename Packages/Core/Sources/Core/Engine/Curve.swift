import Foundation

/// One control point of a fan curve.
public struct CurvePoint: Sendable, Hashable, Codable {
    public let celsius: Double
    public let duty: Duty

    public init(celsius: Double, duty: Duty) {
        self.celsius = celsius
        self.duty = duty
    }
}

/// A piecewise linear, continuous transfer function from temperature to duty
/// (`docs/product/control-model.md`, ADR 0010).
///
/// The monotonicity constraints live in the only initialiser: strictly
/// increasing temperatures, non-decreasing duties, 2–16 points, all finite.
/// A `Curve` value that violates them cannot exist, so every consumer —
/// interpolation, hysteresis, the editor of P6 — starts from a guarantee
/// instead of a hope.
public struct Curve: Sendable, Hashable {

    public enum ValidationError: Error, Equatable {
        case tooFewPoints(Int)
        case tooManyPoints(Int)
        case temperaturesNotStrictlyIncreasing(at: Int)
        case dutyDecreases(at: Int)
        case temperatureNotFinite(at: Int)
        case temperatureOutOfRange(at: Int)
    }

    /// The published schema's range for control point temperatures.
    public static let temperatureRange: ClosedRange<Double> = 0...120

    public static let minimumPoints = 2
    public static let maximumPoints = 16

    /// Sorted, validated. The array is as the initialiser proved it.
    public let points: [CurvePoint]

    public init(points: [CurvePoint]) throws {
        guard points.count >= Self.minimumPoints else {
            throw ValidationError.tooFewPoints(points.count)
        }
        guard points.count <= Self.maximumPoints else {
            throw ValidationError.tooManyPoints(points.count)
        }
        for (index, point) in points.enumerated() {
            guard point.celsius.isFinite else {
                throw ValidationError.temperatureNotFinite(at: index)
            }
            guard Self.temperatureRange.contains(point.celsius) else {
                throw ValidationError.temperatureOutOfRange(at: index)
            }
            guard index > 0 else { continue }
            guard point.celsius > points[index - 1].celsius else {
                throw ValidationError.temperaturesNotStrictlyIncreasing(at: index)
            }
            guard point.duty >= points[index - 1].duty else {
                throw ValidationError.dutyDecreases(at: index)
            }
        }
        self.points = points
    }

    /// Linear interpolation between the surrounding points; clamped to the
    /// first and last values beyond the ends. Total over every input: a NaN
    /// temperature reads as "beyond the hot end", because for a fan curve
    /// the safe reading of an unreadable temperature is the hot one.
    public func duty(at celsius: Double) -> Duty {
        guard let first = points.first, let last = points.last else {
            // Unreachable by construction; the safe answer anyway.
            return Duty(1)
        }
        if celsius.isNaN { return last.duty }
        if celsius <= first.celsius { return first.duty }
        if celsius >= last.celsius { return last.duty }

        for index in 1..<points.count {
            let upper = points[index]
            guard celsius <= upper.celsius else { continue }
            let lower = points[index - 1]
            let span = upper.celsius - lower.celsius
            let fraction = (celsius - lower.celsius) / span
            let value =
                lower.duty.value + (upper.duty.value - lower.duty.value) * fraction
            return Duty(value)
        }
        return last.duty
    }

    /// The one hand-built curve that cannot fail validation: full duty
    /// everywhere. Exists so unreachable fallbacks have somewhere safe to
    /// land without a force-try.
    public static let fullSpeedFallback: Curve = {
        let points = [
            CurvePoint(celsius: 0, duty: Duty(1)),
            CurvePoint(celsius: 100, duty: Duty(1)),
        ]
        if let curve = try? Curve(points: points) { return curve }
        fatalError("the constant full-speed curve failed its own validation")
    }()

    /// The falling branch of the hysteresis pair: the same curve shifted
    /// left by `band` degrees, so at any temperature it answers what the
    /// base curve would answer `band` degrees hotter.
    public func shiftedLeft(by band: Double) -> Curve {
        let shift = max(0, band)
        // Shifting preserves both monotonicity constraints, but a point
        // closer to 0 than the band would leave the schema's temperature
        // range. Such a curve keeps its base branch instead — no hysteresis
        // beats an invalid curve, and the output stays monotone either way.
        let shifted = points.map { CurvePoint(celsius: $0.celsius - shift, duty: $0.duty) }
        return (try? Curve(points: shifted)) ?? self
    }
}

/// Codable through the validating initialiser: a curve decoded from a
/// configuration file is either valid or a thrown `DecodingError` — the G6
/// groundwork. There is no path that yields a decoded-but-invalid curve.
extension Curve: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try container.decode([CurvePoint].self)
        do {
            try self.init(points: decoded)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "invalid curve: \(error)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(points)
    }
}
