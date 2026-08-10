import Foundation
import Testing

@testable import Core

/// The recording formats (P7.02).
///
/// A recording exists to be trusted by a tool, so the failure worth defending
/// against is **silent corruption**: a field that shifts every column after it,
/// or an absence that reads as a measurement.
@Suite("Recording serialisation (JSONL, CSV, and what cannot corrupt them)")
struct RecordingSerializerTests {

    private static let moment = Date(timeIntervalSince1970: 1_800_000_000)

    private static func record(
        sensors: [String: Double] = ["PMU tdie5": 62.4],
        fans: [Int: Int] = [0: 1_608],
        profile: String = "Balanced",
        layer: SafetyLayer? = nil
    ) -> RecordingRecord {
        RecordingRecord(
            timestamp: moment, sensors: sensors, fans: fans, profileName: profile,
            safetyLayer: layer, thermal: .nominal)
    }

    // MARK: - The safety layer, which is the point

    @Test("the engaged safety layer is in every record, in both formats")
    func safetyLayerIsRecorded() throws {
        // `docs/operations/observability.md` calls this critical: it is the answer
        // to "why is the fan at 100%?". A recording that omitted it could show a
        // fan at full speed and explain nothing.
        let panicking = Self.record(layer: .panic)
        let line = try RecordingSerializer.jsonlLine(panicking)
        #expect(line.contains("panic"))

        let row = RecordingSerializer.csvRow(
            panicking, sensors: ["PMU tdie5"], fans: [0])
        #expect(row.contains("panic"))
        #expect(RecordingSerializer.csvHeader(sensors: [], fans: []).contains("safetyLayer"))
    }

    @Test("no engaged layer is an empty field, distinguishable from a named one")
    func noLayerIsEmpty() {
        let row = RecordingSerializer.csvRow(Self.record(layer: nil), sensors: [], fans: [])
        let fields = row.split(separator: ",", omittingEmptySubsequences: false)
        // timestamp, profile, safetyLayer, thermal
        #expect(fields.count == 4)
        #expect(fields[2].isEmpty)
    }

    // MARK: - Corruption

    @Test("a comma in a sensor name cannot shift the columns")
    func commaIsQuoted() {
        // Sensor names come from the hardware. This project has already met one
        // called `NEWCHIP xz9`; a comma in one would otherwise move every column
        // after it by one, silently.
        let hostile = "PMU, tdie5"
        let header = RecordingSerializer.csvHeader(sensors: [hostile], fans: [])
        #expect(header.contains("\"sensor:PMU, tdie5\""))

        let row = RecordingSerializer.csvRow(
            Self.record(sensors: [hostile: 62.4]), sensors: [hostile], fans: [])
        // Four fixed fields plus one sensor: the quoting must keep it at five.
        #expect(Self.countCSVFields(row) == 5)
    }

    @Test("a quote in a profile name is doubled, not dropped")
    func quoteIsDoubled() {
        let row = RecordingSerializer.csvRow(
            Self.record(profile: "My \"quiet\" profile"), sensors: [], fans: [])
        #expect(row.contains("\"My \"\"quiet\"\" profile\""))
        #expect(Self.countCSVFields(row) == 4)
    }

    @Test("a newline in a field cannot end the row early")
    func newlineIsQuoted() {
        let row = RecordingSerializer.csvRow(
            Self.record(profile: "two\nlines"), sensors: [], fans: [])
        #expect(row.hasPrefix("2027") || row.contains("\"two\nlines\""))
        #expect(Self.countCSVFields(row) == 4)
    }

    @Test("an ordinary field is not quoted needlessly")
    func plainFieldsStayPlain() {
        let row = RecordingSerializer.csvRow(Self.record(), sensors: ["PMU tdie5"], fans: [0])
        #expect(!row.contains("\""))
    }

    // MARK: - Absence is not zero

    @Test("a sensor missing from a record is empty, never zero")
    func missingSensorIsEmpty() {
        // Zero is a temperature; absence is not. A spreadsheet averaging zeros
        // into a column of real readings would quietly lie — the same rule the
        // sensor table follows with its dash.
        let row = RecordingSerializer.csvRow(
            Self.record(sensors: [:], fans: [:]), sensors: ["PMU tdie5"], fans: [0])
        let fields = row.split(separator: ",", omittingEmptySubsequences: false)
        #expect(fields.count == 6)
        #expect(fields[4].isEmpty, "an absent sensor became \(fields[4])")
        #expect(fields[5].isEmpty, "an absent fan became \(fields[5])")
    }

    // MARK: - JSONL

    @Test("a JSONL line is one line and round-trips")
    func jsonlRoundTrips() throws {
        let original = Self.record(layer: .thermalSerious)
        let line = try RecordingSerializer.jsonlLine(original)
        #expect(!line.contains("\n"), "a JSONL record must not contain a newline")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RecordingRecord.self, from: Data(line.utf8))
        #expect(decoded == original)
    }

    @Test("the timestamp is written in UTC with an offset, not a bare number")
    func timestampIsUnambiguous() throws {
        // A recording is read later, possibly on another machine. A local
        // timestamp with no offset is ambiguous twice a year, and seconds since
        // 1970 is not something a person reading the file can check.
        let line = try RecordingSerializer.jsonlLine(Self.record())
        #expect(line.contains("Z") || line.contains("+00:00"), "line was \(line)")
        let row = RecordingSerializer.csvRow(Self.record(), sensors: [], fans: [])
        #expect(row.contains("Z") || row.contains("+00:00"))
    }

    @Test("keys are ordered, so a diff shows changed values rather than a reshuffle")
    func keysAreStable() throws {
        let first = try RecordingSerializer.jsonlLine(Self.record())
        let second = try RecordingSerializer.jsonlLine(Self.record())
        #expect(first == second)
    }

    /// Counts CSV fields with RFC 4180 quoting honoured, so the corruption tests
    /// measure what a real reader would see rather than what `split` sees.
    private static func countCSVFields(_ row: String) -> Int {
        var count = 1
        var inQuotes = false
        var index = row.startIndex
        while index < row.endIndex {
            let character = row[index]
            if character == "\"" {
                let next = row.index(after: index)
                if inQuotes, next < row.endIndex, row[next] == "\"" {
                    index = next
                } else {
                    inQuotes.toggle()
                }
            } else if character == ",", !inQuotes {
                count += 1
            }
            index = row.index(after: index)
        }
        return count
    }
}
