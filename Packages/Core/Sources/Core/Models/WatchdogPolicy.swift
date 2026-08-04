import Foundation

/// The decision half of the dead man's switch (ADR 0009, invariant G3).
///
/// The helper's watchdog has two parts: a timer that ticks, and a decision
/// about what a tick means. The timer has to live in the helper, but the
/// decision is pure — and only pure code can carry invariant tests. This is
/// the same split that moved the K4 filter into `FanTargetGuard`.
///
/// Two rules are enforced here rather than merely documented:
///
/// - The timeout is **locked to 10–60 seconds**. A caller asking for less is
///   given the minimum; asking for more is given the maximum; there is no way
///   to represent a disabled watchdog.
/// - Expiry is a comparison of two instants supplied by the caller, so a test
///   can prove the boundary without waiting for wall-clock time to pass.
public struct WatchdogPolicy: Sendable, Equatable {

    /// The range the timeout can never leave (invariant G3).
    public static let allowedTimeout: ClosedRange<TimeInterval> = 10...60

    /// Effective timeout in seconds, already clamped.
    public let timeout: TimeInterval

    /// Clamps whatever is requested into the allowed range.
    public init(requestedTimeoutSeconds: TimeInterval) {
        timeout = min(
            Self.allowedTimeout.upperBound,
            max(Self.allowedTimeout.lowerBound, requestedTimeoutSeconds)
        )
    }

    /// Derives the timeout from the heartbeat cadence: an application that
    /// misses `missedHeartbeatsBeforeRelease` beats in a row is considered
    /// gone. The product is clamped like every other request.
    public init(heartbeatIntervalSeconds: Int, missedHeartbeatsBeforeRelease: Int) {
        self.init(
            requestedTimeoutSeconds: TimeInterval(
                heartbeatIntervalSeconds * missedHeartbeatsBeforeRelease
            )
        )
    }

    /// Whether silence since `lastHeartbeat` has outlived the timeout.
    ///
    /// A `lastHeartbeat` in the future (clock adjustment) does not expire:
    /// the watchdog releases on proven silence, not on clock confusion, and
    /// the next genuine heartbeat resets the window either way.
    public func hasExpired(lastHeartbeat: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastHeartbeat) > timeout
    }
}
