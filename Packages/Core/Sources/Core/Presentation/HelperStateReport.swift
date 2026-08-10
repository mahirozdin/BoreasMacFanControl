import Foundation

/// The `--helper-status` contract between the application binary and the `boreas`
/// command line tool (P7.14).
///
/// **Why this type exists at all.** The flag used to print one line — the
/// helper's state as a *localised sentence* — and two callers read it: `boreas
/// status` to show the user, and `boreas profile <name>` to decide whether fan
/// control is available. The second did `answer.contains("enabled")`, so on a
/// Mac set to any of the four non-English languages this product ships, the
/// decision was made against a word that was never going to be there. Measured
/// on one unchanged helper: the flag answered `etkin` under the system locale
/// and `enabled` under `-AppleLanguages '(en)'`, so `boreas profile Quiet`
/// refused with "the fan control helper is not installed" while `boreas status`
/// reported it enabled — one binary, one truth, two answers.
///
/// The repair is not a wider match. **A sentence written for a person is the
/// wrong input for a decision**, so the flag now emits both: a line for the
/// human, and a token for the machine. Formatting and parsing live here, in one
/// place both binaries import, so neither side writes the other's literal.
public enum HelperStateReport: Sendable {

    /// The machine-readable state. Never localised, never shown to a user; it
    /// is a wire value, and translating it is what broke the last one.
    public enum State: String, Sendable, CaseIterable, Equatable {
        case notRegistered = "not-registered"
        case enabled = "enabled"
        case requiresApproval = "requires-approval"
        case notFound = "not-found"
        case unknown = "unknown"
    }

    /// The human line keeps its original prefix and stays first: somebody
    /// running the flag by hand should meet the sentence, not the token, and
    /// anything already scraping this output keeps working.
    public static let summaryPrefix = "helper status: "
    public static let statePrefix = "helper state: "

    /// What the application prints.
    public static func lines(state: State, summary: String) -> String {
        "\(summaryPrefix)\(summary)\n\(statePrefix)\(state.rawValue)"
    }

    /// The machine-readable state, or `nil` when the output does not carry one.
    ///
    /// `nil` is deliberately not `.unknown`: a build too old to emit the token
    /// is a different situation from a helper whose status this build does not
    /// recognise, and a caller that has to tell them apart should be able to.
    public static func state(in output: String) -> State? {
        line(withPrefix: statePrefix, in: output).flatMap(State.init(rawValue:))
    }

    /// The localised sentence, for display. Falls back to the whole trimmed
    /// output so a caller can still show *something* if the format changes.
    public static func summary(in output: String) -> String {
        line(withPrefix: summaryPrefix, in: output)
            ?? output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func line(withPrefix prefix: String, in output: String) -> String? {
        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = raw.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
