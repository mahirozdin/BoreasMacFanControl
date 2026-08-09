import Core
import SwiftUI

/// Control settings (P6.08): the default profile, each profile's priority
/// and trigger summary, and the panic threshold.
struct ControlSettings: View {
    let store: ConfigurationStore
    let control: ControlModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: profilesTitle) {
                SettingsRow(
                    label: defaultLabel,
                    help: String(
                        localized: "settings.control.default.help",
                        defaultValue:
                            "Used when no trigger holds and nothing is selected by hand.",
                        comment: "Explains what the default profile is for")
                ) {
                    Picker(selection: defaultProfileBinding) {
                        ForEach(store.configuration.profiles, id: \.name) { profile in
                            Text(verbatim: profile.displayName).tag(profile.name)
                        }
                    } label: {
                        Text(verbatim: defaultLabel)
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }

                ForEach(store.configuration.profiles, id: \.name) { profile in
                    profileRow(profile)
                }
            }

            SettingsSection(title: safetyTitle) {
                SettingsRow(
                    label: panicLabel,
                    help: String(
                        localized: "settings.control.panic.help",
                        defaultValue:
                            """
                            Above this, every fan goes to full speed and holds there. \
                            It can be lowered, never raised above the default — the \
                            ceiling is the default (ADR 0022).
                            """,
                        comment: "Explains the panic threshold and why it cannot be raised")
                ) {
                    HStack(spacing: 8) {
                        Slider(
                            value: panicBinding,
                            in: PanicThreshold.floorCelsius...PanicThreshold.defaultCelsius
                        )
                        .frame(width: 200)
                        Text(
                            verbatim:
                                "\(Int(store.configuration.safety.panicThreshold.celsius)) °C"
                        )
                        .monospacedDigit()
                        .frame(width: 50, alignment: .leading)
                    }
                }

                SettingsRow(
                    label: watchdogLabel,
                    help: String(
                        localized: "settings.control.watchdog.help",
                        defaultValue:
                            """
                            Fixed, and shown here as a fact rather than a control: the \
                            helper reads no configuration and its message surface is \
                            exactly four methods, so there is no way to deliver a \
                            different value to it (ADR 0023).
                            """,
                        comment: "Explains why the watchdog timeout cannot be changed")
                ) {
                    Text(
                        verbatim:
                            "\(Int(store.configuration.safety.watchdogTimeoutSeconds)) s"
                    )
                    .monospacedDigit()
                }
            }
        }
        .padding(20)
    }

    private func profileRow(_ profile: Profile) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: profile.displayName)
                .frame(width: 120, alignment: .leading)

            Text(
                verbatim: profile.enginePaused
                    ? firmwareLabel
                    : "\(profile.binding.input.group.displayName) · "
                        + "\(profile.binding.curve.points.count) points"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 210, alignment: .leading)

            Text(verbatim: triggerSummary(profile))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    /// Triggers are shown, not edited. Editing them means a trigger editor
    /// with one interface per kind — application pickers, time windows,
    /// battery thresholds — which is its own piece of work; showing them is
    /// what keeps arbitration explicable in the meantime.
    private func triggerSummary(_ profile: Profile) -> String {
        guard !profile.triggers.isEmpty else {
            return String(
                localized: "settings.control.trigger.none", defaultValue: "no automatic trigger",
                comment: "Shown for a profile that is only reachable manually or as the default")
        }
        return profile.triggers.map(\.displayCondition).joined(separator: ", ")
    }

    // MARK: - Bindings

    private var defaultProfileBinding: Binding<String> {
        Binding(
            get: { store.configuration.defaultProfileName },
            set: { name in
                store.update { $0.defaultProfileName = name }
                control.reloadFromConfiguration()
            })
    }

    /// The type clamps into [70, 95] whatever arrives, so the slider's own
    /// bounds are a courtesy rather than the guarantee (G2).
    private var panicBinding: Binding<Double> {
        Binding(
            get: { store.configuration.safety.panicThreshold.celsius },
            set: { celsius in
                store.update {
                    $0.safety = ConfigurationFile.Safety(
                        panicThreshold: PanicThreshold(celsius: celsius.rounded()),
                        watchdogTimeoutSeconds: $0.safety.watchdogTimeoutSeconds)
                }
            })
    }

    private var profilesTitle: String {
        String(
            localized: "settings.control.section.profiles", defaultValue: "Profiles",
            comment: "Settings section heading: the profile list and default")
    }

    private var safetyTitle: String {
        String(
            localized: "settings.control.section.safety", defaultValue: "Safety limits",
            comment: "Settings section heading: panic threshold and watchdog")
    }

    private var defaultLabel: String {
        String(
            localized: "settings.control.default", defaultValue: "Default profile",
            comment: "Setting: which profile arbitration falls back to")
    }

    private var panicLabel: String {
        String(
            localized: "settings.control.panic", defaultValue: "Panic threshold",
            comment: "Setting: the K3 trigger temperature")
    }

    private var watchdogLabel: String {
        String(
            localized: "settings.control.watchdog", defaultValue: "Watchdog timeout",
            comment: "Setting shown read-only: how long the helper waits before releasing")
    }

    private var firmwareLabel: String {
        String(
            localized: "settings.control.firmware", defaultValue: "the firmware keeps the fans",
            comment: "Description of the System profile in the profile list")
    }
}
