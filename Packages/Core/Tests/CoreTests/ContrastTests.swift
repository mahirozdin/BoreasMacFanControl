import Foundation
import Testing

@testable import Core

/// The numeric contrast audit the P6.01 run log deferred to P6.12.
///
/// Two things are being established here, and they are different in kind. The
/// first is that the *maths* is right — checked against ratios WCAG 2.1
/// publishes, so a subtle error in the transfer curve cannot hide behind
/// plausible-looking numbers. The second is that this product's colours clear
/// the requirement **their role actually carries**, which is not the same
/// number for a chart line and for a swatch printed beside its own value.
@Suite("Contrast (WCAG 2.1 relative luminance, per-role requirements)")
struct ContrastTests {

    private static let sweep = stride(from: -20.0, through: 130.0, by: 0.5)

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> ScaleColor {
        ScaleColor(red: red, green: green, blue: blue)
    }

    // MARK: - The maths, against published values

    @Test("relative luminance matches the sRGB definition at its anchors")
    func luminanceAnchors() {
        #expect(Self.rgb(0, 0, 0).relativeLuminance == 0)
        #expect(abs(Self.rgb(1, 1, 1).relativeLuminance - 1) < 1e-12)
        // The primaries are the weights themselves at full intensity, which is
        // what makes an error in any one of the three visible here.
        #expect(abs(Self.rgb(1, 0, 0).relativeLuminance - 0.2126) < 1e-12)
        #expect(abs(Self.rgb(0, 1, 0).relativeLuminance - 0.7152) < 1e-12)
        #expect(abs(Self.rgb(0, 0, 1).relativeLuminance - 0.0722) < 1e-12)
    }

    @Test("the ratio reproduces the ratios WCAG publishes")
    func ratioAgainstPublishedValues() {
        let black = Self.rgb(0, 0, 0)
        let white = Self.rgb(1, 1, 1)
        // Black on white is the maximum the formula can produce: 1.05 / 0.05.
        #expect(abs(white.contrastRatio(against: black) - 21) < 1e-9)
        #expect(white.contrastRatio(against: white) == 1)
        // Mid grey #777777 against white is a widely published 4.48:1 — just
        // under the body-text threshold, which is why it is the example
        // everybody quotes.
        let grey = Self.rgb(0x77 / 255, 0x77 / 255, 0x77 / 255)
        let measured = white.contrastRatio(against: grey)
        #expect(abs(measured - 4.48) < 0.01, "measured \(measured)")
    }

    @Test("the ratio is symmetric — argument order cannot flatter a colour")
    func ratioIsSymmetric() {
        for celsius in Self.sweep {
            let color = TemperatureScale.color(for: celsius)
            for background in AppearanceBackground.both {
                #expect(
                    abs(
                        color.contrastRatio(against: background)
                            - background.contrastRatio(against: color)) < 1e-12)
            }
        }
    }

    // MARK: - The product's colours, at the requirement their role carries

    @Test("every chart series colour clears 3:1 in both appearances")
    func seriesPaletteClearsRequiredGraphicThreshold() {
        // A chart line IS the data: remove it and the content is gone, which
        // is precisely WCAG 1.4.11's "graphical object required to understand
        // the content". So this one is a standard, not a ratchet.
        let required = ContrastRequirement.requiredGraphic.minimumRatio
        for (index, color) in SeriesPalette.colors.enumerated() {
            for background in AppearanceBackground.both {
                let ratio = color.contrastRatio(against: background)
                #expect(
                    ratio >= required,
                    "series \(index) reaches only \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    @Test("the series luminance band is exactly what 3:1 on both appearances allows")
    func luminanceBandIsDerived() {
        // The band is a *derived* quantity written down as a constant, and a
        // constant that has drifted from its derivation is worse than no
        // constant. This recomputes it from the two backgrounds and the 3:1
        // requirement, so retuning either end of the appearance pair fails
        // here rather than silently widening what the palette may do.
        let required = ContrastRequirement.requiredGraphic.minimumRatio
        let darkLuminance = AppearanceBackground.dark.relativeLuminance
        let lightLuminance = AppearanceBackground.light.relativeLuminance
        let lowest = required * (darkLuminance + 0.05) - 0.05
        let highest = (lightLuminance + 0.05) / required - 0.05

        #expect(SeriesPalette.luminanceBand.lowerBound >= lowest)
        #expect(SeriesPalette.luminanceBand.upperBound <= highest)
        // And the band must not have collapsed to nothing through rounding.
        #expect(SeriesPalette.luminanceBand.lowerBound < SeriesPalette.luminanceBand.upperBound)
    }

    @Test("every series colour sits inside the declared band")
    func seriesColoursSitInsideTheBand() {
        for (index, color) in SeriesPalette.colors.enumerated() {
            let luminance = color.relativeLuminance
            #expect(
                SeriesPalette.luminanceBand.contains(luminance),
                "series \(index) has luminance \(String(format: "%.3f", luminance))"
            )
        }
    }

    @Test("the temperature ramp never falls below its visibility floor")
    func temperatureRampClearsVisibilityFloor() {
        // The ramp's role is `reinforcingSwatch`: every place it is used
        // (`Color.temperature`) is a dot or a gauge with the temperature
        // printed beside it, so the number is the carrier. The floor stops a
        // future retune from making a swatch vanish into one appearance.
        let floor = ContrastRequirement.reinforcingSwatch.minimumRatio
        var worst = (ratio: Double.infinity, celsius: 0.0, dark: false)
        for celsius in Self.sweep {
            let color = TemperatureScale.color(for: celsius)
            for (isDark, background) in [
                (false, AppearanceBackground.light), (true, AppearanceBackground.dark),
            ] {
                let ratio = color.contrastRatio(against: background)
                if ratio < worst.ratio { worst = (ratio, celsius, isDark) }
                let appearance = isDark ? "dark" : "light"
                let measured = String(format: "%.2f", ratio)
                #expect(
                    ratio >= floor,
                    "\(celsius) °C reaches only \(measured):1 on the \(appearance) appearance"
                )
            }
        }
        // The worst case is *reported* by `--a11y-drill`, which measures the
        // same thing on the colours actually drawn. A test's job here is to
        // refuse a regression, not to narrate — and SwiftLint forbids `print`
        // in this repository, correctly.
        #expect(worst.ratio.isFinite)
    }

    @Test("the ramp's warm end is honestly below the required-graphic threshold")
    func warmEndIsBelowRequiredGraphicAndThatIsRecorded() {
        // This is the finding the audit produced, pinned so it cannot be
        // forgotten or quietly reinterpreted as compliance. The warm orange
        // does NOT reach 3:1 against a light window, and it is not supposed
        // to: reaching it would mean darkening the orange towards red, which
        // the red-exclusion rule forbids outright.
        //
        // The test asserts the *shape* of the trade-off — warm end below 3:1,
        // still above the floor — so that if somebody ever does retune the
        // stops to clear 3:1, this test fails and makes them come here and
        // rewrite the reasoning rather than leaving a stale comment behind.
        let warm = TemperatureScale.color(for: TemperatureScale.warmFloorCelsius)
        let ratio = warm.contrastRatio(against: AppearanceBackground.light)
        #expect(ratio < ContrastRequirement.requiredGraphic.minimumRatio)
        #expect(ratio >= ContrastRequirement.reinforcingSwatch.minimumRatio)
    }

    @Test("the two appearance backgrounds are far enough apart to be a real test")
    func backgroundsAreDistinct() {
        // A guard on the fixture itself. If somebody ever "simplified" these
        // two constants towards each other, every test above would keep
        // passing while measuring nothing.
        let separation = AppearanceBackground.light.contrastRatio(
            against: AppearanceBackground.dark)
        #expect(separation > 10, "the two appearances differ by only \(separation):1")
    }
}
