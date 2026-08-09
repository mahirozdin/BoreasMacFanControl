import Core
import SwiftUI

/// The main window's Control tab (P6.05).
///
/// The active profile **and why it is active**, the safety chain's live
/// state, the manual override with its duration picker, and which sensor
/// group each fan follows. The curve editor lands here in P6.06.
struct ControlTab: View {
    let model: MonitorModel
    let control: ControlModel
    let setup: HelperSetupModel

    var body: some View {
        ScrollView {
            ControlContent(model: model, control: control, setup: setup)
        }
    }
}

/// The Control tab's content, split from its scroll container for the same
/// reason as the monitoring tab: `ScrollView` draws nothing under
/// `ImageRenderer`, so the evidence photographs the content.
struct ControlContent: View {
    let model: MonitorModel
    let control: ControlModel
    let setup: HelperSetupModel
    /// Frozen "now" for the render evidence; live otherwise.
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProfilePickerSection(control: control, setup: setup)
            ActivationExplanation(control: control)
            Divider()
            CurveEditorSection(model: model, control: control, now: now)
            Divider()
            SafetyChainStatus(control: control)
            Divider()
            ManualOverrideSection(control: control)
            Divider()
            FanMappingSection(model: model, control: control)
        }
        .padding(18)
    }
}

/// "Why is this profile active" — the transparency the blueprint asks for
/// by name. A user who cannot tell *why* the fans changed has no way to
/// disagree with the decision.
struct ActivationExplanation: View {
    let control: ControlModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
            Text(verbatim: explanation)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var explanation: String {
        guard let outcome = control.outcome else {
            return String(
                localized: "control.why.none",
                defaultValue: "No profile is configured.",
                comment: "Shown in the control tab when there is no profile to activate")
        }
        let name = outcome.profile.displayName

        switch outcome.reason {
        case .manual(let until):
            guard let until else {
                return String(
                    localized: "control.why.manual",
                    defaultValue: "\(name) is active because you selected it.",
                    comment: "Explains that the active profile was chosen by the user")
            }
            let time = until.formatted(date: .omitted, time: .shortened)
            return String(
                localized: "control.why.manual.timed",
                defaultValue: "\(name) is active because you selected it, until \(time).",
                comment: "Explains a user-selected profile that expires at a given time")
        case .trigger(let trigger):
            return String(
                localized: "control.why.trigger",
                defaultValue: "\(name) is active because \(trigger.displayCondition).",
                comment: "Explains which trigger condition activated the profile")
        case .fallback:
            return String(
                localized: "control.why.fallback",
                defaultValue: "\(name) is active because no other profile's condition holds.",
                comment: "Explains that the default profile is active by fallback")
        }
    }
}

/// The safety chain, layer by layer, with whichever one is intervening
/// right now called out.
///
/// Every layer is listed even when nothing is happening: the guarantee the
/// product makes is that these cannot be switched off, and a list that
/// appeared only during trouble would make that guarantee invisible.
struct SafetyChainStatus: View {
    let control: ControlModel

    private struct Layer: Identifiable {
        let id: String
        let name: String
        let detail: String
        let acting: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "control.section.safety", defaultValue: "Safety chain",
                    comment: "Heading of the safety chain status list in the control tab")
            )
            .font(.headline)

            ForEach(layers) { layer in
                HStack(spacing: 8) {
                    Image(systemName: layer.acting ? "exclamationmark.circle.fill" : "checkmark.shield")
                        .foregroundStyle(layer.acting ? Color.panicAccent : Color.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: layer.name)
                            .font(.callout)
                        Text(verbatim: layer.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(verbatim: layer.acting ? actingText : armedText)
                        .font(.caption)
                        .fontWeight(layer.acting ? .semibold : .regular)
                        .foregroundStyle(layer.acting ? Color.panicAccent : Color.secondary)
                }
            }
        }
    }

    private var actingText: String {
        String(
            localized: "control.safety.acting", defaultValue: "acting now",
            comment: "Status of a safety chain layer that is currently overriding the output")
    }

    private var armedText: String {
        String(
            localized: "control.safety.armed", defaultValue: "armed",
            comment: "Status of a safety chain layer that is active but not intervening")
    }

    /// Built apart from the list because `defaultValue` takes a single
    /// localisation literal — the range's two bounds have to be in scope
    /// before the string, not concatenated into it.
    private var watchdogDetail: String {
        let low = Int(WatchdogPolicy.allowedTimeout.lowerBound)
        let high = Int(WatchdogPolicy.allowedTimeout.upperBound)
        return String(
            localized: "control.safety.k5.detail",
            defaultValue: "No heartbeat for \(low) to \(high) seconds hands the fans back.",
            comment: "What safety chain layer K5 does, with the permitted timeout range")
    }

    private var layers: [Layer] {
        let active = control.activeLayer
        return [
            Layer(
                id: "K1",
                name: String(
                    localized: "control.safety.k1", defaultValue: "K1 — Fan floor",
                    comment: "Safety chain layer K1"),
                detail: String(
                    localized: "control.safety.k1.detail",
                    defaultValue: "Output never goes below the hardware minimum.",
                    comment: "What safety chain layer K1 does"),
                acting: false),
            Layer(
                id: "K2",
                name: String(
                    localized: "control.safety.k2", defaultValue: "K2 — Thermal state",
                    comment: "Safety chain layer K2"),
                detail: String(
                    localized: "control.safety.k2.detail",
                    defaultValue: "Serious raises the floor to 55%, critical forces 100%.",
                    comment: "What safety chain layer K2 does"),
                acting: active == .thermalSerious || active == .thermalCritical),
            Layer(
                id: "K3",
                name: String(
                    localized: "control.safety.k3", defaultValue: "K3 — Panic threshold",
                    comment: "Safety chain layer K3"),
                detail: String(
                    localized: "control.safety.k3.detail",
                    defaultValue:
                        "Above \(Int(PanicThreshold.defaultCelsius)) °C: full speed, held for 30 seconds.",
                    comment: "What safety chain layer K3 does, with the threshold temperature"),
                acting: active == .panic),
            Layer(
                id: "K4",
                name: String(
                    localized: "control.safety.k4", defaultValue: "K4 — Helper guard",
                    comment: "Safety chain layer K4"),
                detail: String(
                    localized: "control.safety.k4.detail",
                    defaultValue: "The helper refuses any speed the hardware does not accept.",
                    comment: "What safety chain layer K4 does"),
                acting: false),
            Layer(
                id: "K5",
                name: String(
                    localized: "control.safety.k5", defaultValue: "K5 — Watchdog",
                    comment: "Safety chain layer K5"),
                detail: watchdogDetail,
                acting: false),
        ]
    }
}
