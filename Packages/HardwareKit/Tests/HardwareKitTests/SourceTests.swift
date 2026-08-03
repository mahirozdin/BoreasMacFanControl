import Core
import Foundation
import Testing

@testable import HardwareKit

@Suite("Mock sources")
struct MockSourceTests {

    @Test("the same script always produces the same readings")
    func deterministic() async throws {
        let first = MockSensorSource.appleSiliconDesktop()
        let second = MockSensorSource.appleSiliconDesktop()
        let firstReadings = try await first.snapshot()
        let secondReadings = try await second.snapshot()
        #expect(firstReadings == secondReadings)
    }

    @Test("scripted frames advance and then hold on the last one")
    func framesAdvanceThenHold() async throws {
        let cool = SensorClassifier.makeReading(rawName: "CPU die", celsius: 40)
        let warm = SensorClassifier.makeReading(rawName: "CPU die", celsius: 70)
        let source = MockSensorSource(frames: [[cool], [warm]])

        #expect(try await source.snapshot().first?.celsius == 40)
        #expect(try await source.snapshot().first?.celsius == 70)
        #expect(try await source.snapshot().first?.celsius == 70, "must hold, not wrap")
    }

    @Test("reset rewinds a scripted sequence")
    func resetRewinds() async throws {
        let cool = SensorClassifier.makeReading(rawName: "CPU die", celsius: 40)
        let warm = SensorClassifier.makeReading(rawName: "CPU die", celsius: 70)
        let source = MockSensorSource(frames: [[cool], [warm]])

        _ = try await source.snapshot()
        _ = try await source.snapshot()
        await source.reset()
        #expect(try await source.snapshot().first?.celsius == 40)
    }

    @Test("a failing source throws rather than returning an empty result")
    func failingSourceThrows() async {
        let source = MockSensorSource.failing()
        await #expect(throws: HardwareError.self) {
            _ = try await source.snapshot()
        }
    }

    @Test("an unmapped sensor survives into the readings and is visible")
    func unmappedSensorSurvives() async throws {
        let readings = try await MockSensorSource.appleSiliconDesktop().snapshot()
        let mystery = readings.first { $0.rawName == "TQ4X mystery probe" }
        #expect(mystery != nil, "unmapped sensors must not be filtered out")
        #expect(mystery?.group == .uncategorized)
    }
}

@Suite("Machine shapes the development hardware cannot provide")
struct MachineShapeTests {

    @Test("a fanless machine reports no fans, and that is not an error")
    func fanless() async throws {
        let fans = try await MockFanSource.fanless.fans()
        #expect(fans.isEmpty)
    }

    @Test("a dual fan machine exposes independent speed ranges")
    func dualFan() async throws {
        let fans = try await MockFanSource.dualFan.fans()
        #expect(fans.count == 2)
        #expect(fans[0].maximumRPM != fans[1].maximumRPM, "per-fan curves need distinct ranges")
    }

    @Test("a parked fan is reported as powered off, not as running at zero")
    func poweredOff() async throws {
        let fans = try await MockFanSource.poweredOff.fans()
        let fan = try #require(fans.first)
        #expect(fan.isPoweredOff)
        #expect(fan.currentRPM == 0)
    }

    @Test("a desktop reports mains power and no battery level")
    func desktopPower() {
        let context = MockPowerSource.desktop.current()
        #expect(context.source == .adapter)
        #expect(context.batteryPercentage == nil)
    }

    @Test("battery percentage is clamped to 0...100")
    func batteryClamping() {
        #expect(PowerContext(source: .battery, batteryPercentage: 140).batteryPercentage == 100)
        #expect(PowerContext(source: .battery, batteryPercentage: -3).batteryPercentage == 0)
    }
}

@Suite("Replay source")
struct ReplaySourceTests {

    private func makeFrames() -> [ReplaySensorSource.Frame] {
        (0..<3).map { step in
            ReplaySensorSource.Frame(
                timestamp: Date(timeIntervalSince1970: Double(step)),
                readings: [SensorClassifier.makeReading(rawName: "CPU die", celsius: 50 + Double(step) * 10)]
            )
        }
    }

    @Test("a recorded session is reproduced frame by frame")
    func reproducesExactly() async throws {
        let source = ReplaySensorSource(frames: makeFrames())
        #expect(try await source.snapshot().first?.celsius == 50)
        #expect(try await source.snapshot().first?.celsius == 60)
        #expect(try await source.snapshot().first?.celsius == 70)
    }

    @Test("past the end it holds the last frame instead of failing")
    func holdsAtEnd() async throws {
        let source = ReplaySensorSource(frames: makeFrames())
        for _ in 0..<3 { _ = try await source.snapshot() }
        #expect(try await source.snapshot().first?.celsius == 70)
    }

    @Test("looping wraps back to the first frame")
    func loops() async throws {
        let source = ReplaySensorSource(frames: makeFrames(), loops: true)
        for _ in 0..<3 { _ = try await source.snapshot() }
        #expect(try await source.snapshot().first?.celsius == 50)
    }

    @Test("a truncated recording still loads, skipping unusable lines")
    func skipsMalformedLines() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let good = try encoder.encode(makeFrames()[0])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("boreas-replay-\(UUID().uuidString).jsonl")
        let line = try #require(String(bytes: good, encoding: .utf8))
        var text = line + "\n"
        text += "{ this line is truncated\n"  // a crashed session looks like this
        text += line + "\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = try ReplaySensorSource(contentsOf: url)
        #expect(source.frameCount == 2, "the two intact frames must survive")
    }

    @Test("a recording with nothing decodable is an error, not silent emptiness")
    func emptyRecordingThrows() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("boreas-empty-\(UUID().uuidString).jsonl")
        try "not json at all\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: HardwareError.self) {
            _ = try ReplaySensorSource(contentsOf: url)
        }
    }
}

@Suite("SMC decoding")
struct SMCDecodingTests {

    @Test("four character keys round trip through the wire encoding")
    func keyRoundTrip() {
        for key in ["TC0P", "F0Ac", "#KEY", "FNum"] {
            let encoded = SMCConnection.encode(key: key)
            #expect(SMCConnection.decode(key: encoded) == key)
        }
    }

    @Test("a float payload decodes little endian")
    func floatDecoding() {
        let value = SMCValue(key: "TC0P", type: "flt ", bytes: [0x00, 0x00, 0x8C, 0x42])
        let decoded = try? #require(value.numericValue)
        #expect(decoded.map { abs($0 - 70) < 0.001 } == true)
    }

    @Test("fixed point types decode with their documented scaling")
    func fixedPointDecoding() {
        let sp78 = SMCValue(key: "TC0D", type: "sp78", bytes: [45, 128])
        #expect(sp78.numericValue == 45.5)

        let fpe2 = SMCValue(key: "F0Ac", type: "fpe2", bytes: [0x1F, 0x40])
        #expect(fpe2.numericValue == 2000)
    }

    @Test("an unknown type tag yields nil instead of a guessed number")
    func unknownTypeIsNotGuessed() {
        let value = SMCValue(key: "TQ4X", type: "zz99", bytes: [1, 2, 3, 4])
        #expect(value.numericValue == nil, "guessing produces a plausible wrong temperature")
    }

    @Test("a truncated payload yields nil rather than reading past the end")
    func truncatedPayload() {
        #expect(SMCValue(key: "TC0P", type: "flt ", bytes: [0x00, 0x00]).numericValue == nil)
        #expect(SMCValue(key: "TC0D", type: "sp78", bytes: [45]).numericValue == nil)
    }

    @Test("fan name decoding tolerates payloads that carry no label")
    func fanNameDecoding() {
        #expect(LiveFanSource.decodeFanName([0, 0, 0, 0]) == nil)
        #expect(LiveFanSource.decodeFanName([]) == nil)
        let named: [UInt8] = [0, 0, 0, 0] + Array("Left Side".utf8)
        #expect(LiveFanSource.decodeFanName(named) == "Left Side")
    }
}
