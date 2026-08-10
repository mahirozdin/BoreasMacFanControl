import Core
import SwiftUI

/// The Recording tab (P7.02), the second of the two P6.08 left out.
///
/// P6.08's reasoning — a tab of switches controlling a subsystem that does not
/// exist is what the honesty rule forbids — held until the subsystem existed. It
/// does now, so the settings window is finally the seven tabs the blueprint asks
/// for.
struct RecordingSettingsTab: View {
    let store: ConfigurationStore
    let recording: RecordingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            enableSwitch
            Divider()
            formatAndInterval
            Divider()
            limits
            Divider()
            state
        }
        .onAppear { recording.refreshStatus() }
    }

    private var settings: RecordingSettings { store.configuration.recording }

    // MARK: - The switch

    private var enableSwitch: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                isOn: Binding(
                    get: { settings.isEnabled },
                    set: { wanted in store.update { $0.recording.isEnabled = wanted } })
            ) {
                Text(
                    String(
                        localized: "settings.record.enable",
                        defaultValue: "Record measurements to a file",
                        comment: "Main switch for measurement recording"))
            }
            .font(.headline)

            Text(
                String(
                    localized: "settings.record.note",
                    defaultValue: """
                        Off unless you ask for it. Every sample is written locally and \
                        nothing is ever sent anywhere.
                        """,
                    comment: "Explains that recording is local only and off by default")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Format and interval

    private var formatAndInterval: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(
                selection: Binding(
                    get: { settings.format },
                    set: { value in store.update { $0.recording.format = value } })
            ) {
                ForEach(RecordingFormat.allCases, id: \.self) { format in
                    Text(verbatim: format.settingsLabel).tag(format)
                }
            } label: {
                Text(
                    String(
                        localized: "settings.record.format", defaultValue: "Format",
                        comment: "Picker choosing the recording file format"))
            }
            .frame(maxWidth: 320)

            Text(verbatim: settings.format.settingsExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(
                    String(
                        localized: "settings.record.interval",
                        defaultValue: "Write a sample every",
                        comment: "Label of the recording interval stepper"))
                Stepper(
                    value: Binding(
                        get: { settings.intervalSeconds },
                        set: { value in store.update { $0.recording.intervalSeconds = value } }),
                    in: RecordingSettings.intervalRange, step: 5
                ) {
                    Text(
                        String(
                            localized: "settings.record.interval.value",
                            defaultValue: "\(settings.intervalSeconds) s",
                            comment: "The recording interval in seconds")
                    )
                    .monospacedDigit()
                }
            }
        }
        .disabled(!settings.isEnabled)
    }

    // MARK: - Limits

    private var limits: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "settings.record.section.limits", defaultValue: "Limits",
                    comment: "Heading of the recording retention and disk limit section")
            )
            .font(.headline)

            HStack(spacing: 8) {
                Text(
                    String(
                        localized: "settings.record.retention", defaultValue: "Keep files for",
                        comment: "Label of the recording retention stepper"))
                Stepper(
                    value: Binding(
                        get: { settings.retentionDays },
                        set: { value in store.update { $0.recording.retentionDays = value } }),
                    in: RecordingSettings.retentionRange
                ) {
                    Text(
                        String(
                            localized: "settings.record.retention.value",
                            defaultValue: "\(settings.retentionDays) days",
                            comment: "The recording retention period in days")
                    )
                    .monospacedDigit()
                }
            }

            HStack(spacing: 8) {
                Text(
                    String(
                        localized: "settings.record.ceiling", defaultValue: "Never use more than",
                        comment: "Label of the recording disk ceiling stepper"))
                Stepper(
                    value: Binding(
                        get: { settings.diskCeilingBytes / 100_000_000 },
                        set: { value in
                            store.update { $0.recording.diskCeilingBytes = value * 100_000_000 }
                        }),
                    in: 1...200
                ) {
                    Text(
                        String(
                            localized: "settings.record.ceiling.value",
                            defaultValue: "\(settings.diskCeilingBytes / 1_000_000) MB",
                            comment: "The recording disk ceiling in megabytes")
                    )
                    .monospacedDigit()
                }
            }

            Text(
                String(
                    localized: "settings.record.ceiling.note",
                    defaultValue: """
                        This limit wins over the one above it. If recordings reach it, \
                        the oldest are deleted even when they are newer than the \
                        retention period.
                        """,
                    comment: "Explains that the disk ceiling overrides the retention setting")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(!settings.isEnabled)
    }

    // MARK: - State

    /// What is actually on disk, and what the limits have had to do about it.
    ///
    /// The ceiling deleting a file the user asked to keep is **surfaced here
    /// rather than notified**: it is a standing condition, not an event, and it
    /// keeps being true until they raise the ceiling or shorten retention. A
    /// notification would interrupt once and then be gone.
    private var state: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                String(
                    localized: "settings.record.section.state", defaultValue: "On disk",
                    comment: "Heading of the recording status section")
            )
            .font(.headline)

            Text(
                String(
                    localized: "settings.record.state.summary",
                    defaultValue: """
                        \(recording.status.fileCount) file(s), \
                        \(recording.status.totalBytes / 1_000_000) MB
                        """,
                    comment: "How many recording files exist and how much space they use")
            )
            .font(.callout)
            .monospacedDigit()

            if recording.status.ceilingDeletedCount > 0 {
                Label {
                    Text(
                        String(
                            localized: "settings.record.state.ceiling",
                            defaultValue: """
                                The size limit has deleted \
                                \(recording.status.ceilingDeletedCount) file(s) this session. \
                                Raise the limit or shorten the retention period to keep more.
                                """,
                            comment: "Shown when the disk ceiling has had to delete recordings")
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.warningAccent)
                }
                .font(.caption)
            }

            if let error = recording.status.lastError {
                Label {
                    Text(
                        String(
                            localized: "settings.record.state.error",
                            defaultValue: "The last write did not succeed: \(error)",
                            comment: "Shown when a recording write failed")
                    )
                    .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.panicAccent)
                }
                .font(.caption)
            }

            Button {
                recording.revealInFinder()
            } label: {
                Text(
                    String(
                        localized: "settings.record.reveal", defaultValue: "Show in Finder",
                        comment: "Button opening the recordings folder"))
            }
        }
    }
}

extension RecordingFormat {

    var settingsLabel: String {
        switch self {
        case .jsonl:
            return String(
                localized: "settings.record.format.jsonl", defaultValue: "JSON Lines",
                comment: "Recording format: one JSON object per line")
        case .csv:
            return String(
                localized: "settings.record.format.csv", defaultValue: "CSV",
                comment: "Recording format: comma separated values")
        }
    }

    var settingsExplanation: String {
        switch self {
        case .jsonl:
            return String(
                localized: "settings.record.format.jsonl.note",
                defaultValue: """
                    One line per sample. Best for scripts, and a file cut short by a \
                    power loss is still readable up to its last complete line.
                    """,
                comment: "Explains what the JSON Lines recording format is good for")
        case .csv:
            return String(
                localized: "settings.record.format.csv.note",
                defaultValue: """
                    Opens directly in a spreadsheet. The columns are fixed when a file \
                    starts, so a sensor that appears later in the day is not in it.
                    """,
                comment: "Explains what the CSV recording format is good for and its limitation")
        }
    }
}
