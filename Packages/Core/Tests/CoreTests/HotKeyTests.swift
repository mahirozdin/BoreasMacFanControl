import Foundation
import Testing

@testable import Core

@Suite("Global shortcuts (a combination that eats typing is unrepresentable)")
struct HotKeyTests {

    @Test("a combination without command, option or control cannot exist")
    func bareKeysRefused() {
        // A global hotkey fires wherever the user is typing. `F` would
        // swallow the letter in every application on the machine.
        #expect(HotKey(keyCode: 3, modifiers: []) == nil)
        // Shift does not qualify: ⇧F is still a letter somebody is typing.
        #expect(HotKey(keyCode: 3, modifiers: [.shift]) == nil)
    }

    @Test("any qualifying modifier is enough")
    func qualifyingModifiersAccepted() {
        #expect(HotKey(keyCode: 3, modifiers: [.command]) != nil)
        #expect(HotKey(keyCode: 3, modifiers: [.option]) != nil)
        #expect(HotKey(keyCode: 3, modifiers: [.control]) != nil)
        #expect(HotKey(keyCode: 3, modifiers: [.option, .shift, .command]) != nil)
    }

    @Test("a hand-edited configuration cannot install a shortcut the interface would refuse")
    func decodingEnforcesTheSameRule() {
        let bare = Data(#"{"keyCode":3,"modifiers":8}"#.utf8)  // shift only
        #expect((try? JSONDecoder().decode(HotKey.self, from: bare)) == nil)

        let valid = Data(#"{"keyCode":3,"modifiers":11}"#.utf8)  // ⌘⌥⇧
        #expect((try? JSONDecoder().decode(HotKey.self, from: valid)) != nil)
    }

    @Test("a shortcut round-trips through the configuration unchanged")
    func roundTrips() {
        guard let original = HotKey(keyCode: 11, modifiers: [.command, .option, .shift]) else {
            Issue.record("the combination should be constructible")
            return
        }
        let data = (try? JSONEncoder().encode(original)) ?? Data()
        #expect((try? JSONDecoder().decode(HotKey.self, from: data)) == original)
    }

    @Test("combinations are written the way macOS writes them")
    func displayOrder() {
        let all = HotKey(keyCode: 11, modifiers: [.command, .option, .control, .shift])
        // Control, option, shift, command — the system's own order.
        #expect(all?.displayString == "⌃⌥⇧⌘B")

        #expect(HotKey(keyCode: 49, modifiers: [.command])?.displayString == "⌘Space")
        #expect(HotKey(keyCode: 122, modifiers: [.control])?.displayString == "⌃F1")
    }

    @Test("an unknown key is reported as its code rather than guessed at")
    func unknownKeysAreNotInvented() {
        #expect(HotKey.keyName(for: 200) == "#200")
    }

    @Test("no shortcut action can make the machine quieter without anyone looking")
    func everyActionShowsSomethingOrCoolsMore() {
        // The rule this test protects: a key pressed by accident from
        // inside another application must never be able to reduce cooling.
        // `releaseToFirmware` hands control back to the hardware's own
        // management, which is the safe state every failure path uses.
        for action in HotKeyAction.allCases {
            switch action {
            case .openMainWindow, .openSettings, .boost, .releaseToFirmware:
                // Enumerated deliberately: adding a case makes this test
                // fail to compile, which is the moment to think about it.
                continue
            }
        }
        #expect(HotKeyAction.allCases.count == 4)
        #expect(HotKeyAction.boostMinutes > 0)
    }
}
