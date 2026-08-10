import Core
import Foundation
import Observation
import SwiftUI
import os

/// Watches the running application and turns state *changes* into notification
/// events (P7.01).
///
/// **Edges, not levels.** Every trigger here fires on a transition, not on a
/// condition: the thermal state *becoming* serious, the panic layer *engaging*,
/// the profile *changing*. A level-triggered version would hand the policy the
/// same event on every two-second cycle and rely on the suppression window to
/// hide the flood — which works right up until somebody shortens the window to
/// one minute and gets a notification every minute for an hour.
///
/// The policy is still there, and still necessary: an edge can oscillate. But
/// the two mechanisms answer different problems, and conflating them is how a
/// notification system becomes a thing users switch off.
@MainActor
@Observable
final class NotificationModel {

    private(set) var authorization: NotificationAuthorization = .notAsked

    /// What the last batch decided, for the settings tab and the drill. Kept so
    /// the interface can be honest about a notification the user never saw:
    /// "held back by quiet hours" is a better answer than silence.
    private(set) var lastWithheld: [NotificationDecision.Withheld] = []

    private var policy = NotificationPolicy()
    private let sink: any NotificationSink
    private let store: ConfigurationStore?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "notifications")

    /// A level that has to be *seen* before an edge can be read off it.
    ///
    /// The four detectors below all did the same seed-then-compare dance with a
    /// plain optional, and for `Bool` the lint rule objected — correctly, since
    /// `Bool?` has three states and only two of them mean anything. Naming the
    /// pattern removes the repetition and says what the third state is: not that
    /// the value is unknown, but that **nothing has been observed yet**, and a
    /// first observation is never an edge. Launching a machine that is already
    /// hot must not announce a transition that did not happen.
    private struct Level<Value: Equatable> {
        private var seen: Value?

        /// Records `value` and returns the value it replaced — `nil` on the very
        /// first call, which is what makes the first observation silent.
        mutating func advance(to value: Value) -> Value? {
            defer { seen = value }
            return seen
        }
    }

    private var thermalLevel = Level<ThermalPressure>()
    private var panicLevel = Level<Bool>()
    private var profileLevel = Level<String>()
    private var helperLevel = Level<Bool>()
    private var thresholdsAbove: Set<SensorGroup> = []

    /// What a threshold crossing was really about, keyed by the *localised*
    /// subject the event carries — see `stableSubject(for:subject:)` for why the
    /// two have to be kept apart.
    private var thresholdFacts: [String: (identifier: String, celsius: Double)] = [:]

    init(
        sink: any NotificationSink = LiveNotificationSink(),
        store: ConfigurationStore? = nil,
        fixedAuthorizationForRendering: NotificationAuthorization? = nil
    ) {
        self.sink = sink
        self.store = store
        // Named like `fixedInstallerStateForRendering`, and needed for the same
        // reason: `refreshAuthorization` is asynchronous, so the camera
        // photographs the view before the answer arrives and every variant
        // comes out in the `notAsked` state. Two render fixtures that look
        // identical are not two pieces of evidence — the P6.12 `--render-a11y`
        // command was deleted for exactly that.
        if let fixedAuthorizationForRendering {
            authorization = fixedAuthorizationForRendering
        }
    }

    private var settings: NotificationSettings {
        store?.configuration.notifications ?? NotificationSettings()
    }

    private var automationSettings: AutomationSettings {
        store?.configuration.automation ?? AutomationSettings()
    }

    /// The automation hooks (P7.10). Held here because hooks fire on the same
    /// decision notifications do — see `deliver(_:now:)` for why that is the
    /// right seam, and for the one place the two deliberately part company.
    let automation = AutomationRunner()

    /// Reads the permission the system already holds, without asking for it.
    func refreshAuthorization() {
        Task { [sink] in
            let state = await sink.authorizationState()
            await MainActor.run { self.authorization = state }
        }
    }

    /// Asks for the permission — **only** from the switch in the settings tab.
    ///
    /// Called at the moment the user turns notifications on, never at launch.
    /// If they refuse, the switch goes back off rather than staying on and
    /// delivering nothing: a control that claims to be enabled while the system
    /// says otherwise is the dishonesty the whole project is built against.
    func enableAndRequestPermission() {
        Task { [sink] in
            let state = await sink.requestAuthorization()
            await MainActor.run {
                self.authorization = state
                if state != .granted {
                    self.store?.update { $0.notifications.isEnabled = false }
                }
            }
        }
    }

    /// One observation of the running system. Called from the monitor's cycle.
    func observe(monitor: MonitorModel, control: ControlModel, now: Date = Date()) {
        var events: [NotificationEvent] = []
        events.append(contentsOf: thermalEvents(monitor.thermal))
        events.append(contentsOf: panicEvents(control))
        events.append(contentsOf: profileEvents(control))
        events.append(contentsOf: helperEvents(control))
        events.append(contentsOf: thresholdEvents(monitor))
        if !events.isEmpty {
            deliver(events, now: now)
        }
        // Separate call rather than folded in: the health checks are level
        // triggered and deduplicated by the once-per-session rule, while
        // everything above is edge triggered. Mixing the two in one batch would
        // make the distinction invisible to whoever reads this next.
        observeHealth(monitor: monitor, control: control, now: now)
    }

    /// The two hardware health triggers, connected in P7.03.
    ///
    /// P7.01 shipped them wired and **inert**, because nothing produced the
    /// findings yet — and said so. Both now run the real `Core` checks over the
    /// same readings the diagnostics tab uses, so a notification and the tab can
    /// never disagree about whether something is worth a look.
    ///
    /// Both kinds are once-per-session by `NotificationKind.isOncePerSession`,
    /// which is what makes it safe to call this on every cycle: a fan that is not
    /// tracking its targets will still not be tracking them in fifteen minutes,
    /// and the policy already refuses to say so twice.
    func observeHealth(monitor: MonitorModel, control: ControlModel, now: Date = Date()) {
        var events: [NotificationEvent] = []

        if DiagnosticChecks.fanResponse(samples: control.fanResponseSamples).verdict
            == .needsAttention
        {
            events.append(NotificationEvent(kind: .fanAnomaly))
        }
        if DiagnosticChecks.batteryHealth(monitor.batteryReading).verdict == .needsAttention {
            events.append(NotificationEvent(kind: .batteryHealth))
        }
        guard !events.isEmpty else { return }
        deliver(events, now: now)
    }

    // MARK: - Edges

    private func thermalEvents(_ thermal: ThermalPressure) -> [NotificationEvent] {
        guard let previous = thermalLevel.advance(to: thermal) else { return [] }
        // Rising into serious or critical only. Falling back is good news, and
        // good news does not need to interrupt anybody.
        let raised: Set<ThermalPressure> = [.serious, .critical]
        guard raised.contains(thermal), !raised.contains(previous) else { return [] }
        return [NotificationEvent(kind: .thermalState, subject: thermal.rawValue)]
    }

    private func panicEvents(_ control: ControlModel) -> [NotificationEvent] {
        let engaged = control.activeLayer == .panic
        guard let previous = panicLevel.advance(to: engaged), engaged, !previous else { return [] }
        return [NotificationEvent(kind: .panicEngaged)]
    }

    private func profileEvents(_ control: ControlModel) -> [NotificationEvent] {
        guard let name = control.outcome?.profile.displayName else { return [] }
        guard let previous = profileLevel.advance(to: name), name != previous else { return [] }
        return [NotificationEvent(kind: .profileChanged, subject: name)]
    }

    /// The helper going away — a dropped connection or the watchdog handing the
    /// fans back. Both mean the same thing to the user, and G4 says it is the
    /// correct outcome rather than a failure, which is what the wording says.
    private func helperEvents(_ control: ControlModel) -> [NotificationEvent] {
        let reachable = control.state == .controlling || control.state == .panic
        guard let previous = helperLevel.advance(to: reachable), previous, !reachable
        else { return [] }
        // Only when it was not the user's own doing: selecting System is a hand
        // on the wheel, not a loss of control.
        guard control.lastProblem != nil else { return [] }
        return [NotificationEvent(kind: .daemonLost)]
    }

    /// User thresholds, per sensor group.
    ///
    /// Hysteresis by construction: a group has to fall **two degrees** below its
    /// threshold before it can announce crossing it again. Without that a sensor
    /// sitting exactly on the line produces an edge on every cycle, and the
    /// suppression window would be doing the work a threshold should do itself.
    private func thresholdEvents(_ monitor: MonitorModel) -> [NotificationEvent] {
        guard let store else { return [] }
        var events: [NotificationEvent] = []
        for (group, readings) in monitor.grouped.map({ ($0.group, $0.readings) }) {
            guard let threshold = store.configuration.notifications.thresholds[group],
                let hottest = readings.map(\.celsius).max()
            else { continue }
            let wasAbove = thresholdsAbove.contains(group)
            if hottest >= threshold, !wasAbove {
                thresholdsAbove.insert(group)
                // Recorded beside the event: the event carries the localised
                // name a person reads, automation needs the stable one and the
                // number (P7.10).
                thresholdFacts[group.displayName] = (group.rawValue, hottest)
                events.append(NotificationEvent(kind: .thresholdCrossed, subject: group.displayName))
            } else if wasAbove, hottest < threshold - Self.thresholdReleaseCelsius {
                thresholdsAbove.remove(group)
                thresholdFacts.removeValue(forKey: group.displayName)
            }
        }
        return events
    }

    /// How far a group has to fall below its threshold before it can cross it
    /// again. Two degrees is the smallest gap that survives ordinary sensor
    /// noise on this hardware, measured in the P6.09 diagnostics work.
    private static let thresholdReleaseCelsius: Double = 2

    // MARK: - Automation

    /// One hook run per delivered notification (P7.10).
    ///
    /// A coalesced delivery carries several subjects; each becomes its own
    /// context, because a script is given one thing to act on rather than a
    /// sentence to parse. `celsius` is filled only where the event is about a
    /// temperature — an absent value expands to empty, which
    /// `AutomationTemplate` distinguishes from a mistyped placeholder.
    private func fireAutomation(for deliveries: [NotificationDecision.Delivery], now: Date) {
        let settings = automationSettings
        guard !settings.runnable().isEmpty else { return }

        var contexts: [AutomationContext] = []
        for delivery in deliveries {
            if delivery.subjects.isEmpty {
                contexts.append(AutomationContext(kind: delivery.kind, timestamp: now))
            } else {
                for subject in delivery.subjects {
                    contexts.append(
                        AutomationContext(
                            kind: delivery.kind,
                            subject: stableSubject(for: delivery.kind, subject: subject),
                            celsius: temperature(for: delivery.kind, subject: subject),
                            timestamp: now))
                }
            }
        }

        let runner = automation
        Task { [contexts, settings] in
            for context in contexts {
                await runner.fire(context, settings: settings)
            }
        }
    }

    /// The temperature a threshold crossing was about. `nil` for every other
    /// kind: a profile change has no temperature, and inventing one would be
    /// worse than leaving the placeholder empty.
    private func temperature(for kind: NotificationKind, subject: String) -> Double? {
        guard kind == .thresholdCrossed else { return nil }
        return thresholdFacts[subject]?.celsius
    }

    /// The **stable** name for a subject, for a payload a script will parse.
    ///
    /// A threshold crossing's subject is the sensor group's *localised* display
    /// name, which is right for a notification a person reads and wrong for a
    /// webhook: under a translated interface `${sensor}` would arrive as the
    /// translated group name, and a script matching `compute` would break the
    /// day somebody changed the interface language. That is exactly the defect P7.14 found in the CLI —
    /// a decision value that moves with the display language — and it is not
    /// shipping again here. Every other kind's subject is already stable: a
    /// profile name is the user's own text, a fan is a number.
    private func stableSubject(for kind: NotificationKind, subject: String) -> String {
        guard kind == .thresholdCrossed else { return subject }
        return thresholdFacts[subject]?.identifier ?? subject
    }

    // MARK: - Delivery

    private func deliver(_ events: [NotificationEvent], now: Date) {
        let decision = policy.decide(on: events, settings: settings, now: now)
        lastWithheld = decision.withheld

        for withheld in decision.withheld {
            // Both values are `.public` deliberately: a kind and a reason are
            // this application's own vocabulary, never anything about the user
            // (P3 — no personal data in a log line).
            let kind = withheld.event.kind.rawValue
            let reason = withheld.reason.rawValue
            logger.debug(
                "notification withheld: \(kind, privacy: .public) (\(reason, privacy: .public))")
        }
        guard !decision.deliver.isEmpty else { return }

        // Automation fires here, and **before the authorization check on
        // purpose** (P7.10). A webhook is not a notification: requiring the
        // system's notification permission before this application may reach
        // somebody's monitoring endpoint would break exactly the headless
        // remote machine [ADR 0015](../../../docs/architecture/adr/0015-automation-hooks-not-email.md)
        // exists for, where nobody is present to grant anything.
        //
        // It fires on the *decision* rather than on raw events, so P7.01's
        // whole noise-control chain applies to hooks too and there is one place
        // to configure it. Quiet hours therefore silence a webhook — acceptable
        // because the panic survives all five mechanisms, so the event meaning
        // "this Mac is in trouble" always gets through.
        fireAutomation(for: decision.deliver, now: now)

        // The permission is checked here rather than in the policy: whether the
        // user granted it is a fact about the system, not a decision about
        // noise, and `Core` has no business knowing about permissions.
        guard authorization == .granted else {
            logger.debug("notification not delivered: no authorization")
            return
        }

        for delivery in decision.deliver {
            let title = delivery.title
            let body = delivery.body
            let identifier = delivery.identifier
            Task { [sink] in
                await sink.deliver(title: title, body: body, identifier: identifier)
            }
        }
    }
}
