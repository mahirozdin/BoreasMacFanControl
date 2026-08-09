import Core
import Foundation

/// Profile editing, split from `ControlModel` so that file stays inside the
/// lint budget. Same model, same rules.
extension ControlModel {

    // MARK: - Profile editing (P6.06)

    /// Replaces the active profile with an edited copy, in place.
    ///
    /// The engine reads the active profile fresh on every cycle, so an edit
    /// reaches the fans within one tick — which is what makes the curve
    /// editor an instrument rather than a drawing. Edits live in memory
    /// only: writing them to the configuration file arrives with the
    /// settings window, and pretending to persist would be worse than not
    /// persisting.
    ///
    /// Per-fan overrides keep their own curves; the editor edits the
    /// profile's default binding, and per-fan curves belong with profile
    /// management (P6.08).
    public func updateActiveProfile(
        curve: Curve? = nil,
        hysteresis: Hysteresis? = nil,
        smoothing: EWMA? = nil,
        slew: RateLimit? = nil
    ) {
        guard let active = outcome?.profile,
            let index = profiles.firstIndex(where: { $0.name == active.name })
        else { return }

        let old = profiles[index]
        let binding = curve.map { FanBinding(curve: $0, input: old.binding.input) } ?? old.binding
        profiles[index] = Profile(
            name: old.name,
            binding: binding,
            perFan: old.perFan,
            triggers: old.triggers,
            priority: old.priority,
            smoothing: smoothing ?? old.smoothing,
            hysteresis: hysteresis ?? old.hysteresis,
            slew: slew ?? old.slew,
            enginePaused: old.enginePaused)
        refreshOutcome()

        // Persisted when there is somewhere to persist to. The store
        // coalesces, so a drag writes once when it settles rather than on
        // every frame.
        store?.update { $0.profiles = profiles }
    }
}
