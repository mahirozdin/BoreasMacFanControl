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
    }

    private let logger = Logger(subsystem: "com.bubiapps.boreas.fanhelper", category: "service")
    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Created once. Immutable, so the async read path needs no lock at all.
    private let fanReader: LiveFanSource?
    private var watchdog: Watchdog?

    override init() {
        fanReader = try? LiveFanSource()
        super.init()
        watchdog = Watchdog(timeoutSeconds: 15) { [weak self] in
            self?.logger.error("watchdog expired")
            self?.performRelease()
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

        state.withLock { $0.isControlling = true }
        watchdog?.start()

        // Writing to the SMC lands in P4. The surface, the safety filter and
        // the watchdog are all in place and exercised; only the final write is
        // missing, and saying so beats pretending it worked.
        logger.notice("targets accepted for \(fanIDs.count, privacy: .public) fan(s)")
        reply(false, "fan writing is not implemented yet")
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

    /// Idempotent. Called on release, on watchdog expiry, on sleep, on shutdown
    /// and when the connection drops, so it must never be the thing that fails.
    func performRelease() {
        let wasControlling = state.withLock { current -> Bool in
            let was = current.isControlling
            current.isControlling = false
            return was
        }
        watchdog?.stop()
        if wasControlling {
            logger.notice("fans handed back to firmware")
        }
    }
}
