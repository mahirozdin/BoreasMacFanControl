import Core
import Foundation

/// Writes fan speeds. The only protocol in this package that changes the
/// machine instead of observing it.
///
/// The `Live` implementation works only inside the privileged helper: the
/// kernel refuses SMC writes from an unprivileged process (measured — see
/// `docs/architecture/privilege-model.md`). Reading stays privilege free,
/// which is the M3 split.
public protocol FanActuator: Sendable {

    var identifier: String { get }

    /// Takes the listed fans over and drives them at the given targets.
    ///
    /// The first take-over of a fan saves its original state; later calls
    /// only move the target. Values are expected to be inside hardware
    /// limits — the safety chain rejects anything else before it gets here.
    func apply(_ targets: [FanTarget]) async throws

    /// Hands every taken-over fan back to the firmware.
    ///
    /// Idempotent: calling it with nothing taken over, or calling it twice,
    /// is safe and does nothing. It runs on quit, sleep, shutdown and
    /// watchdog expiry, so it must never be the thing that fails.
    func releaseToFirmware() async throws
}
