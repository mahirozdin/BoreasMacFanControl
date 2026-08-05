import Core
import Foundation

/// What the status item shows and how it is laid out (P6.03).
///
/// Lives in user defaults under the `Keys` below; the P6.08 Appearance tab
/// edits the same keys, so "configurable" is true before the settings
/// window exists. Renders freeze an explicit value instead of reading
/// storage, which keeps the evidence deterministic.
struct StatusItemStyle: Equatable {
    /// The hottest reading overall.
    var showTemperature = true
    /// A second group whose hottest is shown after the primary, or `nil`.
    var secondaryGroup: SensorGroup?
    /// The first fan's speed.
    var showFan = true
    /// The mini chart of the recent hottest-temperature history.
    var showChart = false
    /// Two stacked micro rows instead of one line.
    var vertical = false
    /// Numbers only, no unit marks, tighter spacing (blueprint §9.2).
    var compact = false

    enum Keys {
        static let showTemperature = "statusItem.showTemperature"
        static let secondaryGroup = "statusItem.secondaryGroup"
        static let showFan = "statusItem.showFan"
        static let showChart = "statusItem.showChart"
        static let vertical = "statusItem.vertical"
        static let compact = "statusItem.compact"
    }
}
