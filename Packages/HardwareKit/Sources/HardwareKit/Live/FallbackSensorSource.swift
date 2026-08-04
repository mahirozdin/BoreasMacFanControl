import Core
import Foundation
import OSLog

/// Reads from a preferred source, falling back to a second one when it fails.
///
/// Split out from ``LiveSensorSource`` so the degradation logic can be tested
/// against mocks. Wiring two real backends together and hoping is not a test;
/// the interesting behaviour is *when* it demotes and *whether* it recovers,
/// and neither is observable through real hardware on demand.
///
/// ## Demotion is not immediate
///
/// One failed read is not evidence of a broken interface — a service can be
/// busy for a moment. Demotion happens only after a run of failures, so a
/// transient hiccup does not permanently cost the user readable sensor names.
/// Recovery is immediate in the other direction: the moment the preferred
/// source answers again, it is used again.
public actor FallbackSensorSource: SensorSource {

    public nonisolated let identifier: String

    /// Which source answered the most recent read.
    public enum Backend: String, Sendable {
        case preferred
        case fallback
        case none
    }

    private let preferred: any SensorSource
    private let fallback: any SensorSource
    private let failuresBeforeDemotion: Int
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "sensor")

    private var consecutiveFailures = 0

    public private(set) var activeBackend: Backend = .none

    /// Non-nil when the reading is coming from somewhere other than the
    /// preferred source. The interface shows this so a user is never quietly
    /// given a degraded view.
    public private(set) var degradedReason: String?

    public init(
        identifier: String = "fallback",
        preferred: any SensorSource,
        fallback: any SensorSource,
        failuresBeforeDemotion: Int = 3
    ) {
        self.identifier = identifier
        self.preferred = preferred
        self.fallback = fallback
        self.failuresBeforeDemotion = max(1, failuresBeforeDemotion)
    }

    public func snapshot() async throws -> [SensorReading] {
        do {
            let readings = try await preferred.snapshot()
            if consecutiveFailures > 0 {
                logger.notice("preferred sensor source recovered")
            }
            consecutiveFailures = 0
            activeBackend = .preferred
            degradedReason = nil
            return readings
        } catch {
            consecutiveFailures += 1
            logger.debug(
                "preferred sensor source failed (\(self.consecutiveFailures, privacy: .public))"
            )
        }

        do {
            let readings = try await fallback.snapshot()
            activeBackend = .fallback
            degradedReason =
                consecutiveFailures >= failuresBeforeDemotion
                ? "named sensors unavailable, showing hardware keys"
                : nil
            return readings
        } catch {
            activeBackend = .none
            degradedReason = "no sensor backend is answering"
            logger.error("both sensor backends failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    /// Number of consecutive preferred-source failures. Exposed for diagnostics.
    public var failureCount: Int { consecutiveFailures }
}
