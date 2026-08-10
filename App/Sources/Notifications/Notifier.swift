import Core
import Foundation
import UserNotifications
import os

/// Delivering a notification, behind a protocol (P7.01).
///
/// The M2 reasoning applied outside hardware: the *decision* to notify is
/// `Core.NotificationPolicy` and is tested there, but the wiring between real
/// events and that decision has to be exercised too — and it cannot be, against
/// a real `UNUserNotificationCenter`, without a user, a permission dialog and a
/// visible banner. So the sink is a protocol with a live implementation and a
/// recording one, and `--notification-drill` drives the real event path into the
/// recorder.
protocol NotificationSink: Sendable {

    /// Whether the user has granted permission. `nil` means "not asked yet",
    /// which is a different state from "refused" and the interface says so.
    func authorizationState() async -> NotificationAuthorization

    /// Asks, once, at the moment the user turns notifications on.
    func requestAuthorization() async -> NotificationAuthorization

    func deliver(title: String, body: String, identifier: String) async
}

enum NotificationAuthorization: Sendable, Equatable {
    case notAsked
    case granted
    case denied
}

/// The real sink.
///
/// **The permission is requested when the user switches notifications on, and
/// never at launch.** Notifications are not on the I2 forbidden list, so asking
/// is allowed — but this application has spent six phases asking for nothing,
/// and a menu bar utility that opens with a permission dialog is the behaviour
/// that gets it quit and deleted. Same call as P6.10's shortcuts, which all
/// start unset.
struct LiveNotificationSink: NotificationSink {

    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "notifications")

    func authorizationState() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notAsked
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .granted
        @unknown default:
            // A status this build does not know is treated as "not asked"
            // rather than as granted: the failure that matters is claiming a
            // permission we do not have and then silently delivering nothing.
            return .notAsked
        }
    }

    func requestAuthorization() async -> NotificationAuthorization {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            return granted ? .granted : .denied
        } catch {
            // Thrown rather than swallowed by the caller's standards (§6.3),
            // but there is nothing to degrade to here: a refused permission and
            // a failed request look the same to the user, and both mean "no
            // notifications". Logged so it is diagnosable.
            logger.error("notification authorization failed: \(error.localizedDescription)")
            return .denied
        }
    }

    func deliver(title: String, body: String, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // No sound by default: a thermal notice is information, not an alarm,
        // and the one kind that *is* urgent already says so in its words.
        let request = UNNotificationRequest(
            identifier: identifier, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("notification delivery failed: \(error.localizedDescription)")
        }
    }
}

/// A sink that records instead of delivering, for the drill.
///
/// An actor rather than a class with a lock: the drill writes from the main
/// actor and reads after awaiting, and this is the shape that makes that safe
/// without anybody remembering to hold something.
actor RecordingNotificationSink: NotificationSink {

    struct Delivered: Equatable {
        let title: String
        let body: String
        let identifier: String
    }

    private(set) var delivered: [Delivered] = []
    private var authorization: NotificationAuthorization
    private(set) var authorizationRequests = 0

    init(authorization: NotificationAuthorization = .granted) {
        self.authorization = authorization
    }

    func authorizationState() async -> NotificationAuthorization { authorization }

    func requestAuthorization() async -> NotificationAuthorization {
        authorizationRequests += 1
        if authorization == .notAsked { authorization = .granted }
        return authorization
    }

    func deliver(title: String, body: String, identifier: String) async {
        delivered.append(Delivered(title: title, body: body, identifier: identifier))
    }

    func reset() {
        delivered.removeAll()
        authorizationRequests = 0
    }
}
