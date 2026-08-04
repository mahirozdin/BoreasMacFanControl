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

        var summary: String {
            switch self {
            case .notRegistered: return "not registered"
            case .enabled: return "enabled"
            case .requiresApproval: return "waiting for approval in System Settings"
            case .notFound: return "not found"
            case .unknown(let raw): return "unknown status \(raw)"
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
