import Core
import SwiftUI

/// The manual override (P6.05): a duty slider with a duration picker.
///
/// P4.08 built this slider, P6.02 took it out of the menu bar panel and
/// promised it back here — the panel is for switching profiles, the control
/// tab is where a user deliberately overrules the engine.
///
/// Expiry returns to the engine rather than to the firmware: the user asked
/// to take the wheel for half an hour, not to stop cooling afterwards. The
/// safety chain sits after the override either way, so an override can
/// raise the fans and never hold them below what K1–K3 demand.
struct ManualOverrideSection: View {
    let control: ControlModel

    @State private var duty: Double = 0.35
    @State private var minutes: Int? = 30

    private static let durations: [Int?] = [30, 60, 180, nil]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "control.section.override", defaultValue: "Manual override",
                    comment: "Heading of the manual fan override section in the control tab")
            )
            .font(.headline)

            HStack(spacing: 10) {
                Slider(value: $duty, in: 0...1)
                    .frame(maxWidth: 260)
                Text(verbatim: "\(Duty(duty).percent)%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)

                Picker(selection: $minutes) {
                    ForEach(Self.durations, id: \.self) { choice in
                        Text(verbatim: label(for: choice)).tag(choice)
                    }
                } label: {
                    Text(
                        String(
                            localized: "control.override.duration", defaultValue: "For",
                            comment: "Label of the manual override duration picker"))
                }
                .frame(width: 190)
                .disabled(control.isDutyOverridden)

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    control.overrideDuty(
                        duty, until: minutes.map { Date().addingTimeInterval(Double($0) * 60) })
                } label: {
                    Text(
                        String(
                            localized: "control.override.start", defaultValue: "Take Over",
                            comment: "Button that starts driving the fans at the slider value"))
                }
                .disabled(control.isDutyOverridden)

                Button {
                    control.clearDutyOverride()
                } label: {
                    Text(
                        String(
                            localized: "control.override.stop",
                            defaultValue: "Return to Automatic",
                            comment: "Button that hands control back to the curve engine"))
                }
                .disabled(!control.isDutyOverridden)

                if let caption = statusCaption {
                    Text(verbatim: caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { duty = control.manualDuty }
        .onChange(of: duty) { _, newValue in
            // While the override is running the slider is live: a slider
            // that only takes effect on a button press would leave the
            // number and the fans disagreeing.
            if control.isDutyOverridden {
                control.overrideDuty(newValue, until: control.dutyOverrideUntil)
            }
        }
    }

    private var statusCaption: String? {
        guard control.isDutyOverridden else { return nil }
        guard let until = control.dutyOverrideUntil else {
            return String(
                localized: "control.override.indefinite",
                defaultValue: "You are driving the fans until you hand them back.",
                comment: "Caption while an open-ended manual override is running")
        }
        let time = until.formatted(date: .omitted, time: .shortened)
        return String(
            localized: "control.override.until",
            defaultValue: "Back to automatic at \(time).",
            comment: "Caption while a timed manual override is running")
    }

    private func label(for choice: Int?) -> String {
        guard let choice else {
            return String(
                localized: "control.override.forever", defaultValue: "Until I stop",
                comment: "Manual override duration choice with no time limit")
        }
        return String(
            localized: "control.override.minutes", defaultValue: "\(choice) minutes",
            comment: "Manual override duration choice in minutes")
    }
}

/// Which sensor group each fan follows in the active profile (P6.05).
///
/// Read-only here: editing a binding changes a profile, which belongs with
/// the rest of profile management in the settings window (P6.08). Showing
/// it is what makes the engine's behaviour explicable — a fan whose curve
/// is bound to a group nobody expected is otherwise invisible.
struct FanMappingSection: View {
    let model: MonitorModel
    let control: ControlModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "control.section.mapping", defaultValue: "Fan inputs",
                    comment: "Heading of the per-fan sensor mapping list in the control tab")
            )
            .font(.headline)

            if let profile = control.outcome?.profile {
                ForEach(model.fans) { fan in
                    let binding = profile.binding(forFan: fan.id)
                    HStack(spacing: 8) {
                        Text(verbatim: fan.name)
                            .frame(width: 120, alignment: .leading)
                        // The arrow *is* the relationship, and an arrow read
                        // aloud is nothing at all — the composed label below
                        // says "follows" in words instead.
                        Image(systemName: "arrow.left")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        Text(verbatim: binding.input.group.displayName)
                        Text(verbatim: binding.input.aggregate.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .font(.callout)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(
                            localized: "control.mapping.accessibility",
                            defaultValue: """
                                \(fan.name) follows \(binding.input.group.displayName), \
                                \(binding.input.aggregate.rawValue)
                                """,
                            comment:
                                "VoiceOver label of one fan-to-sensor-group mapping row in the control tab"
                        ))
                }
            }

            if model.fans.isEmpty {
                Text(
                    String(
                        localized: "control.mapping.nofans",
                        defaultValue: "This Mac reports no controllable fan.",
                        comment: "Shown in the fan mapping list on a machine with no fans")
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }
}
