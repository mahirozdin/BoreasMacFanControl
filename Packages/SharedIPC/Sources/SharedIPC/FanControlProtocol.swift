import Foundation

/// The complete surface the privileged helper exposes.
///
/// Four methods, and widening it requires an ADR (invariant M4). The helper
/// runs as root; every method added to this protocol is a new way for a local
/// process to reach that privilege, so the cost of each one is permanent.
///
/// ## Only primitives cross the boundary
///
/// Every parameter is an `NSNumber`, a `String` or an array of those. No
/// structured payload, no encoded object, no path, no command. The helper
/// therefore has **nothing to parse**, which removes decoding bugs as a class
/// rather than trying to write them correctly.
///
/// Parallel arrays look primitive because they are meant to. A richer type
/// would need `NSSecureCoding` on both sides, and that decoder would sit inside
/// the root process.
///
/// ## What is deliberately absent
///
/// Reply closures are `@Sendable`: they are invoked from whatever queue
/// finished the work, and Swift 6 is right to insist that be stated.
///
/// - No method takes a file path or a command. The helper never touches the
///   filesystem or spawns anything.
/// - No method reads configuration. Curve evaluation, profiles and user
///   settings all stay in the unprivileged application (ADR 0007).
/// - Nothing here can raise the helper's own privileges or install anything.
@objc public protocol FanControlProtocol {

    /// Describes the fans the helper can see.
    ///
    /// Parallel arrays, all the same length: `ids[i]` describes the fan whose
    /// current speed is `currentRPM[i]`.
    func describeFans(
        reply:
            @escaping @Sendable (
                _ ids: [NSNumber],
                _ minimumRPM: [NSNumber],
                _ maximumRPM: [NSNumber],
                _ currentRPM: [NSNumber]
            ) -> Void
    )

    /// Requests target speeds.
    ///
    /// The helper clamps every value to what the hardware reports as its own
    /// limits before writing. A request outside those limits is rejected and
    /// logged rather than adjusted silently, because a caller asking for an
    /// impossible speed has a bug worth surfacing.
    ///
    /// - Parameter reply: success, and a reason when it is false.
    func applyTargets(
        fanIDs: [NSNumber],
        targetRPM: [NSNumber],
        reply: @escaping @Sendable (_ succeeded: Bool, _ reason: String?) -> Void
    )

    /// Hands every fan back to the firmware.
    ///
    /// Idempotent: calling it when control was never taken, or calling it
    /// repeatedly, is safe. This runs on quit, on sleep, on shutdown and when
    /// the watchdog fires, so it must never be the thing that fails.
    func releaseToFirmware(reply: @escaping @Sendable (_ succeeded: Bool, _ reason: String?) -> Void)

    /// Proves the application is still alive.
    ///
    /// The helper hands the fans back if it stops hearing this. The nonce is
    /// echoed so the caller can tell a real answer from a stale one.
    ///
    /// This is the dead man's switch (ADR 0009). It is the reason the helper
    /// does not need to trust the application to clean up after itself: an
    /// application that is killed, hangs or crashes cannot send a heartbeat,
    /// and that silence is the signal.
    func heartbeat(nonce: NSNumber, reply: @escaping @Sendable (_ echoedNonce: NSNumber) -> Void)
}
