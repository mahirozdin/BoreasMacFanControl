import ApplicationServices
import Carbon.HIToolbox
import Core
import Foundation

/// The P6.10 drill: global shortcuts work **without** the Accessibility
/// permission, and a combination somebody else holds is reported rather
/// than silently ignored.
///
/// The claim being tested is an invariant, not a feature. I2 says this
/// project never asks for Accessibility; the obvious way to watch keys
/// system-wide (`NSEvent.addGlobalMonitorForEvents`) requires it. So the
/// drill asserts that this process is **not** trusted for accessibility
/// *and* that registration succeeded anyway — which is the whole argument
/// for using the window server's own hotkey registration.
///
/// What it cannot do is press a key: synthesising one needs the very
/// permission being avoided. It gets as close as is possible without a
/// human — the handler and the action routing are exercised by sending the
/// same Carbon event the window server would send.
@MainActor
enum ShortcutDrill {

    static func run(report: (String) -> Void) {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        // 1. The invariant: this process is not trusted for accessibility.
        //    Nothing below may change that.
        let trustedBefore = AXIsProcessTrusted()
        check("the process is not trusted for accessibility", !trustedBefore)

        guard let combination = HotKey(keyCode: 11, modifiers: [.command, .option, .control, .shift])
        else {
            report("could not build the test combination")
            exit(1)
        }
        report("  using \(combination.displayString)")

        // 2. Registration succeeds with no permission and no prompt.
        let first = GlobalShortcuts()
        var fired: [HotKeyAction] = []
        first.onAction = { fired.append($0) }
        first.apply([.boost: combination])
        check("registered without any permission", first.refused.isEmpty)
        check("still not trusted for accessibility afterwards", !AXIsProcessTrusted())

        // 3. A combination already held cannot be taken, and that is
        //    reported — the failure path the settings window shows.
        let second = GlobalShortcuts()
        second.apply([.boost: combination])
        check("a combination already held is refused, not ignored", second.refused.contains(.boost))

        // 4. The handler and the routing: the same Carbon event the window
        //    server sends, sent by hand. This proves everything except the
        //    keyboard itself.
        sendHotKeyEvent(identifier: 3)  // boost is the third action
        check("a hot key event reaches the action", fired == [.boost])

        // 5. Releasing lets the combination be taken again, so a shortcut
        //    that moves does not stay bound where it was.
        first.apply([:])
        let third = GlobalShortcuts()
        third.apply([.boost: combination])
        check("clearing a shortcut frees the combination", third.refused.isEmpty)
        third.apply([:])

        report(passed ? "SHORTCUT DRILL PASS" : "SHORTCUT DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    /// Sends the event the window server would send when the combination is
    /// pressed. It goes to this application's own event target, so nothing
    /// system-wide is being simulated — only the delivery the handler sees.
    private static func sendHotKeyEvent(identifier: UInt32) {
        var event: EventRef?
        let created = CreateEvent(
            nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed),
            0, OSType(kEventAttributeNone), &event)
        guard created == noErr, let event else { return }
        defer { ReleaseEvent(event) }

        var hotKeyID = EventHotKeyID(signature: 0x42_4F_52_45, id: identifier)
        SetEventParameter(
            event, EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &hotKeyID)
        SendEventToEventTarget(event, GetApplicationEventTarget())
    }
}
