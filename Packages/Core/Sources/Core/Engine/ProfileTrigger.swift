import Foundation

/// A condition that can activate a profile
/// (`docs/product/control-model.md`, trigger types).
///
/// Manual selection is deliberately **not** a trigger: it is an input to
/// arbitration that beats every trigger, and modelling it as a condition
/// would let it lose.
public enum ProfileTrigger: Sendable, Hashable, Codable {

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
