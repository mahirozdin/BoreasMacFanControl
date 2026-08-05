import Foundation

/// Thermal pressure as the engine sees it — a mirror of the official
/// `ProcessInfo.ThermalState` so the chain stays a pure function of its
/// inputs instead of reading global state.
public enum ThermalPressure: String, Sendable, Hashable, Codable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical

    public init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default:
            // A thermal state this build has never heard of is not good
            // news. The safe reading of "unknown" is the worst case.
            self = .critical
        }
    }
}

/// The K3 trigger temperature. Invariant G2: the user may lower it below the
/// default, never raise it above — a type that cannot hold a raised value
/// removes that bug class instead of testing for it at every call site.
///
/// The frozen blueprint's schema section allows `[70, 105]`, which its own
/// K2/K3 rule contradicts; the safety invariant wins and the ceiling is the
/// default. Recorded as ADR 0022.
public struct PanicThreshold: Sendable, Hashable, Codable {

    /// The default trigger, and by G2 also the ceiling.
    public static let defaultCelsius: Double = 95
    /// Below this a panic threshold stops being a panic threshold and
    /// becomes a permanently-on switch; the blueprint's own lower bound.
    public static let floorCelsius: Double = 70

    public let celsius: Double

    public init(celsius: Double) {
        if celsius.isNaN {
            // Ambiguity resolves to the safe side, and for a trigger
            // threshold the safe side is DOWN: a lower threshold panics
            // sooner. The same reasoning that sends an ambiguous Duty UP.
            self.celsius = Self.floorCelsius
        } else {
            self.celsius = min(Self.defaultCelsius, max(Self.floorCelsius, celsius))
        }
    }

    public static let standard = PanicThreshold(celsius: defaultCelsius)
}

/// Which safety layer determined the final output. `nil` means the request
/// passed through untouched. Recorded in logs (P7.02) and shown in the
/// interface (P6.05) — the user is always told why the fans are loud.
public enum SafetyLayer: String, Sendable, Hashable, Codable {
    case thermalSerious
    case thermalCritical
    case panic
}

/// K3's memory: while `until` is in the future, the panic output holds even
/// if the temperature has already recovered. Value semantics on purpose —
/// the chain returns the next lock state instead of mutating anything.
public struct PanicLock: Sendable, Hashable, Codable {
    public let until: Date?

    public init(until: Date? = nil) {
        self.until = until
    }

    public static let released = PanicLock()

    public func isActive(at now: Date) -> Bool {
        guard let until else { return false }
        return now < until
    }
}

/// The engine-side safety layers (K1–K3), as one pure function.
///
/// Invariant G1: every layer only raises. The implementation makes that
/// structural — each layer is a `max` against a floor, so there is no code
/// path that could lower the request. K1 is carried by the types themselves:
/// `Duty` cannot hold a value below 0 and `Duty.rpm(for:)` maps 0 to the
/// hardware minimum, so "below the fan floor" is unrepresentable.
///
/// Invariant G2: there is no flag to switch K2 or K3 off — deliberately.
/// The only tunable is `PanicThreshold`, which can only move down.
public enum SafetyChain {

    /// K2: the `serious` thermal state raises the floor to 55%.
    public static let seriousFloor = Duty(0.55)
    /// K2: the `critical` thermal state forces full speed.
    public static let criticalDuty = Duty(1)
    /// K3: how long the panic output holds after it triggers.
    public static let panicHoldSeconds: TimeInterval = 30

    public struct Verdict: Sendable, Hashable {
        public let duty: Duty
        public let activeLayer: SafetyLayer?
        public let lock: PanicLock
    }

    /// Applies K2 and K3 to the engine's requested duty.
    ///
    /// - Parameters:
    ///   - requested: what the curve (or the manual slider) asked for.
    ///     Already K1-safe by construction of `Duty`.
    ///   - thermal: the official thermal pressure reading.
    ///   - hottestCelsius: the hottest sensor, `nil` when no sensor reads.
    ///   - threshold: the K3 trigger. Only lowerable (G2).
    ///   - lock: the K3 state from the previous evaluation.
    ///   - now: the caller's clock, injected so the hold is testable.
    public static func govern(
        requested: Duty,
        thermal: ThermalPressure,
        hottestCelsius: Double?,
        threshold: PanicThreshold = .standard,
        lock: PanicLock = .released,
        now: Date
    ) -> Verdict {
        var duty = requested
        var layer: SafetyLayer?

        // K2 — thermal state floors. A floor, not a value: if the user's
        // curve already asks for more, the higher request stands (G1).
        switch thermal {
        case .nominal, .fair:
            break
        case .serious:
            if seriousFloor > duty {
                duty = seriousFloor
                layer = .thermalSerious
            }
        case .critical:
            if criticalDuty > duty {
                duty = criticalDuty
            }
            // Critical is reported even when the curve already sat at 100%:
            // the reason the fans are at full speed is the thermal state.
            layer = .thermalCritical
        }

        // K3 — panic. Triggers strictly above the threshold, and re-arms the
        // hold on every evaluation that stays above it, so the lock expires
        // 30 s after the *last* excursion, not the first.
        var nextLock = lock
        if let hottestCelsius, hottestCelsius > threshold.celsius {
            nextLock = PanicLock(until: now.addingTimeInterval(panicHoldSeconds))
        } else if !lock.isActive(at: now) {
            nextLock = .released
        }

        if nextLock.isActive(at: now) {
            duty = Duty(1)
            layer = .panic
        }

        return Verdict(duty: duty, activeLayer: layer, lock: nextLock)
    }
}
