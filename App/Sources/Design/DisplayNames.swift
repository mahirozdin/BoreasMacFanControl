import Core
import SwiftUI

/// Localised display vocabulary for `Core` identifiers.
///
/// `Core` speaks in stable identifiers (`SensorGroup.rawValue`, built-in
/// profile names); the interface owes the user words. The mapping lives here,
/// in one place, so every view names the same thing the same way (Y1/Y2:
/// every string localised, every string with a translator comment).
extension SensorGroup {

    /// The user-facing name of the group.
    var displayName: String {
        switch self {
        case .compute:
            return String(
                localized: "group.compute",
                defaultValue: "Compute",
                comment: "Sensor group: die temperatures not tied to one CPU cluster")
        case .computePerformance:
            return String(
                localized: "group.compute.performance",
                defaultValue: "Performance cores",
                comment: "Sensor group: performance CPU cluster temperatures")
        case .computeEfficiency:
            return String(
                localized: "group.compute.efficiency",
                defaultValue: "Efficiency cores",
                comment: "Sensor group: efficiency CPU cluster temperatures")
        case .graphics:
            return String(
                localized: "group.graphics",
                defaultValue: "Graphics",
                comment: "Sensor group: GPU temperatures")
        case .memory:
            return String(
                localized: "group.memory",
                defaultValue: "Memory",
                comment: "Sensor group: RAM temperatures")
        case .storage:
            return String(
                localized: "group.storage",
                defaultValue: "Storage",
                comment: "Sensor group: SSD and NAND temperatures")
        case .power:
            return String(
                localized: "group.power",
                defaultValue: "Power",
                comment: "Sensor group: power delivery and charger temperatures")
        case .battery:
            return String(
                localized: "group.battery",
                defaultValue: "Battery",
                comment: "Sensor group: battery temperatures")
        case .chassis:
            return String(
                localized: "group.chassis",
                defaultValue: "Chassis",
                comment: "Sensor group: enclosure and skin temperatures")
        case .airflow:
            return String(
                localized: "group.airflow",
                defaultValue: "Airflow",
                comment: "Sensor group: air intake and exhaust temperatures")
        case .wireless:
            return String(
                localized: "group.wireless",
                defaultValue: "Wireless",
                comment: "Sensor group: radio module temperatures")
        case .uncategorized:
            return String(
                localized: "group.uncategorized",
                defaultValue: "Uncategorized",
                comment: "Sensor group for sensors the classifier does not recognise yet")
        }
    }
}

extension HistoryWindow {

    var displayName: String {
        switch self {
        case .fiveMinutes:
            return String(
                localized: "window.5m", defaultValue: "5 min",
                comment: "Chart time window: the last five minutes")
        case .oneHour:
            return String(
                localized: "window.1h", defaultValue: "1 hr",
                comment: "Chart time window: the last hour")
        case .sixHours:
            return String(
                localized: "window.6h", defaultValue: "6 hr",
                comment: "Chart time window: the last six hours")
        case .twentyFourHours:
            return String(
                localized: "window.24h", defaultValue: "24 hr",
                comment: "Chart time window: the last twenty four hours")
        }
    }
}

extension SafetyLayer {

    /// The layer's short name for the safety chain status list.
    var displayName: String {
        switch self {
        case .thermalSerious:
            return String(
                localized: "layer.k2.serious", defaultValue: "Thermal state: serious",
                comment: "Safety chain layer K2 while the system reports serious thermal pressure")
        case .thermalCritical:
            return String(
                localized: "layer.k2.critical", defaultValue: "Thermal state: critical",
                comment: "Safety chain layer K2 while the system reports critical thermal pressure")
        case .panic:
            return String(
                localized: "layer.k3", defaultValue: "Panic threshold",
                comment: "Safety chain layer K3, triggered by a sensor above the panic threshold")
        }
    }
}

extension ThermalPressure {

    var displayName: String {
        switch self {
        case .nominal:
            return String(
                localized: "thermal.nominal", defaultValue: "Nominal",
                comment: "System thermal pressure: nothing unusual")
        case .fair:
            return String(
                localized: "thermal.fair", defaultValue: "Fair",
                comment: "System thermal pressure: slightly elevated")
        case .serious:
            return String(
                localized: "thermal.serious", defaultValue: "Serious",
                comment: "System thermal pressure: the system is throttling")
        case .critical:
            return String(
                localized: "thermal.critical", defaultValue: "Critical",
                comment: "System thermal pressure: the system is at its limit")
        }
    }
}

extension ProfileTrigger {

    /// A sentence fragment naming the condition, for the control tab's
    /// "why is this profile active" line.
    var displayCondition: String {
        switch self {
        case .powerSource(let source):
            switch source {
            case .battery:
                return String(
                    localized: "trigger.power.battery", defaultValue: "running on battery",
                    comment: "Profile trigger condition: the Mac is on battery power")
            case .adapter:
                return String(
                    localized: "trigger.power.adapter", defaultValue: "plugged in",
                    comment: "Profile trigger condition: the Mac is on mains power")
            }
        case .application(let bundleIdentifier, let foregroundOnly):
            return foregroundOnly
                ? String(
                    localized: "trigger.app.foreground",
                    defaultValue: "\(bundleIdentifier) is in the foreground",
                    comment: "Profile trigger condition: a named application is frontmost")
                : String(
                    localized: "trigger.app.running",
                    defaultValue: "\(bundleIdentifier) is running",
                    comment: "Profile trigger condition: a named application is running")
        case .timeWindow(let startMinute, let endMinute):
            return String(
                localized: "trigger.time",
                defaultValue: "the time is between \(Self.clock(startMinute)) and \(Self.clock(endMinute))",
                comment: "Profile trigger condition: the current time is inside a daily window")
        case .batteryAtOrBelow(let percent):
            return String(
                localized: "trigger.battery",
                defaultValue: "the battery is at or below \(percent)%",
                comment: "Profile trigger condition: battery charge below a threshold")
        case .externalDisplay(let connected):
            return connected
                ? String(
                    localized: "trigger.display.connected",
                    defaultValue: "an external display is connected",
                    comment: "Profile trigger condition: an external display is attached")
                : String(
                    localized: "trigger.display.disconnected",
                    defaultValue: "no external display is connected",
                    comment: "Profile trigger condition: no external display is attached")
        case .thermalStateAtLeast(let level):
            return String(
                localized: "trigger.thermal",
                defaultValue: "the thermal state is \(level.displayName) or worse",
                comment: "Profile trigger condition: thermal pressure at or above a level")
        }
    }

    private static func clock(_ minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }
}

extension Profile {

    /// The user-facing name. Built-in names double as localisation keys
    /// (`Profile.name` documents this); a user-created profile shows
    /// whatever the user typed, untranslated.
    var displayName: String {
        switch name {
        case "Quiet":
            return String(
                localized: "profile.quiet",
                defaultValue: "Quiet",
                comment: "Built-in profile: trades peak temperature for silence")
        case "Balanced":
            return String(
                localized: "profile.balanced",
                defaultValue: "Balanced",
                comment: "Built-in profile: the default curve")
        case "Performance":
            return String(
                localized: "profile.performance",
                defaultValue: "Performance",
                comment: "Built-in profile: cools earlier and harder")
        case "System":
            return String(
                localized: "profile.system",
                defaultValue: "System",
                comment: "Built-in profile: the engine pauses and firmware keeps the fans")
        default:
            return name
        }
    }
}
