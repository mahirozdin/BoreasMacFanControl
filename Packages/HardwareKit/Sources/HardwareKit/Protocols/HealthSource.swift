import Core
import Foundation

/// Reads what the machine reports about its battery and its drive (P7.03).
///
/// Behind a protocol like every other hardware access (M2), and for a reason
/// this one makes vivid: the development machine has **no battery**, so the
/// entire laptop path is only reachable through the mock. R8 names that as a
/// tracked risk and M07 as the manual task that will close it.
public protocol HealthSource: Sendable {
    var identifier: String { get }

    /// The battery as the system reports it, or `nil` when the read failed.
    ///
    /// A machine with no battery answers with `isInstalled == false` rather than
    /// `nil` — the two are different facts and the check must be able to tell
    /// them apart. Never throws for that reason: absence is an answer.
    func battery() -> DiagnosticChecks.BatteryReading?

    /// The drive's capacity and, when the machine reports one, the temperature
    /// of its storage sensors.
    ///
    /// `nandCelsius` is passed in rather than read here: the sensor stack already
    /// samples it, and a second reader would be a second answer to the same
    /// question.
    func storage(nandCelsius: Double?) -> DiagnosticChecks.StorageReading?
}
