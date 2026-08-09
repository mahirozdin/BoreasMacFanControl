import AppKit
import Core
import Foundation
import SwiftUI

/// The P6.12 drill: the colours that actually get drawn are the colours `Core`
/// decided, and their real contrast clears the requirement their role carries.
///
/// **Why a drill and not a unit test.** `ContrastTests` measures
/// `Core.ScaleColor` values, which is the right place for the arithmetic — but
/// `Core` never draws anything. Between `TemperatureScale.color(for:)` and a
/// pixel sits `DesignSystem`, which turns components into a SwiftUI `Color`,
/// and then AppKit, which resolves that `Color` per appearance. A transposed
/// channel or a `Color.primary` that resolves darker than assumed would leave
/// every `Core` test green while the product on screen failed the audit. This
/// drill closes that gap by resolving the *App layer's* colours through
/// `NSColor` and re-measuring them.
///
/// **Why there is no render command beside it.** There was one, and it was
/// deleted for being fake evidence: `--render-a11y` produced five conditions
/// whose PNGs were **byte-identical**, because `dynamicTypeSize` is inert on
/// macOS and the high-contrast appearance leaves these colours untouched. Both
/// facts are measured in `reportPlatformLimits` rather than asserted, so the
/// next session inherits the measurement instead of the assumption.
@MainActor
enum AccessibilityDrill {

    /// One appearance the product actually runs in, with the background its
    /// colours have to survive.
    private struct Surface {
        let name: String
        let appearance: NSAppearance.Name
        let background: ScaleColor
    }

    private static let surfaces: [Surface] = [
        Surface(name: "light", appearance: .aqua, background: AppearanceBackground.light),
        Surface(name: "dark", appearance: .darkAqua, background: AppearanceBackground.dark),
        Surface(
            name: "light + increase contrast", appearance: .accessibilityHighContrastAqua,
            background: AppearanceBackground.light),
        Surface(
            name: "dark + increase contrast", appearance: .accessibilityHighContrastDarkAqua,
            background: AppearanceBackground.dark),
    ]

    /// The sweep the ramp is measured over: past both clamps, fine enough that
    /// no stop can hide between two samples.
    private static let sweep = stride(from: -10.0, through: 120.0, by: 0.5)

    static func run(report: (String) -> Void) {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        checkCoreIsDrawnFaithfully(check)
        checkContrastOnEverySurface(check)
        checkSpokenContent(check, report: report)
        reportPlatformLimits(report)

        report(passed ? "ACCESSIBILITY DRILL PASS" : "ACCESSIBILITY DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    // MARK: - The App layer realises Core's decisions

    private static func checkCoreIsDrawnFaithfully(_ check: (String, Bool) -> Void) {
        var rampDrift = 0.0
        for celsius in sweep {
            guard let drawn = components(of: Color.temperature(celsius), in: .aqua) else {
                check("Color.temperature(\(celsius)) resolves at all", false)
                return
            }
            rampDrift = max(rampDrift, drift(drawn, from: TemperatureScale.color(for: celsius)))
        }
        // A tolerance, not equality: the round trip goes through a colour space
        // conversion, and demanding bit-exactness would fail on arithmetic
        // rather than on a mistake.
        check(
            "the temperature ramp is drawn exactly as Core decided "
                + "(worst channel drift \(format(rampDrift)))",
            rampDrift < 0.01)

        var seriesDrift = 0.0
        for index in SeriesPalette.colors.indices {
            guard let drawn = components(of: Color.series(index), in: .aqua) else { continue }
            seriesDrift = max(seriesDrift, drift(drawn, from: SeriesPalette.colors[index]))
        }
        check(
            "the series palette is drawn exactly as Core decided "
                + "(worst channel drift \(format(seriesDrift)))",
            seriesDrift < 0.01)
    }

    // MARK: - The requirement, measured on what is really drawn

    private static func checkContrastOnEverySurface(_ check: (String, Bool) -> Void) {
        let required = ContrastRequirement.requiredGraphic.minimumRatio
        for surface in surfaces {
            var worst = Double.infinity
            var worstIndex = 0
            for index in SeriesPalette.colors.indices {
                guard let drawn = components(of: Color.series(index), in: surface.appearance)
                else { continue }
                let ratio = drawn.contrastRatio(against: surface.background)
                if ratio < worst {
                    worst = ratio
                    worstIndex = index
                }
            }
            check(
                "chart series clear \(format(required)):1 on \(surface.name) "
                    + "(worst \(format(worst)):1, series \(worstIndex))",
                worst >= required)
        }

        let floor = ContrastRequirement.reinforcingSwatch.minimumRatio
        for surface in surfaces {
            var worst = Double.infinity
            var worstCelsius = 0.0
            for celsius in sweep {
                guard let drawn = components(of: Color.temperature(celsius), in: surface.appearance)
                else { continue }
                let ratio = drawn.contrastRatio(against: surface.background)
                if ratio < worst {
                    worst = ratio
                    worstCelsius = celsius
                }
            }
            check(
                "the temperature ramp clears its \(format(floor)):1 visibility floor on "
                    + "\(surface.name) (worst \(format(worst)):1 at \(worstCelsius) °C)",
                worst >= floor)
        }
    }

    // MARK: - What is actually said

    private static func checkSpokenContent(
        _ check: (String, Bool) -> Void, report: (String) -> Void
    ) {
        // An empty spoken label is silence where a sentence belongs, and it is
        // the exact failure a missing translation produces.
        let announcements: [StatusItemAnnouncement] = [
            StatusItemAnnouncement(control: .firmware, hottestCelsius: 62.4, fanRPM: 1_608),
            StatusItemAnnouncement(
                control: .driving(profileName: "Balanced"), hottestCelsius: 78.6, fanRPM: 3_140),
            StatusItemAnnouncement(
                control: .drivingTemporarily(profileName: "Quiet"), hottestCelsius: 55.0,
                fanRPM: 1_200),
            StatusItemAnnouncement(control: .panicking, hottestCelsius: 96.8, fanRPM: 4_900),
            StatusItemAnnouncement(control: .firmware, hottestCelsius: nil, fanRPM: nil),
        ]
        let allSpeak = announcements.allSatisfy {
            !$0.spokenLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        check("every menu bar announcement produces a sentence", allSpeak)
        report("  e.g. \"\(announcements[3].spokenLabel)\"")

        // The curve reads as a point list, which is the documented accessible
        // path to the editor (docs/product/ui.md).
        guard
            let curve = BuiltInProfiles.all().first(where: { $0.name == "Balanced" })?
                .binding.curve
        else {
            check("the Balanced curve exists to be read aloud", false)
            return
        }
        let spoken = curve.spokenPointList
        check(
            "the curve reads as \(curve.points.count) numbered points",
            !spoken.isEmpty && spoken.contains("1"))
        report("  \"\(spoken)\"")
    }

    // MARK: - Platform limits, measured rather than assumed

    /// The two facts the deleted render command was supposed to photograph, plus
    /// the two that are genuinely manual. None is a pass/fail: they are platform
    /// behaviour this project has to live with, and recording the measurement is
    /// what stops the next session assuming otherwise.
    private static func reportPlatformLimits(_ report: (String) -> Void) {
        report("  — platform measurements, not assertions —")
        report("  Dynamic Type on macOS: \(dynamicTypeReport())")
        report("  Increase Contrast on our colours: \(increaseContrastReport())")
        report(
            "  Reduce Transparency: "
                + "\(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency) "
                + "(read-only system setting — manual check)")
        report(
            "  Reduce Motion: the interface declares no animation, so there is "
                + "nothing to reduce (enforced by make gate-a11y)")
    }

    /// Does `dynamicTypeSize` change any layout on this platform?
    ///
    /// Measured by laying out the same text at the smallest and the largest size
    /// there is. On macOS the answer is no — there is no system-wide Dynamic
    /// Type control and `NSFont.preferredFont(forTextStyle: .body)` returns a
    /// fixed size — which is why invariant Y3 (no fixed-size text container) is
    /// tested by the **pseudo-locale** layout test (P6.13) and not here:
    /// translated strings are what actually change a label's length.
    private static func dynamicTypeReport() -> String {
        let sample = Text(verbatim: "Temperature 62 degrees Celsius").font(.body)
        let small = NSHostingView(rootView: sample.environment(\.dynamicTypeSize, .xSmall))
            .fittingSize
        let large = NSHostingView(rootView: sample.environment(\.dynamicTypeSize, .accessibility5))
            .fittingSize
        let scales = abs(small.width - large.width) > 0.5 || abs(small.height - large.height) > 0.5
        return scales
            ? "scales text (\(Int(small.width)) → \(Int(large.width)) pt wide)"
            : "inert — identical layout at xSmall and accessibility5 "
                + "(\(Int(small.width))×\(Int(small.height)) pt both)"
    }

    /// Does the high-contrast appearance change the colours this product draws?
    ///
    /// Measured on the one colour most likely to move — the system red the panic
    /// state uses, which `DesignSystem` deliberately takes from the system
    /// precisely so it can adapt.
    private static func increaseContrastReport() -> String {
        guard let plain = components(of: Color.panicAccent, in: .aqua),
            let contrasted = components(of: Color.panicAccent, in: .accessibilityHighContrastAqua)
        else { return "could not resolve" }
        let moved = drift(plain, from: contrasted)
        return moved < 0.001
            ? "unchanged (panic red identical in both appearances) — AppKit applies it to "
                + "its own control drawing, not to colour values"
            : "shifts the panic red by \(format(moved)) per channel"
    }

    // MARK: - Measurement helpers

    /// Resolves a SwiftUI `Color` to sRGB components as AppKit draws it under a
    /// given appearance, so the measurement is of the drawn colour rather than of
    /// the value that was asked for.
    private static func components(
        of color: Color, in appearance: NSAppearance.Name
    )
        -> ScaleColor?
    {
        guard let named = NSAppearance(named: appearance) else { return nil }
        var resolved: NSColor?
        named.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB)
        }
        guard let resolved else { return nil }
        return ScaleColor.forMeasurement(
            red: resolved.redComponent,
            green: resolved.greenComponent,
            blue: resolved.blueComponent)
    }

    private static func drift(_ one: ScaleColor, from other: ScaleColor) -> Double {
        max(
            abs(one.red - other.red),
            max(abs(one.green - other.green), abs(one.blue - other.blue)))
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
