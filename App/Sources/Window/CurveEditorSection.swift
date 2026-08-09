import Core
import SwiftUI

/// The curve editor with everything around it (P6.06): axis labels,
/// templates, undo/redo and the live parameters.
///
/// Edits reach the running engine within one cycle — the editor is an
/// instrument, not a drawing. They are not written to disk: persistence
/// arrives with the settings window, and an editor that pretended to save
/// would be worse than one that plainly does not.
struct CurveEditorSection: View {
    let model: MonitorModel
    let control: ControlModel
    /// Frozen "now" for the render evidence; live otherwise.
    var now: Date = Date()

    @State private var undoStack: [Curve] = []
    @State private var redoStack: [Curve] = []

    private var profile: Profile? { control.outcome?.profile }
    private var curve: Curve? { profile?.binding.curve }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let profile, let curve {
                plot(profile: profile, curve: curve)

                HStack(alignment: .top, spacing: 24) {
                    // The numbers sit beside the picture rather than behind
                    // a disclosure: a list that has to be found first is
                    // not an accessible equivalent of a plot that is simply
                    // there (P6.07).
                    CurvePointTable(
                        curve: curve,
                        onChange: { edited in control.updateActiveProfile(curve: edited) },
                        onBeginEdit: { pushUndo(curve) })
                    CurveParameterPanel(profile: profile, control: control)
                    Spacer(minLength: 0)
                }
            } else {
                Text(
                    String(
                        localized: "curve.none",
                        defaultValue: "No profile is active, so there is no curve to edit.",
                        comment: "Shown in the curve editor when no profile is active")
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(
                String(
                    localized: "curve.section", defaultValue: "Fan curve",
                    comment: "Heading of the curve editor section in the control tab")
            )
            .font(.headline)

            Spacer()

            // `.help` is a tooltip, and a tooltip is not a name: VoiceOver
            // reads an icon-only button from its label, which here is a glyph
            // with no text in it. Both are needed, and they say the same word.
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(undoStack.isEmpty)
            .help(
                String(
                    localized: "curve.undo", defaultValue: "Undo",
                    comment: "Tooltip of the curve editor undo button")
            )
            .accessibilityLabel(
                String(
                    localized: "curve.undo", defaultValue: "Undo",
                    comment: "Tooltip of the curve editor undo button"))

            Button {
                redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(redoStack.isEmpty)
            .help(
                String(
                    localized: "curve.redo", defaultValue: "Redo",
                    comment: "Tooltip of the curve editor redo button")
            )
            .accessibilityLabel(
                String(
                    localized: "curve.redo", defaultValue: "Redo",
                    comment: "Tooltip of the curve editor redo button"))

            ForEach(BuiltInProfiles.all(), id: \.name) { template in
                if !template.enginePaused {
                    Button {
                        apply(template.binding.curve)
                    } label: {
                        Text(verbatim: template.displayName)
                            .font(.caption)
                    }
                    .help(
                        String(
                            localized: "curve.template.help",
                            defaultValue: "Start from this built-in curve",
                            comment: "Tooltip on a curve editor template button"))
                }
            }
        }
    }

    private func plot(profile: Profile, curve: Curve) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                // The duty axis, top to bottom, beside the plot.
                VStack {
                    ForEach([100, 75, 50, 25, 0], id: \.self) { percent in
                        Text(verbatim: "\(percent)%")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                        if percent != 0 { Spacer(minLength: 0) }
                    }
                }
                .frame(width: 32, height: 260)

                CurveEditor(
                    curve: curve,
                    hysteresis: profile.hysteresis,
                    operatingPoint: operatingPoint(profile: profile),
                    trail: trail(profile: profile),
                    onChange: { edited in control.updateActiveProfile(curve: edited) },
                    onBeginEdit: { pushUndo(curve) })
            }

            HStack {
                ForEach(
                    Array(
                        stride(
                            from: Curve.temperatureRange.lowerBound,
                            through: Curve.temperatureRange.upperBound, by: 20)), id: \.self
                ) { celsius in
                    Text(verbatim: "\(Int(celsius))°")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    if celsius != Curve.temperatureRange.upperBound { Spacer(minLength: 0) }
                }
            }
            .padding(.leading, 38)

            Text(
                String(
                    localized: "curve.hint",
                    defaultValue:
                        "Drag a point to reshape · double-click to add · right-click a point to remove",
                    comment: "One-line instructions under the curve editor")
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    /// Where the machine is now: the bound group's hottest reading against
    /// the fan's actual duty.
    private func operatingPoint(profile: Profile) -> (celsius: Double, duty: Double)? {
        let group = profile.binding.input.group
        guard let fan = model.fans.first,
            let celsius = model.grouped.first(where: { $0.group == group })?.readings.first?.celsius
        else { return nil }
        return (celsius, fan.currentDuty.value)
    }

    private func trail(profile: Profile) -> [(celsius: Double, duty: Double)] {
        guard let fan = model.fans.first else { return [] }
        return model.operatingTrail(
            group: profile.binding.input.group, fanID: fan.id, seconds: 60, now: now)
    }

    // MARK: - Undo

    private func pushUndo(_ current: Curve) {
        undoStack.append(current)
        // A new edit invalidates the redo branch — the alternative is a
        // tree, and nobody wants a tree in a fan curve editor.
        redoStack.removeAll()
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    private func apply(_ template: Curve) {
        guard let curve else { return }
        pushUndo(curve)
        control.updateActiveProfile(curve: template)
    }

    private func undo() {
        guard let previous = undoStack.popLast(), let curve else { return }
        redoStack.append(curve)
        control.updateActiveProfile(curve: previous)
    }

    private func redo() {
        guard let next = redoStack.popLast(), let curve else { return }
        undoStack.append(curve)
        control.updateActiveProfile(curve: next)
    }
}

/// The live parameters beside the curve: hysteresis, smoothing and the
/// asymmetric rate limits.
///
/// They belong here rather than in settings because their effect is only
/// legible against the curve — the hysteresis band is drawn in the plot,
/// and the rate limits are what put the trail cloud where it is.
struct CurveParameterPanel: View {
    let profile: Profile
    let control: ControlModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            row(
                label: String(
                    localized: "curve.param.hysteresis", defaultValue: "Hysteresis",
                    comment: "Curve parameter: the width of the no-reaction band, in degrees"),
                value: String(format: "%.1f °C", profile.hysteresis.band),
                binding: Binding(
                    get: { profile.hysteresis.band },
                    set: { control.updateActiveProfile(hysteresis: Hysteresis(band: $0)) }),
                range: 0...8)

            row(
                label: String(
                    localized: "curve.param.smoothing", defaultValue: "Smoothing",
                    comment: "Curve parameter: the EWMA factor applied to the input temperature"),
                value: String(format: "%.2f", profile.smoothing.alpha),
                binding: Binding(
                    get: { profile.smoothing.alpha },
                    set: { control.updateActiveProfile(smoothing: EWMA(alpha: $0)) }),
                range: 0.05...1)

            row(
                label: String(
                    localized: "curve.param.rise", defaultValue: "Rise limit",
                    comment: "Curve parameter: how fast the fan may speed up, in rpm per second"),
                value: "\(Int(profile.slew.maxRisePerSecond)) rpm/s",
                binding: Binding(
                    get: { profile.slew.maxRisePerSecond },
                    set: {
                        control.updateActiveProfile(
                            slew: RateLimit(
                                maxRisePerSecond: $0,
                                maxFallPerSecond: profile.slew.maxFallPerSecond))
                    }),
                range: 100...2_000)

            row(
                label: String(
                    localized: "curve.param.fall", defaultValue: "Fall limit",
                    comment: "Curve parameter: how fast the fan may slow down, in rpm per second"),
                value: "\(Int(profile.slew.maxFallPerSecond)) rpm/s",
                binding: Binding(
                    get: { profile.slew.maxFallPerSecond },
                    set: {
                        control.updateActiveProfile(
                            slew: RateLimit(
                                maxRisePerSecond: profile.slew.maxRisePerSecond,
                                maxFallPerSecond: $0))
                    }),
                range: 50...1_000)
        }
    }

    private func row(
        label: String,
        value: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: label)
                .font(.caption)
                .frame(width: 90, alignment: .leading)
            Slider(value: binding, in: range)
                .frame(maxWidth: 220)
            Text(verbatim: value)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}
