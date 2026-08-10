import Core
import Foundation

/// Deterministic health readings.
///
/// **This is the only way the laptop path is reachable on the development
/// hardware**, which is a Mac mini with no battery — so the fixtures below are
/// not conveniences, they are the coverage. R8, and the manual task M07 that
/// will eventually replace them with real reports.
public struct MockHealthSource: HealthSource {

    public let identifier = "mock"

    private let batteryReading: DiagnosticChecks.BatteryReading?
    private let freeFraction: Double
    private let advertisesSmart: Bool

    public init(
        battery: DiagnosticChecks.BatteryReading?,
        freeFraction: Double = 0.42,
        advertisesSmart: Bool = true
    ) {
        self.batteryReading = battery
        self.freeFraction = freeFraction
        self.advertisesSmart = advertisesSmart
    }

    public func battery() -> DiagnosticChecks.BatteryReading? { batteryReading }

    public func storage(nandCelsius: Double?) -> DiagnosticChecks.StorageReading? {
        let total: Int64 = 494_384_795_648
        return DiagnosticChecks.StorageReading(
            totalBytes: total,
            freeBytes: Int64(Double(total) * freeFraction),
            nandCelsius: nandCelsius,
            advertisesSmart: advertisesSmart)
    }

    /// A desktop: no battery, and that is a complete answer rather than a gap.
    public static let desktop = MockHealthSource(
        battery: DiagnosticChecks.BatteryReading(
            isInstalled: false, cycleCount: 0, capacityFraction: nil, celsius: nil))

    /// A healthy laptop battery.
    public static let laptop = MockHealthSource(
        battery: DiagnosticChecks.BatteryReading(
            isInstalled: true, cycleCount: 143, capacityFraction: 0.94, celsius: 29.5))

    /// One that has aged normally — the case whose *wording* matters most.
    public static let wornLaptop = MockHealthSource(
        battery: DiagnosticChecks.BatteryReading(
            isInstalled: true, cycleCount: 940, capacityFraction: 0.71, celsius: 31))

    /// A battery being charged in the heat.
    public static let warmLaptop = MockHealthSource(
        battery: DiagnosticChecks.BatteryReading(
            isInstalled: true, cycleCount: 260, capacityFraction: 0.91, celsius: 38.4))

    /// A drive with almost nothing left.
    public static let fullDisk = MockHealthSource(
        battery: DiagnosticChecks.BatteryReading(
            isInstalled: false, cycleCount: 0, capacityFraction: nil, celsius: nil),
        freeFraction: 0.03)

    /// Nothing readable at all — the degraded path.
    public static let unreadable = MockHealthSource(battery: nil, advertisesSmart: false)
}
