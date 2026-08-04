import Foundation

/// Identifiers shared between the app and the privileged daemon.
///
/// The XPC surface itself lands in P3. Keeping the names here means neither
/// side hard-codes a string the other could drift away from.
public enum BoreasIPC: Sendable {

    /// Mach service the privileged daemon registers.
    public static let machServiceName = "com.bubiapps.boreas.fanhelper"

    /// Interval at which the app proves it is still alive.
    /// Missing three of these hands the fans back to firmware.
    public static let heartbeatIntervalSeconds = 5

    /// How many missed heartbeats end control.
    public static let missedHeartbeatsBeforeRelease = 3

    /// Bundle identifier of the application allowed to connect.
    public static let clientBundleIdentifier = "com.bubiapps.boreas"

    /// Code signing requirement the helper applies to anything connecting to
    /// it, and the application applies to the helper.
    ///
    /// Pinned to the **team**, not to a certificate. A designated requirement
    /// names the exact signing certificate, so it stops matching the moment a
    /// build moves from Apple Development to Developer ID. Both certificates
    /// carry the same team identifier, so this one string is correct in
    /// development and in a release.
    ///
    /// The team identifier is substituted at build time from `Local.xcconfig`;
    /// it is account information and is not committed (ADR 0019).
    public static func requirement(teamIdentifier: String, identifier: String) -> String {
        """
        identifier "\(identifier)" \
        and anchor apple generic \
        and certificate leaf[subject.OU] = "\(teamIdentifier)"
        """
    }
}
