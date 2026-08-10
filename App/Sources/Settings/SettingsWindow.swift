import Core
import SwiftUI

/// The settings window (P6.08).
///
/// The blueprint lists seven tabs. Six are here. **Notifications joined them
/// in P7.01, when its subsystem arrived** — P6.08 left it out on the grounds
/// that a tab full of switches changing nothing is what the honesty rule exists
/// to prevent, and that reasoning held until there was something for the
/// switches to change. Recording is still absent on the same grounds; P7.02
/// owns it.
struct SettingsWindow: View {
    static let windowID = "settings"

    let store: ConfigurationStore
    let model: MonitorModel
    let control: ControlModel
    let setup: HelperSetupModel
    let shortcuts: GlobalShortcuts
    let notifications: NotificationModel

    var body: some View {
        TabView {
            SettingsScroll { GeneralSettings(store: store, shortcuts: shortcuts) }
                .tabItem { tabLabel(generalTitle, systemImage: "gearshape") }

            SettingsScroll { AppearanceSettings() }
                .tabItem { tabLabel(appearanceTitle, systemImage: "paintbrush") }

            SettingsScroll { SensorSettings(store: store, model: model, control: control) }
                .tabItem { tabLabel(sensorsTitle, systemImage: "thermometer.medium") }

            SettingsScroll { ControlSettings(store: store, control: control) }
                .tabItem { tabLabel(controlTitle, systemImage: "slider.horizontal.3") }

            SettingsScroll {
                NotificationSettingsTab(
                    store: store, model: model, notifications: notifications)
            }
            .tabItem { tabLabel(notificationsTitle, systemImage: "bell") }

            SettingsScroll { AdvancedSettings(store: store, control: control, setup: setup) }
                .tabItem { tabLabel(advancedTitle, systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 620, height: 470)
    }

    private func tabLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(verbatim: title)
        } icon: {
            Image(systemName: systemImage)
        }
    }

    private var notificationsTitle: String {
        String(
            localized: "settings.tab.notifications", defaultValue: "Notifications",
            comment: "Settings tab: which events produce a notification, and how often")
    }

    private var generalTitle: String {
        String(
            localized: "settings.tab.general", defaultValue: "General",
            comment: "Settings tab: sampling and launch behaviour")
    }

    private var appearanceTitle: String {
        String(
            localized: "settings.tab.appearance", defaultValue: "Appearance",
            comment: "Settings tab: what the menu bar item shows and how")
    }

    private var sensorsTitle: String {
        String(
            localized: "settings.tab.sensors", defaultValue: "Sensors",
            comment: "Settings tab: naming, grouping and hiding sensors")
    }

    private var controlTitle: String {
        String(
            localized: "settings.tab.control", defaultValue: "Control",
            comment: "Settings tab: profiles and the panic threshold")
    }

    private var advancedTitle: String {
        String(
            localized: "settings.tab.advanced", defaultValue: "Advanced",
            comment: "Settings tab: the helper, the configuration file and resetting")
    }
}

/// Every tab scrolls, and every tab's content is a separate view — the
/// container/content split the render evidence needs (`ScrollView` draws
/// nothing under `ImageRenderer`).
struct SettingsScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
        }
    }
}

/// A titled block of settings, so every tab reads the same way.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One labelled row. The label column is fixed so controls line up down the
/// tab without a Form, which is AppKit-backed and invisible to the camera.
struct SettingsRow<Content: View>: View {
    let label: String
    var help: String?
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: label)
                .frame(width: 170, alignment: .trailing)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                content
                if let help {
                    Text(verbatim: help)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
