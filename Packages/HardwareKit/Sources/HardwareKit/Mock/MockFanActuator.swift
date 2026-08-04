import Core
import Foundation

/// Deterministic fake of the write path.
///
/// Records what it was asked to do so tests can assert on the sequence, and
/// enforces the same contract shape as the real thing: applying remembers the
/// fans, releasing forgets them, releasing twice is fine.
public actor MockFanActuator: FanActuator {

    public nonisolated let identifier = "mock"

    public private(set) var appliedBatches: [[FanTarget]] = []
    public private(set) var releaseCount = 0
    public private(set) var heldFanIDs: Set<Int> = []

    /// When set, the next `apply` throws — for exercising failure paths.
    public var nextApplyError: (any Error)?

    public init() {}

    public func apply(_ targets: [FanTarget]) async throws {
        if let error = nextApplyError {
            nextApplyError = nil
            throw error
        }
        appliedBatches.append(targets)
        for target in targets { heldFanIDs.insert(target.fanID) }
    }

    public func releaseToFirmware() async throws {
        releaseCount += 1
        heldFanIDs.removeAll()
    }

    public func setNextApplyError(_ error: (any Error)?) {
        nextApplyError = error
    }
}
