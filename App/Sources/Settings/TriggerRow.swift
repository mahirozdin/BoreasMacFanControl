import AppKit
import Core
import SwiftUI

/// One trigger, with the editor its kind needs (P6.14).
///
/// Six kinds, six shapes — which is the reason this was its own task
/// rather than a line in the settings tab. The switch is exhaustive over
/// `ProfileTrigger`, so a seventh kind cannot be added to the engine
/// without somebody deciding how it is edited.
struct TriggerRow: View {
    let trigger: ProfileTrigger
    let onChange: (ProfileTrigger) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            editor

            Spacer(minLength: 0)

            Button(action: onRemove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(
                String(
                    localized: "trigger.remove", defaultValue: "Remove this trigger",
                    comment: "Tooltip of the button that removes a trigger"))
        }
        .font(.callout)
    }

    @ViewBuilder
    private var editor: some View {
        switch trigger {
        case .powerSource(let source):
            Picker(selection: sourceBinding(source)) {
                Text(
                    String(
                        localized: "trigger.edit.power.battery", defaultValue: "On battery",
                        comment: "Power source choice: running on battery")
                ).tag(PowerContext.Source.battery)
                Text(
                    String(
                        localized: "trigger.edit.power.adapter", defaultValue: "Plugged in",
                        comment: "Power source choice: running on mains")
                ).tag(PowerContext.Source.adapter)
            } label: {
                Text(verbatim: TriggerKind.powerSource.title)
            }
            .labelsHidden()
            .frame(width: 190)

        case .application(let bundleIdentifier, let foregroundOnly):
            ApplicationTriggerEditor(
                bundleIdentifier: bundleIdentifier,
                foregroundOnly: foregroundOnly,
                onChange: onChange)

        case .timeWindow(let start, let end):
            HStack(spacing: 6) {
                MinutePicker(minute: start) { onChange(.timeWindow(startMinute: $0, endMinute: end)) }
                Text(verbatim: "–")
                    .foregroundStyle(.tertiary)
                MinutePicker(minute: end) { onChange(.timeWindow(startMinute: start, endMinute: $0)) }
                // A window that wraps midnight is legal and means what it
                // looks like; saying so beats leaving somebody to wonder.
                if start > end {
                    Text(
                        String(
                            localized: "trigger.edit.time.overnight", defaultValue: "overnight",
                            comment: "Note on a time window that crosses midnight")
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

        case .batteryAtOrBelow(let percent):
            HStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { Double(percent) },
                        set: { onChange(.batteryAtOrBelow(percent: Int($0.rounded()))) }),
                    in: 5...95
                )
                .frame(width: 140)
                Text(verbatim: "≤ \(percent)%")
                    .monospacedDigit()
                    .frame(width: 56, alignment: .leading)
            }

        case .externalDisplay(let connected):
            Picker(
                selection: Binding(
                    get: { connected },
                    set: { onChange(.externalDisplay(connected: $0)) })
            ) {
                Text(
                    String(
                        localized: "trigger.edit.display.connected", defaultValue: "Connected",
                        comment: "External display choice: one is attached")
                ).tag(true)
                Text(
                    String(
                        localized: "trigger.edit.display.disconnected",
                        defaultValue: "Not connected",
                        comment: "External display choice: none attached")
                ).tag(false)
            } label: {
                Text(verbatim: TriggerKind.externalDisplay.title)
            }
            .labelsHidden()
            .frame(width: 190)

        case .thermalStateAtLeast(let level):
            Picker(
                selection: Binding(
                    get: { level },
                    set: { onChange(.thermalStateAtLeast($0)) })
            ) {
                // `nominal` is deliberately absent: "at least nominal" is
                // always true, which is a trigger that means nothing.
                ForEach([ThermalPressure.fair, .serious, .critical], id: \.self) { pressure in
                    Text(verbatim: pressure.displayName).tag(pressure)
                }
            } label: {
                Text(verbatim: TriggerKind.thermalState.title)
            }
            .labelsHidden()
            .frame(width: 190)
        }
    }

    private func sourceBinding(_ source: PowerContext.Source) -> Binding<PowerContext.Source> {
        Binding(get: { source }, set: { onChange(.powerSource($0)) })
    }
}

/// The application trigger: a bundle identifier, chosen by picking the
/// application rather than typed.
///
/// Nobody knows their editor's bundle identifier by heart, and a typed one
/// that is subtly wrong produces a trigger that simply never fires — the
/// worst kind of bug, because nothing appears broken.
struct ApplicationTriggerEditor: View {
    let bundleIdentifier: String
    let foregroundOnly: Bool
    let onChange: (ProfileTrigger) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                chooseApplication()
            } label: {
                Text(verbatim: bundleIdentifier.isEmpty ? chooseLabel : bundleIdentifier)
                    .font(.caption)
                    .monospaced()
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 190, alignment: .leading)
            }

            Toggle(
                isOn: Binding(
                    get: { foregroundOnly },
                    set: {
                        onChange(
                            .application(bundleIdentifier: bundleIdentifier, foregroundOnly: $0))
                    })
            ) {
                Text(
                    String(
                        localized: "trigger.edit.app.frontmost", defaultValue: "only when frontmost",
                        comment: "Whether the application trigger needs the app to be in front"))
            }
            .toggleStyle(.checkbox)
            .font(.caption)
        }
    }

    private var chooseLabel: String {
        String(
            localized: "trigger.edit.app.choose", defaultValue: "Choose an application…",
            comment: "Button that opens a picker to select the application for a trigger")
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
            let identifier = Bundle(url: url)?.bundleIdentifier
        else { return }
        onChange(.application(bundleIdentifier: identifier, foregroundOnly: foregroundOnly))
    }
}

/// An hour and minute, as two steppers rather than a date picker: the value
/// is a minute of the day, not a moment, and a date picker would invite a
/// calendar into a setting that has no date in it.
struct MinutePicker: View {
    let minute: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            Stepper(value: hourBinding, in: 0...23) {
                Text(verbatim: String(format: "%02d", minute / 60))
                    .monospacedDigit()
            }
            .fixedSize()
            Text(verbatim: ":")
                .foregroundStyle(.tertiary)
            Stepper(value: minuteBinding, in: 0...55, step: 5) {
                Text(verbatim: String(format: "%02d", minute % 60))
                    .monospacedDigit()
            }
            .fixedSize()
        }
        .font(.caption)
    }

    private var hourBinding: Binding<Int> {
        Binding(get: { minute / 60 }, set: { onChange($0 * 60 + minute % 60) })
    }

    private var minuteBinding: Binding<Int> {
        Binding(get: { minute % 60 }, set: { onChange((minute / 60) * 60 + $0) })
    }
}
