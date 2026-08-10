import Foundation
import Testing

@testable import Core

/// The one-click unknown-sensor report (P7.09).
///
/// The URL is transmitted **on page load, not on submit**, so the tests that
/// matter here are the ones about what cannot get into it and about the query
/// staying well formed — a stray `&` inside a hardware key would invent a
/// parameter, and a comma left unescaped would truncate a model identifier.
@Suite("Unknown sensor report link")
struct SensorReportLinkTests {

    private static let base = "https://github.com/owner/repo"

    private func sample(
        model: String = "Mac16,10",
        chip: String = "Apple M4",
        sensors: [String] = ["TCMz", "PMU tdev1"],
        fans: Int = 1
    ) -> SensorReportLink.Facts {
        SensorReportLink.Facts(
            modelIdentifier: model, chip: chip, sensorNames: sensors, fanCount: fans)
    }

    @Test("carries the template and every field the form expects")
    func carriesFields() throws {
        let link = try #require(SensorReportLink.link(base: Self.base, facts: sample()))
        #expect(link.url.hasPrefix("https://github.com/owner/repo/issues/new?"))
        #expect(link.url.contains("template=unknown_sensor.yml"))
        for identifier in SensorReportLink.templateFieldIdentifiers where identifier != "sensors" {
            #expect(link.url.contains("&\(identifier)="))
        }
        #expect(link.url.contains("&sensors="))
        #expect(link.omittedSensorCount == 0)
    }

    /// `Mac16,10` is a real value and the comma is a real hazard: left alone it
    /// is legal in a query but arrives inconsistently, and the identifier is the
    /// one field a maintainer sorts by.
    @Test("escapes the comma in a model identifier")
    func escapesComma() throws {
        let link = try #require(SensorReportLink.link(base: Self.base, facts: sample()))
        #expect(link.url.contains("model=Mac16%2C10"))
        #expect(!link.url.contains("Mac16,10"))
    }

    @Test("joins sensor names with an escaped newline and escapes the space")
    func joinsSensors() throws {
        let link = try #require(SensorReportLink.link(base: Self.base, facts: sample()))
        #expect(link.url.contains("sensors=TCMz%0APMU%20tdev1"))
    }

    /// A hardware key is not a promise of well behaved characters, and the
    /// separators are the whole grammar of a query string.
    @Test("a hardware key cannot invent a query parameter")
    func hostileKeyCannotInjectParameters() throws {
        let hostile = "T&admin=1&x=Cz"
        let link = try #require(
            SensorReportLink.link(base: Self.base, facts: sample(sensors: [hostile])))
        #expect(!link.url.contains("admin=1"))
        #expect(link.url.contains("T%26admin%3D1%26x%3DCz"))
        // Exactly the four parameters the form declares, and no fifth.
        let query = try #require(link.url.split(separator: "?").last)
        let keys = query.split(separator: "&").compactMap { $0.split(separator: "=").first }
        #expect(keys.map(String.init) == ["template", "model", "chip", "fans", "sensors"])
    }

    @Test("nothing to report means no link at all")
    func noSensorsNoLink() {
        #expect(SensorReportLink.link(base: Self.base, facts: sample(sensors: [])) == nil)
    }

    @Test("no repository address means no link")
    func noBaseNoLink() {
        #expect(SensorReportLink.link(base: "   ", facts: sample()) == nil)
    }

    @Test("a trailing slash on the repository address does not double up")
    func trailingSlash() throws {
        let link = try #require(
            SensorReportLink.link(base: Self.base + "/", facts: sample()))
        #expect(!link.url.contains("repo//issues"))
    }

    /// The cap has to hold and it has to be *counted*: a report that silently
    /// dropped half the sensor list would read as a complete description of the
    /// machine, which is the failure mode this project refuses everywhere else.
    @Test("the length budget truncates, stays inside itself, and says how much it dropped")
    func truncationIsCountedAndBounded() throws {
        let many = (0..<400).map { "SENSOR-KEY-NUMBER-\($0)" }
        let link = try #require(SensorReportLink.link(base: Self.base, facts: sample(sensors: many)))
        #expect(link.url.count <= SensorReportLink.maximumURLLength)
        #expect(link.omittedSensorCount > 0)

        let included = many.count - link.omittedSensorCount
        #expect(included > 0)
        // What survives is a prefix of the truth, not a sample of it.
        #expect(link.url.contains("SENSOR-KEY-NUMBER-0"))
        #expect(!link.url.contains("SENSOR-KEY-NUMBER-\(many.count - 1)"))
    }

    @Test("a single sensor name too large for the budget yields no link")
    func oversizedSingleNameYieldsNoLink() {
        let enormous = String(repeating: "K", count: SensorReportLink.maximumURLLength + 1)
        #expect(SensorReportLink.link(base: Self.base, facts: sample(sensors: [enormous])) == nil)
    }

    /// Pins the field identifiers to the form that actually ships.
    ///
    /// A unit test reading a repository file is unusual, and it is the point:
    /// these ids are a contract between two files, and the failure being guarded
    /// is somebody renaming a field in the template while this list keeps
    /// claiming to pre-fill it. Restating the ids without pinning them is the
    /// drift the project refuses; a missing file fails rather than skips, so the
    /// check cannot pass by not running.
    @Test("the field identifiers match the shipped issue template")
    func identifiersMatchTemplate() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repository root
        let template =
            repositoryRoot
            .appendingPathComponent(".github/ISSUE_TEMPLATE")
            .appendingPathComponent(SensorReportLink.templateName)

        let yaml = try String(contentsOf: template, encoding: .utf8)
        let declared = yaml.split(separator: "\n").compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("id:") else { return nil }
            return trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
        }

        for identifier in SensorReportLink.templateFieldIdentifiers {
            #expect(
                declared.contains(identifier),
                "the template no longer declares a field with id '\(identifier)'")
        }
    }
}
