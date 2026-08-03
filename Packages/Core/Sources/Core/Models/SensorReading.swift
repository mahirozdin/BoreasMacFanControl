import Foundation

/// A single temperature sample.
///
/// `rawName` is kept alongside `displayName` on purpose: when a user reports an
/// unrecognised sensor, the raw string is what the maintainers need, and asking
/// them to dig it out again is a poor trade for a few bytes.
public struct SensorReading: Sendable, Hashable, Identifiable, Codable {

    /// Stable identity derived from the raw hardware name.
    public let id: String

    /// Name exactly as the hardware reported it.
    public let rawName: String

    /// Human readable name after normalisation.
    public let displayName: String

    public let group: SensorGroup

    public let celsius: Double

    public init(
        rawName: String,
        displayName: String,
        group: SensorGroup,
        celsius: Double
    ) {
        self.id = rawName
        self.rawName = rawName
        self.displayName = displayName
        self.group = group
        self.celsius = celsius
    }

    /// Readings outside this range mean the sensor is asleep, missing or lying.
    ///
    /// Apple Silicon parks unused clusters and the sensors then report values
    /// far outside anything physical. Feeding those into a fan curve would
    /// either spin the fans up for no reason or, worse, hold them down.
    public static let plausibleRange: ClosedRange<Double> = -20...150

    public var isPlausible: Bool {
        Self.plausibleRange.contains(celsius)
    }
}
