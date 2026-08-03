import Core
import Foundation

/// Reports how the machine is powered, so profiles can react to it.
public protocol PowerSource: Sendable {
    var identifier: String { get }

    /// Never throws. A machine that cannot answer is a desktop on mains power,
    /// which is the correct answer rather than a missing one.
    func current() -> PowerContext
}
