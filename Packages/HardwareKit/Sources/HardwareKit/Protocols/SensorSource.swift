import Core
import Foundation

/// Supplies temperature readings.
///
/// Reading temperatures needs no privileges on Apple Silicon, so this protocol
/// never crosses into the daemon. Implementations are expected to `throw`
/// rather than return an empty array when they cannot read: an empty result and
/// a failed read mean different things to the caller, and collapsing them
/// hides broken hardware support behind a plausible looking silence.
public protocol SensorSource: Sendable {
    /// A short identifier used in logs and diagnostics.
    var identifier: String { get }

    /// Reads every sensor the backend can see.
    func snapshot() async throws -> [SensorReading]
}

/// Why a hardware read failed.
public enum HardwareError: Error, Sendable, Equatable {
    /// The backing service could not be opened. Usually means this macOS
    /// version moved or removed the interface.
    case serviceUnavailable(String)

    /// The service was reachable but returned nothing usable.
    case noData(String)

    /// A value came back in a shape this build does not understand.
    /// The sensor is skipped rather than guessed at.
    case unsupportedDataType(key: String, type: String)

    /// Writing requires the privileged helper, which is not installed.
    case privilegedHelperUnavailable
}
