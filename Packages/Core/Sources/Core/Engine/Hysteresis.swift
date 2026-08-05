import Foundation

/// Dual-curve hysteresis with a direction lock
/// (`docs/product/control-model.md`).
///
/// Two curves: the base one for rising temperatures, and the same curve
/// shifted left by `H` for falling ones. The engine stays **locked** to the
/// branch it is on until the temperature moves `H` degrees against it; while
/// locked, the output holds at the branch extreme — a flat plateau of width
/// `H`. The handoff is continuous by construction: the falling curve at
/// `extreme − H` equals the base curve at `extreme`, so switching branches
/// never steps the output.
///
/// That plateau is the whole point: a temperature oscillating by less than
/// `H` around any value produces a **constant** output, which is the
/// "no oscillation around a threshold" requirement of P5.04.
public struct Hysteresis: Sendable, Hashable {

    public enum Branch: String, Sendable, Hashable, Codable {
        case rising
        case falling
    }

    /// The band width in degrees. Non-negative; 0 disables the effect.
    public let band: Double

    public struct State: Sendable, Hashable, Codable {
        public let branch: Branch
        /// The running extreme: the highest temperature seen while rising,
        /// the lowest while falling.
        public let extreme: Double

        public init(branch: Branch, extreme: Double) {
            self.branch = branch
            self.extreme = extreme
        }
    }

    public init(band: Double) {
        self.band = band.isFinite ? max(0, band) : 0
    }

    /// The default 3 °C band.
    public static let standard = Hysteresis(band: 3)

    /// Evaluates one sample against the curve pair.
    ///
    /// Pure: the caller keeps the state between samples. A `nil` state means
    /// the first sample, which starts on the rising branch at its own
    /// temperature.
    public func evaluate(
        curve: Curve, celsius: Double, state: State?
    ) -> (duty: Duty, state: State) {
        guard celsius.isFinite else {
            // An unreadable temperature reads hot (the curve's own rule);
            // the state is left where it was so recovery is seamless.
            let held = state ?? State(branch: .rising, extreme: celsius)
            return (curve.duty(at: .nan), held)
        }
        guard let state else {
            let fresh = State(branch: .rising, extreme: celsius)
            return (curve.duty(at: celsius), fresh)
        }

        let falling = curve.shiftedLeft(by: band)

        switch state.branch {
        case .rising:
            if celsius >= state.extreme {
                let next = State(branch: .rising, extreme: celsius)
                return (curve.duty(at: celsius), next)
            }
            if celsius > state.extreme - band {
                // Inside the band: locked, output holds at the extreme.
                return (curve.duty(at: state.extreme), state)
            }
            // Crossed the band against the direction: hand off to the
            // falling curve. falling(extreme − band) == curve(extreme), so
            // the output is continuous at this switch.
            let next = State(branch: .falling, extreme: celsius)
            return (falling.duty(at: celsius), next)

        case .falling:
            if celsius <= state.extreme {
                let next = State(branch: .falling, extreme: celsius)
                return (falling.duty(at: celsius), next)
            }
            if celsius < state.extreme + band {
                return (falling.duty(at: state.extreme), state)
            }
            let next = State(branch: .rising, extreme: celsius)
            return (curve.duty(at: celsius), next)
        }
    }
}
