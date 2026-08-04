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
    private static let queueKey = DispatchSpecificKey<Bool>()

    private var lastHeartbeat: Date?
    private var timer: (any DispatchSourceTimer)?

    init(policy: WatchdogPolicy, onExpiry: @escaping @Sendable () -> Void) {
        self.policy = policy
        self.onExpiry = onExpiry
        queue.setSpecific(key: Self.queueKey, value: true)
    }

    /// Runs `body` on the queue, inline when already there.
    ///
    /// The expiry callback leads to `performRelease`, which calls `stop()` —
    /// and the callback itself runs on this queue. A plain `queue.sync` there
    /// deadlocks on its own queue and takes the whole release down with it.
    /// That is not hypothetical: the freeze drill left a fan stuck in forced
    /// mode exactly this way once the write path was real.
    private func onQueue<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: Self.queueKey) == true {
            return body()
        }
        return queue.sync(execute: body)
    }

    /// Starts watching. Called when control is taken, not at launch: a helper
    /// that is not controlling anything has nothing to hand back.
    func start() {
        onQueue {
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
        onQueue {
            timer?.cancel()
            timer = nil
            lastHeartbeat = nil
        }
    }

    func recordHeartbeat() {
        onQueue { lastHeartbeat = Date() }
    }

    /// For tests and diagnostics.
    var secondsSinceHeartbeat: TimeInterval? {
        onQueue {
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
