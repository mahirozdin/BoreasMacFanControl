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
                        }
                    }
                    .frame(width: Self.width(of: entry), alignment: Self.alignment(of: entry))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    static func width(of column: SensorColumn) -> CGFloat {
        switch column {
        case .name: return 220
        case .group: return 130
        case .current, .maximum, .mean: return 70
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
    }

    /// An absent statistic shows a dash — never a zero, which would read as
    /// a temperature.
    private func numeric(_ value: Double?) -> some View {
        Text(verbatim: value.map { String(format: "%.1f", $0) } ?? "—")
            .monospacedDigit()
            .frame(width: SensorTable.width(of: .current), alignment: .trailing)
    }
}
