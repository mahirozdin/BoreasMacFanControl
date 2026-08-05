import Foundation

/// Which sensors feed a curve, and how they collapse into one temperature
/// (`docs/product/control-model.md`, input selection).
public struct SensorInput: Sendable, Hashable, Codable {
    public let group: SensorGroup
    public let aggregate: SensorAggregate
    public let smoothing: EWMA

    public init(group: SensorGroup, aggregate: SensorAggregate = .max, smoothing: EWMA = .standard) {
        self.group = group
        self.aggregate = aggregate
        self.smoothing = smoothing
    }
}

/// One fan's behaviour inside a profile: its curve and its input.
public struct FanBinding: Sendable, Hashable, Codable {
    public let curve: Curve
    public let input: SensorInput

    public init(curve: Curve, input: SensorInput) {
        self.curve = curve
        self.input = input
    }
}

/// A named behaviour: curves, an optional trigger, a priority
/// (`docs/product/control-model.md`, profiles).
public struct Profile: Sendable, Hashable, Codable {

    /// Stable identifier. The built-in names double as localisation keys;
    /// user-created profiles carry whatever the user typed.
    public let name: String

    /// The binding used for any fan without an entry in `perFan`.
    public let binding: FanBinding

    /// Per-fan overrides — a profile may give each fan its own curve and
    /// its own sensor group.
    public let perFan: [Int: FanBinding]

    /// The condition that activates this profile automatically. `nil` means
    /// the profile is reachable only manually or as the default.
    public let trigger: ProfileTrigger?

    /// Higher wins among profiles whose trigger holds.
    public let priority: Int

    /// The `System` profile: the engine does not drive at all and the
    /// firmware keeps the fans. Modelled as data, not a special case in the
    /// loop, so arbitration can select it like any other profile.
    public let enginePaused: Bool

    public init(
        name: String,
        binding: FanBinding,
        perFan: [Int: FanBinding] = [:],
        trigger: ProfileTrigger? = nil,
        priority: Int = 0,
        enginePaused: Bool = false
    ) {
        self.name = name
        self.binding = binding
        self.perFan = perFan
        self.trigger = trigger
        self.priority = priority
        self.enginePaused = enginePaused
    }

    public func binding(forFan fanID: Int) -> FanBinding {
        perFan[fanID] ?? binding
    }
}

/// The built-in profiles. Point values are this project's own product
/// decision (the blueprint describes the intent qualitatively): `Balanced`
/// is the blueprint's worked example; `Quiet` engages later and shallower,
/// trading peak temperature for silence; `Performance` engages earlier and
/// steeper. All three end at full duty by 88 °C — no profile is allowed to
/// be a way of never cooling hard.
public enum BuiltInProfiles {

    public static let defaultName = "Balanced"

    static let balancedCurve = fixed([
        (35, 0.00), (50, 0.20), (65, 0.45), (78, 0.75), (88, 1.00),
    ])
    static let quietCurve = fixed([
        (40, 0.00), (58, 0.15), (72, 0.40), (82, 0.70), (88, 1.00),
    ])
    static let performanceCurve = fixed([
        (30, 0.10), (45, 0.35), (60, 0.65), (72, 0.90), (88, 1.00),
    ])

    public static func all(group: SensorGroup = .compute) -> [Profile] {
        let input = SensorInput(group: group)
        return [
            Profile(
                name: "Quiet",
                binding: FanBinding(curve: quietCurve, input: input)),
            Profile(
                name: defaultName,
                binding: FanBinding(curve: balancedCurve, input: input)),
            Profile(
                name: "Performance",
                binding: FanBinding(curve: performanceCurve, input: input)),
            Profile(
                name: "System",
                binding: FanBinding(curve: balancedCurve, input: input),
                enginePaused: true),
        ]
    }

    /// The literals above are static and proven monotone by the curve tests;
    /// a failure here would be a typo in this file, caught by every test run
    /// because the built-ins are exercised constantly.
    private static func fixed(_ points: [(Double, Double)]) -> Curve {
        let curvePoints = points.map { CurvePoint(celsius: $0.0, duty: Duty($0.1)) }
        if let curve = try? Curve(points: curvePoints) {
            return curve
        }
        // Unreachable for the literals above; the safe direction anyway.
        return Curve.fullSpeedFallback
    }
}
