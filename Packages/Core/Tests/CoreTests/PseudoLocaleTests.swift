import Foundation
import Testing

@testable import Core

/// The pseudo-locale expansion (P6.13).
///
/// The property that matters is the one the platform's own doubling breaks: a
/// lengthened string must still be a **valid format string with the same
/// placeholders**. Without that, a pseudo-locale can only ever stretch labels
/// that take no arguments, which is most of the interesting ones excluded.
@Suite("Pseudo-locale expansion (longer, without corrupting the format)")
struct PseudoLocaleTests {

    private static let samples = [
        "Temperature",
        "Fan curve",
        "now %@, maximum %@, mean %@",
        "Hottest sensor %lld degrees Celsius",
        "Point %1$lld, %2$lld degrees, %3$lld percent",
        "The fans followed their targets to within %lld rpm on average.",
        "100%% of the range",
        "°C",
    ]

    @Test("expansion reaches the requested factor")
    func reachesTheFactor() {
        for sample in Self.samples {
            let expanded = PseudoLocale.expand(sample, factor: 1.4)
            // Strings made only of specifiers cannot grow, and must not be
            // corrupted in the attempt — those are covered separately below.
            guard !PseudoLocale.literalRuns(of: sample).isEmpty else { continue }
            #expect(
                Double(expanded.count) >= Double(sample.count) * 1.4,
                "\"\(sample)\" grew to \(expanded.count) from \(sample.count)")
        }
    }

    @Test("every format specifier survives expansion, in order")
    func specifiersSurvive() {
        // This is the test that rules out the platform's `-NSDoubleLocalizedStrings`:
        // it turns "%lld" into "lld", so a doubled string can no longer be
        // formatted with the arguments its caller has.
        for sample in Self.samples {
            let expanded = PseudoLocale.expand(sample)
            #expect(
                Self.specifiers(in: expanded) == Self.specifiers(in: sample),
                "\"\(sample)\" became \"\(expanded)\"")
        }
    }

    @Test("a string of nothing but specifiers is returned untouched")
    func pureFormatIsUntouched() {
        // There is no literal text to stretch, and inventing some would corrupt
        // the format. Returning it unchanged is the only safe answer.
        #expect(PseudoLocale.expand("%@") == "%@")
        #expect(PseudoLocale.expand("%lld") == "%lld")
    }

    @Test("an escaped per cent sign is literal text, not a placeholder")
    func escapedPercentIsLiteral() {
        let expanded = PseudoLocale.expand("100%% done")
        #expect(expanded.contains("%%"))
        #expect(Self.specifiers(in: expanded).isEmpty)
        #expect(expanded.count > "100%% done".count)
    }

    @Test("a factor of 1 or less changes nothing")
    func noFactorNoChange() {
        #expect(PseudoLocale.expand("Temperature", factor: 1) == "Temperature")
        #expect(PseudoLocale.expand("Temperature", factor: 0.5) == "Temperature")
        #expect(PseudoLocale.expand("", factor: 2) == "")
    }

    @Test("the diagnostic factor is harsher than the one that fails a build")
    func diagnosticIsHarsher() {
        // If these ever crossed, the drill would be failing on the lenient
        // measurement and reporting the strict one — backwards, and silently.
        #expect(PseudoLocale.diagnosticFactor > PseudoLocale.expansionFactor)
        #expect(PseudoLocale.expansionFactor > 1)
    }

    /// The conversion specifiers in a string, in order, with positional
    /// prefixes kept — reordering a placeholder is as much a corruption as
    /// losing one.
    private static func specifiers(in text: String) -> [String] {
        let pattern = try? NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:lld|lu|ld|[@dfsxX])")
        guard let pattern else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
