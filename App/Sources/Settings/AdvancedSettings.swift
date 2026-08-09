import AppKit
import Core
import SwiftUI

/// Advanced settings (P6.08): the helper, the configuration file itself,
/// and the way back to defaults.
struct AdvancedSettings: View {
    let store: ConfigurationStore
    let control: ControlModel
    let setup: HelperSetupModel

    @Environment(\.openWindow) private var openWindow
    @State private var lastAction: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: helperTitle) {
                SettingsRow(
                    label: statusLabel,
                    help: String(
                        localized: "settings.advanced.helper.help",
                        defaultValue:
                            """
                            Reading temperatures never needs the helper. It exists only \
                            to write fan speeds, and removing it leaves a fully working \
                            monitor.
                            """,
                        comment: "Explains what the privileged helper is for")
                ) {
                    HStack(spacing: 10) {
                        Text(verbatim: setup.installerState.summary)
                        Button {
                            openWindow(id: HelperSetupView.windowID)
                            NSApplication.shared.activate(ignoringOtherApps: true)
                        } label: {
                            Text(
                                String(
                                    localized: "settings.advanced.helper.open",
                                    defaultValue: "Fan Control…",
                                    comment: "Button opening the helper install and removal window"
                                ))
                        }
                    }
                }
            }

            SettingsSection(title: fileTitle) {
                SettingsRow(label: locationLabel) {
                    HStack(spacing: 10) {
                        Text(verbatim: store.fileURL.path)
                            .font(.caption)
                            .monospaced()
                            .lineLimit(1)
                            .truncationMode(.head)
                            .textSelection(.enabled)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                        } label: {
                            Text(
                                String(
                                    localized: "settings.advanced.reveal", defaultValue: "Show",
                                    comment: "Button revealing the configuration file in Finder"))
                        }
                    }
                }

                SettingsRow(
                    label: transferLabel,
                    help: String(
                        localized: "settings.advanced.transfer.help",
                        defaultValue:
                            """
                            An imported file goes through the same checks as one found \
                            at startup, including migration from an older version. A \
                            file that fails them changes nothing.
                            """,
                        comment: "Explains that import is validated exactly like a normal load")
                ) {
                    HStack(spacing: 10) {
                        Button {
                            exportConfiguration()
                        } label: {
                            Text(
                                String(
                                    localized: "settings.advanced.export", defaultValue: "Export…",
                                    comment: "Button that writes the configuration to a chosen file"
                                ))
                        }
                        Button {
                            importConfiguration()
                        } label: {
                            Text(
                                String(
                                    localized: "settings.advanced.import", defaultValue: "Import…",
                                    comment: "Button that loads a configuration from a chosen file"))
                        }
                    }
                }

                if let migrated = store.migratedFromVersion {
                    statusLine(
                        String(
                            localized: "settings.advanced.migrated",
                            defaultValue:
                                """
                                This configuration was upgraded from version \(migrated). \
                                The original is beside it as config.backup.json.
                                """,
                            comment: "Reports that the configuration was migrated on load"),
                        systemImage: "arrow.up.circle", tint: .secondary)
                }
                if let problem = store.problem {
                    statusLine(
                        String(
                            localized: "settings.advanced.problem",
                            defaultValue:
                                """
                                The configuration file was refused at \
                                \(problem.fieldPath) and the last valid settings are in use.
                                """,
                            comment: "Reports that the configuration file could not be used"),
                        systemImage: "exclamationmark.triangle", tint: .panicAccent)
                }
                if let writeProblem = store.writeProblem {
                    statusLine(
                        String(
                            localized: "settings.advanced.writeproblem",
                            defaultValue: "Settings could not be saved: \(writeProblem)",
                            comment: "Reports that writing the configuration file failed"),
                        systemImage: "exclamationmark.triangle", tint: .panicAccent)
                }
                if let lastAction {
                    statusLine(lastAction, systemImage: "checkmark.circle", tint: .secondary)
                }
            }

            SettingsSection(title: resetTitle) {
                SettingsRow(
                    label: resetLabel,
                    help: String(
                        localized: "settings.advanced.reset.help",
                        defaultValue:
                            """
                            Restores every setting, profile and curve to the built-in \
                            defaults. The previous file is kept as config.backup.json.
                            """,
                        comment: "Explains what resetting to defaults does")
                ) {
                    Button(role: .destructive) {
                        store.resetToDefaults()
                        control.reloadFromConfiguration()
                        lastAction = String(
                            localized: "settings.advanced.reset.done",
                            defaultValue: "Settings restored to defaults.",
                            comment: "Confirms that the configuration was reset")
                    } label: {
                        Text(
                            String(
                                localized: "settings.advanced.reset.button",
                                defaultValue: "Restore Defaults",
                                comment: "Button that resets the whole configuration"))
                    }
                }
            }
        }
        .padding(20)
    }

    private func statusLine(_ text: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
        .font(.caption)
    }

    // MARK: - File transfer

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "boreas-config.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        lastAction =
            store.export(to: url)
            ? String(
                localized: "settings.advanced.export.done", defaultValue: "Configuration exported.",
                comment: "Confirms a successful configuration export")
            : String(
                localized: "settings.advanced.export.failed",
                defaultValue: "The configuration could not be written there.",
                comment: "Reports a failed configuration export")
    }

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if store.importFrom(url) {
            control.reloadFromConfiguration()
            lastAction = String(
                localized: "settings.advanced.import.done", defaultValue: "Configuration imported.",
                comment: "Confirms a successful configuration import")
        } else {
            lastAction = String(
                localized: "settings.advanced.import.failed",
                defaultValue: "That file was refused; nothing changed.",
                comment: "Reports a refused configuration import")
        }
    }

    private var helperTitle: String {
        String(
            localized: "settings.advanced.section.helper", defaultValue: "Fan control helper",
            comment: "Settings section heading: the privileged helper")
    }

    private var fileTitle: String {
        String(
            localized: "settings.advanced.section.file", defaultValue: "Configuration file",
            comment: "Settings section heading: the configuration file on disk")
    }

    private var resetTitle: String {
        String(
            localized: "settings.advanced.section.reset", defaultValue: "Reset",
            comment: "Settings section heading: restoring defaults")
    }

    private var statusLabel: String {
        String(
            localized: "settings.advanced.status", defaultValue: "Status",
            comment: "Label of the helper status row")
    }

    private var locationLabel: String {
        String(
            localized: "settings.advanced.location", defaultValue: "Location",
            comment: "Label of the configuration file path row")
    }

    private var transferLabel: String {
        String(
            localized: "settings.advanced.transfer", defaultValue: "Transfer",
            comment: "Label of the export and import row")
    }

    private var resetLabel: String {
        String(
            localized: "settings.advanced.reset", defaultValue: "Restore defaults",
            comment: "Label of the reset row")
    }
}
