import Core
import SwiftUI

/// The panel that opens from the menu bar.
///
/// Scaffold for P2: it shows what the hardware layer reports so the reads can
/// be seen working. Profiles, the curve editor and fan controls arrive in P6.
struct MenuBarPanel: View {
    let model: MonitorModel

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
            Text(
                String(
                    localized: "panel.control.unavailable",
                    defaultValue: "Fan control arrives in a later build",
                    comment: "Placeholder while the privileged helper is not yet implemented"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

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

    private func sectionTitle(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
