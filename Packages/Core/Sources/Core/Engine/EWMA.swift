import Foundation

/// Exponentially weighted moving average — the input smoothing stage
/// (`docs/product/control-model.md`, stage 1).
///
/// `output = α·sample + (1 − α)·previous`. Pure: the caller keeps the
/// previous value between samples.
///
/// The boundaries mean exactly what they say and are pinned by tests:
/// `α = 1` is no smoothing at all (the sample passes through), `α = 0`
/// freezes the output at the first value ever seen. Neither is useful in
/// production; both must behave, because a clamp that misbehaves at its own
/// edges hides bugs in everything built on it.
public struct EWMA: Sendable, Hashable {

    /// Smoothing factor, clamped into `[0, 1]`. An ambiguous value (NaN)
    /// resolves to 1 — no smoothing — because for a safety input the
    /// unsmoothed truth is the conservative choice.
    public let alpha: Double

    public init(alpha: Double) {
        if alpha.isNaN {
            self.alpha = 1
        } else {
            self.alpha = min(1, max(0, alpha))
        }
    }

    /// The default from the control model.
    public static let standard = EWMA(alpha: 0.30)

    /// One smoothing step. The first sample (no previous) passes through
    /// unchanged — there is nothing to average against, and inventing a
    /// starting value would bias the warm-up.
    public func smooth(previous: Double?, sample: Double) -> Double {
        guard let previous, previous.isFinite else { return sample }
        guard sample.isFinite else { return previous }
        return alpha * sample + (1 - alpha) * previous
    }
}
