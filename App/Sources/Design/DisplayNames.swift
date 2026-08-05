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
