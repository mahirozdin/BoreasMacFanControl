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

/// Categorical colours for chart series — one per sensor group or fan.
///
/// This does **not** contradict `TemperatureScale`. That scale encodes one
/// value's magnitude, for a dot or a gauge where nothing else can. In a
/// time series the y-axis already carries magnitude, so spending hue on it
/// again would be redundant *and* would leave two groups at the same
/// temperature indistinguishable — the one thing a multi-series chart must
/// never do. Here hue carries identity instead.
///
/// The reserved-red rule still holds: every entry stays out of the red
/// corridor, and the test proves it the same way the ramp's does.
public enum SeriesPalette {

    /// The luminance band inside which 3:1 holds against **both** appearances.
    ///
    /// A chart line is a graphical object required to understand the content
    /// (WCAG 2.1 §1.4.11), so it owes 3:1 — and it owes it on a near-white
    /// window *and* a near-black one. Those two requirements pull in opposite
    /// directions and leave a band only a factor of two wide, derived from
    /// `AppearanceBackground`:
    ///
    /// - too light and it dissolves into the light appearance,
    /// - too dark and it dissolves into the dark one.
    ///
    /// **This band is why the palette was retuned in P6.12.** P6.01 aimed for
    /// "a middle luminance so they hold up against both appearances", which was
    /// the right instinct with the wrong number: five of the seven original
    /// entries sat at 0.29–0.45 and reached only 2.0–3.0:1 against a light
    /// window. The contrast audit measured it, `ContrastTests` now enforces it,
    /// and eyeballing a swatch cannot be the check — the ceiling is much lower
    /// than it looks.
    /// Rounded *inwards* at both ends, deliberately: the derivation gives
    /// 0.1406…0.2850, and a constant rounded outwards would permit a colour
    /// the requirement forbids. `ContrastTests` recomputes the bounds and
    /// refuses a band wider than the arithmetic allows — it caught this
    /// constant at `0.14` on the first run.
    public static let luminanceBand: ClosedRange<Double> = 0.141...0.284

    /// Seven hues spread around the wheel, all avoiding red, all inside
    /// `luminanceBand`.
    ///
    /// Retuned in P6.12 by adjusting **brightness only**: hue carries series
    /// identity here, so the hues and saturations of the P6.01 palette are
    /// kept (every hue is within a degree of where it was) and only the
    /// luminance moved. Fixing contrast by shifting hues would have traded one
    /// accessibility property for another.
    public static let colors: [ScaleColor] = [
        ScaleColor(red: 0.26, green: 0.50, blue: 0.82),  // blue    ~214°
        ScaleColor(red: 0.14, green: 0.56, blue: 0.51),  // teal    ~173°
        ScaleColor(red: 0.65, green: 0.46, blue: 0.16),  // amber   ~37°
        ScaleColor(red: 0.51, green: 0.44, blue: 0.83),  // violet  ~251°
        ScaleColor(red: 0.28, green: 0.56, blue: 0.28),  // green   ~120°
        ScaleColor(red: 0.72, green: 0.37, blue: 0.70),  // magenta ~303°
        // Yellow-green, not the olive this started as: at ~55° that entry
        // sat 18° from the amber above and the distinctness test refused
        // it. Moved into the widest remaining gap.
        ScaleColor(red: 0.43, green: 0.54, blue: 0.16),  // yellow-green ~77°
    ]

    /// The colour for a series index, wrapping when there are more series
    /// than colours. Wrapping is acceptable because a chart legend names
    /// every series — colour is the shortcut, never the only key.
    public static func color(at index: Int) -> ScaleColor {
        colors[((index % colors.count) + colors.count) % colors.count]
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
