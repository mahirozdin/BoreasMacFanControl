import Core
import Foundation

/// Deterministic power context.
///
/// The development machine is a desktop with no battery, so every battery
/// dependent path — profile switching on unplug, low battery behaviour — is
/// only reachable here.
public struct MockPowerSource: PowerSource {

    public let identifier = "mock"

    private let context: PowerContext

    public init(_ context: PowerContext) {
        self.context = context
    }

    public func current() -> PowerContext { context }

    public static let desktop = MockPowerSource(.desktop)
    public static let onAdapter = MockPowerSource(PowerContext(source: .adapter, batteryPercentage: 88))
    public static let onBattery = MockPowerSource(PowerContext(source: .battery, batteryPercentage: 62))
    public static let batteryLow = MockPowerSource(PowerContext(source: .battery, batteryPercentage: 12))
}
