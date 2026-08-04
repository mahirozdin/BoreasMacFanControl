import Core
import SwiftUI

/// The panel that opens from the menu bar.
///
/// Scaffold for P2: it shows what the hardware layer reports so the reads can
/// be seen working. Profiles, the curve editor and fan controls arrive in P6.
struct MenuBarPanel: View {
    let model: MonitorModel
    let setup: HelperSetupModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let problem = model.sensorProblem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
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
                fanSection
            }

            if !model.readings.isEmpty {
                Divider()
                sensorSection
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
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
                Text(verbatim: String(format: "%.1f °C", hottest.celsius))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fanSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(
                String(
                    localized: "panel.section.fans",
                    defaultValue: "Fans",
                    comment: "Heading above the list of fans"
                )
            )
            ForEach(model.fans) { fan in
                HStack {
                    Text(verbatim: fan.name)
                    Spacer()
                    if fan.isPoweredOff {
                        Text(
                            String(
                                localized: "panel.fan.parked",
                                defaultValue: "parked",
                                comment: "Shown when the firmware has switched a fan off entirely"
                            )
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: "\(fan.currentRPM) rpm")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }
        }
    }

    private var sensorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(
                String(
                    localized: "panel.section.temperatures",
                    defaultValue: "Temperatures",
                    comment: "Heading above the grouped temperature list"
                )
            )
            ForEach(model.grouped, id: \.group) { entry in
                HStack {
                    Text(verbatim: entry.group.rawValue)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let hottest = entry.readings.first {
                        Text(verbatim: String(format: "%.1f °C", hottest.celsius))
                            .monospacedDigit()
                    }
                    Text(verbatim: "(\(entry.readings.count))")
                        .foregroundStyle(.tertiary)
                }
                .font(.callout)
            }
        }
    }

    private var footer: some View {
        HStack {
            // A Mac without a controllable fan gets no setup offer — the
            // error-scenario table says exactly that, and a quiet footer is
            // not an error state (invariant İ4).
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
                .buttonStyle(.link)

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
            .buttonStyle(.link)
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

    private func sectionTitle(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
