import Core
import SwiftUI

/// The words for every notification (P7.01).
///
/// Same split as `DiagnosticWording` and `AccessibilityWording`, for the same
/// reason: `Core` decides *which* events are delivered, and the words live in
/// the App layer where the String Catalog and `make gate-i18n` can see them.
/// `Core` has no bundle in this application, so a string there is invisible to
/// both — the blind spot P6.11 found two dozen violations in.
///
/// The switch is exhaustive over `NotificationKind`, so a new trigger is a
/// compile error until somebody writes what it says.
///
/// **The honesty rule applies here as much as in the diagnostics.** A
/// notification is the most intrusive thing this application does, so none of
/// these sentences names a fault it cannot know: a fan that is not tracking its
/// targets is reported as worth a look, never as broken. `make gate-i18n`
/// enforces the vocabulary over the catalogue, in every language.
extension NotificationDecision.Delivery {

    var title: String {
        switch kind {
        case .thresholdCrossed:
            return String(
                localized: "notify.threshold.title", defaultValue: "Temperature threshold reached",
                comment: "Notification title: a sensor group crossed the user's threshold")
        case .thermalState:
            return String(
                localized: "notify.thermal.title", defaultValue: "The system is under thermal load",
                comment: "Notification title: the system thermal state reached serious or above")
        case .panicEngaged:
            return String(
                localized: "notify.panic.title", defaultValue: "Cooling at full speed",
                comment: "Notification title: the panic layer engaged")
        case .fanAnomaly:
            return String(
                localized: "notify.fan.title", defaultValue: "A fan check is worth a look",
                comment: "Notification title: a fan check raised a concern")
        case .daemonLost:
            return String(
                localized: "notify.daemon.title", defaultValue: "Fan control handed back",
                comment: "Notification title: the helper connection dropped or the watchdog fired")
        case .profileChanged:
            return String(
                localized: "notify.profile.title", defaultValue: "Profile changed",
                comment: "Notification title: the active profile changed")
        case .batteryHealth:
            return String(
                localized: "notify.battery.title", defaultValue: "Battery health has changed",
                comment: "Notification title: battery health degraded")
        }
    }

    var body: String {
        switch kind {
        case .thresholdCrossed:
            // Coalesced: the subjects are the groups that crossed together, and
            // the sentence has to work for one as well as for five.
            return String(
                localized: "notify.threshold.body",
                defaultValue: "Above your threshold: \(subjects.joined(separator: ", "))",
                comment: "Notification body: which sensor groups crossed the threshold")
        case .thermalState:
            return String(
                localized: "notify.thermal.body",
                defaultValue: "The system reports raised thermal pressure. The fans are responding.",
                comment: "Notification body for the thermal state trigger")
        case .panicEngaged:
            return String(
                localized: "notify.panic.body",
                defaultValue: """
                    A sensor crossed the panic threshold, so the fans are at full \
                    speed until it falls back.
                    """,
                comment: "Notification body for the panic layer trigger")
        case .fanAnomaly:
            // Never "the fan is faulty" — the honesty rule
            // (docs/operations/diagnostics.md), and the gate refuses the
            // vocabulary in every language.
            return String(
                localized: "notify.fan.body",
                defaultValue: """
                    The fans are not following their targets as closely as expected. \
                    Diagnostics has the details and some things to try.
                    """,
                comment: "Notification body for the fan anomaly trigger")
        case .daemonLost:
            return String(
                localized: "notify.daemon.body",
                defaultValue: """
                    The fans are back under the system's control. Nothing is at risk — \
                    this is what is supposed to happen.
                    """,
                comment: "Notification body for the daemon connection lost trigger")
        case .profileChanged:
            return String(
                localized: "notify.profile.body",
                defaultValue: "Now running: \(subjects.first ?? "")",
                comment: "Notification body naming the profile that became active")
        case .batteryHealth:
            return String(
                localized: "notify.battery.body",
                defaultValue: "The system reports a change in battery condition.",
                comment: "Notification body for the battery health trigger")
        }
    }

    /// A stable identifier, so the notification centre replaces rather than
    /// stacks. The suppression window already stops repeats inside the app;
    /// this stops a second banner appearing above the first when it does not.
    var identifier: String {
        "boreas.\(kind.rawValue).\(subjects.joined(separator: "."))"
    }
}

extension NotificationKind {

    /// The label in the Notifications settings tab.
    var settingsLabel: String {
        switch self {
        case .thresholdCrossed:
            return String(
                localized: "settings.notify.threshold",
                defaultValue: "A sensor group crosses a threshold",
                comment: "Notification settings: the threshold trigger")
        case .thermalState:
            return String(
                localized: "settings.notify.thermal",
                defaultValue: "The system reports raised thermal pressure",
                comment: "Notification settings: the thermal state trigger")
        case .panicEngaged:
            return String(
                localized: "settings.notify.panic",
                defaultValue: "Cooling goes to full speed",
                comment: "Notification settings: the panic layer trigger")
        case .fanAnomaly:
            return String(
                localized: "settings.notify.fan",
                defaultValue: "A fan check is worth a look",
                comment: "Notification settings: the fan anomaly trigger")
        case .daemonLost:
            return String(
                localized: "settings.notify.daemon",
                defaultValue: "Fan control is handed back to the system",
                comment: "Notification settings: the daemon connection trigger")
        case .profileChanged:
            return String(
                localized: "settings.notify.profile",
                defaultValue: "The active profile changes",
                comment: "Notification settings: the profile change trigger")
        case .batteryHealth:
            return String(
                localized: "settings.notify.battery",
                defaultValue: "Battery condition changes",
                comment: "Notification settings: the battery health trigger")
        }
    }

    /// Said in the settings tab beside the switch, for the one trigger that
    /// cannot be switched off — so the disabled control explains itself rather
    /// than looking broken. The same treatment the watchdog timeout got in
    /// P6.08 under ADR 0023.
    var alwaysOnNote: String? {
        guard isAlwaysDelivered else { return nil }
        return String(
            localized: "settings.notify.panic.note",
            defaultValue: "Always on, like the panic threshold itself",
            comment: "Notification settings: why the panic trigger cannot be switched off")
    }
}
