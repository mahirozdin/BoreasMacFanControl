import Foundation

/// Where a temperature sensor sits inside the machine.
///
/// Hardware reports sensor names that differ between chip generations, so the
/// mapping is decided at runtime by ``SensorClassifier`` rather than baked into
/// a per-model table. A sensor that matches nothing lands in
/// ``SensorGroup/uncategorized`` and is still shown to the user — hiding it
/// would remove the only signal that support for new hardware is incomplete.
public enum SensorGroup: String, Sendable, Hashable, CaseIterable, Codable {
    case computePerformance = "compute.performance"
    case computeEfficiency = "compute.efficiency"
    case graphics
    case memory
    case storage
    case power
    case battery
    case chassis
    case airflow
    case wireless
    case uncategorized

    /// Groups a fan curve may sensibly follow.
    ///
    /// ``SensorGroup/uncategorized`` is excluded: binding cooling to a sensor
    /// nobody has identified is how a machine ends up running its fans off a
    /// battery thermistor.
    public static var curveInputCandidates: [SensorGroup] {
        allCases.filter { $0 != .uncategorized }
    }
}
