import Core
import Foundation

/// Deterministic stand-in for real fans.
public struct MockFanSource: FanSource {

    public let identifier = "mock"

    private let states: [FanState]
    private let failure: HardwareError?

    public init(states: [FanState], failure: HardwareError? = nil) {
        self.states = states
        self.failure = failure
    }

    public func fans() async throws -> [FanState] {
        if let failure { throw failure }
        return states
    }

    // MARK: - Machine shapes the development hardware cannot provide

    /// Single fan desktop, matching the development machine.
    public static let singleFan = MockFanSource(states: [
        FanState(id: 0, name: "Fan 1", currentRPM: 1300, minimumRPM: 1200, maximumRPM: 4800)
    ])

    /// Two fans with different ranges, as laptops and workstations have.
    /// Per-fan curves can only be exercised against this.
    public static let dualFan = MockFanSource(states: [
        FanState(id: 0, name: "Left Side", currentRPM: 2143, minimumRPM: 2160, maximumRPM: 5927),
        FanState(id: 1, name: "Right Side", currentRPM: 1992, minimumRPM: 2000, maximumRPM: 5489),
    ])

    /// A machine with no fan at all. The interface must stay sensible here and
    /// must not offer to install the daemon.
    public static let fanless = MockFanSource(states: [])

    /// Firmware has parked the fans. No software can drive them in this state.
    public static let poweredOff = MockFanSource(states: [
        FanState(
            id: 0, name: "Fan 1", currentRPM: 0,
            minimumRPM: 1200, maximumRPM: 4800, isPoweredOff: true
        )
    ])
}
