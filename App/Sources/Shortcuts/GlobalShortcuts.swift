import Carbon.HIToolbox
import Core
import Foundation
import OSLog
import Observation

/// Registers the global shortcuts with the window server (P6.10).
///
/// **Carbon's `RegisterEventHotKey`, not an `NSEvent` global monitor.** The
/// monitor is the obvious way to watch keys system-wide and it requires
/// Accessibility permission, which invariant I2 forbids this project from
/// ever asking for. Registering a hotkey asks the window server to deliver
/// one specific combination and needs no permission at all — the product
/// gets the feature without the promise being broken. The API is old; the
/// alternative is a permission prompt the project has promised never to
/// show.
///
/// A combination another application already holds cannot be registered.
/// That is reported rather than swallowed: a shortcut that silently does
/// nothing is worse than one the user is told to change.
@MainActor
@Observable
final class GlobalShortcuts {

    /// Actions whose combination the system refused, with the reason
    /// usually being that something else holds it.
    private(set) var refused: Set<HotKeyAction> = []

    /// Invoked on the main actor when a registered combination is pressed.
    var onAction: ((HotKeyAction) -> Void)?

    private var registrations: [UInt32: (action: HotKeyAction, ref: EventHotKeyRef)] = [:]
    private var handler: EventHandlerRef?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "shortcuts")

    /// Four bytes identifying this application's hotkeys to the window
    /// server, so another application's are never mistaken for ours.
    private static let signature: OSType = 0x42_4F_52_45  // "BORE"

    /// Replaces every registration with the given set. Called at launch and
    /// whenever the configuration changes; unregistering first means a
    /// combination that moved does not stay bound to where it was.
    func apply(_ shortcuts: [HotKeyAction: HotKey]) {
        unregisterAll()
        installHandlerIfNeeded()
        refused = []

        for (action, hotKey) in shortcuts {
            register(action: action, hotKey: hotKey)
        }
    }

    private func register(action: HotKeyAction, hotKey: HotKey) {
        guard let index = HotKeyAction.allCases.firstIndex(of: action) else { return }
        let identifier = UInt32(index + 1)
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotKey.keyCode),
            carbonModifiers(hotKey.modifiers),
            EventHotKeyID(signature: Self.signature, id: identifier),
            GetApplicationEventTarget(),
            0,
            &reference)

        guard status == noErr, let reference else {
            // Almost always: another application registered it first.
            refused.insert(action)
            logger.error(
                "could not register \(action.rawValue, privacy: .public): status \(status)")
            return
        }
        registrations[identifier] = (action, reference)
    }

    private func unregisterAll() {
        for (_, registration) in registrations {
            UnregisterEventHotKey(registration.ref)
        }
        registrations = [:]
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // The callback is a C function pointer and cannot capture, so it
        // reaches this instance through an unmanaged pointer handed to the
        // handler as its user data. The instance outlives the handler: it
        // is owned by the application scene for the whole run.
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                // An event this handler does not recognise must be passed
                // on, not consumed. Returning noErr means "handled" and
                // stops Carbon offering the event to any other handler —
                // which would make this application quietly swallow other
                // people's hot keys. The drill caught exactly that.
                guard status == noErr, identifier.signature == GlobalShortcuts.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                // Hot key events arrive on the main run loop, which is the
                // main actor — asserting that is cheaper and more honest
                // than hopping and losing the ordering.
                let handled = MainActor.assumeIsolated { () -> Bool in
                    let shortcuts = Unmanaged<GlobalShortcuts>.fromOpaque(userData)
                        .takeUnretainedValue()
                    return shortcuts.dispatch(identifier.id)
                }
                return handled ? noErr : OSStatus(eventNotHandledErr)
            },
            1, &specification, context, &handler)
        if status != noErr {
            logger.error("hot key handler could not be installed: status \(status)")
        }
    }

    /// Returns whether this instance owns the identifier. The answer
    /// becomes the handler's Carbon result, so an identifier belonging to
    /// somebody else is passed along rather than eaten.
    private func dispatch(_ identifier: UInt32) -> Bool {
        guard let registration = registrations[identifier] else { return false }
        logger.notice("global shortcut fired: \(registration.action.rawValue, privacy: .public)")
        onAction?(registration.action)
        return true
    }

    private func carbonModifiers(_ modifiers: HotKey.Modifiers) -> UInt32 {
        var carbon: Int = 0
        if modifiers.contains(.command) { carbon |= cmdKey }
        if modifiers.contains(.option) { carbon |= optionKey }
        if modifiers.contains(.control) { carbon |= controlKey }
        if modifiers.contains(.shift) { carbon |= shiftKey }
        return UInt32(carbon)
    }

    // No `deinit` cleanup, deliberately. Registrations belong to the
    // process and the window server reclaims them when it exits, and this
    // object lives for the whole run — so a deinit would only ever fire at
    // exit, where it changes nothing. Reaching main-actor state from a
    // nonisolated `deinit` would also mean weakening the isolation of the
    // registration table to buy that nothing.
    //
    // The case that *does* matter — a combination that moved — is handled
    // by `apply` unregistering everything before it registers anything.
}
