import Core
import Testing

@testable import HardwareKit

@Suite("Graceful degradation")
struct FallbackSensorSourceTests {

    private func reading(_ name: String, _ celsius: Double) -> SensorReading {
        SensorClassifier.makeReading(rawName: name, celsius: celsius)
    }

    private func working(_ name: String) -> MockSensorSource {
        MockSensorSource(readings: [reading(name, 50)])
    }

    @Test("the preferred source is used while it works")
    func prefersPrimary() async throws {
        let source = FallbackSensorSource(
            preferred: working("PMU tdie1"),
            fallback: working("TC0P")
        )
        let readings = try await source.snapshot()
        #expect(readings.first?.rawName == "PMU tdie1")
        #expect(await source.activeBackend == .preferred)
        #expect(await source.degradedReason == nil)
    }

    @Test("a failing preferred source falls through instead of throwing")
    func fallsThrough() async throws {
        let source = FallbackSensorSource(
            preferred: MockSensorSource.failing(),
            fallback: working("TC0P")
        )
        let readings = try await source.snapshot()
        #expect(readings.first?.rawName == "TC0P")
        #expect(await source.activeBackend == .fallback)
    }

    @Test("a single failure does not permanently demote the preferred source")
    func singleFailureIsNotDemotion() async throws {
        let source = FallbackSensorSource(
            preferred: MockSensorSource.failing(),
            fallback: working("TC0P"),
            failuresBeforeDemotion: 3
        )
        _ = try await source.snapshot()
        // Reading from the fallback, but not yet flagged as degraded: one
        // hiccup should not cost the user their sensor names.
        #expect(await source.degradedReason == nil)
        #expect(await source.failureCount == 1)
    }

    @Test("a run of failures does flag the reading as degraded")
    func repeatedFailureIsDemotion() async throws {
        let source = FallbackSensorSource(
            preferred: MockSensorSource.failing(),
            fallback: working("TC0P"),
            failuresBeforeDemotion: 3
        )
        for _ in 0..<3 { _ = try await source.snapshot() }
        #expect(await source.degradedReason != nil, "the user must be told they are on a degraded path")
    }

    @Test("recovery is immediate once the preferred source answers again")
    func recovers() async throws {
        // Fails on the first read, then succeeds.
        let flaky = MockSensorSource(frames: [[], [reading("PMU tdie1", 55)]])
        let source = FallbackSensorSource(preferred: flaky, fallback: working("TC0P"))

        _ = try await source.snapshot()  // empty frame counts as a working read
        let second = try await source.snapshot()
        #expect(second.first?.rawName == "PMU tdie1")
        #expect(await source.activeBackend == .preferred)
        #expect(await source.degradedReason == nil)
    }

    @Test("when both sources fail the error surfaces, with a reason recorded")
    func bothFail() async {
        let source = FallbackSensorSource(
            preferred: MockSensorSource.failing(),
            fallback: MockSensorSource.failing()
        )
        await #expect(throws: HardwareError.self) {
            _ = try await source.snapshot()
        }
        #expect(await source.activeBackend == .none)
        #expect(await source.degradedReason == "no sensor backend is answering")
    }

    @Test("demotion threshold cannot be set below one")
    func thresholdFloor() async throws {
        let source = FallbackSensorSource(
            preferred: MockSensorSource.failing(),
            fallback: working("TC0P"),
            failuresBeforeDemotion: 0
        )
        _ = try await source.snapshot()
        #expect(await source.degradedReason != nil)
    }
}
