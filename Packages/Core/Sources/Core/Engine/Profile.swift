import Foundation

/// Which sensors feed a curve, and how they collapse into one temperature
/// (`docs/product/control-model.md`, input selection).
public struct SensorInput: Sendable, Hashable, Codable {
    public let group: SensorGroup
    public let aggregate: SensorAggregate

    public init(group: SensorGroup, aggregate: SensorAggregate = .max) {
        self.group = group
        self.aggregate = aggregate
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

/// A named behaviour: curves, triggers, processing parameters, a priority
/// (`docs/product/control-model.md`, profiles).
///
/// Smoothing, hysteresis and the slew limits sit at the profile level — the
/// blueprint's wire schema puts them there, and it reads right: a "Quiet"
/// profile is quiet in how it *moves*, not only in where its curve sits.
public struct Profile: Sendable, Hashable {

    /// Stable identifier. The built-in names double as localisation keys;
    /// user-created profiles carry whatever the user typed.
    public let name: String

    /// The binding used for any fan without an entry in `perFan`.
    public let binding: FanBinding

    /// Per-fan overrides — a profile may give each fan its own curve and
    /// its own sensor group.
    public let perFan: [Int: FanBinding]

    /// The conditions that activate this profile automatically. The profile
    /// holds when **any** of them holds — the blueprint's own example binds
    /// "Night Quiet" to a time window *or* battery power. Empty means the
    /// profile is reachable only manually or as the default.
    public let triggers: [ProfileTrigger]

    /// Higher wins among profiles whose trigger holds.
    public let priority: Int

    /// Input smoothing for every curve in this profile.
    public let smoothing: EWMA

    /// The hysteresis band for every curve in this profile.
    public let hysteresis: Hysteresis

    /// The output slew limits for every fan in this profile.
    public let slew: RateLimit

    /// The `System` profile: the engine does not drive at all and the
    /// firmware keeps the fans. Modelled as data, not a special case in the
    /// loop, so arbitration can select it like any other profile.
    public let enginePaused: Bool

    public init(
        name: String,
        binding: FanBinding,
        perFan: [Int: FanBinding] = [:],
        triggers: [ProfileTrigger] = [],
        priority: Int = 0,
        smoothing: EWMA = .standard,
        hysteresis: Hysteresis = .standard,
        slew: RateLimit = .standard,
        enginePaused: Bool = false
    ) {
        self.name = name
        self.binding = binding
        self.perFan = perFan
        self.triggers = triggers
        self.priority = priority
        self.smoothing = smoothing
        self.hysteresis = hysteresis
        self.slew = slew
        self.enginePaused = enginePaused
    }

    public func binding(forFan fanID: Int) -> FanBinding {
        perFan[fanID] ?? binding
    }

    /// The first trigger that holds, or `nil` when none does. The specific
    /// trigger is returned, not just a Bool, so arbitration can tell the
    /// user *which* condition made this profile active.
    public func holdingTrigger(in environment: ProfileTrigger.Environment) -> ProfileTrigger? {
        triggers.first { $0.holds(in: environment) }
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
                binding: FanBinding(curve: quietCurve, input: input),
                smoothing: EWMA(alpha: 0.2),
                hysteresis: Hysteresis(band: 5),
                slew: RateLimit(maxRisePerSecond: 300, maxFallPerSecond: 100)),
            Profile(
                name: defaultName,
                binding: FanBinding(curve: balancedCurve, input: input)),
            Profile(
                name: "Performance",
                binding: FanBinding(curve: performanceCurve, input: input),
                smoothing: EWMA(alpha: 0.4)),
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

/// The wire format keeps per-fan overrides as an object keyed by the fan
/// id ("0", "1", …). Swift would otherwise encode an Int-keyed dictionary
/// as a flat array, which no schema reader would forgive.
extension Profile: Codable {

    private enum CodingKeys: String, CodingKey {
        case name
        case binding
        case perFan
        case triggers
        case priority
        case smoothing
        case hysteresis
        case slew
        case enginePaused
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPerFan =
            try container.decodeIfPresent([String: FanBinding].self, forKey: .perFan) ?? [:]
        var perFan: [Int: FanBinding] = [:]
        for (key, value) in rawPerFan {
            guard let fanID = Int(key) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .perFan, in: container,
                    debugDescription: "fan id \"\(key)\" is not a number")
            }
            perFan[fanID] = value
        }
        self.init(
            name: try container.decode(String.self, forKey: .name),
            binding: try container.decode(FanBinding.self, forKey: .binding),
            perFan: perFan,
            triggers: try container.decodeIfPresent([ProfileTrigger].self, forKey: .triggers)
                ?? [],
            priority: try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0,
            smoothing: try container.decodeIfPresent(EWMA.self, forKey: .smoothing) ?? .standard,
            hysteresis: try container.decodeIfPresent(Hysteresis.self, forKey: .hysteresis)
                ?? .standard,
            slew: try container.decodeIfPresent(RateLimit.self, forKey: .slew) ?? .standard,
            enginePaused: try container.decodeIfPresent(Bool.self, forKey: .enginePaused)
                ?? false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(binding, forKey: .binding)
        if !perFan.isEmpty {
            let keyed = Dictionary(uniqueKeysWithValues: perFan.map { (String($0.key), $0.value) })
            try container.encode(keyed, forKey: .perFan)
        }
        if !triggers.isEmpty { try container.encode(triggers, forKey: .triggers) }
        try container.encode(priority, forKey: .priority)
        try container.encode(smoothing, forKey: .smoothing)
        try container.encode(hysteresis, forKey: .hysteresis)
        try container.encode(slew, forKey: .slew)
        if enginePaused { try container.encode(enginePaused, forKey: .enginePaused) }
    }
}
