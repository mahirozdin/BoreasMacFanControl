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
}
