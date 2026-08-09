import Core
import SwiftUI

/// The panel that opens from the menu bar (P6.02).
///
/// Profile picker, fans with their fill, temperatures grouped and
/// collapsible — each section its own view in `PanelSections.swift`. The
/// P4.08 manual slider left the panel: the picker is the panel's control
/// surface, and raw duty control returns as the control tab's manual
/// override (P6.05). The sampling loop never stops while the panel is open;
/// it belongs to the label, not to this view.
struct MenuBarPanel: View {
    let model: MonitorModel
    let setup: HelperSetupModel
    let control: ControlModel

    @Environment(\.openWindow) private var openWindow
    private let initiallyExpanded: Set<SensorGroup>

    init(
        model: MonitorModel,
        setup: HelperSetupModel,
        control: ControlModel,
        initiallyExpanded: Set<SensorGroup> = []
    ) {
        self.model = model
        self.setup = setup
        self.control = control
        self.initiallyExpanded = initiallyExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let problem = model.sensorProblem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(Color.warningAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let degraded = model.degradedReason {
                Label(degraded, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.fans.isEmpty {
                Divider()
                ProfilePickerSection(control: control, setup: setup)
                Divider()
                FanListSection(fans: model.fans)
            }

            if !model.readings.isEmpty {
                Divider()
                SensorGroupList(model: model, initiallyExpanded: initiallyExpanded)
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text(
                String(
                    localized: "panel.title",
                    defaultValue: "Boreas",
                    comment: "Product name at the top of the menu bar panel"
                )
            )
            .font(.headline)

            Spacer()

            if let hottest = model.hottest {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.temperature(hottest.celsius))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(verbatim: String(format: "%.1f °C", hottest.celsius))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: MainWindow.windowID)
                // An LSUIElement app is never frontmost on its own; without
                // this the window opens behind whatever has focus.
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Text(
                    String(
                        localized: "panel.mainwindow.button",
                        defaultValue: "Main Window",
                        comment: "Menu bar panel button that opens the main window"
                    )
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            Button {
                openWindow(id: SettingsWindow.windowID)
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Text(
                    String(
                        localized: "panel.settings.button",
                        defaultValue: "Settings",
                        comment: "Menu bar panel button that opens the settings window"
                    )
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            // A Mac without a controllable fan gets no setup offer — the
            // error-scenario table says exactly that, and a quiet footer is
            // not an error state (invariant I4).
            if !model.fans.isEmpty {
                Button {
                    openWindow(id: HelperSetupView.windowID)
                    // An LSUIElement app is never frontmost on its own; without
                    // this the window opens behind whatever has focus.
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Text(
                        String(
                            localized: "panel.fancontrol.button",
                            defaultValue: "Fan Control…",
                            comment: "Menu bar panel button that opens the fan control setup window"
                        )
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)

                if let status = setupStatus {
                    Text(verbatim: status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(
                    String(
                        localized: "panel.quit",
                        defaultValue: "Quit",
                        comment: "Button that closes the application"
                    )
                )
            }
            // Plain style with the tint colour, not `.link`: the link style
            // is AppKit-backed and `ImageRenderer` draws it as a placeholder,
            // which would falsify the render evidence. Visually identical.
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
    }

    /// One-word helper status next to the setup button. Absence of the helper
    /// is not worth a word: not installed is the normal starting state.
    private var setupStatus: String? {
        switch setup.installerState {
        case .enabled:
            return String(
                localized: "panel.fancontrol.ready",
                defaultValue: "ready",
                comment: "Tiny status next to the fan control button when the helper is installed"
            )
        case .requiresApproval:
            return String(
                localized: "panel.fancontrol.approval",
                defaultValue: "approval pending",
                comment: """
                    Tiny status next to the fan control button while System Settings \
                    approval is pending
                    """
            )
        case .notRegistered, .notFound, .unknown:
            return nil
        }
    }
}
