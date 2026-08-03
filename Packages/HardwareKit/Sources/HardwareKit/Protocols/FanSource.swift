import Core
import Foundation

/// Reports what the fans are doing. Read only.
///
/// The write path lives behind a separate protocol introduced with the
/// privileged daemon, so nothing that merely observes the machine can be
/// mistaken for something that changes it.
public protocol FanSource: Sendable {
    var identifier: String { get }

    /// Current state of every fan. An empty array is a valid answer: several
    /// Macs genuinely have no fan, and that is not an error.
    func fans() async throws -> [FanState]
}
