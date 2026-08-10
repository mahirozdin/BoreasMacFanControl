import Foundation

/// One recorded sample (P7.02).
///
/// The fields are the ones `docs/operations/observability.md` names: timestamp,
/// sensors, fans, active profile, and the **engaged safety layer** — which that
/// document calls critical, because it is the answer to "why is the fan at
/// 100%?". A recording without it can show a fan at full speed and offer no
/// explanation, which is the same failure the diagnostics honesty rule exists to
/// prevent one level up.
public struct RecordingRecord: Sendable, Hashable, Codable {

    public let timestamp: Date

    /// Sensor readings, keyed by the sensor's raw hardware name.
    ///
    /// Raw names rather than display names: a recording is data for a tool to
    /// process, and a user's rename (P6.08) would make two files from the same
    /// machine disagree about what a column is called.
    public let sensors: [String: Double]

    /// Fan speeds in rpm, keyed by fan id.
    public let fans: [Int: Int]

    public let profileName: String

    /// The safety layer overriding the engine, or `nil` when none is.
    public let safetyLayer: SafetyLayer?

    /// The thermal pressure the system reported.
    public let thermal: ThermalPressure

    public init(
        timestamp: Date,
        sensors: [String: Double],
        fans: [Int: Int],
        profileName: String,
        safetyLayer: SafetyLayer?,
        thermal: ThermalPressure
    ) {
        self.timestamp = timestamp
        self.sensors = sensors
        self.fans = fans
        self.profileName = profileName
        self.safetyLayer = safetyLayer
        self.thermal = thermal
    }
}

/// How a recording is written.
public enum RecordingFormat: String, Sendable, Hashable, Codable, CaseIterable {

    /// One JSON object per line. The default, because it survives schema
    /// evolution: a reader that does not know a new field ignores it, and a file
    /// half written when the machine lost power is still readable up to its last
    /// complete line.
    case jsonl

    /// Comma separated, for spreadsheets.
    ///
    /// **Needs a fixed column order**, which is the awkward part: the set of
    /// sensors is discovered at runtime and can change between launches, so the
    /// header cannot be derived per line. `RecordingSerializer` takes the column
    /// order explicitly for that reason and a header is written once per file.
    case csv

    public var fileExtension: String { rawValue }
}

/// Turns records into bytes (P7.02).
///
/// Separated from anything that touches a disk so the format is testable on its
/// own: what a line looks like, how a missing sensor is represented, and — the
/// one that matters — that **no field can silently corrupt the format**. A
/// sensor name containing a comma would break CSV, and a profile name containing
/// a quote would break it differently.
public enum RecordingSerializer {

    /// The columns that come before the discovered sensors and fans.
    public static let fixedColumns = ["timestamp", "profile", "safetyLayer", "thermal"]

    /// A JSONL line, without its newline.
    ///
    /// The encoder is configured for **stable key order**, because a diff
    /// between two recordings should show changed values rather than reshuffled
    /// keys, and ISO 8601 timestamps, because a `Double` since 1970 is not
    /// something a person reading the file can check.
    public static func jsonlLine(_ record: RecordingRecord) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        // The failable initialiser the repository's lint rule prefers. An empty
        // string cannot happen — `JSONEncoder` produces UTF-8 — but refusing to
        // assume it costs nothing.
        return String(bytes: data, encoding: .utf8) ?? ""

    }

    /// The CSV header for a fixed set of sensor and fan columns.
    public static func csvHeader(sensors: [String], fans: [Int]) -> String {
        let columns =
            fixedColumns + sensors.map { "sensor:\($0)" } + fans.map { "fan:\($0)" }
        return columns.map(escapeCSV).joined(separator: ",")
    }

    /// One CSV row, in the same column order as the header.
    ///
    /// A sensor the record does not carry becomes an **empty field, not a zero**.
    /// Zero is a temperature; absence is not, and a spreadsheet averaging zeros
    /// into a column of real readings would quietly lie — the same rule the
    /// sensor table follows with its dash.
    public static func csvRow(
        _ record: RecordingRecord, sensors: [String], fans: [Int]
    ) -> String {
        var fields = [
            record.timestamp.formatted(iso8601),
            record.profileName,
            record.safetyLayer?.rawValue ?? "",
            record.thermal.rawValue,
        ]
        for sensor in sensors {
            fields.append(record.sensors[sensor].map { String(format: "%.2f", $0) } ?? "")
        }
        for fan in fans {
            fields.append(record.fans[fan].map(String.init) ?? "")
        }
        return fields.map(escapeCSV).joined(separator: ",")
    }

    /// RFC 4180 quoting: a field containing a comma, a quote or a newline is
    /// wrapped in quotes and its own quotes are doubled.
    ///
    /// Not theoretical. Sensor names come from the hardware and this project has
    /// already met one called `NEWCHIP xz9`; a comma in one would otherwise
    /// shift every column after it by one, silently, in a file whose whole
    /// purpose is to be trusted by a tool.
    static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n")
        else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// A value type, not `ISO8601DateFormatter`.
    ///
    /// Strict concurrency (T1) refuses a shared mutable formatter, and it is
    /// right to: `ISO8601DateFormatter` is a class with settable properties and a
    /// `static let` of one is shared mutable state. The modern format style is a
    /// value, so it is `Sendable` for free.
    ///
    /// **UTC, deliberately.** A recording is data somebody will read later,
    /// possibly on another machine, and a local timestamp with no offset is
    /// ambiguous twice a year.
    static let iso8601 = Date.ISO8601FormatStyle(timeZone: .gmt)
}
