import Core
import SwiftUI

/// The automation hooks section of the Notifications tab (P7.10).
///
/// Its own file because the tab was over the length limit with it inline, and
/// because it is its own concern: everything above it configures what macOS
/// shows a person, this configures what leaves the machine.
///
/// **The hooks themselves are edited in the configuration file, not here.** A
/// hook is a URL or a path plus arguments — a text field's worth of syntax the
/// file already expresses well, and an editor for it would be its own task.
/// What belongs in the interface is the part [ADR 0015](../../../docs/architecture/adr/0015-automation-hooks-not-email.md)
/// makes a requirement: **the switch that lets a hook execute code, and the
/// warning beside it.** A user must be able to find and revoke that permission
/// without opening a JSON file.
struct AutomationSection: View {
    let store: ConfigurationStore

    /// The hooks themselves are edited in the configuration file, not here.
    ///
    /// A hook is a URL or a path plus arguments — a text field's worth of
    /// syntax that the file already expresses well, and building an editor for
    /// it would be its own task. What belongs in the interface is the part ADR
    /// 0015 makes a requirement: **the switch that lets a hook execute code,
    /// and the warning beside it.** A user must be able to find and revoke that
    /// permission without opening a JSON file.
    var body: some View {
        SettingsSection(title: automationTitle) {
            Toggle(isOn: automationEnabledBinding) {
                Text(
                    String(
                        localized: "settings.automation.enabled",
                        defaultValue: "Run automation hooks",
                        comment: "Master switch for webhook and command automation hooks"))
            }

            Text(
                String(
                    localized: "settings.automation.detail",
                    defaultValue: """
                        Hooks fire on the notifications that get through, so the rules above \
                        apply to them too. They are defined in the configuration file: a \
                        webhook posts to a URL you choose, a command runs a script on this Mac.
                        """,
                    comment: "Explains when automation hooks run and where they are defined")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: commandHooksBinding) {
                Text(
                    String(
                        localized: "settings.automation.commands",
                        defaultValue: "Allow hooks to run commands",
                        comment: "Switch permitting the command hook, which executes a script"))
            }
            .disabled(!store.configuration.automation.isEnabled)

            // The warning ADR 0015 requires, and it says what the risk actually
            // is rather than "are you sure?".
            Text(
                String(
                    localized: "settings.automation.commands.warning",
                    defaultValue: """
                        A command hook runs a program on this Mac with your account's \
                        privileges, every time a hook fires. Only turn this on for a script \
                        you wrote or have read. It never runs as an administrator, and the \
                        fan helper never runs it.
                        """,
                    comment: "Warning shown beside the switch that permits command hooks")
            )
            .font(.caption)
            .foregroundStyle(Color.warningAccent)
            .fixedSize(horizontal: false, vertical: true)

            if !withheldCommands.isEmpty {
                // Configured but not permitted. Saying so beats leaving the
                // user to wonder why their script never runs.
                Text(
                    String(
                        localized: "settings.automation.withheld",
                        defaultValue: """
                            Command hooks in the configuration file are not running, because \
                            the switch above is off. Count: \(withheldCommands.count)
                            """,
                        comment: "Shown when command hooks exist in the file but are not permitted")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var withheldCommands: [AutomationHook] {
        store.configuration.automation.withheldCommandHooks()
    }

    private var automationTitle: String {
        String(
            localized: "settings.automation.section",
            defaultValue: "Automation hooks",
            comment: "Settings section heading for webhook and command hooks")
    }

    private var automationEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.configuration.automation.isEnabled },
            set: { value in
                store.update { configuration in
                    configuration.automation.isEnabled = value
                    // Turning automation off also withdraws the command
                    // permission. Leaving it armed for the next time the master
                    // switch is flipped would make "off" mean two things.
                    if !value { configuration.automation.commandHooksAllowed = false }
                }
            })
    }

    private var commandHooksBinding: Binding<Bool> {
        Binding(
            get: { store.configuration.automation.commandHooksAllowed },
            set: { value in
                store.update { $0.automation.commandHooksAllowed = value }
            })
    }
}
