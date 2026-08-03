import Foundation

/// How the machine is currently powered.
///
/// Profiles can be bound to this: quieter on battery, more aggressive on the
/// adapter. Desktops report ``PowerContext/Source/adapter`` and no battery
/// level, which is the correct answer rather than a missing one.
public struct PowerContext: Sendable, Hashable, Codable {

    public enum Source: String, Sendable, Hashable, Codable {
        case adapter
        case battery
    }

    public let source: Source

    /// Charge level 0...100, or nil on machines without a battery.
    public let batteryPercentage: Int?

    public init(source: Source, batteryPercentage: Int? = nil) {
        self.source = source
        self.batteryPercentage = batteryPercentage.map { Swift.min(100, Swift.max(0, $0)) }
    }

    public static let desktop = PowerContext(source: .adapter, batteryPercentage: nil)
}
