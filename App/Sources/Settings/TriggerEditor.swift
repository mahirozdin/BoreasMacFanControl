import AppKit
import Core
import SwiftUI

/// Editing a profile's triggers (P6.14).
///
/// Profiles have carried triggers since P5.07 and arbitration has honoured
/// them since P5.08, but until now nothing in the interface could create
/// one: P6.08 shipped the list read-only, which left automatic profile
/// switching reachable only by hand-editing `config.json`. The reason it
/// was deferred is real — each of the six kinds needs its own editor — and
/// that is what this is.
///
/// **The engine sees a new trigger on its next cycle.** Edits go through
/// the configuration store, which is the same path the curve editor takes,
/// so a trigger added here is a trigger arbitration is already using two
/// seconds later.
struct TriggerEditor: View {
    let store: ConfigurationStore
    let control: ControlModel
    let profileName: String

    private var profile: Profile? {
        store.configuration.profiles.first { $0.name == profileName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let profile {
                ForEach(Array(profile.triggers.enumerated()), id: \.offset) { index, trigger in
                    TriggerRow(
                        trigger: trigger,
                        onChange: { edited in replace(at: index, with: edited) },
                        onRemove: { remove(at: index) })
                }

                HStack(spacing: 8) {
                    Menu {
                        ForEach(TriggerKind.allCases, id: \.self) { kind in
                            Button {
                                append(kind.blankTrigger)
                            } label: {
                                Text(verbatim: kind.title)
                            }
                        }
                    } label: {
                        Label {
                            Text(
                                String(
                                    localized: "trigger.add", defaultValue: "Add Trigger",
                                    comment: "Menu that adds a trigger to a profile"))
                        } icon: {
                            Image(systemName: "plus")
                        }
                        .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    if profile.triggers.isEmpty {
                        Text(
                            String(
                                localized: "trigger.none.help",
                                defaultValue: """
                                    With no trigger, this profile is reachable only by \
                                    choosing it, or as the default.
                                    """,
                                comment: "Explains what having no trigger means for a profile")
                        )
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)

                    // Priority decides between two profiles whose triggers
                    // both hold, so it only means anything beside them.
                    Stepper(value: priorityBinding, in: 0...9) {
                        Text(
                            String(
                                localized: "trigger.priority",
                                defaultValue: "Priority \(profile.priority)",
                                comment: "Stepper setting a profile's arbitration priority")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
            }
        }
    }

    // MARK: - Editing

    private var priorityBinding: Binding<Int> {
        Binding(
            get: { profile?.priority ?? 0 },
            set: { priority in
                edit { old in
                    Profile(
                        name: old.name, binding: old.binding, perFan: old.perFan,
                        triggers: old.triggers, priority: priority,
                        smoothing: old.smoothing, hysteresis: old.hysteresis,
                        slew: old.slew, enginePaused: old.enginePaused)
                }
            })
    }

    private func append(_ trigger: ProfileTrigger) {
        edit { old in rebuilt(old, triggers: old.triggers + [trigger]) }
    }

    private func replace(at index: Int, with trigger: ProfileTrigger) {
        edit { old in
            var triggers = old.triggers
            guard triggers.indices.contains(index) else { return old }
            triggers[index] = trigger
            return rebuilt(old, triggers: triggers)
        }
    }

    private func remove(at index: Int) {
        edit { old in
            var triggers = old.triggers
            guard triggers.indices.contains(index) else { return old }
            triggers.remove(at: index)
            return rebuilt(old, triggers: triggers)
        }
    }

    private func rebuilt(_ old: Profile, triggers: [ProfileTrigger]) -> Profile {
        Profile(
            name: old.name, binding: old.binding, perFan: old.perFan,
            triggers: triggers, priority: old.priority,
            smoothing: old.smoothing, hysteresis: old.hysteresis,
            slew: old.slew, enginePaused: old.enginePaused)
    }

    /// One edit, written through the store and handed to the model. The
    /// engine reads the profile fresh every cycle, so this is all it takes
    /// for a new trigger to start being honoured.
    private func edit(_ transform: (Profile) -> Profile) {
        store.update { configuration in
            guard let index = configuration.profiles.firstIndex(where: { $0.name == profileName })
            else { return }
            configuration.profiles[index] = transform(configuration.profiles[index])
        }
        control.reloadFromConfiguration()
    }
}

/// The six kinds, as a list something can offer.
enum TriggerKind: String, CaseIterable {
    case powerSource
    case application
    case timeWindow
    case battery
    case externalDisplay
    case thermalState

    /// A new trigger of this kind, with defaults chosen to be harmless:
    /// nothing that would start driving fans the moment it is added.
    var blankTrigger: ProfileTrigger {
        switch self {
        case .powerSource: return .powerSource(.battery)
        case .application: return .application(bundleIdentifier: "", foregroundOnly: true)
        case .timeWindow: return .timeWindow(startMinute: 22 * 60, endMinute: 8 * 60)
        case .battery: return .batteryAtOrBelow(percent: 20)
        case .externalDisplay: return .externalDisplay(connected: true)
        case .thermalState: return .thermalStateAtLeast(.serious)
        }
    }

    var title: String {
        switch self {
        case .powerSource:
            return String(
                localized: "trigger.kind.power", defaultValue: "Power source",
                comment: "Trigger kind: mains or battery")
        case .application:
            return String(
                localized: "trigger.kind.application", defaultValue: "An application",
                comment: "Trigger kind: a named application running or frontmost")
        case .timeWindow:
            return String(
                localized: "trigger.kind.time", defaultValue: "Time of day",
                comment: "Trigger kind: a daily time window")
        case .battery:
            return String(
                localized: "trigger.kind.battery", defaultValue: "Battery level",
                comment: "Trigger kind: battery charge at or below a threshold")
        case .externalDisplay:
            return String(
                localized: "trigger.kind.display", defaultValue: "External display",
                comment: "Trigger kind: an external display connected or not")
        case .thermalState:
            return String(
                localized: "trigger.kind.thermal", defaultValue: "Thermal state",
                comment: "Trigger kind: system thermal pressure at or above a level")
        }
    }
}
