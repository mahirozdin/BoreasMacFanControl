import Core
import Foundation

/// Applies the safety chain's K4 layer inside the privileged helper.
///
/// The rule itself is `Core.FanTargetGuard`, which is pure and therefore
/// testable; this is the thin adapter that uses it. Keeping the arithmetic out
/// of the helper means the safety layer is covered by the same test run as
/// everything else rather than by inspection.
typealias SafetyGovernor = FanTargetGuard
