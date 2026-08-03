import Foundation

/// Namespace for values that are shared across every Boreas component.
///
/// `Core` deliberately depends on Foundation and nothing else. Hardware
/// access lives behind protocols in `HardwareKit`; the control engine here
/// stays pure so it can be exercised in CI without a real fan.
public enum Boreas: Sendable {

    /// Version of the on-disk configuration schema.
    ///
    /// Bumping this requires a migration with a test proving no data loss.
    public static let configSchemaVersion = 1

    /// Bounds the watchdog timeout. The daemon hands the fans back to
    /// firmware when the app misses this many seconds of heartbeats.
    ///
    /// The range is locked: a watchdog that can be switched off is not a
    /// safety mechanism.
    public static let watchdogTimeoutRange: ClosedRange<Int> = 10...60

    /// Temperature above which the safety chain forces full speed and holds.
    /// Users may lower this, never raise it.
    public static let panicTemperatureRange: ClosedRange<Int> = 70...105
}
