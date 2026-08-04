import Core
import Foundation

/// The sensor backend the application uses.
///
/// Concrete wiring only: it prefers ``HIDSensorSource``, because that is the
/// only backend reporting readable names, and falls back to
/// ``SMCSensorSource``. The degradation behaviour itself lives in
/// ``FallbackSensorSource`` so it can be tested against mocks.
///
/// ## Why a fallback exists
///
/// Both backends are undocumented, but they are **different mechanisms**, so a
/// single macOS release breaking both is unlikely. Depending on one would mean
/// a point release could turn the application into a window showing nothing
/// (risk R1). Fan control is unaffected either way: it never depended on
/// sensor reads.
public actor LiveSensorSource: SensorSource {

    public nonisolated let identifier = "live"

    private let composite: FallbackSensorSource

    /// - Throws: only when neither backend can even be constructed, which
    ///   means this Mac exposes no temperature interface at all.
    public init(overrides: [String: SensorOverride] = [:]) throws {
        let smc = try SMCSensorSource(overrides: overrides)

        if HIDSensorSource.isAvailable, let hid = try? HIDSensorSource(overrides: overrides) {
            composite = FallbackSensorSource(identifier: "live", preferred: hid, fallback: smc)
        } else {
            // No HID interface on this system. The SMC still answers, so the
            // application runs with hardware keys instead of names rather than
            // failing outright.
            composite = FallbackSensorSource(identifier: "live", preferred: smc, fallback: smc)
        }
    }

    public func snapshot() async throws -> [SensorReading] {
        try await composite.snapshot()
    }

    /// Which backend answered last.
    public var activeBackend: FallbackSensorSource.Backend {
        get async { await composite.activeBackend }
    }

    /// Non-nil when readings are coming from a degraded path.
    public var degradedReason: String? {
        get async { await composite.degradedReason }
    }
}
