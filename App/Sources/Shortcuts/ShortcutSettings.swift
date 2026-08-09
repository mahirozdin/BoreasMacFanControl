import AppKit
import Core
import SwiftUI

/// The shortcuts section of the settings window (P6.10).
///
/// Every action starts unset. A global combination is a shared resource —
/// once registered, no other application can have it — and helping itself
/// to two of them at first launch is what makes a menu bar utility
/// unwelcome. They are here, plainly, for anyone who wants them.
struct ShortcutSettings: View {
    let store: ConfigurationStore
    let shortcuts: GlobalShortcuts

    var body: some View {
        SettingsSection(title: title) {
            Text(
                String(
                    localized: "settings.shortcuts.help",
                    defaultValue:
                        """
                        These work anywhere, without Boreas being frontmost, and \
                        without any accessibility permission. A combination another \
                        application already holds cannot be taken, and Boreas says so \
                        rather than doing nothing.
                        """,
                    comment: "Explains what global shortcuts are and their one limitation")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            ForEach(HotKeyAction.allCases, id: \.self) { action in
                SettingsRow(label: label(for: action), help: help(for: action)) {
                    HStack(spacing: 8) {
                        ShortcutField(
                            hotKey: store.configuration.shortcuts[action],
                            onChange: { hotKey in
                                store.update { $0.shortcuts[action] = hotKey }
                                shortcuts.apply(store.configuration.shortcuts)
                            })

                        if shortcuts.refused.contains(action) {
                            Label {
                                Text(
                                    String(
                                        localized: "settings.shortcuts.refused",
                                        defaultValue: "already in use elsewhere",
                                        comment:
                                            "Shown when the system refused to register a shortcut"))
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(Color.warningAccent)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var title: String {
        String(
            localized: "settings.shortcuts.section", defaultValue: "Global shortcuts",
            comment: "Settings section heading: system-wide key combinations")
    }

    private func label(for action: HotKeyAction) -> String {
        switch action {
        case .openMainWindow:
            return String(
                localized: "shortcut.mainwindow", defaultValue: "Open the main window",
                comment: "Global shortcut action: bring up the main window")
        case .openSettings:
            return String(
                localized: "shortcut.settings", defaultValue: "Open settings",
                comment: "Global shortcut action: bring up the settings window")
        case .boost:
            return String(
                localized: "shortcut.boost", defaultValue: "Full speed for a while",
                comment: "Global shortcut action: run the fans at full speed temporarily")
        case .releaseToFirmware:
            return String(
                localized: "shortcut.release", defaultValue: "Hand the fans back",
                comment: "Global shortcut action: release fan control to the firmware")
        }
    }

    private func help(for action: HotKeyAction) -> String? {
        switch action {
        case .boost:
            return String(
                localized: "shortcut.boost.help",
                defaultValue: """
                    Runs every fan at full speed for \(HotKeyAction.boostMinutes) minutes, \
                    then hands back to the curve.
                    """,
                comment: "Explains what the boost shortcut does and how long it lasts")
        case .releaseToFirmware:
            return String(
                localized: "shortcut.release.help",
                defaultValue: "Returns the fans to the Mac's own management, as quitting does.",
                comment: "Explains what the release shortcut does")
        case .openMainWindow, .openSettings:
            return nil
        }
    }
}

/// A field that records the next combination pressed into it.
///
/// Recording uses a **local** event monitor, which sees only the keys
/// delivered to this application's own window and therefore needs no
/// permission. Nothing here watches keys system-wide; that job belongs to
/// the window server, through `GlobalShortcuts`.
struct ShortcutField: View {
    let hotKey: HotKey?
    let onChange: (HotKey?) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var rejected = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if isRecording { stopRecording() } else { startRecording() }
            } label: {
                Text(verbatim: fieldText)
                    .font(.callout)
                    .monospacedDigit()
                    .frame(width: 130)
                    .padding(.vertical, 3)
                    .background(
                        isRecording ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5).strokeBorder(
                            isRecording ? Color.accentColor : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if hotKey != nil {
                Button {
                    onChange(nil)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(
                    String(
                        localized: "settings.shortcuts.clear", defaultValue: "Remove this shortcut",
                        comment: "Tooltip of the button that clears a shortcut")
                )
                .accessibilityLabel(
                    String(
                        localized: "settings.shortcuts.clear", defaultValue: "Remove this shortcut",
                        comment: "Tooltip of the button that clears a shortcut"))
            }

            if rejected {
                Text(
                    String(
                        localized: "settings.shortcuts.needsmodifier",
                        defaultValue: "add ⌘, ⌥ or ⌃",
                        comment:
                            "Shown when a recorded combination has no qualifying modifier")
                )
                .font(.caption)
                .foregroundStyle(Color.warningAccent)
            }
        }
        .onDisappear { stopRecording() }
    }

    private var fieldText: String {
        if isRecording {
            return String(
                localized: "settings.shortcuts.recording", defaultValue: "Press keys…",
                comment: "Placeholder while a shortcut is being recorded")
        }
        return hotKey?.displayString
            ?? String(
                localized: "settings.shortcuts.unset", defaultValue: "Not set",
                comment: "Shown for an action with no shortcut assigned")
    }

    private func startRecording() {
        isRecording = true
        rejected = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Escape leaves the field as it was, which is what escape means
            // everywhere else.
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            var modifiers: HotKey.Modifiers = []
            if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
            if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
            if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
            if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }

            if let recorded = HotKey(keyCode: Int(event.keyCode), modifiers: modifiers) {
                onChange(recorded)
                stopRecording()
            } else {
                // The type refused it: a bare key would swallow typing
                // everywhere. Say which modifier is missing instead of
                // silently ignoring the press.
                rejected = true
            }
            // Swallowed either way, so recording a shortcut never also
            // performs whatever that combination normally does.
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
