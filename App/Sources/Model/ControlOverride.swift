import Core
import Foundation

/// The manual duty override, split from `ControlModel` so that file stays
/// inside the lint budget. Same model, same rules.
extension ControlModel {

    // MARK: - Manual duty override (P6.05)

    /// Hands the requested duty to the slider instead of the engine, for a
    /// while.
    ///
    /// Expiry returns control to the *engine*, not to the firmware: the
    /// user asked to take the wheel for half an hour, not to stop cooling
    /// afterwards. The safety chain is in the path either way, so an
    /// override can raise the fans but never hold them below what K1–K3
    /// demand.
    public func overrideDuty(_ duty: Double, until: Date?) {
        manualDuty = duty
        dutyOverrideUntil = until
        source = .manualDuty
        if state == .monitoring {
            engage(source: .manualDuty)
        }
    }

    /// Gives the engine back the wheel. If the active profile pauses the
    /// engine, the loop releases to firmware instead of idling engaged.
    public func clearDutyOverride() {
        dutyOverrideUntil = nil
        source = .engine
        refreshOutcome()
        reconcile()
    }
}
