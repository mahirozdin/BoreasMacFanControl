import Foundation
import OSLog
import Observation

/// Drives the helper setup window through install, approval, verification
/// and removal.
///
/// The phases mirror what the user can actually observe, not internal API
/// states: `SMAppService` reports `requiresApproval`, but what matters to the
/// person watching is "macOS wants a click in System Settings, and the app
/// will notice by itself once it happens".
@MainActor
@Observable
public final class HelperSetupModel {

    public enum Phase: Equatable {
        /// Nothing installed; the disclosure text and the install button show.
        case idle
        /// `register()` is running.
        case installing
        /// macOS wants the user to approve the item in System Settings.
        /// The model polls until the approval lands.
        case awaitingApproval
        /// Registration succeeded; proving the connection end to end.
        case verifying
        /// The helper answered and the signature check passed on both sides.
        case ready(fanCount: Int)
        /// The helper was unregistered; nothing of it remains active.
        case removed
        /// Something failed. The associated text is the system's own words.
        case failed(String)
    }

    public private(set) var phase: Phase = .idle

    private let installer = HelperInstaller()
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "setup")
    private var pollTask: Task<Void, Never>?

    /// How often the model asks whether the System Settings approval landed.
    /// Two seconds keeps the window responsive without hammering the API.
    private static let approvalPollInterval: Duration = .seconds(2)

    public init() {}

    /// Render support (`--render-panel`): pins `installerState` so the panel
    /// evidence does not depend on what happens to be installed on the
    /// rendering machine. Never set outside the render command.
    var fixedInstallerStateForRendering: HelperInstaller.State?

    /// Raw installer state, for the short status line in the menu bar panel.
    public var installerState: HelperInstaller.State {
        fixedInstallerStateForRendering ?? installer.state
    }

    /// Called when the setup window appears. Puts the phase in front of
    /// whatever state the machine is really in — the helper may have been
    /// installed or removed outside this window's lifetime.
    public func onAppear() {
        switch installer.state {
        case .enabled:
            verify()
        case .requiresApproval:
            enterAwaitingApproval()
        case .notRegistered, .notFound, .unknown:
            if phase != .removed { phase = .idle }
        }
    }

    /// Registers the helper. macOS asks the user for approval; nothing here
    /// can install anything silently.
    public func install() {
        phase = .installing
        let failure = installer.register()

        switch installer.state {
        case .enabled:
            verify()
        case .requiresApproval:
            // Not a failure even when register() returned an error:
            // "Operation not permitted" plus this state is the documented
            // macOS 13+ approval flow.
            enterAwaitingApproval()
        default:
            phase = .failed(failure ?? installer.state.summary)
        }
    }

    /// Opens the System Settings pane where the pending approval lives.
    public func openApprovalSettings() {
        installer.openApprovalSettings()
    }

    /// Proves the installation end to end: a nonce round trip (both code
    /// signatures checked) and a fan description over the privileged path.
    public func verify() {
        stopPolling()
        phase = .verifying
        Task { [weak self] in
            do {
                let client = HelperClient()
                guard try await client.ping() else {
                    self?.phase = .failed("helper answered with a stale nonce")
                    return
                }
                let fans = try await client.describeFans()
                self?.phase = .ready(fanCount: fans.count)
            } catch {
                self?.logger.error(
                    "verification failed: \(String(describing: error), privacy: .public)")
                self?.phase = .failed(String(describing: error))
            }
        }
    }

    /// Unregisters the helper. launchd stops it; the firmware keeps the fans.
    public func remove() {
        stopPolling()
        if let failure = installer.unregister() {
            phase = .failed(failure)
        } else {
            phase = .removed
        }
    }

    // MARK: - Approval polling

    private func enterAwaitingApproval() {
        phase = .awaitingApproval
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: HelperSetupModel.approvalPollInterval)
                guard let self, self.phase == .awaitingApproval else { return }
                if self.installer.state == .enabled {
                    self.verify()
                    return
                }
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
