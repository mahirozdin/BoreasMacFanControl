import Foundation
import OSLog
import ServiceManagement
import SharedIPC

/// Installs, removes and reports on the privileged helper.
///
/// Uses `SMAppService`, which has been the supported route since macOS 13.
/// The older `SMJobBless` flow is deliberately not used: it is deprecated, and
/// starting a new project on it would be taking on known debt.
///
/// Registration asks the user for administrator authentication once. Nothing
/// here can install anything without that prompt, and removal is a single call.
@MainActor
public final class HelperInstaller {

    public enum State: Equatable {
        case notRegistered
        case enabled
        case requiresApproval
        case notFound
        case unknown(Int)

        /// Shown in the diagnostics tab, so these are user facing text and were
        /// English in every language until the P7.06 Russian render made it
        /// obvious. `gate-i18n` did not catch them: its Y1 pattern looks for a
        /// literal inside `Text(…)`, and a `String` returned from a model is
        /// invisible to it — the same class of blind spot P6.11 found in `Core`.
        var summary: String {
            switch self {
            case .notRegistered:
                return String(
                    localized: "helper.status.notregistered", defaultValue: "not registered",
                    comment: "Helper state: it has never been installed")
            case .enabled:
                return String(
                    localized: "helper.status.enabled", defaultValue: "enabled",
                    comment: "Helper state: installed and approved")
            case .requiresApproval:
                return String(
                    localized: "helper.status.approval",
                    defaultValue: "waiting for approval in System Settings",
                    comment: "Helper state: registered but the user has not approved it yet")
            case .notFound:
                return String(
                    localized: "helper.status.notfound", defaultValue: "not found",
                    comment: "Helper state: the service is missing from the app bundle")
            case .unknown(let raw):
                return String(
                    localized: "helper.status.unknown", defaultValue: "unknown status \(raw)",
                    comment: "Helper state: a status code this build does not recognise")
            }
        }
    }

    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "helper")

    /// Name of the launchd property list inside the application bundle.
    private let plistName = "\(BoreasIPC.machServiceName).plist"

    public init() {}

    private var service: SMAppService {
        SMAppService.daemon(plistName: plistName)
    }

    public var state: State {
        switch service.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .unknown(service.status.rawValue)
        }
    }

    /// Registers the helper. Prompts for administrator authentication.
    ///
    /// - Returns: nil on success, or a message describing what went wrong.
    public func register() -> String? {
        do {
            try service.register()
            logger.notice("helper registered")
            return nil
        } catch {
            logger.error("registration failed: \(String(describing: error), privacy: .public)")
            return String(describing: error)
        }
    }

    /// Removes the helper and everything it installed.
    public func unregister() -> String? {
        do {
            try service.unregister()
            logger.notice("helper removed")
            return nil
        } catch {
            logger.error("removal failed: \(String(describing: error), privacy: .public)")
            return String(describing: error)
        }
    }

    /// Opens the pane where a pending approval is granted.
    public func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
