import Core
import SwiftUI

/// The Notifications tab (P7.01), which P6.08 deliberately left out.
///
/// P6.08's reasoning was that a tab of switches controlling a subsystem that
/// does not exist is exactly what the honesty rule forbids. The subsystem exists
/// now, so the tab does.
///
/// **The main switch is the only thing that asks for a permission**, and it
/// asks at the moment it is turned on. Nothing here runs at launch — see
/// `LiveNotificationSink` for why a menu bar utility that opens with a
/// permission dialog is a menu bar utility that gets deleted.
struct NotificationSettingsTab: View {
    let store: ConfigurationStore
    let model: MonitorModel
    let notifications: NotificationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            mainSwitch
            Divider()
            triggers
            Divider()
            noiseControl
            Divider()
            thresholds
            Divider()
            AutomationSection(store: store)
        }
        .onAppear { notifications.refreshAuthorization() }
    }

    // MARK: - The main switch

    private var mainSwitch: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: enabledBinding) {
                Text(
                    String(
                        localized: "settings.notify.enable",
                        defaultValue: "Send notifications",
                        comment: "Main switch for the whole notification subsystem"))
            }
            .font(.headline)

            if let note = authorizationNote {
                Text(verbatim: note)
                    .font(.caption)
                    .foregroundStyle(
                        notifications.authorization == .denied
                            ? Color.panicAccent : Color.secondary
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Turning it on asks for the permission; turning it off just turns it off.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { store.configuration.notifications.isEnabled },
            set: { wanted in
                store.update { $0.notifications.isEnabled = wanted }
                if wanted { notifications.enableAndRequestPermission() }
            })
    }

    /// Says what the *system* thinks, not what the switch thinks — a switch that
    /// reads "on" while macOS is refusing to show anything is the dishonesty
    /// this whole project is built against.
    private var authorizationNote: String? {
        switch notifications.authorization {
        case .granted:
            return nil
        case .notAsked:
            return String(
                localized: "settings.notify.permission.notasked",
                defaultValue: """
                    Turning this on asks macOS for permission to show notifications. \
                    Nothing is requested before then.
                    """,
                comment: "Explains that the notification permission is only requested on demand")
        case .denied:
            return String(
                localized: "settings.notify.permission.denied",
                defaultValue: """
                    macOS is not allowing notifications from Boreas. You can change \
                    that in System Settings, under Notifications.
                    """,
                comment: "Shown when the system has refused the notification permission")
        }
    }

    // MARK: - Triggers

    private var triggers: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                String(
                    localized: "settings.notify.section.triggers", defaultValue: "Tell me when",
                    comment: "Heading of the notification trigger list")
            )
            .font(.headline)

            ForEach(NotificationKind.allCases, id: \.self) { kind in
                triggerRow(kind)
            }
        }
        .disabled(!store.configuration.notifications.isEnabled)
    }

    private func triggerRow(_ kind: NotificationKind) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Toggle(isOn: kindBinding(kind)) {
                Text(verbatim: kind.settingsLabel)
            }
            // Refused rather than hidden, the P6.06 rule: a control that
            // explains why it cannot be changed is easier to understand than
            // one that is not there.
            .disabled(kind.isAlwaysDelivered)

            if let note = kind.alwaysOnNote {
                Text(verbatim: note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
            }
        }
    }

    private func kindBinding(_ kind: NotificationKind) -> Binding<Bool> {
        Binding(
            get: {
                kind.isAlwaysDelivered
                    || store.configuration.notifications.enabledKinds.contains(kind)
            },
            set: { wanted in
                store.update {
                    if wanted {
                        $0.notifications.enabledKinds.insert(kind)
                    } else {
                        $0.notifications.enabledKinds.remove(kind)
                    }
                }
            })
    }

    // MARK: - Noise control

    private var noiseControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "settings.notify.section.noise", defaultValue: "Keeping it quiet",
                    comment: "Heading of the notification noise control section")
            )
            .font(.headline)

            HStack(spacing: 8) {
                Text(
                    String(
                        localized: "settings.notify.window",
                        defaultValue: "Do not repeat the same notice for",
                        comment: "Label of the notification suppression window stepper"))
                Stepper(value: windowBinding, in: NotificationSettings.suppressionWindowRange) {
                    Text(
                        String(
                            localized: "settings.notify.window.value",
                            defaultValue:
                                "\(store.configuration.notifications.suppressionWindowMinutes) min",
                            comment: "The suppression window in minutes")
                    )
                    .monospacedDigit()
                }
            }

            Toggle(isOn: quietHoursBinding) {
                Text(
                    String(
                        localized: "settings.notify.quiet", defaultValue: "Quiet hours",
                        comment: "Switch enabling the notification quiet hours window"))
            }

            if let quietHours = store.configuration.notifications.quietHours {
                HStack(spacing: 8) {
                    minuteStepper(
                        label: String(
                            localized: "settings.notify.quiet.from", defaultValue: "From",
                            comment: "Start of the quiet hours window"),
                        minute: quietHours.startMinuteOfDay,
                        onChange: { minute in
                            store.update {
                                $0.notifications.quietHours = QuietHours(
                                    startMinuteOfDay: minute,
                                    endMinuteOfDay: quietHours.endMinuteOfDay)
                            }
                        })
                    minuteStepper(
                        label: String(
                            localized: "settings.notify.quiet.to", defaultValue: "To",
                            comment: "End of the quiet hours window"),
                        minute: quietHours.endMinuteOfDay,
                        onChange: { minute in
                            store.update {
                                $0.notifications.quietHours = QuietHours(
                                    startMinuteOfDay: quietHours.startMinuteOfDay,
                                    endMinuteOfDay: minute)
                            }
                        })
                }
                .padding(.leading, 22)

                Text(
                    String(
                        localized: "settings.notify.quiet.note",
                        defaultValue: """
                            Full-speed cooling is still announced during quiet hours. \
                            Everything else waits.
                            """,
                        comment: "Explains that the panic notification ignores quiet hours")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 22)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!store.configuration.notifications.isEnabled)
    }

    private var windowBinding: Binding<Int> {
        Binding(
            get: { store.configuration.notifications.suppressionWindowMinutes },
            set: { minutes in
                store.update { $0.notifications.suppressionWindowMinutes = minutes }
            })
    }

    private var quietHoursBinding: Binding<Bool> {
        Binding(
            get: { store.configuration.notifications.quietHours != nil },
            set: { wanted in
                store.update {
                    // A sensible night rather than midnight-to-midnight, which
                    // the type reads as an empty window and would look broken.
                    $0.notifications.quietHours =
                        wanted
                        ? QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 7 * 60) : nil
                }
            })
    }

    /// Hours and minutes as two steppers, the same shape the P6.14 time-window
    /// trigger editor uses — one control the user already knows from this app.
    private func minuteStepper(
        label: String, minute: Int, onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: label)
                .font(.callout)
            Stepper(
                value: Binding(get: { minute / 60 }, set: { onChange($0 * 60 + minute % 60) }),
                in: 0...23
            ) {
                Text(verbatim: String(format: "%02d", minute / 60))
                    .monospacedDigit()
            }
            Text(verbatim: ":")
            Stepper(
                value: Binding(
                    get: { minute % 60 }, set: { onChange((minute / 60) * 60 + $0) }),
                in: 0...59, step: 15
            ) {
                Text(verbatim: String(format: "%02d", minute % 60))
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Thresholds

    private var thresholds: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "settings.notify.section.thresholds",
                    defaultValue: "Temperature thresholds",
                    comment: "Heading of the per-group notification threshold list")
            )
            .font(.headline)

            Text(
                String(
                    localized: "settings.notify.thresholds.note",
                    defaultValue: """
                        There is no default: what counts as hot depends on the machine \
                        and on what you are doing with it. Set one only for the groups \
                        you want to hear about.
                        """,
                    comment: "Explains why notification thresholds ship unset")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            ForEach(presentGroups, id: \.self) { group in
                thresholdRow(group)
            }
        }
        .disabled(!store.configuration.notifications.isEnabled)
    }

    /// Only the groups this Mac actually reports. Offering a threshold for a
    /// sensor group that does not exist here is the same class of dishonesty as
    /// a switch that changes nothing.
    private var presentGroups: [SensorGroup] {
        model.grouped.map(\.group)
    }

    private func thresholdRow(_ group: SensorGroup) -> some View {
        let current = store.configuration.notifications.thresholds[group]
        return HStack(spacing: 8) {
            Toggle(
                isOn: Binding(
                    get: { current != nil },
                    set: { wanted in
                        store.update {
                            $0.notifications.thresholds[group] = wanted ? 85 : nil
                        }
                    })
            ) {
                Text(verbatim: group.displayName)
            }
            .toggleStyle(.checkbox)

            if let current {
                Stepper(
                    value: Binding(
                        get: { current },
                        set: { value in
                            store.update { $0.notifications.thresholds[group] = value }
                        }),
                    in: NotificationSettings.thresholdRange, step: 1
                ) {
                    Text(
                        String(
                            localized: "settings.notify.threshold.value",
                            defaultValue: "\(Int(current)) °C",
                            comment: "A notification threshold in degrees Celsius")
                    )
                    .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
    }
}
