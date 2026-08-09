import Core
import ServiceManagement
import SwiftUI

/// General settings (P6.08): how often the hardware is read, and whether
/// the application starts with the session.
struct GeneralSettings: View {
    let store: ConfigurationStore

    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemProblem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: samplingTitle) {
                SettingsRow(
                    label: String(
                        localized: "settings.general.interval", defaultValue: "Read sensors every",
                        comment: "Setting: how often the hardware is sampled"),
                    help: String(
                        localized: "settings.general.interval.help",
                        defaultValue:
                            """
                            Shorter is more responsive and costs a little more power. \
                            The control loop follows the same cadence.
                            """,
                        comment: "Explains the trade-off behind the sampling interval")
                ) {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { Double(store.configuration.general.samplingIntervalSeconds) },
                                set: { seconds in
                                    store.update {
                                        $0.general = ConfigurationFile.General(
                                            samplingIntervalSeconds: Int(seconds.rounded()))
                                    }
                                }),
                            in: 1...30
                        )
                        .frame(width: 200)
                        Text(
                            verbatim: "\(store.configuration.general.samplingIntervalSeconds) s"
                        )
                        .monospacedDigit()
                        .frame(width: 40, alignment: .leading)
                    }
                }
            }

            SettingsSection(title: startupTitle) {
                SettingsRow(
                    label: String(
                        localized: "settings.general.login", defaultValue: "Start at login",
                        comment: "Setting: register the application as a login item"),
                    help: loginItemProblem
                        ?? String(
                            localized: "settings.general.login.help",
                            defaultValue:
                                """
                                Registers Boreas as a login item. macOS shows it in Login \
                                Items, where it can also be turned off.
                                """,
                            comment: "Explains what the login item switch does")
                ) {
                    Toggle(isOn: loginBinding) {
                        Text(
                            String(
                                localized: "settings.general.login.toggle", defaultValue: "Enabled",
                                comment: "Label of the start-at-login switch"))
                    }
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            SettingsSection(title: languageTitle) {
                Text(
                    String(
                        localized: "settings.general.language.help",
                        defaultValue:
                            """
                            Boreas follows the language order in System Settings. macOS \
                            also lets you set a different language for this application \
                            alone, under Language & Region.
                            """,
                        comment: "Explains that the application language is a system setting")
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
    }

    /// Registration can fail — the system is entitled to refuse — so the
    /// switch reflects what the system says afterwards rather than what was
    /// asked for.
    private var loginBinding: Binding<Bool> {
        Binding(
            get: { launchesAtLogin },
            set: { wanted in
                do {
                    if wanted {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    loginItemProblem = nil
                } catch {
                    loginItemProblem = String(describing: error)
                }
                launchesAtLogin = SMAppService.mainApp.status == .enabled
            })
    }

    private var samplingTitle: String {
        String(
            localized: "settings.general.section.sampling", defaultValue: "Sampling",
            comment: "Settings section heading: how often the hardware is read")
    }

    private var startupTitle: String {
        String(
            localized: "settings.general.section.startup", defaultValue: "Startup",
            comment: "Settings section heading: launch behaviour")
    }

    private var languageTitle: String {
        String(
            localized: "settings.general.section.language", defaultValue: "Language",
            comment: "Settings section heading: application language")
    }
}

/// Appearance settings (P6.08): the status item's content and layout.
///
/// These write the same `statusItem.*` defaults keys the menu bar label has
/// read since P6.03 — the promise made there that the settings tab would
/// edit the same keys, kept.
struct AppearanceSettings: View {
    @AppStorage(StatusItemStyle.Keys.showTemperature) private var showTemperature = true
    @AppStorage(StatusItemStyle.Keys.secondaryGroup) private var secondaryGroupRaw = ""
    @AppStorage(StatusItemStyle.Keys.showFan) private var showFan = true
    @AppStorage(StatusItemStyle.Keys.showChart) private var showChart = false
    @AppStorage(StatusItemStyle.Keys.vertical) private var vertical = false
    @AppStorage(StatusItemStyle.Keys.compact) private var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: contentTitle) {
                SettingsRow(label: showLabel) {
                    VStack(alignment: .leading, spacing: 4) {
                        switchRow(temperatureLabel, isOn: $showTemperature)
                        switchRow(fanLabel, isOn: $showFan)
                        switchRow(chartLabel, isOn: $showChart)
                    }
                }

                SettingsRow(
                    label: secondaryLabel,
                    help: String(
                        localized: "settings.appearance.secondary.help",
                        defaultValue:
                            "A second temperature beside the first, taken from one group.",
                        comment: "Explains the secondary temperature setting")
                ) {
                    Picker(selection: $secondaryGroupRaw) {
                        Text(verbatim: noneLabel).tag("")
                        ForEach(SensorGroup.allCases, id: \.self) { group in
                            Text(verbatim: group.displayName).tag(group.rawValue)
                        }
                    } label: {
                        Text(verbatim: secondaryLabel)
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
            }

            SettingsSection(title: layoutTitle) {
                SettingsRow(
                    label: layoutLabel,
                    help: String(
                        localized: "settings.appearance.compact.help",
                        defaultValue:
                            """
                            Compact drops the degree marks and tightens the spacing, \
                            which is what to reach for when the menu bar runs out of room.
                            """,
                        comment: "Explains compact mode")
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        switchRow(verticalLabel, isOn: $vertical)
                        switchRow(compactLabel, isOn: $compact)
                    }
                }
            }
        }
        .padding(20)
    }

    private func switchRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(verbatim: label)
        }
        .toggleStyle(.checkbox)
    }

    private var contentTitle: String {
        String(
            localized: "settings.appearance.section.content", defaultValue: "Menu bar content",
            comment: "Settings section heading: what the status item shows")
    }

    private var layoutTitle: String {
        String(
            localized: "settings.appearance.section.layout", defaultValue: "Menu bar layout",
            comment: "Settings section heading: how the status item is arranged")
    }

    private var showLabel: String {
        String(
            localized: "settings.appearance.show", defaultValue: "Show",
            comment: "Label of the group of status item content switches")
    }

    private var layoutLabel: String {
        String(
            localized: "settings.appearance.layout", defaultValue: "Layout",
            comment: "Label of the group of status item layout switches")
    }

    private var temperatureLabel: String {
        String(
            localized: "settings.appearance.temperature", defaultValue: "Hottest temperature",
            comment: "Status item content option: the hottest sensor reading")
    }

    private var fanLabel: String {
        String(
            localized: "settings.appearance.fan", defaultValue: "Fan speed",
            comment: "Status item content option: the fan's speed")
    }

    private var chartLabel: String {
        String(
            localized: "settings.appearance.chart", defaultValue: "Mini chart",
            comment: "Status item content option: the three minute sparkline")
    }

    private var verticalLabel: String {
        String(
            localized: "settings.appearance.vertical", defaultValue: "Two stacked rows",
            comment: "Status item layout option: vertical instead of horizontal")
    }

    private var compactLabel: String {
        String(
            localized: "settings.appearance.compact", defaultValue: "Compact (numbers only)",
            comment: "Status item layout option: compact mode")
    }

    private var secondaryLabel: String {
        String(
            localized: "settings.appearance.secondary", defaultValue: "Secondary temperature",
            comment: "Setting: an additional temperature shown in the menu bar")
    }

    private var noneLabel: String {
        String(
            localized: "settings.appearance.secondary.none", defaultValue: "None",
            comment: "Choice meaning no secondary temperature is shown")
    }
}
