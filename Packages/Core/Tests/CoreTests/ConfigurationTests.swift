import Foundation
import Testing

@testable import Core

@Suite("Configuration (schema, G6 fallback, migration)")
struct ConfigurationTests {

    // MARK: - G6: a broken configuration does not crash

    @Test("garbage bytes fall back to the last valid configuration with a problem attached")
    func garbageFallsBack() {
        let outcome = ConfigurationLoader.load(candidate: Data("not json at all".utf8))
        #expect(outcome.configuration == .standard)
        #expect(outcome.problem != nil)
    }

    @Test("a downhill curve is refused and the problem names the field path")
    func downhillCurveNamesTheField() throws {
        var config = ConfigurationFile.standard
        let data = try JSONEncoder().encode(config)
        var text = try #require(String(bytes: data, encoding: .utf8))
        // Corrupt one duty so the balanced curve runs downhill.
        #expect(text.contains(#""duty":0.75"#) || text.contains(#""duty":0.75"#))
        text = text.replacingOccurrences(of: #""duty":0.75"#, with: #""duty":0.05"#)

        let outcome = ConfigurationLoader.load(candidate: Data(text.utf8))
        #expect(outcome.configuration == .standard)
        let problem = try #require(outcome.problem)
        #expect(problem.fieldPath.contains("profiles"))
        #expect(problem.detail.contains("curve"))
        // Silence the unused-var warning path: config stays the baseline.
        config = outcome.configuration
    }

    @Test("a configuration from a newer build is refused, not half-read")
    func newerVersionRefused() throws {
        var object: [String: Any] = ["schemaVersion": 99]
        object["profiles"] = []
        let data = try JSONSerialization.data(withJSONObject: object)
        let outcome = ConfigurationLoader.load(candidate: data)
        #expect(outcome.configuration == .standard)
        #expect(outcome.problem?.fieldPath == "schemaVersion")
    }

    @Test("no file at all means the standard configuration, with no problem to report")
    func absenceIsNotAProblem() {
        let outcome = ConfigurationLoader.load(candidate: nil)
        #expect(outcome.configuration == .standard)
        #expect(outcome.problem == nil)
    }

    @Test("the standard configuration round-trips through its own wire format")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(ConfigurationFile.standard)
        let outcome = ConfigurationLoader.load(candidate: data)
        #expect(outcome.problem == nil)
        #expect(outcome.configuration == ConfigurationFile.standard)
        #expect(outcome.migratedFromVersion == nil)
    }

    @Test("decoded values pass through the clamping types")
    func decodedValuesAreClamped() throws {
        let json = """
            {
              "schemaVersion": 1,
              "general": { "samplingIntervalSeconds": 500 },
              "safety": { "panicTemperatureCelsius": 104, "watchdogTimeoutSeconds": 300 },
              "profiles": []
            }
            """
        let outcome = ConfigurationLoader.load(candidate: Data(json.utf8))
        #expect(outcome.problem == nil)
        #expect(outcome.configuration.general.samplingIntervalSeconds == 60)
        #expect(outcome.configuration.safety.panicThreshold.celsius == 95)
        #expect(outcome.configuration.safety.watchdogTimeoutSeconds == 60)
    }

    // MARK: - Migration (P5.11)

    private let v0Document = """
        {
          "general": { "samplingIntervalSeconds": 5 },
          "safety": { "panicTemperatureCelsius": 105, "watchdogTimeoutSeconds": 20 },
          "profiles": [
            {
              "name": "My Studio",
              "priority": 42,
              "triggers": [
                { "type": "application", "bundleIdentifier": "com.example.studio" }
              ],
              "smoothing": 0.25,
              "hysteresis": 4,
              "slew": { "maxRisePerSecond": 500, "maxFallPerSecond": 120 },
              "binding": {
                "curve": [
                  { "celsius": 42, "duty": 0.1 },
                  { "celsius": 90, "duty": 1.0 }
                ],
                "input": { "group": "compute", "aggregate": "p95" }
              }
            }
          ]
        }
        """

    @Test("a v0 document migrates without losing a single user value")
    func v0MigratesLosslessly() throws {
        let outcome = ConfigurationLoader.load(candidate: Data(v0Document.utf8))

        #expect(outcome.problem == nil)
        #expect(outcome.migratedFromVersion == 0)
        // The pre-migration original is handed back for the backup file.
        #expect(outcome.backupOfOriginal == Data(v0Document.utf8))

        let config = outcome.configuration
        #expect(config.schemaVersion == 1)
        // The one deliberate change: ADR 0022 narrowed the panic ceiling.
        #expect(config.safety.panicThreshold.celsius == 95)

        // Everything the user wrote survives.
        #expect(config.general.samplingIntervalSeconds == 5)
        #expect(config.safety.watchdogTimeoutSeconds == 20)
        let profile = try #require(config.profiles.first)
        #expect(profile.name == "My Studio")
        #expect(profile.priority == 42)
        #expect(
            profile.triggers == [
                .application(bundleIdentifier: "com.example.studio", foregroundOnly: false)
            ])
        #expect(profile.smoothing == EWMA(alpha: 0.25))
        #expect(profile.hysteresis == Hysteresis(band: 4))
        #expect(profile.slew == RateLimit(maxRisePerSecond: 500, maxFallPerSecond: 120))
        #expect(profile.binding.curve.points.count == 2)
        #expect(profile.binding.curve.points[0].celsius == 42)
        #expect(profile.binding.input.aggregate == .p95)
    }

    @Test("a current document is not touched by the migrator")
    func currentDocumentUntouched() throws {
        let data = try JSONEncoder().encode(ConfigurationFile.standard)
        let result = ConfigurationMigrator.migrateIfNeeded(data)
        #expect(result.fromVersion == nil)
        #expect(result.data == data)
    }
}
