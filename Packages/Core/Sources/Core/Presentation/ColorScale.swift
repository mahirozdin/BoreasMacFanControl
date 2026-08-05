import Foundation

/// A colour as plain sRGB components in `0...1`, free of any UI framework.
///
/// The design system's colour *decisions* live in `Core` so they can sit under
/// unit tests — the same split that keeps `FanTargetGuard` and
/// `WatchdogPolicy` testable. The App layer only converts these components
/// into a SwiftUI `Color`; it never invents colours of its own.
public struct ScaleColor: Sendable, Hashable {

    public let red: Double
    public let green: Double
    public let blue: Double

    /// Internal on purpose: colours are produced by the scales below, never
    /// constructed ad hoc by callers. The scales only ever interpolate
    /// between in-range stops, so the components are in `0...1` by
    /// construction and need no defensive clamping here.
    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// HSV hue in degrees `[0, 360)`; `0` for achromatic colours.
    ///
    /// Exposed so tests (and later chart legends) can reason about colour
    /// identity — "is this red?" is a hue question, not an RGB question.
    public var hueDegrees: Double {
        let high = Swift.max(red, green, blue)
        let low = Swift.min(red, green, blue)
        let delta = high - low
        guard delta > 0 else { return 0 }

        let hue: Double
        if high == red {
            hue = (green - blue) / delta
        } else if high == green {
            hue = 2 + (blue - red) / delta
        } else {
            hue = 4 + (red - green) / delta
        }
        let degrees = hue * 60
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// HSV saturation in `0...1`; `0` for achromatic colours.
    public var saturation: Double {
        let high = Swift.max(red, green, blue)
        guard high > 0 else { return 0 }
        return (high - Swift.min(red, green, blue)) / high
    }
}

/// The continuous temperature colour scale: cool blue → neutral → warm orange.
///
/// Binding decisions (`docs/product/ui.md`, source blueprint §9):
///
/// - **Continuous, not banded.** A discrete three-colour band would contradict
///   the continuous curve philosophy of ADR 0010 — continuous data is
///   visualised continuously. The comparison test keeps this measurable.
/// - **Red never appears.** Red is reserved for panic/error signalling, which
///   is an *event*, not a point on this ramp. The warm end is orange, and the
///   scale deliberately saturates below the panic threshold: by the time K3
///   territory is reached the ramp has said everything it can, and the panic
///   state itself is carried by the semantic red accent, never by the ramp.
public enum TemperatureScale {

    /// At or below this the ramp is fully cool blue. Apple Silicon idle die
    /// temperatures sit in the 35–45 °C band; colder than 40 °C carries no
    /// extra information worth a colour step.
    public static let coolCeilingCelsius: Double = 40

    /// The visual midpoint of the ramp — sustained light load. The ramp
    /// passes through a *neutral* grey here rather than blending blue into
    /// orange directly: the middle of the range is "nothing remarkable", and
    /// a saturated in-between hue (purple) would invent meaning.
    public static let neutralCelsius: Double = 60

    /// At or above this the ramp is fully warm orange — sustained heavy load.
    /// Chosen below the K3 panic floor (70 °C, `PanicThreshold`): the ramp
    /// exhausts its vocabulary *before* panic can begin, so "very warm" and
    /// "panicking" can never be confused as neighbouring shades.
    public static let warmFloorCelsius: Double = 85

    /// Full-cool stop. Hue ≈ 215° — unmistakably blue on both appearances.
    static let coolStop = ScaleColor(red: 0.30, green: 0.56, blue: 0.92)

    /// Neutral stop. Saturation ≈ 0.03 — a hair on the cool side of grey so
    /// the ramp never looks *warmer* than it is.
    static let neutralStop = ScaleColor(red: 0.62, green: 0.62, blue: 0.64)

    /// Full-warm stop. Hue ≈ 31° — clearly orange, with enough green kept in
    /// the mix that it cannot read as red.
    static let warmStop = ScaleColor(red: 0.98, green: 0.55, blue: 0.10)

    /// The colour for a temperature, clamped at both ends.
    ///
    /// An unreadable temperature (`NaN`) answers with the hot end — the same
    /// rule `Curve` applies: of the two possible misreadings, "too alarming"
    /// is recoverable and "too reassuring" is not.
    public static func color(for celsius: Double) -> ScaleColor {
        if celsius.isNaN {
            return warmStop
        }
        if celsius <= coolCeilingCelsius {
            return coolStop
        }
        if celsius >= warmFloorCelsius {
            return warmStop
        }
        if celsius <= neutralCelsius {
            let position = (celsius - coolCeilingCelsius) / (neutralCelsius - coolCeilingCelsius)
            return blend(from: coolStop, to: neutralStop, position: position)
        }
        let position = (celsius - neutralCelsius) / (warmFloorCelsius - neutralCelsius)
        return blend(from: neutralStop, to: warmStop, position: position)
    }

    /// Straight-line interpolation per channel. Between in-range stops the
    /// result is in range for any `position` in `0...1`, which the callers
    /// above guarantee by construction.
    private static func blend(from: ScaleColor, to: ScaleColor, position: Double) -> ScaleColor {
        ScaleColor(
            red: from.red + (to.red - from.red) * position,
            green: from.green + (to.green - from.green) * position,
            blue: from.blue + (to.blue - from.blue) * position
        )
    }
}

/// The fan gauge scale: how *much* of the appearance-adaptive neutral grey a
/// fan gauge fills, never which hue.
///
/// Fans are rendered as a neutral grey fill (`docs/product/ui.md`) so the
/// temperature ramp keeps sole ownership of hue. Core decides the fill
/// *fraction*; the App layer pairs it with the system's adaptive foreground
/// so the grey stays legible in both light and dark appearance without this
/// layer knowing appearances exist.
public enum FanScale {

    /// Fill shown for a fan driven at the hardware minimum. Zero fill would
    /// be indistinguishable from "not running", and `Duty` zero means "the
    /// hardware minimum", not "off" — a driven fan is always visibly filled.
    /// (A parked fan is the consumer's case to present; it is a state, not a
    /// point on this scale.)
    public static let visibilityFloor: Double = 0.12

    /// Fill fraction in `[visibilityFloor, 1]`, linear in duty.
    public static func fillFraction(for duty: Duty) -> Double {
        visibilityFloor + (1 - visibilityFloor) * duty.value
    }
}
