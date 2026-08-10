import Foundation
import Testing

@testable import Core

/// Automation hooks (P7.10, ADR 0015).
///
/// **Most of these are about something not running.** The command hook can
/// execute arbitrary code with the user's privileges, so the tests that matter
/// are the ones proving it stays still: off by default, off when the main
/// switch is off, and off when it is listed but not permitted.
@Suite("Automation hooks — off until asked, twice")
struct AutomationTests {

    private static let webhook = AutomationHook.webhook(
        url: "https://example.com/hook", method: "POST", template: "${kind}")
    private static let command = AutomationHook.command(
        path: "/usr/bin/true", arguments: ["${sensor}", "${celsius}"])

    // MARK: - The gate

    @Test("a fresh configuration runs nothing at all")
    func defaultsRunNothing() {
        let settings = AutomationSettings()
        #expect(settings.isEnabled == false)
        #expect(settings.commandHooksAllowed == false)
        #expect(settings.runnable().isEmpty)
    }

    @Test("the main switch alone does not release a command hook")
    func mainSwitchDoesNotReleaseCommands() {
        let settings = AutomationSettings(
            isEnabled: true, hooks: [Self.webhook, Self.command])
        let runnable = settings.runnable()
        #expect(runnable.count == 1)
        #expect(runnable.first == Self.webhook)
        #expect(settings.withheldCommandHooks() == [Self.command])
    }

    @Test("both switches on releases both kinds")
    func bothSwitchesRunEverything() {
        let settings = AutomationSettings(
            isEnabled: true, commandHooksAllowed: true, hooks: [Self.webhook, Self.command])
        #expect(settings.runnable().count == 2)
        #expect(settings.withheldCommandHooks().isEmpty)
    }

    /// Permitting commands while the main switch is off must not run them.
    /// The two switches are an AND, and the order they are set in is not the
    /// user's problem.
    @Test("permitting commands with the main switch off still runs nothing")
    func commandsPermittedButMainSwitchOff() {
        let settings = AutomationSettings(
            isEnabled: false, commandHooksAllowed: true, hooks: [Self.webhook, Self.command])
        #expect(settings.runnable().isEmpty)
    }

    @Test("a command hook is the one that executes code")
    func executesCode() {
        #expect(Self.command.executesCode)
        #expect(!Self.webhook.executesCode)
    }

    // MARK: - Limits

    @Test("a hostile timeout and concurrency are clamped, not refused")
    func limitsAreClamped() {
        let hostile = AutomationSettings(timeoutSeconds: 600, maximumConcurrent: 500)
        #expect(hostile.timeoutSeconds == AutomationSettings.timeoutRange.upperBound)
        #expect(hostile.maximumConcurrent == AutomationSettings.concurrencyRange.upperBound)

        let tiny = AutomationSettings(timeoutSeconds: 0, maximumConcurrent: 0)
        #expect(tiny.timeoutSeconds == AutomationSettings.timeoutRange.lowerBound)
        #expect(tiny.maximumConcurrent == AutomationSettings.concurrencyRange.lowerBound)
    }

    @Test("a hostile document is clamped through the decoder too")
    func decodedLimitsAreClamped() throws {
        let json = """
            {"isEnabled": true, "timeoutSeconds": 9999, "maximumConcurrent": 9999}
            """
        let settings = try JSONDecoder().decode(
            AutomationSettings.self, from: Data(json.utf8))
        #expect(settings.timeoutSeconds == 60)
        #expect(settings.maximumConcurrent == 8)
        // Not mentioned in the document, so still off.
        #expect(settings.commandHooksAllowed == false)
    }

    // MARK: - Wire format

    @Test("each hook round-trips through its type discriminator")
    func hooksRoundTrip() throws {
        for hook in [Self.webhook, Self.command] {
            let data = try JSONEncoder().encode(hook)
            #expect(try JSONDecoder().decode(AutomationHook.self, from: data) == hook)
        }
    }

    @Test("a webhook without a method defaults to POST")
    func webhookMethodDefaults() throws {
        let json = #"{"type": "webhook", "url": "https://example.com"}"#
        let hook = try JSONDecoder().decode(AutomationHook.self, from: Data(json.utf8))
        #expect(hook == .webhook(url: "https://example.com", method: "POST", template: ""))
    }

    // MARK: - Templates

    @Test("every documented placeholder expands")
    func placeholdersExpand() {
        // Not a value ending in 5: `%.1f` over a binary double rounds 81.25
        // down to 81.2, which is correct and would only make this test look
        // fragile about something it is not testing.
        let context = AutomationContext(
            kind: .thresholdCrossed, subject: "compute", celsius: 81.6,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000))
        let expanded = AutomationTemplate.expand(
            "${kind} ${subject} ${sensor} ${celsius}", with: context)
        #expect(expanded == "thresholdCrossed compute compute 81.6")
        #expect(
            AutomationTemplate.expand("${timestamp}", with: context).hasPrefix("2027-01-15T"))
    }

    /// A typo that expanded to nothing would produce a body that looks
    /// deliberate and is wrong. Left as written, it names itself.
    @Test("an unknown placeholder is left exactly as written")
    func unknownPlaceholderSurvives() {
        let context = AutomationContext(kind: .panicEngaged, timestamp: Date())
        #expect(
            AutomationTemplate.expand("${sesnor}", with: context) == "${sesnor}")
    }

    /// Absent is not the same as mistyped: a profile change has no temperature,
    /// and that is a fact about the event rather than an error in the template.
    @Test("a placeholder with no value this time expands to empty")
    func absentValueExpandsEmpty() {
        let context = AutomationContext(kind: .profileChanged, subject: "Quiet", timestamp: Date())
        #expect(AutomationTemplate.expand("[${celsius}]", with: context) == "[]")
        #expect(AutomationTemplate.expand("[${subject}]", with: context) == "[Quiet]")
    }

    /// The value is parsed by somebody's script, so the decimal separator must
    /// not follow the machine's locale.
    @Test("celsius formats with a dot wherever the machine is")
    func celsiusIsMachineReadable() {
        let context = AutomationContext(
            kind: .thresholdCrossed, celsius: 72.05, timestamp: Date())
        let value = AutomationTemplate.expand("${celsius}", with: context)
        #expect(value.contains("."))
        #expect(!value.contains(","))
    }
}

/// The `shortcuts` on-disk shape, corrected in P7.10.
///
/// It used to be Swift's alternating array for a dictionary with an enum key —
/// `["boost", {…}]` — which round-trips correctly and is unpleasant to edit by
/// hand. Nobody noticed in P6.10 because all four shortcuts ship unset, so it
/// had never reached a real file.
@Suite("Shortcuts on disk — an object, and older files still load")
struct ShortcutsEncodingTests {

    // Force-unwrapped in a test on purpose: the initialiser is failable
    // because it refuses a combination with no qualifying modifier, and
    // this one has command+option. A nil here is a broken test, not a case
    // to handle.
    /// `HotKey` refuses a combination with no qualifying modifier, so this one
    /// carries command+option. Unwrapped with `#require` rather than `!`: the
    /// lint rule is right that a force unwrap is a crash waiting for somebody's
    /// typo, and `#require` fails the test with the reason instead.
    private func key() throws -> HotKey {
        try #require(HotKey(keyCode: 100, modifiers: [.command, .option]))
    }

    @Test("shortcuts are written as an object keyed by action name")
    func writesAnObject() throws {
        let file = ConfigurationFile(shortcuts: [.boost: try key()])
        let data = try JSONEncoder().encode(file)
        let json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let shortcuts = try #require(json["shortcuts"] as? [String: Any])
        #expect(shortcuts.keys.contains("boost"))
        // The shape that used to ship would have been an array here.
        #expect(!(json["shortcuts"] is [Any]))
    }

    @Test("the object form round-trips")
    func objectRoundTrips() throws {
        let file = ConfigurationFile(shortcuts: [.boost: try key(), .releaseToFirmware: try key()])
        let data = try JSONEncoder().encode(file)
        let back = try JSONDecoder().decode(ConfigurationFile.self, from: data)
        #expect(back.shortcuts == file.shortcuts)
    }

    /// A file written by any build before P7.10. It does not stop being valid
    /// because the writer improved.
    @Test("the legacy alternating array still loads")
    func legacyArrayStillLoads() throws {
        let json = """
            {"schemaVersion": 1, "shortcuts": ["boost", {"keyCode": 100, "modifiers": 3}]}
            """
        let file = try JSONDecoder().decode(ConfigurationFile.self, from: Data(json.utf8))
        #expect(file.shortcuts == [.boost: try key()])
    }

    /// The P6.10 rule, unchanged: refused rather than silently dropped.
    @Test("an unrecognised action name is refused")
    func unknownActionIsRefused() {
        let json = """
            {"schemaVersion": 1, "shortcuts": {"summonADragon": {"keyCode": 1, "modifiers": 0}}}
            """
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ConfigurationFile.self, from: Data(json.utf8))
        }
    }

    @Test("a missing section means no shortcuts, not a failure")
    func missingSectionIsFine() throws {
        let file = try JSONDecoder().decode(
            ConfigurationFile.self, from: Data(#"{"schemaVersion": 1}"#.utf8))
        #expect(file.shortcuts.isEmpty)
        #expect(file.automation == AutomationSettings())
    }
}
