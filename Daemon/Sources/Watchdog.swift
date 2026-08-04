import Core
import Foundation
import OSLog

/// Hands the fans back when the application stops proving it is alive.
///
/// The helper does not trust the application to clean up after itself, because
/// the cases that matter are exactly the ones where it cannot: a crash, a hang,
/// `kill -9`, a logout. None of those can send a farewell message. Silence is
/// the signal, and silence is something the helper can observe on its own.
///
/// This type owns only the timer. What a tick *means* — the 10–60 s clamp and
/// the expiry decision — lives in `Core.WatchdogPolicy`, where the invariant
/// tests of ADR 0009 can actually run.
final class Watchdog: @unchecked Sendable {

    private let policy: WatchdogPolicy
    private let onExpiry: @Sendable () -> Void
    private let logger = Logger(subsystem: "com.bubiapps.boreas.fanhelper", category: "watchdog")
    private let queue = DispatchQueue(label: "com.bubiapps.boreas.fanhelper.watchdog")

    private var lastHeartbeat: Date?
    private var timer: (any DispatchSourceTimer)?

    init(policy: WatchdogPolicy, onExpiry: @escaping @Sendable () -> Void) {
        self.policy = policy
        self.onExpiry = onExpiry
    }

    /// Starts watching. Called when control is taken, not at launch: a helper
    /// that is not controlling anything has nothing to hand back.
    func start() {
        queue.sync {
            lastHeartbeat = Date()
            guard timer == nil else { return }
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now() + 1, repeating: 1)
            source.setEventHandler { [weak self] in self?.tick() }
            source.resume()
            timer = source
            logger.notice("watchdog armed, timeout \(self.policy.timeout, privacy: .public)s")
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            lastHeartbeat = nil
        }
    }

    func recordHeartbeat() {
        queue.sync { lastHeartbeat = Date() }
    }

    /// For tests and diagnostics.
    var secondsSinceHeartbeat: TimeInterval? {
        queue.sync {
            guard let lastHeartbeat else { return nil }
            return Date().timeIntervalSince(lastHeartbeat)
        }
    }

    private func tick() {
        guard let last = lastHeartbeat else { return }
        guard policy.hasExpired(lastHeartbeat: last, now: Date()) else { return }

        logger.error("no heartbeat for \(self.policy.timeout, privacy: .public)s, releasing fans")
        timer?.cancel()
        timer = nil
        lastHeartbeat = nil
        onExpiry()
    }
}
