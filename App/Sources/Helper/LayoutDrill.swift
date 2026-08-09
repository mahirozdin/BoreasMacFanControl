import AppKit
import Core
import Foundation
import SwiftUI

/// The P6.13 layout drill: does any fixed-width text container clip a
/// translation, in any language the product ships — or in one 40% longer than
/// the longest it has?
///
/// **Why this is the only check invariant Y3 has.** Y3 forbids a text container
/// with a fixed pixel width or height, and the reason was always recorded as
/// Dynamic Type. P6.12 measured that and found it inert on macOS: identical
/// layout at `xSmall` and `accessibility5`. What actually stretches a label
/// here is translation, so a *pseudo-locale* is the instrument, and the
/// reasoning lives with the expansion in `Core.PseudoLocale`.
///
/// **Why not simply ban fixed widths.** A sortable table needs its columns to
/// line up, and the sensor table has five. The honest rule is not "no fixed
/// width" but "no fixed width that clips what it has to hold", which is a
/// measurement — so this measures it.
///
/// **Where the inventory comes from.** Every container checked below derives its
/// strings and its width from the same declarations the views use
/// (`SensorColumn.allCases` with `SensorTable.width(of:)`,
/// `CurvePointTable.temperatureColumnWidth`), so a column that is resized or
/// renamed moves here automatically. A hand-copied list of widths would go
/// stale the first time somebody adjusted one, and go stale silently.
@MainActor
enum LayoutDrill {

    /// One text container whose width cannot grow with its content.
    private struct Container {
        let place: String
        let strings: [String]
        let available: CGFloat
        let font: NSFont
    }

    static func run(report: (String) -> Void) {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        let languages = shippedLanguages()
        guard !languages.isEmpty else {
            report("  FAIL no .lproj localisations in the bundle — nothing to measure")
            exit(1)
        }
        report("  languages found in the bundle: \(languages.joined(separator: ", "))")

        checkKeysStillResolve(check)

        for language in languages {
            measure(language: language, check: check, report: report)
        }

        reportSurfaceWidths(report)

        report(passed ? "LAYOUT DRILL PASS" : "LAYOUT DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    /// The derived keys still resolve to the strings the views show.
    ///
    /// `localizationKey` is built from `rawValue`, which is the only way one
    /// fact can live in one place — but a derivation is a guess until it is
    /// checked. Rename a key in the catalogue and the lookup falls back to the
    /// key text; without this the drill would then measure `"table.column.name"`
    /// and cheerfully pass.
    private static func checkKeysStillResolve(_ check: (String, Bool) -> Void) {
        // The *current* language, not a fixed one: `displayName` resolves in
        // whatever locale the process is running under, so comparing it against
        // a hard-coded `en` lookup compares English with Turkish and fails for
        // the wrong reason. It did, on the first run.
        let current = Bundle.main.preferredLocalizations.first ?? "en"
        guard let bundle = localisedBundle(current) else {
            check("the \(current) localisation loads, to verify the derived keys", false)
            return
        }
        let columnsAgree = SensorColumn.allCases.allSatisfy {
            localised($0.localizationKey, in: bundle) == $0.displayName
                || $0.displayName.isEmpty
        }
        let groupsAgree = SensorGroup.allCases.allSatisfy {
            localised($0.localizationKey, in: bundle) == $0.displayName
                || $0.displayName.isEmpty
        }
        check(
            "every derived catalogue key still resolves to what the view shows",
            columnsAgree && groupsAgree)
    }

    // MARK: - The measurement

    private static func measure(
        language: String, check: (String, Bool) -> Void, report: (String) -> Void
    ) {
        guard let bundle = localisedBundle(language) else {
            check("the \(language) localisation loads", false)
            return
        }

        var worstHeadroom = Double.infinity
        var worstLabel = ""
        var failures: [String] = []
        var tight: [String] = []

        for container in containers(in: bundle) {
            for string in container.strings {
                let natural = width(of: string, font: container.font)
                // Headroom is what the pseudo-locale eats into: how many times
                // its own width the string could grow to and still fit.
                let headroom = natural > 0 ? Double(container.available / natural) : .infinity
                if headroom < worstHeadroom {
                    worstHeadroom = headroom
                    worstLabel = "\(container.place) \"\(string)\""
                }

                let expanded = PseudoLocale.expand(string)
                if width(of: expanded, font: container.font) > container.available {
                    failures.append(
                        "\(container.place) \"\(string)\" needs "
                            + "\(format(width(of: expanded, font: container.font))) pt of "
                            + "\(format(container.available)) at "
                            + "\(format(PseudoLocale.expansionFactor))×")
                }

                let diagnostic = PseudoLocale.expand(
                    string, factor: PseudoLocale.diagnosticFactor)
                if width(of: diagnostic, font: container.font) > container.available {
                    tight.append("\(container.place) \"\(string)\"")
                }
            }
        }

        check(
            "\(language): every fixed-width container survives "
                + "\(format(PseudoLocale.expansionFactor))× expansion",
            failures.isEmpty)
        for failure in failures {
            report("       \(failure)")
        }
        report(
            "       tightest: \(worstLabel) has "
                + "\(format(worstHeadroom))× headroom")
        if !tight.isEmpty {
            // Reported, never failed: see `PseudoLocale.diagnosticFactor`.
            report(
                "       \(tight.count) container(s) would clip at "
                    + "\(format(PseudoLocale.diagnosticFactor))× — headroom note, not a defect")
        }
    }

    /// Every fixed-width text container in the product, with the strings it has
    /// to hold in this language.
    private static func containers(in bundle: Bundle) -> [Container] {
        // `.caption` semibold and `.callout` as the views declare them. Taken
        // from `NSFont.preferredFont` so the sizes track the system's rather
        // than being guessed — P6.12 measured these at 10 pt and 13 pt.
        let caption = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        let callout = NSFont.preferredFont(forTextStyle: .body)

        var containers: [Container] = []

        // The sensor table's five columns (P6.04). Headers in caption semibold,
        // and the group names that fill the widest cell in callout.
        for column in SensorColumn.allCases {
            containers.append(
                Container(
                    place: "sensor table header",
                    strings: [localised(column.localizationKey, in: bundle)],
                    available: SensorTable.width(of: column),
                    font: caption))
        }
        containers.append(
            Container(
                place: "sensor table group cell",
                strings: SensorGroup.allCases.map { localised($0.localizationKey, in: bundle) },
                available: SensorTable.width(of: .group),
                font: callout))

        // The numeric curve table's two columns (P6.07).
        containers.append(
            Container(
                place: "curve table header",
                strings: [localised("curve.table.temperature", in: bundle)],
                available: CurvePointTable.temperatureColumnWidth,
                font: caption))
        containers.append(
            Container(
                place: "curve table header",
                strings: [localised("curve.table.duty", in: bundle)],
                available: CurvePointTable.dutyColumnWidth,
                font: caption))

        return containers
    }

    // MARK: - Surface widths, reported

    /// The whole-surface measurement, reported rather than asserted.
    ///
    /// A surface's ideal width is only a *hint* about clipping: a fixed-width
    /// column clips without changing the width of the window around it, which is
    /// exactly why the per-container measurement above exists. What this is good
    /// for is spotting a surface that has outgrown its window — and for that a
    /// number a human reads beats a threshold guessed here.
    private static func reportSurfaceWidths(_ report: (String) -> Void) {
        report("  — surface ideal widths, for comparison against the window —")
        let monitor = MonitorModel(
            fixedForRendering: [SensorClassifier.makeReading(rawName: "PMU tdie5", celsius: 62.4)],
            fans: [
                FanState(
                    id: 0, name: "Fan 0", currentRPM: 1_608, minimumRPM: 1_000,
                    maximumRPM: 4_900, isPoweredOff: false)
            ])
        let control = ControlModel(
            fixedForRendering: monitor,
            selection: ManualSelection(profileName: "Balanced"),
            state: .controlling, layer: nil)
        let setup = HelperSetupModel()
        setup.fixedInstallerStateForRendering = .enabled

        let panel = NSHostingView(
            rootView: MenuBarPanel(model: monitor, setup: setup, control: control))
        report("  menu bar panel: \(format(panel.fittingSize.width)) pt wide")
    }

    // MARK: - Helpers

    /// The languages actually in the built bundle, so adding one in P7.06 is
    /// measured without touching this drill.
    private static func shippedLanguages() -> [String] {
        (Bundle.main.localizations.filter { $0 != "Base" }).sorted()
    }

    private static func localisedBundle(_ language: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    /// The string as this language has it, falling back to the key so a missing
    /// entry shows up as an obviously wrong measurement rather than as a pass.
    private static func localised(_ key: String, in bundle: Bundle) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    private static func width(of text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
