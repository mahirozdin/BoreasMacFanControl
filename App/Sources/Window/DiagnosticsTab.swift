import Core
import SwiftUI

/// The main window's Diagnostics tab (P6.09).
///
/// Two halves, and the split matters. The **summary** is what the
/// application has actually discovered about this Mac — facts, stated
/// plainly. The **checks** are inferences, and every one of them is phrased
/// under the honesty rule: what was measured, what could explain it, what
/// to do next, and never a diagnosis.
///
/// The rule is enforced by `Core.Diagnostic`, which has no case for
/// "faulty" and refuses to raise a concern without offering an explanation
/// beside it. This view only renders what that type allows to exist.
struct DiagnosticsTab: View {
    let model: MonitorModel
    let control: ControlModel
    let setup: HelperSetupModel
    var recording: RecordingModel?
    var now: Date = Date()

    var body: some View {
        ScrollView {
            DiagnosticsContent(
                model: model, control: control, setup: setup, recording: recording,
                now: now)
        }
    }
}

struct DiagnosticsContent: View {
    let model: MonitorModel
    let control: ControlModel
    let setup: HelperSetupModel
    /// Optional so every render fixture and drill that builds this tab keeps
    /// working: without it the log access section is simply absent, which is the
    /// honest thing for a build that cannot offer it.
    var recording: RecordingModel?
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SystemSummary(model: model, setup: setup, now: now)
            Divider()

            Text(
                String(
                    localized: "diagnostics.checks", defaultValue: "Checks",
                    comment: "Heading above the diagnostic check results")
            )
            .font(.headline)

            Text(
                String(
                    localized: "diagnostics.honesty",
                    defaultValue:
                        """
                        These are observations, not verdicts. Boreas can measure what \
                        the hardware reports; it cannot see inside your Mac, so it \
                        never tells you something is faulty — it tells you what it \
                        measured and what could explain it.
                        """,
                    comment: "States plainly what the diagnostics can and cannot know")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(findings.enumerated()), id: \.offset) { _, entry in
                DiagnosticRow(title: entry.title, finding: entry.finding)
            }

            Divider()
            logAccess
            Divider()
            pendingChecks
        }
        .padding(18)
    }

    /// Log access, deferred here by P6.09 and delivered by P7.02.
    ///
    /// It reveals the folder rather than showing the contents inline, and that is
    /// the whole design: a log viewer inside the application would have to decide
    /// what to redact, and the honest answer is that the user's own tools are
    /// better at reading a file than anything built here would be. Revealing a
    /// folder needs no permission — it is theirs, and the act is theirs.
    @ViewBuilder
    private var logAccess: some View {
        if let recording {
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    String(
                        localized: "diagnostics.logs.title", defaultValue: "Recordings",
                        comment: "Heading of the recording access section in diagnostics")
                )
                .font(.callout)
                .fontWeight(.medium)

                Text(
                    String(
                        localized: "diagnostics.logs.detail",
                        defaultValue: """
                            \(recording.status.fileCount) recording file(s) on this Mac, \
                            \(recording.status.totalBytes / 1_000_000) MB. Nothing is sent \
                            anywhere; recording is switched on in Settings and off by default.
                            """,
                        comment: "Says how many recordings exist and that they stay local")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Button {
                    recording.revealInFinder()
                } label: {
                    Text(
                        String(
                            localized: "diagnostics.logs.reveal",
                            defaultValue: "Show in Finder",
                            comment: "Button opening the recordings folder from diagnostics"))
                }
            }
            .onAppear { recording.refreshStatus() }
        }
    }

    // MARK: - Running the checks

    private var findings: [(title: String, finding: Diagnostic)] {
        [
            (
                String(
                    localized: "diagnostics.check.response", defaultValue: "Fan response",
                    comment: "Diagnostic check: whether the fans follow their targets"),
                DiagnosticChecks.fanResponse(samples: control.fanResponseSamples)
            ),
            (
                String(
                    localized: "diagnostics.check.balance", defaultValue: "Fan balance",
                    comment: "Diagnostic check: whether multiple fans run together"),
                DiagnosticChecks.fanBalance(
                    speeds: model.fans.filter { !$0.isPoweredOff }.map(\.currentRPM))
            ),
            (
                String(
                    localized: "diagnostics.check.sensors", defaultValue: "Sensor validity",
                    comment: "Diagnostic check: whether the sensors report sensible values"),
                sensorValidity
            ),
            (
                String(
                    localized: "diagnostics.check.thermal", defaultValue: "Thermal history",
                    comment: "Diagnostic check: time spent under thermal pressure"),
                thermalHistory
            ),
        ]
    }

    /// A sensor counts as stuck only after enough samples to mean it: on
    /// Apple Silicon a parked cluster reports one number by design, and
    /// calling that broken after four readings would be noise.
    private var sensorValidity: Diagnostic {
        let outOfRange =
            model.allReadings
            .filter { !$0.isPlausible }
            .map(\.displayName)

        let stuck =
            model.allReadings
            .filter { reading in
                guard let stats = model.statistics[reading.id], stats.sampleCount >= 30,
                    let spread = stats.spread
                else { return false }
                return spread < 0.05
            }
            .map(\.displayName)

        return DiagnosticChecks.sensorValidity(
            outOfRange: outOfRange, stuck: stuck, totalSensors: model.allReadings.count)
    }

    private var thermalHistory: Diagnostic {
        DiagnosticChecks.thermalHistory(
            seriousSeconds: model.thermalSeconds[.serious] ?? 0,
            criticalSeconds: model.thermalSeconds[.critical] ?? 0,
            sessionSeconds: now.timeIntervalSince(model.sessionStart),
            peakCelsius: model.statistics.values.compactMap(\.maximum).max())
    }

    /// Named rather than silently missing: a diagnostics tab that quietly
    /// omitted two of the six checks would be overstating its coverage by
    /// omission, which is the same failure the honesty rule is about.
    private var pendingChecks: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                String(
                    localized: "diagnostics.pending.title", defaultValue: "Not checked yet",
                    comment: "Heading above the checks this build does not perform")
            )
            .font(.callout)
            .fontWeight(.medium)

            Text(
                String(
                    localized: "diagnostics.pending.detail",
                    defaultValue:
                        """
                        Battery health and storage health are not among the checks \
                        above. They need hardware readings this build does not take \
                        yet, and neither can be verified on the Mac this was developed \
                        on. They are listed here so their absence is visible rather \
                        than implied.
                        """,
                    comment: "Explains which diagnostic checks are missing and why")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One check: its verdict, what was measured, and — only when a concern is
/// raised — what could explain it and what to try.
struct DiagnosticRow: View {
    let title: String
    let finding: Diagnostic

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // The verdict is spelled out in words below (`verdictLabel`),
            // so the glyph and its tint are the sighted shortcut to the same
            // fact rather than the fact itself.
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(verbatim: title)
                        .fontWeight(.medium)
                    // The verdict is spelled out as well as coloured —
                    // colour never carries information alone.
                    Text(verbatim: verdictLabel)
                        .font(.caption)
                        .foregroundStyle(tint)
                }

                Text(verbatim: finding.finding.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !finding.possibleCauses.isEmpty {
                    labelledList(causesTitle, items: finding.possibleCauses.map(\.text))
                }
                if !finding.nextSteps.isEmpty {
                    labelledList(stepsTitle, items: finding.nextSteps.map(\.text))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func labelledList(_ heading: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: heading)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                Text(verbatim: "· \(item)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
    }

    private var symbol: String {
        switch finding.verdict {
        case .healthy: return "checkmark.circle"
        case .needsAttention: return "exclamationmark.circle"
        case .indeterminate: return "clock"
        case .notApplicable: return "minus.circle"
        }
    }

    /// A concern wears the warning colour, never the panic red: the product
    /// keeps red for states it is certain about, and a diagnostic is by
    /// definition not one of those.
    private var tint: Color {
        switch finding.verdict {
        case .healthy: return .secondary
        case .needsAttention: return .warningAccent
        case .indeterminate, .notApplicable: return .secondary
        }
    }

    private var verdictLabel: String {
        switch finding.verdict {
        case .healthy:
            return String(
                localized: "diagnostics.verdict.healthy", defaultValue: "nothing unusual",
                comment: "Diagnostic verdict: the check found nothing to report")
        case .needsAttention:
            return String(
                localized: "diagnostics.verdict.attention", defaultValue: "worth a look",
                comment: "Diagnostic verdict: something measurable is off")
        case .indeterminate:
            return String(
                localized: "diagnostics.verdict.indeterminate", defaultValue: "not enough evidence",
                comment: "Diagnostic verdict: the check cannot say yet")
        case .notApplicable:
            return String(
                localized: "diagnostics.verdict.notapplicable", defaultValue: "does not apply",
                comment: "Diagnostic verdict: the check cannot apply to this Mac")
        }
    }

    private var causesTitle: String {
        String(
            localized: "diagnostics.causes", defaultValue: "This could be:",
            comment: "Heading above the list of possible explanations")
    }

    private var stepsTitle: String {
        String(
            localized: "diagnostics.steps", defaultValue: "You could try:",
            comment: "Heading above the list of suggested next steps")
    }
}
