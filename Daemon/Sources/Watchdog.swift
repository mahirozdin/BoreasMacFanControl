import Foundation
import OSLog

/// Hands the fans back when the application stops proving it is alive.
///
/// The helper does not trust the application to clean up after itself, because
/// the cases that matter are exactly the ones where it cannot: a crash, a hang,
/// `kill -9`, a logout. None of those can send a farewell message. Silence is
/// the signal, and silence is something the helper can observe on its own.
///
/// The timeout is bounded and cannot be switched off. A safety mechanism that
/// can be disabled by configuration is a configuration option, not a safety
/// mechanism.
final class Watchdog: @unchecked Sendable {

    /// Bounds enforced regardless of what a caller asks for.
    static let allowedTimeout: ClosedRange<Int> = 10...60

    private let timeout: TimeInterval
    private let onExpiry: @Sendable () -> Void
    private let logger = Logger(subsystem: "com.bubiapps.boreas.fanhelper", category: "watchdog")
    private let queue = DispatchQueue(label: "com.bubiapps.boreas.fanhelper.watchdog")

    private var lastHeartbeat: Date?
    private var timer: (any DispatchSourceTimer)?

    init(timeoutSeconds: Int, onExpiry: @escaping @Sendable () -> Void) {
        let clamped = min(Self.allowedTimeout.upperBound, max(Self.allowedTimeout.lowerBound, timeoutSeconds))
        self.timeout = TimeInterval(clamped)
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
            logger.notice("watchdog armed, timeout \(self.timeout, privacy: .public)s")
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
        guard Date().timeIntervalSince(last) > timeout else { return }

        logger.error("no heartbeat for \(self.timeout, privacy: .public)s, releasing fans")
        timer?.cancel()
        timer = nil
        lastHeartbeat = nil
        onExpiry()
    }
}
