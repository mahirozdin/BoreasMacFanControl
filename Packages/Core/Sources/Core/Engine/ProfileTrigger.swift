import Foundation

/// A condition that can activate a profile
/// (`docs/product/control-model.md`, trigger types).
///
/// Manual selection is deliberately **not** a trigger: it is an input to
/// arbitration that beats every trigger, and modelling it as a condition
/// would let it lose.
public enum ProfileTrigger: Sendable, Hashable {

    /// The machine runs on the given power source.
    case powerSource(PowerContext.Source)

    /// The application is running (`foregroundOnly: false`) or frontmost
    /// (`foregroundOnly: true`).
    case application(bundleIdentifier: String, foregroundOnly: Bool)

    /// A daily window in minutes since midnight, end exclusive. A window
    /// that wraps midnight (`start > end`, like 23:00–08:00) means "evening
    /// or morning", and that reading is pinned by a test.
    case timeWindow(startMinute: Int, endMinute: Int)

    /// The battery is at or below the given percentage. Never holds on a
    /// machine without a battery — a desktop is not "at 0%".
    case batteryAtOrBelow(percent: Int)

    /// An external display is connected (or not).
    case externalDisplay(connected: Bool)

    /// The thermal pressure is at least the given level.
    case thermalStateAtLeast(ThermalPressure)

    /// What the machine looks like right now. A plain value so trigger
    /// evaluation stays a pure function the tests can feed.
    public struct Environment: Sendable, Hashable {
        public var power: PowerContext
        public var foregroundBundleIdentifier: String?
        public var runningBundleIdentifiers: Set<String>
        public var minuteOfDay: Int
        public var externalDisplayConnected: Bool
        public var thermal: ThermalPressure

        public init(
            power: PowerContext = .desktop,
            foregroundBundleIdentifier: String? = nil,
            runningBundleIdentifiers: Set<String> = [],
            minuteOfDay: Int = 0,
            externalDisplayConnected: Bool = false,
            thermal: ThermalPressure = .nominal
        ) {
            self.power = power
            self.foregroundBundleIdentifier = foregroundBundleIdentifier
            self.runningBundleIdentifiers = runningBundleIdentifiers
            self.minuteOfDay = minuteOfDay
            self.externalDisplayConnected = externalDisplayConnected
            self.thermal = thermal
        }
    }

    public func holds(in environment: Environment) -> Bool {
        switch self {
        case .powerSource(let source):
            return environment.power.source == source

        case .application(let bundleIdentifier, let foregroundOnly):
            if foregroundOnly {
                return environment.foregroundBundleIdentifier == bundleIdentifier
            }
            return environment.runningBundleIdentifiers.contains(bundleIdentifier)

        case .timeWindow(let start, let end):
            let minute = environment.minuteOfDay
            if start == end { return false }
            if start < end { return minute >= start && minute < end }
            // Wraps midnight: 23:00–08:00 holds in the evening OR morning.
            return minute >= start || minute < end

        case .batteryAtOrBelow(let percent):
            guard let level = environment.power.batteryPercentage else { return false }
            return level <= percent

        case .externalDisplay(let connected):
            return environment.externalDisplayConnected == connected

        case .thermalStateAtLeast(let level):
            return environment.thermal.rank >= level.rank
        }
    }
}

extension ThermalPressure {
    /// Ordering for "at least this bad" comparisons.
    var rank: Int {
        switch self {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        }
    }
}

/// The published wire format: a type discriminator plus named fields, so
/// the schema reads like configuration instead of like a compiler artefact.
extension ProfileTrigger: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case bundleIdentifier
        case foregroundOnly
        case startMinute
        case endMinute
        case percent
        case connected
    }

    private enum Kind: String, Codable {
        case powerSource
        case application
        case timeWindow
        case batteryAtOrBelow
        case externalDisplay
        case thermalStateAtLeast
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .powerSource:
            self = .powerSource(try container.decode(PowerContext.Source.self, forKey: .value))
        case .application:
            self = .application(
                bundleIdentifier: try container.decode(String.self, forKey: .bundleIdentifier),
                foregroundOnly: try container.decodeIfPresent(Bool.self, forKey: .foregroundOnly)
                    ?? false)
        case .timeWindow:
            self = .timeWindow(
                startMinute: try container.decode(Int.self, forKey: .startMinute),
                endMinute: try container.decode(Int.self, forKey: .endMinute))
        case .batteryAtOrBelow:
            self = .batteryAtOrBelow(percent: try container.decode(Int.self, forKey: .percent))
        case .externalDisplay:
            self = .externalDisplay(
                connected: try container.decode(Bool.self, forKey: .connected))
        case .thermalStateAtLeast:
            self = .thermalStateAtLeast(
                try container.decode(ThermalPressure.self, forKey: .value))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .powerSource(let source):
            try container.encode(Kind.powerSource, forKey: .type)
            try container.encode(source, forKey: .value)
        case .application(let bundleIdentifier, let foregroundOnly):
            try container.encode(Kind.application, forKey: .type)
            try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
            try container.encode(foregroundOnly, forKey: .foregroundOnly)
        case .timeWindow(let start, let end):
            try container.encode(Kind.timeWindow, forKey: .type)
            try container.encode(start, forKey: .startMinute)
            try container.encode(end, forKey: .endMinute)
        case .batteryAtOrBelow(let percent):
            try container.encode(Kind.batteryAtOrBelow, forKey: .type)
            try container.encode(percent, forKey: .percent)
        case .externalDisplay(let connected):
            try container.encode(Kind.externalDisplay, forKey: .type)
            try container.encode(connected, forKey: .connected)
        case .thermalStateAtLeast(let level):
            try container.encode(Kind.thermalStateAtLeast, forKey: .type)
            try container.encode(level, forKey: .value)
        }
    }
}
