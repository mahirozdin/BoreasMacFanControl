import Foundation

/// Artificially lengthened strings, for the layout test (P6.13).
///
/// **Why invariant Y3 needs this and nothing else.** Y3 forbids a text container
/// with a fixed pixel width or height, and the reason has always been written
/// down as Dynamic Type. P6.12 measured that and found it inert on macOS —
/// `dynamicTypeSize` produces an identical layout at `xSmall` and
/// `accessibility5`. So the thing that actually stretches a label in this
/// product is **translation**, which makes this the only check Y3 has.
///
/// **Why this is not `-NSDoubleLocalizedStrings`.** Foundation ships that flag
/// and it does lengthen strings, but it corrupts format specifiers on the way —
/// `Hottest sensor %lld degrees` comes back as `Hottest sensor lld degrees
/// Hottest sensor 97 degrees`. Harmless when all you want is length, useless if
/// you also want to know that a placeholder survived, and it is fixed at 200%.
/// The flag stays useful for producing *renders* a human can look at; the
/// measured check uses this instead.
public enum PseudoLocale {

    /// How much longer a translation is allowed to be before the layout has to
    /// cope with it.
    ///
    /// **140%, not 200%.** Doubling is the number the tooling reaches for, and
    /// it is a deliberate overshoot: measured expansion from English into
    /// German or Russian — the two languages this product will meet in P7.06 —
    /// clusters around a third to a half again as long. Holding fixed-width
    /// columns to 200% would mean sizing every one of them for a language that
    /// does not exist, and spending that width on nothing is a real cost paid
    /// in every language including English.
    public static let expansionFactor = 1.4

    /// The harsher factor, kept for diagnosis rather than for judgement.
    ///
    /// A container that clears `expansionFactor` but not this one is not a
    /// defect; it is a container with less headroom than another. The layout
    /// drill reports the difference instead of failing on it, because a check
    /// that fails on something acceptable teaches people to ignore it.
    public static let diagnosticFactor = 2.0

    /// Lengthens a string to at least `factor` times its length, without
    /// touching anything a formatter will later read.
    ///
    /// Format specifiers, and the text between them, are preserved exactly:
    /// only the *literal* runs grow. That is the whole difference from the
    /// platform's own doubling, and it means a pseudo string can still be
    /// handed to `String(format:)` with the arguments the real one expects.
    ///
    /// Padding is appended per literal run rather than by repeating the whole
    /// string, so the result still reads as one label of plausible shape rather
    /// than as the same sentence twice — which matters when a human is looking
    /// at the render and deciding whether the truncation they see is real.
    public static func expand(_ source: String, factor: Double = expansionFactor) -> String {
        guard factor > 1, !source.isEmpty else { return source }

        let runs = literalRuns(of: source)
        // Nothing but specifiers: there is no literal text to stretch, and
        // inventing some would corrupt the format.
        guard !runs.isEmpty else { return source }

        // The padding is distributed over the literal runs in proportion to
        // their own length, so a long sentence grows mostly in its long parts.
        let literalLength = runs.reduce(0) { $0 + $1.count }
        let wanted = Int((Double(source.count) * factor).rounded(.up)) - source.count
        guard wanted > 0, literalLength > 0 else { return source }

        var result = ""
        var index = source.startIndex
        var remaining = wanted
        for (position, run) in runs.enumerated() {
            guard let runRange = source.range(of: run, range: index..<source.endIndex) else {
                continue
            }
            result += source[index..<runRange.upperBound]
            index = runRange.upperBound

            // The last run takes whatever is left, so rounding cannot leave the
            // result a character short of the factor.
            let share =
                position == runs.count - 1
                ? remaining
                : Int((Double(wanted) * Double(run.count) / Double(literalLength)).rounded())
            let padding = min(share, remaining)
            if padding > 0 {
                result += String(repeating: padCharacter, count: padding)
                remaining -= padding
            }
        }
        result += source[index...]
        return result
    }

    /// A letter, deliberately, rather than a punctuation mark or a diacritic.
    ///
    /// The padding has to occupy roughly the width real text would, and it has
    /// to be visibly *not* the original — so it is a wide-ish lowercase letter
    /// a reader will not mistake for a translation. A repeated `x` is the
    /// convention; a diacritic-heavy alternative would also test the font's
    /// coverage, which is a different question and not this one.
    private static let padCharacter: Character = "x"

    /// The literal runs of a format string — everything that is not a
    /// conversion specifier.
    ///
    /// Hand-scanned rather than done with a regular expression so the rule is
    /// visible: a `%` starts a specifier, `%%` is an escaped percent sign and
    /// counts as literal text, and a specifier ends at its conversion
    /// character.
    static func literalRuns(of source: String) -> [String] {
        var runs: [String] = []
        var current = ""
        var characters = Array(source)
        var index = 0

        while index < characters.count {
            guard characters[index] == "%" else {
                current.append(characters[index])
                index += 1
                continue
            }
            // `%%` is a literal per cent sign, not a placeholder.
            if index + 1 < characters.count, characters[index + 1] == "%" {
                current.append("%%")
                index += 2
                continue
            }
            if !current.isEmpty {
                runs.append(current)
                current = ""
            }
            // Skip to the end of the specifier: flags, width, positional
            // markers and length modifiers, then the conversion character.
            index += 1
            while index < characters.count, !"diouxXeEfgGcsSpaA@".contains(characters[index]) {
                index += 1
            }
            if index < characters.count { index += 1 }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }
}
