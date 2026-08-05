import Foundation

/// Fan output as a fraction of the usable speed range, always within 0...1.
///
/// A plain `Double` was rejected: every call site would have to remember to
/// clamp, and one that forgets is a fan command outside what the hardware
/// accepts. Making the type unable to hold an invalid value removes that class
/// of bug rather than testing for it.
///
/// `0` is the hardware minimum, not "off". Boreas never stops a fan.
public struct Duty: Sendable, Hashable, Comparable {

    public let value: Double

    public init(_ value: Double) {
        // Non-finite input is a bug upstream, and the two possible failures are
        // not symmetric: too much airflow is noise, too little is heat. So an
        // undefined result resolves UPWARDS.
        //
        //   +infinity -> 1   clamping, unchanged in meaning
        //   -infinity -> 0   clamping, unchanged in meaning
        //   NaN       -> 1   deliberate. A machine whose fans roar because of a
        //                    defect gets reported; one that quietly stops
        //                    cooling gets damaged.
        //
        // This mirrors the safety chain rule that no layer may lower the output.
        if value.isNaN {
            self.value = 1
        } else {
            self.value = Swift.min(1, Swift.max(0, value))
        }
    }

    public static let minimum = Duty(0)
    public static let maximum = Duty(1)

    public var percent: Int { Int((value * 100).rounded()) }

    public static func < (lhs: Duty, rhs: Duty) -> Bool { lhs.value < rhs.value }

    /// Converts to an absolute speed for a given fan.
    ///
    ///     rpm = minimum + (maximum - minimum) * duty
    public func rpm(for fan: FanState) -> Int {
        fan.minimumRPM + Int((Double(fan.span) * value).rounded())
    }
}

/// Codable as a bare number, through the clamping initialiser: a duty
/// decoded from a configuration file obeys the same [0, 1] guarantee as a
/// constructed one, ambiguity resolving up included.
extension Duty: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(Double.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
