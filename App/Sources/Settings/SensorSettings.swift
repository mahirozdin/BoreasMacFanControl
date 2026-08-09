import Core
import SwiftUI

/// Sensor settings (P6.08): rename, re-file and hide individual sensors,
/// plus the report of everything the classifier did not recognise.
///
/// This is the escape hatch ADR 0011 and ADR 0020 argue for: hardware names
/// differ between chip generations, so somebody with an unusual Mac can fix
/// their own machine from configuration instead of waiting for a release —
/// and the uncategorized list is how they find out there is anything to fix.
struct SensorSettings: View {
    let store: ConfigurationStore
    let model: MonitorModel
    let control: ControlModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            uncategorizedReport

            SettingsSection(title: sensorsTitle) {
                Text(
                    String(
                        localized: "settings.sensors.help",
                        defaultValue:
                            """
                            Renaming or re-filing a sensor also changes which curve can \
                            follow it. Hiding one only removes it from the lists: it is \
                            still read, still counts towards its group, and can still \
                            trigger the panic layer.
                            """,
                        comment: "Explains what sensor overrides do and what hiding does not do")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                ForEach(model.allReadings, id: \.id) { reading in
                    SensorOverrideRow(reading: reading, store: store, control: control)
                }

                if model.allReadings.isEmpty {
                    Text(
                        String(
                            localized: "settings.sensors.none",
                            defaultValue: "No sensor is being read right now.",
                            comment: "Shown in the sensor settings when nothing is readable")
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }

    /// Never hidden, never silent: an unrecognised sensor is the only
    /// signal that support for a machine is incomplete (ADR 0020).
    @ViewBuilder
    private var uncategorizedReport: some View {
        let unknown = model.allReadings.filter { $0.group == .uncategorized }
        SettingsSection(title: reportTitle) {
            if unknown.isEmpty {
                Label {
                    Text(
                        String(
                            localized: "settings.sensors.report.clean",
                            defaultValue: "Every sensor on this Mac was recognised.",
                            comment: "Shown when no sensor is uncategorized"))
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
                .font(.callout)
            } else {
                // Phrased so no number has to agree with a verb. Plural
                // forms belong to the String Catalog (P6.11), and a
                // sentence that reads "1 sensors were" in the meantime is
                // a sentence that says nobody looked.
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            String(
                                localized: "settings.sensors.report.count",
                                defaultValue: "Not recognised: \(unknown.count)",
                                comment:
                                    "Reports how many sensors the classifier could not place")
                        )
                        .fontWeight(.medium)

                        Text(
                            String(
                                localized: "settings.sensors.report.detail",
                                defaultValue:
                                    """
                                    Unrecognised sensors are still read and still shown. \
                                    Filing them below teaches this Mac, and the \
                                    unknown-sensor issue template shares the fix with \
                                    everyone else.
                                    """,
                                comment:
                                    "Explains what happens to sensors the classifier cannot place")
                        )
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.warningAccent)
                }
                .font(.callout)
            }
        }
    }

    private var reportTitle: String {
        String(
            localized: "settings.sensors.section.report", defaultValue: "Unrecognised sensors",
            comment: "Settings section heading: the uncategorized sensor report")
    }

    private var sensorsTitle: String {
        String(
            localized: "settings.sensors.section.list", defaultValue: "All sensors",
            comment: "Settings section heading: the editable sensor list")
    }
}

/// One sensor's row: its name, its group, and whether it is shown.
struct SensorOverrideRow: View {
    let reading: SensorReading
    let store: ConfigurationStore
    let control: ControlModel

    private var override: SensorOverride? {
        store.configuration.sensorOverrides[reading.rawName]
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.temperature(reading.celsius))
                .frame(width: 7, height: 7)

            TextField(
                String(
                    localized: "settings.sensors.name", defaultValue: "Name",
                    comment: "Sensor settings column: the sensor's display name"),
                text: nameBinding
            )
            .labelsHidden()
            .frame(width: 170)

            Text(verbatim: reading.rawName)
                .font(.caption)
                .monospaced()
                .foregroundStyle(.tertiary)
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)

            Picker(selection: groupBinding) {
                ForEach(SensorGroup.allCases, id: \.self) { group in
                    Text(verbatim: group.displayName).tag(group)
                }
            } label: {
                Text(
                    String(
                        localized: "settings.sensors.group", defaultValue: "Group",
                        comment: "Sensor settings column: which group the sensor belongs to"))
            }
            .labelsHidden()
            .frame(width: 150)

            Toggle(isOn: shownBinding) {
                Text(
                    String(
                        localized: "settings.sensors.shown", defaultValue: "Shown",
                        comment: "Sensor settings column: whether the sensor appears in the lists"))
            }
            .toggleStyle(.checkbox)

            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    /// Whether this write touches the hidden flag. An `Optional<Bool>`
    /// would say the same thing with one more layer of "which nil is this",
    /// which is the ambiguity lint is objecting to.
    enum HiddenChange {
        case unchanged
        case set(Bool)
    }

    // MARK: - Bindings

    /// An empty name means "no override" rather than a sensor called
    /// nothing — the classifier's own name comes back.
    private var nameBinding: Binding<String> {
        Binding(
            get: { override?.displayName ?? reading.displayName },
            set: { typed in
                let trimmed = typed.trimmingCharacters(in: .whitespaces)
                let normalised = SensorClassifier.normalize(rawName: reading.rawName)
                write(displayName: trimmed.isEmpty || trimmed == normalised ? nil : trimmed)
            })
    }

    private var groupBinding: Binding<SensorGroup> {
        Binding(
            get: { reading.group },
            set: { group in
                write(group: group == SensorClassifier.group(rawName: reading.rawName) ? nil : group)
            })
    }

    private var shownBinding: Binding<Bool> {
        Binding(
            get: { !(override?.hidden ?? false) },
            set: { shown in write(hidden: .set(!shown)) })
    }

    /// Writes one field, keeping the others, and drops the entry entirely
    /// when nothing is overridden any more — a configuration file that
    /// accumulates no-op entries is a file nobody can read.
    private func write(
        displayName: String?? = nil,
        group: SensorGroup?? = nil,
        hidden: HiddenChange = .unchanged
    ) {
        let existing = override
        let name = displayName ?? existing?.displayName
        let newGroup = group ?? existing?.group
        let isHidden: Bool
        switch hidden {
        case .unchanged: isHidden = existing?.hidden ?? false
        case .set(let value): isHidden = value
        }

        store.update { configuration in
            if name == nil, newGroup == nil, !isHidden {
                configuration.sensorOverrides.removeValue(forKey: reading.rawName)
            } else {
                configuration.sensorOverrides[reading.rawName] = SensorOverride(
                    displayName: name, group: newGroup, hidden: isHidden)
            }
        }
    }
}
