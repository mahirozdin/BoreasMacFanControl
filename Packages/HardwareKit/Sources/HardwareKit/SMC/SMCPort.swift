import Foundation

/// The slice of the SMC the fan actuator needs.
///
/// A seam, not an abstraction for its own sake: the actuator's bookkeeping —
/// save the original state once, restore it exactly, retry with backoff, stay
/// idempotent — is where release bugs would live, and those rules can only be
/// tested against a port that can be faked. `SMCConnection` is the one real
/// implementation.
public protocol SMCPort: AnyObject, Sendable {
    func readValue(key: String) throws -> SMCValue?
    func writeValue(key: String, bytes: [UInt8]) throws
}

extension SMCConnection: SMCPort {}
