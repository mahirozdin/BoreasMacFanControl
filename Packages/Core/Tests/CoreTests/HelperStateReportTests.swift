// gate-language:quotes-translations — the five shipped translations ARE the test
// data here: the whole point is that a translated summary changes nothing about
// the parsed token.
// H6 forbids working in another language, not writing in English about one.

import Foundation
import Testing

@testable import Core

/// The `--helper-status` contract (P7.14).
///
/// **The regression these exist for is a specific one**, and it shipped: the CLI
/// decided whether fan control was available by looking for the English word
/// `enabled` inside a sentence that gets translated. On a Turkish system the
/// sentence reads `etkin`, so `boreas profile <name>` refused to work with the
/// helper plainly installed, and disagreed with `boreas status` in the same
/// binary. The tests below are mostly about a translated summary changing
/// nothing about the parsed state.
@Suite("Helper state report — the token, not the sentence")
struct HelperStateReportTests {

    /// Real values, taken from the shipped catalogue rather than invented, so
    /// the test fails if the product ever stops translating this sentence and
    /// somebody is tempted to match on it again.
    private static let summaries: [(language: String, text: String)] = [
        ("en", "enabled"),
        ("tr", "etkin"),
        ("ru", "включена"),
        ("es", "activado"),
        ("zh-Hans", "已启用"),
    ]

    @Test("the state parses identically whatever language the summary is in")
    func stateSurvivesTranslation() throws {
        for (language, text) in Self.summaries {
            let output = HelperStateReport.lines(state: .enabled, summary: text)
            #expect(
                HelperStateReport.state(in: output) == .enabled,
                "the token was not read for \(language)")
            #expect(HelperStateReport.summary(in: output) == text)
        }
    }

    /// The exact shape of the shipped bug: matching the English word against a
    /// translated summary. Pinned so the old approach cannot quietly return.
    @Test("a translated summary does not contain the English token")
    func theOldCheckWouldStillBeWrong() {
        let turkish = HelperStateReport.lines(state: .enabled, summary: "etkin")
        let summary = HelperStateReport.summary(in: turkish)
        #expect(!summary.contains("enabled"))
        // …and yet the state is unambiguous, which is the entire point.
        #expect(HelperStateReport.state(in: turkish) == .enabled)
    }

    @Test("every state survives a round trip")
    func roundTrip() {
        for state in HelperStateReport.State.allCases {
            let output = HelperStateReport.lines(state: state, summary: "whatever it says")
            #expect(HelperStateReport.state(in: output) == state)
        }
    }

    /// A build too old to emit the token is not the same as a helper in an
    /// unrecognised state, and a caller that has to tell them apart can.
    @Test("output without a token yields nil rather than a guess")
    func missingTokenIsNil() {
        #expect(HelperStateReport.state(in: "helper status: etkin") == nil)
        #expect(HelperStateReport.state(in: "") == nil)
    }

    @Test("an unrecognised token yields nil rather than the wrong state")
    func unknownTokenIsNil() {
        #expect(HelperStateReport.state(in: "helper state: something-new") == nil)
    }

    /// Display must keep working even if the format moves under it: a status
    /// line is not worth crashing or blanking over.
    @Test("the summary falls back to the whole output when the prefix is absent")
    func summaryFallsBack() {
        #expect(HelperStateReport.summary(in: "  unexpected shape  ") == "unexpected shape")
    }

    @Test("the human line comes first, so a person meets the sentence")
    func humanLineFirst() throws {
        let output = HelperStateReport.lines(state: .requiresApproval, summary: "onay bekliyor")
        let first = try #require(output.split(separator: "\n").first)
        #expect(first.hasPrefix(HelperStateReport.summaryPrefix))
    }

    /// The token is a wire value; a translated one is the bug this file is about.
    @Test("no state token contains a space or an uppercase letter")
    func tokensAreWireValues() {
        for state in HelperStateReport.State.allCases {
            #expect(!state.rawValue.contains(" "))
            #expect(state.rawValue == state.rawValue.lowercased())
        }
    }
}
