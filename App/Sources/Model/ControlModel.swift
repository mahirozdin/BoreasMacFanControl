import Core
import Foundation
import OSLog
import Observation
import SharedIPC

/// Drives the fans — from the profile engine or from the manual drill duty —
/// with the safety chain always in the path and the state machine always in
/// charge.
///
/// P4.08 built this as the manual-control scaffold and promised that the P5
/// engine would replace the *source* of the requested duty while the cycle —
/// govern, transition, apply, heartbeat — stayed. P6.02 keeps that promise:
/// the menu bar profile picker feeds `select(profileName:until:)`, arbitration
/// chooses the active profile, and `Engine.step` produces the targets. The
/// manual path remains for the hardware drills (`--control-drill`, `make
/// smoke`), which prove the plumbing without involving the engine.
///
/// Every state transition goes through `ControlStateMachine` and is logged
/// (P4.09). A transition the table refuses is logged as an error and not
/// taken — the machine does not bend.
@MainActor
@Observable
public final class ControlModel {

    /// What produces the requested duty while the loop runs.
    private enum Source {
        /// The P4.08 slider / drill value, one duty for every fan.
        case manualDuty
        /// The P5 engine: arbitration picks a profile, `Engine.step` runs.
        case engine
    }

    public private(set) var state: ControlState = .monitoring
    public private(set) var activeLayer: SafetyLayer?
    public private(set) var lastProblem: String?

    /// The configuration this model reads its profiles and safety limits
    /// from, when there is one.
    ///
    /// Optional on purpose: the hardware drills and the render fixtures
    /// build a `ControlModel` too, and a drill that edited a profile would
    /// otherwise write its test curve into the owner's real configuration
    /// file. Without a store the profiles live in memory, which is exactly
    /// what a measuring instrument wants.
    ///
    /// Module-internal rather than private: profile editing lives in
    /// `ControlProfileEditing.swift` so this file stays inside the lint
    /// budget, and `private` is file scoped.
    let store: ConfigurationStore?

    /// The profiles in arbitration order — from the configuration file when
    /// there is one, the built-ins otherwise.
    public internal(set) var profiles: [Profile] = BuiltInProfiles.all()

    /// The user's explicit choice. Starts as `System` — firmware in charge —
    /// so launching the app never takes the fans over by itself; automatic
    /// engagement policy belongs to the configuration work, not to launch.
    /// Modelled as an ordinary manual selection through arbitration rather
    /// than a special "off" flag, the same way `System` itself is data.
    public private(set) var manualSelection: ManualSelection? =
        ManualSelection(profileName: "System")

    /// The arbitration outcome the interface shows: which profile is active
    /// and why. Recomputed on every selection and every engine cycle.
    public private(set) var outcome: Arbitration.Outcome?

    /// The slider's value. Raw `Double` because SwiftUI binds to it; it
    /// becomes a clamped `Duty` at the moment of use, never before.
    public var manualDuty: Double = 0.35

    /// When a manual duty override gives way to the engine again, or `nil`
    /// for "until further notice". The blueprint's own example is "back to
    /// automatic in 30 minutes".
    public private(set) var dutyOverrideUntil: Date?

    /// Whether the slider, rather than the engine, is deciding right now.
    public var isDutyOverridden: Bool { source == .manualDuty }

    public var isEngaged: Bool {
        state == .controlling || state == .panic
    }

    private var source: Source = .engine
    private var engineState: Engine.State = .initial
    private var lastStepAt: Date?
    private let monitor: MonitorModel
    private var client: HelperClient?
    private var panicLock = PanicLock.released
    private var loop: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "control")

    /// How often targets are re-evaluated and re-applied. Matches the
    /// monitor's sampling cadence.
    private let cycleInterval: Duration = .seconds(2)

    public init(monitor: MonitorModel, store: ConfigurationStore? = nil) {
        self.monitor = monitor
        self.store = store
        if let store {
            profiles = store.configuration.profiles
        }
        refreshOutcome()
    }

    /// Re-reads the profiles after the configuration changed underneath —
    /// an import, a reset, or a settings edit.
    public func reloadFromConfiguration() {
        guard let store else { return }
        profiles = store.configuration.profiles
        refreshOutcome()
        reconcile()
    }

    /// Render support (`--render-panel`): freezes the model in a given
    /// presentation state without ever touching the helper. The outcome is
    /// produced by real arbitration on the given selection, so the render
    /// cannot show a combination arbitration would never produce.
    init(
        fixedForRendering monitor: MonitorModel,
        selection: ManualSelection,
        state: ControlState,
        layer: SafetyLayer?
    ) {
        self.monitor = monitor
        self.store = nil
        self.manualSelection = selection
        self.state = state
        self.activeLayer = layer
        refreshOutcome()
    }

    // MARK: - Profile selection (P6.02)

    /// The menu bar picker's entry point: an explicit, possibly time-limited
    /// profile choice. Selecting a driving profile starts the engine loop;
    /// selecting `System` (or letting a timed override expire into it)
    /// releases the fans to firmware.
    public func select(profileName: String, until: Date? = nil) {
        guard profiles.contains(where: { $0.name == profileName }) else {
            logger.error("unknown profile selected: \(profileName, privacy: .public)")
            return
        }
        manualSelection = ManualSelection(profileName: profileName, until: until)
        refreshOutcome()
        reconcile()
    }

    // MARK: - Manual duty override (P6.05)

    /// Hands the requested duty to the slider instead of the engine, for a
    /// while.
    ///
    /// Expiry returns control to the *engine*, not to the firmware: the
    /// user asked to take the wheel for half an hour, not to stop cooling
    /// afterwards. The safety chain is in the path either way, so an
    /// override can raise the fans but never hold them below what K1–K3
    /// demand.
    public func overrideDuty(_ duty: Double, until: Date?) {
        manualDuty = duty
        dutyOverrideUntil = until
        source = .manualDuty
        if state == .monitoring {
            engage(source: .manualDuty)
        }
    }

    /// Gives the engine back the wheel. If the active profile pauses the
    /// engine, the loop releases to firmware instead of idling engaged.
    public func clearDutyOverride() {
        dutyOverrideUntil = nil
        source = .engine
        refreshOutcome()
        reconcile()
    }

    /// Recomputes the arbitration outcome for display and engagement
    /// decisions. Cheap and pure — safe to call every cycle.
    func refreshOutcome() {
        outcome = Arbitration.activeProfile(
            among: profiles,
            manual: manualSelection,
            environment: currentEnvironment(),
            defaultName: store?.configuration.defaultProfileName ?? BuiltInProfiles.defaultName,
            now: Date()
        )
    }

    /// Starts or stops the engine loop so it matches what arbitration wants.
    /// The manual drill path is never started or stopped from here.
    private func reconcile() {
        let wantsEngine = !(outcome?.profile.enginePaused ?? true)
        switch (wantsEngine, state) {
        case (true, .monitoring):
            engage(source: .engine)
        case (false, .controlling), (false, .panic):
            if source == .engine { disengage() }
        default:
            break
        }
    }

    /// What the triggers can see right now. Foreground application and
    /// display sensing arrive with the settings that let users bind them
    /// (P6.08); the built-ins need none of them.
    private func currentEnvironment() -> ProfileTrigger.Environment {
        let now = Date()
        let calendar = Calendar.current
        let minute =
            calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return ProfileTrigger.Environment(
            power: monitor.power,
            minuteOfDay: minute,
            thermal: ThermalPressure(ProcessInfo.processInfo.thermalState)
        )
    }

    // MARK: - Loop control

    /// Turns manual (drill) control on. No-op unless currently monitoring.
    /// The panel no longer calls this; `--control-drill` and `make smoke` do.
    public func engage() {
        engage(source: .manualDuty)
    }

    private func engage(source: Source) {
        guard state == .monitoring, loop == nil else { return }
        self.source = source
        lastProblem = nil
        loop = Task { [weak self] in
            await self?.run()
        }
    }

    /// Turns control off. The loop notices, releases, and the state machine
    /// walks releasing → monitoring.
    public func disengage() {
        transition(on: .releaseRequested)
        loop?.cancel()
    }

    private func run() async {
        let client = HelperClient()
        self.client = client

        do {
            guard try await client.ping() else {
                throw HelperClient.ClientError.rejected("nonce mismatch")
            }
            // The helper builds its K4 limits from this call — describing
            // the fans is the handshake that arms the safety filter, and
            // applying targets before it is refused by design.
            let described = try await client.describeFans()
            guard !described.isEmpty else {
                throw HelperClient.ClientError.rejected("the helper sees no controllable fan")
            }
            await client.beginHeartbeats()
            transition(on: .controlEngaged)

            while !Task.isCancelled, isEngaged {
                await cycle(client)
                try? await Task.sleep(for: cycleInterval)
            }
        } catch {
            lastProblem = String(describing: error)
            logger.error("control loop failed: \(String(describing: error), privacy: .public)")
            transition(on: .releaseRequested)
        }

        // Always through the same exit, whatever ended the loop.
        await client.endHeartbeats()
        do {
            try await client.releaseToFirmware()
        } catch {
            // The daemon's own layers (invalidation, watchdog) still stand
            // behind this; the failure is recorded, not hidden.
            lastProblem = String(describing: error)
            logger.error("release failed: \(String(describing: error), privacy: .public)")
        }
        transition(on: .released)
        activeLayer = nil
        engineState = .initial
        lastStepAt = nil
        self.client = nil
        loop = nil

        // A selection made while this release was still running could not
        // start a loop (the machine refuses monitoring-only transitions), so
        // it is honoured now. Only on a clean exit: after a failure the user
        // re-selects deliberately — an automatic retry here would be a tight
        // engage/fail loop against a helper that just said no.
        if lastProblem == nil { reconcile() }
    }

    private func cycle(_ client: HelperClient) async {
        let fans = monitor.fans
        guard !fans.isEmpty else { return }

        // A timed override ends here rather than on a timer of its own: the
        // loop is already the thing that ticks, and an expiry that can only
        // be noticed while the fans are being driven is an expiry that can
        // never be missed.
        if source == .manualDuty, let until = dutyOverrideUntil, Date() >= until {
            logger.notice("manual duty override expired, returning to the engine")
            clearDutyOverride()
        }

        let targets: [FanTarget]
        switch source {
        case .manualDuty:
            targets = manualTargets(fans: fans)
        case .engine:
            guard let stepped = engineTargets(fans: fans) else {
                // Arbitration moved to a paused profile (a timed override
                // expired, or the user picked System mid-cycle): leave
                // through the normal release exit.
                transition(on: .releaseRequested)
                loop?.cancel()
                return
            }
            targets = stepped
        }

        if activeLayer == .panic, state == .controlling {
            transition(on: .panicRaised)
        } else if activeLayer != .panic, state == .panic {
            transition(on: .panicCleared)
        }

        do {
            let outcome = try await client.requestTargets(
                fanIDs: targets.map(\.fanID),
                targetRPM: targets.map(\.rpm)
            )
            if !outcome.accepted {
                // The daemon's K4 refusing a target the app computed means a
                // bug on one of the two sides. Stop driving and say so.
                lastProblem = outcome.reason
                logger.error(
                    "daemon refused targets: \(outcome.reason ?? "-", privacy: .public)")
                transition(on: .releaseRequested)
                loop?.cancel()
            }
        } catch {
            lastProblem = String(describing: error)
            logger.error("apply failed: \(String(describing: error), privacy: .public)")
            transition(on: .releaseRequested)
            loop?.cancel()
        }
    }

    /// The P4.08 path: one governed duty for every fan.
    private func manualTargets(fans: [FanState]) -> [FanTarget] {
        let verdict = SafetyChain.govern(
            requested: Duty(manualDuty),
            thermal: ThermalPressure(ProcessInfo.processInfo.thermalState),
            // Hidden sensors included, for the same reason as above.
            hottestCelsius: monitor.allReadings.map(\.celsius).max(),
            lock: panicLock,
            now: Date()
        )
        panicLock = verdict.lock
        activeLayer = verdict.activeLayer
        return fans.map { FanTarget(fanID: $0.id, rpm: verdict.duty.rpm(for: $0)) }
    }

    /// The P6.02 path: arbitration picks the profile, `Engine.step` runs the
    /// documented pipeline. Returns `nil` when the active profile pauses the
    /// engine — the caller releases.
    private func engineTargets(fans: [FanState]) -> [FanTarget]? {
        refreshOutcome()
        guard let profile = outcome?.profile, !profile.enginePaused else { return nil }

        let now = Date()
        // `allReadings`, not `readings`: a sensor the user hid is still
        // read, still counted by its group's aggregate and still able to
        // trigger the panic layer. Hiding is a display choice, and the
        // safety chain does not take display choices.
        let readingsByGroup = Dictionary(grouping: monitor.allReadings, by: \.group)
            .mapValues { $0.map(\.celsius) }
        let input = Engine.Input(
            profile: profile,
            fans: fans,
            readingsByGroup: readingsByGroup,
            thermal: ThermalPressure(ProcessInfo.processInfo.thermalState),
            // K3's threshold comes from the configuration; the type clamps
            // it into [70, 95] whatever the file says (G2, ADR 0022).
            panicThreshold: store?.configuration.safety.panicThreshold ?? .standard,
            now: now,
            elapsedSeconds: lastStepAt.map { now.timeIntervalSince($0) } ?? 0
        )
        lastStepAt = now

        let cycle = Engine.step(input, state: engineState)
        engineState = cycle.state
        panicLock = cycle.state.panicLock
        activeLayer = cycle.activeLayer
        return cycle.targets
    }

    private func transition(on event: ControlEvent) {
        guard let next = ControlStateMachine.next(from: state, on: event) else {
            let refusal = "\(state.rawValue) on \(event.rawValue)"
            logger.error("refused transition: \(refusal, privacy: .public)")
            return
        }
        if next != state {
            // P4.09: every taken transition is logged.
            let move = "\(state.rawValue) -> \(next.rawValue) (\(event.rawValue))"
            logger.notice("control state: \(move, privacy: .public)")
        }
        state = next
    }
}
