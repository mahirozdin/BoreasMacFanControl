import Foundation

/// The asymmetric output rate limiter
/// (`docs/product/control-model.md`, stage 3).
///
/// Rising is fast because it is a safety direction; falling is slow because
/// a fan audibly winding down and back up is the most complained-about
/// behaviour in this product category. One "transition time" knob cannot
/// express that asymmetry, which is why there are two.
///
/// This stage shapes the *engine's* output only. The safety chain runs
/// after it and is not rate limited: a panic or a critical thermal state
/// jumps to full speed immediately, acoustics be damned.
public struct RateLimit: Sendable, Hashable {

    /// Maximum rise, RPM per second. Non-negative and finite.
    public let maxRisePerSecond: Double
    /// Maximum fall, RPM per second. Non-negative and finite.
    public let maxFallPerSecond: Double

    public init(maxRisePerSecond: Double, maxFallPerSecond: Double) {
        self.maxRisePerSecond =
            maxRisePerSecond.isFinite ? max(0, maxRisePerSecond) : 0
        self.maxFallPerSecond =
            maxFallPerSecond.isFinite ? max(0, maxFallPerSecond) : 0
    }

    /// The defaults from the control model: 600 up, 150 down.
    public static let standard = RateLimit(maxRisePerSecond: 600, maxFallPerSecond: 150)

    /// Moves from `previousRPM` towards `targetRPM`, covering at most the
    /// distance the elapsed time allows in that direction.
    ///
    /// The first evaluation (no previous) passes the target through: there
    /// is no current speed to move from, and holding the fans at an invented
    /// value would be the limiter making policy.
    public func limit(previousRPM: Int?, targetRPM: Int, elapsedSeconds: Double) -> Int {
        guard let previousRPM else { return targetRPM }
        guard elapsedSeconds.isFinite, elapsedSeconds > 0 else { return previousRPM }

        let delta = Double(targetRPM - previousRPM)
        if delta > 0 {
            let step = min(delta, maxRisePerSecond * elapsedSeconds)
            return previousRPM + Int(step.rounded())
        }
        if delta < 0 {
            let step = min(-delta, maxFallPerSecond * elapsedSeconds)
            return previousRPM - Int(step.rounded())
        }
        return previousRPM
    }
}

/// Codable through the clamping initialiser, so decoded limits obey the
/// same non-negative guarantee as constructed ones.
extension RateLimit: Codable {
    private enum CodingKeys: String, CodingKey {
        case maxRisePerSecond
        case maxFallPerSecond
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            maxRisePerSecond: try container.decode(Double.self, forKey: .maxRisePerSecond),
            maxFallPerSecond: try container.decode(Double.self, forKey: .maxFallPerSecond)
        )
    }
}
