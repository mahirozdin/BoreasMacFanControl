import Foundation

/// Where the control loop stands. The four states of the product's state
/// machine (`docs/product/control-model.md`).
public enum ControlState: String, Sendable, Hashable, Codable {
    /// Reading only. The default, and the state everything falls back to.
    case monitoring
    /// The helper is driving the fans at the engine's targets.
    case controlling
    /// K3 fired: full speed, held until the panic lock releases.
    case panic
    /// Handing the fans back. Idempotent, and always ends in `monitoring`.
    case releasing
}

/// What can happen to the control loop.
public enum ControlEvent: String, Sendable, Hashable {
    /// The user turned control on and the helper answered.
    case controlEngaged
    /// The safety chain reported the panic layer active.
    case panicRaised
    /// The panic lock released and the chain is back to the curve.
    case panicCleared
    /// Anything that ends control: the user turning it off, quit, sleep,
    /// an error, the helper vanishing. They all lead the same way.
    case releaseRequested
    /// The hardware is confirmed back with the firmware.
    case released
}

/// The transition table, pure and total: every (state, event) pair answers
/// either the next state or `nil` for "not a legal move".
///
/// `nil` is not an error to recover from — it is the machine refusing a
/// transition that must not exist, like jumping from `monitoring` straight
/// into `panic` without ever having taken control. Callers log refusals;
/// the table never bends.
public enum ControlStateMachine {

    public static func next(from state: ControlState, on event: ControlEvent) -> ControlState? {
        switch (state, event) {
        case (.monitoring, .controlEngaged):
            return .controlling

        case (.controlling, .panicRaised):
            return .panic
        case (.panic, .panicCleared):
            return .controlling

        // Release can begin from any active state — including panic: the
        // user quitting mid-panic still hands the fans back, and the
        // firmware then runs them as hot hardware demands.
        case (.controlling, .releaseRequested), (.panic, .releaseRequested):
            return .releasing
        case (.releasing, .released):
            return .monitoring

        // Releasing while already monitoring or releasing is idempotent
        // reality, not a state change.
        case (.monitoring, .releaseRequested), (.releasing, .releaseRequested):
            return state

        default:
            return nil
        }
    }
}
