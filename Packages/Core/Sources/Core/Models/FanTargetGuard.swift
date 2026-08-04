import Foundation

/// Decides whether a requested fan speed is physically acceptable.
///
/// This is layer K4 of the safety chain. It lives in `Core` rather than beside
/// the privileged helper for one reason: **a safety layer that cannot be tested
/// is not a safety layer.** The helper is an executable target with no test
/// bundle, so the rule itself lives here as pure arithmetic and the helper
/// applies it.
///
/// The application clamps too, but the helper cannot rely on that. From the
/// helper's side every request is untrusted, including one from a build of the
/// application that has a bug in it.
///
/// ## Rejection, not correction
///
/// An out of range request is refused rather than clamped. Clamping would hide
/// the bug that produced it, and a caller asking for a speed the hardware
/// cannot reach has something wrong with it that is worth surfacing.
public struct FanTargetGuard: Sendable, Hashable {

    public struct Limits: Sendable, Hashable {
        public let id: Int
        public let minimumRPM: Int
        public let maximumRPM: Int

        public init(id: Int, minimumRPM: Int, maximumRPM: Int) {
            self.id = id
            self.minimumRPM = minimumRPM
            self.maximumRPM = maximumRPM
        }
    }

    public enum Verdict: Sendable, Hashable {
        case allowed(fanID: Int, rpm: Int)
        case rejected(reason: String)

        public var isAllowed: Bool {
            if case .allowed = self { return true }
            return false
        }
    }

    private let limits: [Int: Limits]

    public init(limits: [Limits]) {
        self.limits = Dictionary(limits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func evaluate(fanID: Int, requestedRPM: Int) -> Verdict {
        guard let limit = limits[fanID] else {
            return .rejected(reason: "unknown fan \(fanID)")
        }
        guard limit.maximumRPM > limit.minimumRPM else {
            return .rejected(reason: "fan \(fanID) reports no usable speed range")
        }
        guard requestedRPM >= limit.minimumRPM else {
            return .rejected(
                reason: "fan \(fanID): \(requestedRPM) rpm is below the hardware minimum \(limit.minimumRPM)"
            )
        }
        guard requestedRPM <= limit.maximumRPM else {
            return .rejected(
                reason: "fan \(fanID): \(requestedRPM) rpm is above the hardware maximum \(limit.maximumRPM)"
            )
        }
        return .allowed(fanID: fanID, rpm: requestedRPM)
    }

    /// Checks a whole batch. Nothing is applied unless everything passes: a
    /// partly applied batch leaves the fans in a state neither side asked for.
    public func evaluateBatch(_ requests: [(fanID: Int, rpm: Int)]) -> Verdict {
        guard !requests.isEmpty else {
            return .rejected(reason: "no targets given")
        }
        for request in requests {
            let verdict = evaluate(fanID: request.fanID, requestedRPM: request.rpm)
            if case .rejected = verdict { return verdict }
        }
        return .allowed(fanID: requests[0].fanID, rpm: requests[0].rpm)
    }
}
