import Testing

@testable import Core

@Suite("Core constants")
struct CoreConstantTests {

    @Test("watchdog timeout range is locked to 10...60 seconds")
    func watchdogRange() {
        #expect(Boreas.watchdogTimeoutRange.lowerBound == 10)
        #expect(Boreas.watchdogTimeoutRange.upperBound == 60)
    }

    @Test("panic temperature can be lowered but not raised past 105C")
    func panicRange() {
        #expect(Boreas.panicTemperatureRange.upperBound == 105)
        #expect(Boreas.panicTemperatureRange.contains(95))
    }

    @Test("config schema version is positive")
    func schemaVersion() {
        #expect(Boreas.configSchemaVersion >= 1)
    }
}
