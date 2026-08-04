import Core
import Foundation
import Testing

@testable import HardwareKit

/// A scriptable SMC for the actuator's bookkeeping rules.
private final class FakeSMCPort: SMCPort, @unchecked Sendable {

    private let lock = NSLock()
    private var values: [String: SMCValue]
    private(set) var writes: [(key: String, bytes: [UInt8])] = []

    /// Keys whose writes are accepted but change nothing — simulates a write
    /// that silently does not stick.
    var deadKeys: Set<String> = []

    init(values: [String: SMCValue]) {
        self.values = values
    }

    func readValue(key: String) throws -> SMCValue? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func writeValue(key: String, bytes: [UInt8]) throws {
        lock.lock()
        defer { lock.unlock() }
        writes.append((key, bytes))
        guard !deadKeys.contains(key) else { return }
        if let existing = values[key] {
            values[key] = SMCValue(key: key, type: existing.type, bytes: bytes)
        }
    }

    func writesTo(_ key: String) -> [[UInt8]] {
        lock.lock()
        defer { lock.unlock() }
        return writes.filter { $0.key == key }.map(\.bytes)
    }
}

private func makeFanPort(
    mode: UInt8 = 0, targetRPM: Float = 1000
) -> FakeSMCPort {
    FakeSMCPort(values: [
        "F0Md": SMCValue(key: "F0Md", type: "ui8 ", bytes: [mode]),
        "F0Tg": SMCValue(key: "F0Tg", type: "flt ", bytes: LiveFanActuator.floatBytes(targetRPM)),
    ])
}

@Suite("Fan actuator (the write path's bookkeeping)")
struct FanActuatorTests {

    @Test("take-over saves the original state once and forces the mode")
    func takeOverSavesOriginal() throws {
        let port = makeFanPort(mode: 0, targetRPM: 1000)
        let actuator = LiveFanActuator(port: port, sleeper: { _ in })

        try actuator.applyNow([FanTarget(fanID: 0, rpm: 1600)])
        try actuator.applyNow([FanTarget(fanID: 0, rpm: 1800)])

        // The mode was forced exactly once — the second apply only moves the
        // target, it must not re-save state that is now ours, not original.
        #expect(port.writesTo("F0Md") == [[LiveFanActuator.forcedMode]])
        #expect(port.writesTo("F0Tg").count == 2)
        #expect(actuator.isHoldingFans)
    }

    @Test("release restores the exact original bytes, target before mode")
    func releaseRestoresVerbatim() throws {
        let originalTarget = LiveFanActuator.floatBytes(1000)
        let port = makeFanPort(mode: 0, targetRPM: 1000)
        let actuator = LiveFanActuator(port: port, sleeper: { _ in })

        try actuator.applyNow([FanTarget(fanID: 0, rpm: 1600)])
        let writesBeforeRelease = port.writes.count
        try actuator.releaseNow()

        let releaseWrites = Array(port.writes.dropFirst(writesBeforeRelease))
        #expect(releaseWrites.map(\.key) == ["F0Tg", "F0Md"])
        #expect(releaseWrites[0].bytes == originalTarget)
        #expect(releaseWrites[1].bytes == [0])
        #expect(!actuator.isHoldingFans)
    }

    @Test("releaseToFirmware is idempotent")
    func releaseIsIdempotent() throws {
        let port = makeFanPort()
        let actuator = LiveFanActuator(port: port, sleeper: { _ in })

        try actuator.applyNow([FanTarget(fanID: 0, rpm: 1600)])
        try actuator.releaseNow()
        let writesAfterFirst = port.writes.count

        try actuator.releaseNow()
        try actuator.releaseNow()

        // Nothing taken over, nothing written: releasing again is free.
        #expect(port.writes.count == writesAfterFirst)
    }

    @Test("release without a take-over writes nothing")
    func releaseWithoutTakeoverIsFree() throws {
        let port = makeFanPort()
        let actuator = LiveFanActuator(port: port, sleeper: { _ in })
        try actuator.releaseNow()
        #expect(port.writes.isEmpty)
    }

    @Test("a failed restore retries five times with doubling backoff, keeps state")
    func releaseRetriesWithBackoff() throws {
        let port = makeFanPort()
        let recorded = DelayRecorder()
        let actuator = LiveFanActuator(port: port, sleeper: { recorded.append($0) })

        // Take over while the hardware is healthy: the mode really becomes
        // "forced". Then the mode key goes dead — restore writes are accepted
        // but change nothing, so the readback keeps seeing "forced" and every
        // attempt fails.
        try actuator.applyNow([FanTarget(fanID: 0, rpm: 1600)])
        port.deadKeys = ["F0Md"]

        #expect(throws: (any Error).self) { try actuator.releaseNow() }
        // The outer backoff doubles between attempts (the 0.1 s entries are
        // the inner readback patience for the SMC's asynchronous applies).
        #expect(recorded.delays.filter { [0.2, 0.4, 0.8].contains($0) } == [0.2, 0.4, 0.8])
        // The saved state survives a failed release so a later attempt still
        // knows what to restore.
        #expect(actuator.isHoldingFans)

        // The hardware recovers; the next release succeeds and clears state.
        port.deadKeys = []
        try actuator.releaseNow()
        #expect(!actuator.isHoldingFans)
    }

    @Test("an unexpected key type refuses the take-over before any write")
    func wrongTypeRefusesTakeover() throws {
        let port = FakeSMCPort(values: [
            "F0Md": SMCValue(key: "F0Md", type: "flt ", bytes: [0, 0, 0, 0]),
            "F0Tg": SMCValue(key: "F0Tg", type: "flt ", bytes: LiveFanActuator.floatBytes(1000)),
        ])
        let actuator = LiveFanActuator(port: port, sleeper: { _ in })

        #expect(throws: (any Error).self) {
            try actuator.applyNow([FanTarget(fanID: 0, rpm: 1600)])
        }
        #expect(port.writes.isEmpty)
    }

    @Test("a fresh actuator still releases a fan a dead helper left forced")
    func amnesiaGuardReleasesForcedFan() throws {
        // The scenario the freeze drill produced on real hardware: the fan is
        // in forced mode, and the process that knew the original state is
        // gone. A brand new actuator has an empty book — the hardware itself
        // is the only witness, and release must believe it.
        let port = FakeSMCPort(values: [
            "FNum": SMCValue(key: "FNum", type: "ui8 ", bytes: [1]),
            "F0Md": SMCValue(key: "F0Md", type: "ui8 ", bytes: [1]),
            "F0Tg": SMCValue(key: "F0Tg", type: "flt ", bytes: LiveFanActuator.floatBytes(1400)),
        ])
        let actuator = LiveFanActuator(port: port, sleeper: { _ in })

        try actuator.releaseNow()

        #expect(port.writesTo("F0Md") == [[LiveFanActuator.automaticMode]])
        // The original target is unknown, so only the mode is touched — the
        // firmware rewrites its own target the moment it is back in charge.
        #expect(port.writesTo("F0Tg").isEmpty)

        // With the hardware back on automatic, another release is free.
        let writesAfter = port.writes.count
        try actuator.releaseNow()
        #expect(port.writes.count == writesAfter)
    }

    @Test("float bytes are little endian, matching the live flt decode")
    func floatBytesRoundTrip() {
        // Measured on hardware: 1000.0 reads back as 00 00 7a 44.
        #expect(LiveFanActuator.floatBytes(1000) == [0x00, 0x00, 0x7A, 0x44])

        let bytes = LiveFanActuator.floatBytes(1234.5)
        let value = SMCValue(key: "F0Tg", type: "flt ", bytes: bytes)
        #expect(value.numericValue == 1234.5)
    }
}

/// Collects backoff delays without any locking ceremony in the test body.
private final class DelayRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [TimeInterval] = []

    var delays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ delay: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(delay)
    }
}
