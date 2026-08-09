import Foundation

/// Contrast measurement for the design system's colours (P6.12).
///
/// The P6.01 run log left this debt explicitly: the temperature ramp's
/// legibility against both appearances was "verified by inspection, not by a
/// measured contrast ratio", and the accessibility pass was named as the owner
/// of the numeric audit. This is that audit, and it lives in `Core` for the
/// same reason every other colour decision does — a ratio is arithmetic over
/// sRGB components, so it can be a property under test rather than an opinion.
///
/// The maths is WCAG 2.1: each channel is linearised out of sRGB's transfer
/// curve, weighted by the luminous contribution of that primary, and two
/// luminances become a ratio with a `0.05` flare term.
extension ScaleColor {

    /// A colour that came from somewhere else, wrapped so it can be *measured*.
    ///
    /// `ScaleColor.init` is deliberately internal — colours are produced by the
    /// scales, never constructed ad hoc, which is what stops a view inventing
    /// one. Measurement is the exception that proves the rule: the P6.12 drill
    /// resolves what SwiftUI and AppKit actually drew and compares it against
    /// what `Core` decided, and it cannot do that without a way to describe an
    /// observed colour.
    ///
    /// Named for its purpose so the distinction survives autocomplete: nothing
    /// in the design system may call this to make a colour, and a component out
    /// of range is clamped rather than trusted, because it did not come from
    /// here.
    public static func forMeasurement(red: Double, green: Double, blue: Double) -> ScaleColor {
        func clamp(_ value: Double) -> Double { Swift.min(1, Swift.max(0, value)) }
        return ScaleColor(red: clamp(red), green: clamp(green), blue: clamp(blue))
    }

    /// One sRGB channel with the display transfer curve removed.
    ///
    /// The `0.03928` knee and the `2.4` exponent are sRGB's own definition,
    /// reproduced in WCAG 2.1's relative-luminance formula. Written out rather
    /// than approximated with a plain `pow(c, 2.2)`: the gamma-2.2
    /// approximation drifts by a few per cent near black, which is exactly
    /// where the dark appearance does its measuring.
    private static func linear(_ channel: Double) -> Double {
        channel <= 0.039_28
            ? channel / 12.92
            : Foundation.pow((channel + 0.055) / 1.055, 2.4)
    }

    /// WCAG 2.1 relative luminance in `0...1` — `0` is black, `1` is white.
    ///
    /// The weights are not arbitrary: human vision is roughly seven times more
    /// sensitive to green than to blue, which is why a saturated blue can be
    /// "bright" and still read as dark.
    public var relativeLuminance: Double {
        0.2126 * Self.linear(red)
            + 0.7152 * Self.linear(green)
            + 0.0722 * Self.linear(blue)
    }

    /// The WCAG contrast ratio between two colours, always `>= 1`.
    ///
    /// Symmetric by construction — the lighter colour goes on top whichever
    /// way round the arguments arrive, so a caller cannot get a misleadingly
    /// small number by passing them in the wrong order.
    public func contrastRatio(against other: ScaleColor) -> Double {
        let one = relativeLuminance
        let two = other.relativeLuminance
        let lighter = Swift.max(one, two)
        let darker = Swift.min(one, two)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// The two backgrounds every colour in this product has to survive.
///
/// Named here rather than in the App layer because they are what the contrast
/// audit measures *against*, and the audit is a `Core` test. They are the
/// system's window backgrounds to a close approximation; the point of the
/// numbers is to be representative and stable, not to track a system colour
/// that shifts between releases — a threshold measured against a moving
/// background would fail for reasons that have nothing to do with this
/// project's colours.
public enum AppearanceBackground {

    /// Light appearance window background — very near white.
    public static let light = ScaleColor(red: 0.98, green: 0.98, blue: 0.98)

    /// Dark appearance window background. Not black: macOS dark windows sit
    /// well above it, and measuring against black would flatter every colour
    /// by inflating its ratio.
    public static let dark = ScaleColor(red: 0.12, green: 0.12, blue: 0.13)

    public static let both: [ScaleColor] = [light, dark]
}

/// What a colour has to reach, and *why that number and not another*.
///
/// The distinction this type exists to make: WCAG's 3:1 non-text requirement
/// applies to a graphical object **required to understand the content**. A
/// chart line is that — remove it and the data is gone. A coloured dot printed
/// beside the number it encodes is not, because the number is the carrier and
/// the colour is reinforcement. Enforcing 3:1 on the dot would be enforcing a
/// rule that does not apply, and would fail a design that is correct.
///
/// So the requirement is chosen per role, and the role is written down.
public enum ContrastRequirement: Sendable {

    /// WCAG 2.1 §1.4.3 — body text.
    case bodyText

    /// WCAG 2.1 §1.4.3 — large text (18 pt, or 14 pt bold and heavier).
    case largeText

    /// WCAG 2.1 §1.4.11 — a graphical object required to understand the
    /// content. Chart series lines are the case in this product.
    case requiredGraphic

    /// **Not a WCAG level.** A visibility floor for a swatch whose value is
    /// always printed next to it, so the colour is never the sole carrier —
    /// the colour-independence rule in `docs/product/ui.md` is what makes this
    /// weaker requirement legitimate. The floor exists so a swatch cannot
    /// quietly become invisible against one appearance; it is a ratchet
    /// against regression, not a claim of compliance.
    case reinforcingSwatch

    public var minimumRatio: Double {
        switch self {
        case .bodyText: 4.5
        case .largeText: 3.0
        case .requiredGraphic: 3.0
        case .reinforcingSwatch: 1.5
        }
    }
}
