import Testing

@testable import Core

@Suite("Sensor classification")
struct SensorClassifierTests {

    // MARK: grouping

    @Test(
        "efficiency clusters are not filed as performance",
        arguments: ["eACC MTR Temp Sensor1", "EACC_TEMP", "CPU E-Core 2", "ecpu die"]
    )
    func efficiencyBeatsGenericCPU(raw: String) {
        #expect(SensorClassifier.group(rawName: raw) == .computeEfficiency)
    }

    @Test(
        "performance clusters group correctly",
        arguments: ["pACC MTR Temp Sensor3", "PCPU die", "CPU P-Core 0"]
    )
    func performanceCluster(raw: String) {
        #expect(SensorClassifier.group(rawName: raw) == .computePerformance)
    }

    @Test(
        "known areas map to their group",
        arguments: [
            ("GPU MTR Temp Sensor1", SensorGroup.graphics),
            ("gas gauge battery", SensorGroup.battery),
            ("NAND CH0 temp", SensorGroup.storage),
            ("PMGR SOC Die Temp", SensorGroup.power),
            ("LPDDR bank 2", SensorGroup.memory),
            ("Wi-Fi module", SensorGroup.wireless),
            ("Fin Stack Proximity", SensorGroup.airflow),
            ("Trackpad Actuator", SensorGroup.chassis)
        ]
    )
    func knownAreas(raw: String, expected: SensorGroup) {
        #expect(SensorClassifier.group(rawName: raw) == expected)
    }

    @Test("an unrecognised sensor is surfaced, never silently dropped")
    func unknownIsSurfaced() {
        let group = SensorClassifier.group(rawName: "TQ4X mystery probe")
        #expect(group == .uncategorized)
    }

    @Test("uncategorized is not offered as a fan curve input")
    func uncategorizedNotACurveInput() {
        #expect(SensorGroup.curveInputCandidates.contains(.uncategorized) == false)
        #expect(SensorGroup.curveInputCandidates.contains(.computePerformance))
    }

    // MARK: normalisation

    @Test("abbreviations expand and trailing digits get a space")
    func normalisation() {
        #expect(SensorClassifier.normalize(rawName: "pACC MTR Temp Sensor1")
            == "Performance Cluster Sensor Temperature Sensor 1")
        #expect(SensorClassifier.normalize(rawName: "gpu_temp") == "GPU Temperature")
    }

    @Test("codes that carry their own casing are left alone")
    func preservesCodes() {
        #expect(SensorClassifier.normalize(rawName: "TG0D") == "TG0D")
    }

    @Test("an empty or unusable name falls back to the raw string")
    func emptyFallback() {
        #expect(SensorClassifier.normalize(rawName: "") == "")
        #expect(SensorClassifier.normalize(rawName: "   ") == "   ")
    }

    // MARK: overrides

    @Test("a user override wins over both normalisation and grouping")
    func overridesWin() {
        let reading = SensorClassifier.makeReading(
            rawName: "TQ4X",
            celsius: 44,
            overrides: ["TQ4X": SensorOverride(displayName: "Mystery probe", group: .storage)]
        )
        #expect(reading.displayName == "Mystery probe")
        #expect(reading.group == .storage)
        #expect(reading.rawName == "TQ4X")
    }

    @Test("raw name is preserved so users can report unmapped sensors")
    func rawNamePreserved() {
        let reading = SensorClassifier.makeReading(rawName: "pACC MTR Temp Sensor1", celsius: 61)
        #expect(reading.rawName == "pACC MTR Temp Sensor1")
        #expect(reading.id == "pACC MTR Temp Sensor1")
    }

    // MARK: plausibility

    @Test(
        "readings outside the physical range are marked implausible",
        arguments: [(-40.0, false), (0.0, true), (61.0, true), (150.0, true), (1000.0, false)]
    )
    func plausibility(celsius: Double, expected: Bool) {
        let reading = SensorClassifier.makeReading(rawName: "CPU die", celsius: celsius)
        #expect(reading.isPlausible == expected)
    }
}
