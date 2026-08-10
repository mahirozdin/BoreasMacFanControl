import Core
import SwiftUI

/// The settings render evidence (P6.08).
///
/// The fixture store is pointed at a throwaway directory: a camera that
/// wrote to the owner's real `config.json` would be a camera that changes
/// what it photographs.
extension RenderEvidence {

    struct SettingsFixture {
        let store: ConfigurationStore
        let monitor: MonitorModel
        let control: ControlModel
        let setup: HelperSetupModel
    }

    private static func settingsFixture() -> SettingsFixture {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("boreas-render-settings", isDirectory: true)
        let store = ConfigurationStore(directory: directory)
        // Notifications on in the fixture: a tab photographed entirely greyed
        // out would prove only that `.disabled` works.
        store.update {
            $0.notifications.isEnabled = true
            $0.notifications.quietHours = QuietHours(
                startMinuteOfDay: 22 * 60, endMinuteOfDay: 7 * 60)
            $0.notifications.thresholds = [.compute: 88]
        }

        func reading(_ raw: String, _ group: SensorGroup, _ celsius: Double) -> SensorReading {
            SensorClassifier.makeReading(rawName: raw, celsius: celsius)
        }
        let readings = [
            reading("PMU tdie5", .compute, 62.4),
            reading("PMU tdie1", .compute, 58.9),
            reading("GPU tdie0", .graphics, 55.8),
            reading("LPDDR temp", .memory, 46.4),
            // Deliberately unrecognisable, so the uncategorized report has
            // something to report — the one thing that report must never be
            // is invisible.
            reading("NEWCHIP xz9", .uncategorized, 51.2),
        ]
        let fan = FanState(
            id: 0, name: "Fan 0", currentRPM: 1_608,
            minimumRPM: 1_000, maximumRPM: 4_900, isPoweredOff: false)

        let monitor = MonitorModel(fixedForRendering: readings, fans: [fan])
        let control = ControlModel(
            fixedForRendering: monitor,
            selection: ManualSelection(profileName: "Balanced"),
            state: .controlling, layer: nil)
        let setup = HelperSetupModel()
        setup.fixedInstallerStateForRendering = .enabled
        return SettingsFixture(store: store, monitor: monitor, control: control, setup: setup)
    }

    /// Renders each settings tab's content. The tabs are rendered
    /// individually for the usual reason — `TabView` and `ScrollView` draw
    /// nothing under `ImageRenderer`, so the evidence photographs content.
    static func settings(into directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            report("cannot create \(directory.path): \(error)")
            return
        }

        let fixture = settingsFixture()

        let tabs: [(String, AnyView)] = [
            ("1-general", AnyView(GeneralSettings(store: fixture.store, shortcuts: GlobalShortcuts()))),
            ("2-appearance", AnyView(AppearanceSettings())),
            (
                "3-sensors",
                AnyView(
                    SensorSettings(
                        store: fixture.store, model: fixture.monitor, control: fixture.control))
            ),
            (
                "4-control",
                AnyView(ControlSettings(store: fixture.store, control: fixture.control))
            ),
            (
                "5-notifications",
                AnyView(
                    NotificationSettingsTab(
                        store: fixture.store, model: fixture.monitor,
                        // A model over a recording sink: the camera must not
                        // touch the real notification centre, and a granted
                        // authorization is the state worth photographing —
                        // the "not asked yet" note is the other one, and the
                        // fixture below renders it.
                        notifications: NotificationModel(
                            sink: RecordingNotificationSink(authorization: .granted),
                            store: fixture.store,
                            fixedAuthorizationForRendering: .granted)))
            ),
            (
                "6-notifications-denied",
                AnyView(
                    NotificationSettingsTab(
                        store: fixture.store, model: fixture.monitor,
                        notifications: NotificationModel(
                            sink: RecordingNotificationSink(authorization: .denied),
                            store: fixture.store,
                            // The refusal, which is the state the tab most
                            // needs to be honest about: a switch reading "on"
                            // while macOS shows nothing.
                            fixedAuthorizationForRendering: .denied)))
            ),
            (
                "7-advanced",
                AnyView(
                    AdvancedSettings(
                        store: fixture.store, control: fixture.control, setup: fixture.setup))
            ),
        ]

        for (name, tab) in tabs {
            let view =
                tab
                .frame(width: 620)
                .background(Color(white: 0.97))
                .environment(\.colorScheme, .light)
            write(view, to: directory, named: "settings-\(name)")
        }
    }
}
