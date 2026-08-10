import Core
import SwiftUI

/// One line of the sensor table.
struct SensorRow: Identifiable, Hashable {
    let id: String
    let name: String
    let group: SensorGroup
    let current: Double
    let maximum: Double?
    let mean: Double?
}

/// Which column the table is sorted by.
enum SensorColumn: String, CaseIterable, Hashable {
    case name
    case group
    case current
    case maximum
    case mean

    /// The catalogue key for `displayName`, derived from `rawValue` rather than
    /// written twice.
    ///
    /// The P6.13 layout drill needs each header in *every* language, not just
    /// the current one, and that means the key rather than the resolved string.
    /// Deriving it keeps the same fact in one place — and the drill asserts the
    /// derivation still resolves to `displayName`, so a renamed key fails loudly
    /// instead of silently measuring the key text itself.
    var localizationKey: String { "table.column.\(rawValue)" }

    var displayName: String {
        switch self {
        case .name:
            return String(
                localized: "table.column.name", defaultValue: "Sensor",
                comment: "Sensor table column: the sensor's name")
        case .group:
            return String(
                localized: "table.column.group", defaultValue: "Group",
                comment: "Sensor table column: which group the sensor belongs to")
        case .current:
            return String(
                localized: "table.column.current", defaultValue: "Now",
                comment: "Sensor table column: the current reading")
        case .maximum:
            return String(
                localized: "table.column.maximum", defaultValue: "Highest",
                comment: "Sensor table column: the highest reading this session")
        case .mean:
            return String(
                localized: "table.column.mean", defaultValue: "Average",
                comment: "Sensor table column: the average reading this session")
        }
    }
}

/// The sensor table (P6.04): every sensor with its current, session peak
/// and session average, sortable and filterable.
///
/// Hand-rolled from primitives rather than built on `Table`: the P6.02
/// render evidence proved that AppKit-backed SwiftUI containers draw
/// nothing under `ImageRenderer`, and a table that cannot appear in the
/// evidence is a table nobody has actually looked at.
struct SensorTable: View {
    let rows: [SensorRow]
    @Binding var column: SensorColumn
    @Binding var ascending: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ForEach(sorted) { row in
                SensorTableRow(row: row)
                Divider().opacity(0.4)
            }
            if rows.isEmpty {
                Text(
                    String(
                        localized: "table.empty",
                        defaultValue: "No sensor matches this filter.",
                        comment: "Shown when the sensor table filter excludes every sensor")
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
        }
    }

    private var sorted: [SensorRow] {
        let ordered = rows.sorted { left, right in
            switch column {
            case .name: return left.name.localizedStandardCompare(right.name) == .orderedAscending
            case .group: return left.group.rawValue < right.group.rawValue
            case .current: return left.current < right.current
            // A sensor with no statistic yet sorts as the coldest rather
            // than jumping to the top of a "highest" sort.
            case .maximum: return (left.maximum ?? -.infinity) < (right.maximum ?? -.infinity)
            case .mean: return (left.mean ?? -.infinity) < (right.mean ?? -.infinity)
            }
        }
        return ascending ? ordered : ordered.reversed()
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(SensorColumn.allCases, id: \.self) { entry in
                Button {
                    if column == entry {
                        ascending.toggle()
                    } else {
                        column = entry
                        ascending = entry == .name || entry == .group
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(verbatim: entry.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                        // The sort marker is a glyph, not a colour: the
                        // sorted column has to be readable without hue.
                        if column == entry {
                            Image(systemName: ascending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(width: Self.width(of: entry), alignment: Self.alignment(of: entry))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                // The chevron says which column sorts the table and which way.
                // A glyph is enough to *see* it and nothing to hear it, so the
                // direction becomes the header's accessibility value — and the
                // sorted column gains the selected trait, which is how
                // VoiceOver announces "this is the active one" natively.
                .accessibilityLabel(entry.displayName)
                .accessibilityValue(column == entry ? sortOrderText : "")
                .accessibilityAddTraits(column == entry ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private var sortOrderText: String {
        ascending
            ? String(
                localized: "sensors.sort.ascending", defaultValue: "sorted ascending",
                comment: "VoiceOver value of the sensor table column currently sorted upwards")
            : String(
                localized: "sensors.sort.descending", defaultValue: "sorted descending",
                comment: "VoiceOver value of the sensor table column currently sorted downwards")
    }

    /// Column widths, **set by measurement rather than by eye.**
    ///
    /// The P6.13 layout drill measures every header and every group name that
    /// can land in these columns, in every shipped language, against a 1.4×
    /// expansion budget (`Core.PseudoLocale.expansionFactor`) — and the numbers
    /// it started from failed. Turkish "Performans çekirdekleri" needed 144 pt
    /// of a 130 pt column, so the group column was **truncating in the shipped
    /// product**, not merely at risk of it. English "Performance cores" cleared
    /// 130 pt but not the budget, and the Turkish "En yüksek" header did the
    /// same to the 70 pt numeric columns.
    ///
    /// The sensor name column gave up the width the group column needed: names
    /// are raw sensor keys ("PMU tdie5", "NAND CH0 temp"), they are not
    /// localised, and they already truncate in the middle by design.
    ///
    /// **The group column is the widest in the table, and that is a real cost.**
    /// It is sized for "Performans çekirdekleri", a name that per
    /// [ADR 0020](../../../docs/architecture/adr/0020-compute-die-sensor-group.md)
    /// may never appear on Apple Silicon at all — the classifier cannot
    /// attribute a `PMU tdie<n>` to a cluster. The width is reserved anyway:
    /// the layout is static, the group *can* occur, and a column that clips is
    /// a Y3 violation whether or not the case is common.
    ///
    /// **Widened again in P7.06**, when three more languages arrived and the drill
    /// named four violations on the first run — Russian "Максимум" wanted 85.1 pt
    /// of 82, and "Производительные ядра" 216.5 of 215. That is the check doing
    /// exactly what P6.13 built it for: catching a clipped label on the day a
    /// language lands rather than in a bug report months later.
    ///
    /// Change one of these and run `--layout-drill`; it will say whether the new
    /// number holds. The expansion pads with a representative letter, so the
    /// measured width of a 1.4×-longer string is slightly more than 1.4× the
    /// original — which is why these numbers are not simply the naturals × 1.4.
    static func width(of column: SensorColumn) -> CGFloat {
        switch column {
        case .name: return 200
        case .group: return 220
        case .current, .maximum, .mean: return 88
        }
    }

    static func alignment(of column: SensorColumn) -> Alignment {
        switch column {
        case .name, .group: return .leading
        default: return .trailing
        }
    }
}

/// One rendered row. Split out so the table's own body stays inside the
/// lint budget and the row can be reasoned about on its own.
private struct SensorTableRow: View {
    let row: SensorRow

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.temperature(row.current))
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text(verbatim: row.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: SensorTable.width(of: .name), alignment: .leading)

            Text(verbatim: row.group.displayName)
                .foregroundStyle(.secondary)
                .frame(width: SensorTable.width(of: .group), alignment: .leading)

            numeric(row.current)
            numeric(row.maximum)
            numeric(row.mean)

            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.vertical, 3)
        // Six fragments become one sentence, and the three numbers get named:
        // read as separate cells they arrive as "62.4, 71.2, 58.9" with
        // nothing to say which is now, which is the maximum and which is the
        // mean. A column header a listener passed several rows ago is not a
        // label.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "sensors.row.accessibility",
                defaultValue: "\(row.name), \(row.group.displayName)",
                comment: "VoiceOver label of a sensor table row: the sensor's name and group")
        )
        .accessibilityValue(
            String(
                localized: "sensors.row.accessibility.value",
                defaultValue:
                    "now \(spoken(row.current)), maximum \(spoken(row.maximum)), mean \(spoken(row.mean))",
                comment:
                    "VoiceOver value of a sensor table row: its current, maximum and mean temperature"
            ))
    }

    /// An absent statistic said as a word rather than as the dash the eye
    /// gets — a listener hearing "dash" learns nothing.
    private func spoken(_ value: Double?) -> String {
        guard let value else {
            return String(
                localized: "sensors.row.accessibility.absent", defaultValue: "not available",
                comment: "VoiceOver text for a sensor statistic that has no value yet")
        }
        return String(format: "%.1f", value)
    }

    /// An absent statistic shows a dash — never a zero, which would read as
    /// a temperature.
    private func numeric(_ value: Double?) -> some View {
        Text(verbatim: value.map { String(format: "%.1f", $0) } ?? "—")
            .monospacedDigit()
            .frame(width: SensorTable.width(of: .current), alignment: .trailing)
    }
}
