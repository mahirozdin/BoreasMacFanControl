import Core
import Foundation
import HardwareKit
import OSLog
import SharedIPC
import os

/// Implements the four method surface the application talks to.
///
/// Everything privileged this project does happens in this file and the two
/// beside it. That is the point of the split: curves, profiles and hysteresis
/// all run unprivileged, and this stays small enough to read in one sitting.
///
/// State is guarded by a lock rather than by an actor, because XPC requires an
/// `NSObject` subclass and those cannot be actors. Only two fields are guarded,
/// and the hardware reader is immutable, so nothing is ever locked across an
/// `await`.
final class FanControlService: NSObject, FanControlProtocol, @unchecked Sendable {

    private struct State {
        var governor: SafetyGovernor?
        var isControlling = false
        var lastReleaseSucceeded = true
    }

    private let logger = Logger(subsystem: "com.bubiapps.boreas.fanhelper", category: "service")
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Created once. Immutable, so the async read path needs no lock at all.
    private let fanReader: LiveFanSource?
    /// The write path. Nil when the SMC cannot be opened; every apply then
    /// fails loudly instead of pretending.
    private let actuator: LiveFanActuator?
    private var watchdog: Watchdog?

    /// Called after the watchdog has released control because the client fell
    /// silent. Set once by the composition root, before the listener resumes;
    /// it uses this to exit so launchd can relaunch the helper on demand.
    var onWatchdogExpiry: (@Sendable () -> Void)?

    override init() {
        fanReader = try? LiveFanSource()
        actuator = try? LiveFanActuator()
        super.init()
        // The timeout is derived from the shared heartbeat cadence, not typed
        // here as a number: 5 s beats, released after 3 misses. The policy
        // clamps the product into the 10-60 s range whatever the constants say.
        let policy = WatchdogPolicy(
            heartbeatIntervalSeconds: BoreasIPC.heartbeatIntervalSeconds,
            missedHeartbeatsBeforeRelease: BoreasIPC.missedHeartbeatsBeforeRelease
        )
        watchdog = Watchdog(policy: policy) { [weak self] in
            self?.logger.error("watchdog expired")
            self?.performRelease()
            self?.onWatchdogExpiry?()
        }
        if fanReader == nil {
            logger.error("fan interface unavailable at launch")
        }
    }

    // MARK: - FanControlProtocol

    func describeFans(
        reply: @escaping @Sendable ([NSNumber], [NSNumber], [NSNumber], [NSNumber]) -> Void
    ) {
        Task { [weak self] in
            guard let self else { return reply([], [], [], []) }
            let fans = await self.readFans()

            let limits = fans.map {
                SafetyGovernor.Limits(
                    id: $0.id, minimumRPM: $0.minimumRPM, maximumRPM: $0.maximumRPM
                )
            }
            self.state.withLock { $0.governor = SafetyGovernor(limits: limits) }

            reply(
                fans.map { NSNumber(value: $0.id) },
                fans.map { NSNumber(value: $0.minimumRPM) },
                fans.map { NSNumber(value: $0.maximumRPM) },
                fans.map { NSNumber(value: $0.currentRPM) }
            )
        }
    }

    func applyTargets(
        fanIDs: [NSNumber],
        targetRPM: [NSNumber],
        reply: @escaping @Sendable (Bool, String?) -> Void
    ) {
        guard fanIDs.count == targetRPM.count else {
            return reply(false, "fan identifiers and targets must be the same length")
        }
        guard !fanIDs.isEmpty else {
            return reply(false, "no targets given")
        }

        let currentGovernor = state.withLock { $0.governor }
        guard let currentGovernor else {
            return reply(false, "call describeFans before applying targets")
        }

        // The whole batch is checked before any of it is applied. A partly
        // applied batch would leave the fans in a state neither side asked for.
        for (index, identifier) in fanIDs.enumerated() {
            let verdict = currentGovernor.evaluate(
                fanID: identifier.intValue,
                requestedRPM: targetRPM[index].intValue
            )
            if case .rejected(let reason) = verdict {
                logger.error("rejected target: \(reason, privacy: .public)")
                return reply(false, reason)
            }
        }

        guard let actuator else {
            return reply(false, "the fan interface is unavailable on this machine")
        }

        let targets = fanIDs.enumerated().map { index, identifier in
            FanTarget(fanID: identifier.intValue, rpm: targetRPM[index].intValue)
        }

        do {
            try actuator.applyNow(targets)
        } catch {
            // A half-applied batch must not survive: hand back whatever was
            // taken over, then tell the caller the truth.
            do {
                try actuator.releaseNow()
            } catch {
                logger.fault(
                    "release after a failed apply also failed: \(String(describing: error), privacy: .public)"
                )
            }
            logger.error("apply failed: \(String(describing: error), privacy: .public)")
            return reply(false, String(describing: error))
        }

        state.withLock { $0.isControlling = true }
        watchdog?.start()
        logger.notice("driving \(targets.count, privacy: .public) fan(s)")
        reply(true, nil)
    }

    func releaseToFirmware(reply: @escaping @Sendable (Bool, String?) -> Void) {
        performRelease()
        reply(true, nil)
    }

    func heartbeat(nonce: NSNumber, reply: @escaping @Sendable (NSNumber) -> Void) {
        watchdog?.recordHeartbeat()
        reply(nonce)
    }

    // MARK: - Internals

    private func readFans() async -> [FanState] {
        guard let reader = fanReader else {
            logger.error("cannot open the fan interface")
            return []
        }
        do {
            return try await reader.fans()
        } catch {
            logger.error("cannot read fans: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    /// Whether the most recent hardware release completed. The exit paths
    /// turn this into the process exit code — the one unprivileged window
    /// into a root daemon's last act.
    var lastReleaseSucceeded: Bool {
        state.withLock { $0.lastReleaseSucceeded }
    }

    /// Idempotent. Called on release, on watchdog expiry, on sleep, on shutdown
    /// and when the connection drops, so it must never be the thing that fails.
    ///
    /// Synchronous on purpose: the exit paths call this and then `exit()`,
    /// and the hardware hand-back has to be finished by the time they do.
    func performRelease() {
        let wasControlling = state.withLock { current -> Bool in
            let was = current.isControlling
            current.isControlling = false
            return was
        }
        watchdog?.stop()

        // The actuator retries internally with backoff. If it still fails the
        // error is recorded as loudly as a root process can and the saved
        // state is kept, so a later release can try again — but this path
        // never throws: it runs where failure has nowhere to go. The outcome
        // is kept so the exit paths can carry it in the exit code, which is
        // the one channel user space can read without root.
        do {
            try actuator?.releaseNow()
            state.withLock { $0.lastReleaseSucceeded = true }
        } catch {
            state.withLock { $0.lastReleaseSucceeded = false }
            logger.fault(
                "hardware release failed after retries: \(String(describing: error), privacy: .public)"
            )
        }

        if wasControlling {
            logger.notice("fans handed back to firmware")
        }
    }
}
