import Core
import Foundation
import OSLog
import Observation
import SharedIPC

/// Drives the fans at a user-chosen duty, with the safety chain always in
/// the path and the state machine always in charge.
///
/// This is the manual-control scaffold of P4.08: one duty for all fans. The
/// curve engine of P5 will replace the *source* of the requested duty; the
/// cycle below — govern, transition, apply, heartbeat — is the shape the
/// engine inherits.
///
/// Every state transition goes through `ControlStateMachine` and is logged
/// (P4.09). A transition the table refuses is logged as an error and not
/// taken — the machine does not bend.
@MainActor
@Observable
public final class ControlModel {

    public private(set) var state: ControlState = .monitoring
    public private(set) var activeLayer: SafetyLayer?
    public private(set) var lastProblem: String?

    /// The slider's value. Raw `Double` because SwiftUI binds to it; it
    /// becomes a clamped `Duty` at the moment of use, never before.
    public var manualDuty: Double = 0.35

    public var isEngaged: Bool {
        state == .controlling || state == .panic
    }

    private let monitor: MonitorModel
    private var client: HelperClient?
    private var panicLock = PanicLock.released
    private var loop: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "control")

    /// How often targets are re-evaluated and re-applied. Matches the
    /// monitor's sampling cadence; the P5 engine may tighten it.
    private let cycleInterval: Duration = .seconds(2)

    public init(monitor: MonitorModel) {
        self.monitor = monitor
    }

    /// Turns manual control on. No-op unless currently monitoring.
    public func engage() {
        guard state == .monitoring, loop == nil else { return }
        lastProblem = nil
        loop = Task { [weak self] in
            await self?.run()
        }
    }

    /// Turns manual control off. The loop notices, releases, and the state
    /// machine walks releasing → monitoring.
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
        self.client = nil
        loop = nil
    }

    private func cycle(_ client: HelperClient) async {
        let fans = monitor.fans
        guard !fans.isEmpty else { return }

        let verdict = SafetyChain.govern(
            requested: Duty(manualDuty),
            thermal: ThermalPressure(ProcessInfo.processInfo.thermalState),
            hottestCelsius: monitor.hottest?.celsius,
            lock: panicLock,
            now: Date()
        )
        panicLock = verdict.lock
        activeLayer = verdict.activeLayer

        if verdict.activeLayer == .panic, state == .controlling {
            transition(on: .panicRaised)
        } else if verdict.activeLayer != .panic, state == .panic {
            transition(on: .panicCleared)
        }

        do {
            let outcome = try await client.requestTargets(
                fanIDs: fans.map(\.id),
                targetRPM: fans.map { verdict.duty.rpm(for: $0) }
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
