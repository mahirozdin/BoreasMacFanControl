import Core
import Foundation

/// Deterministic stand-in for real sensors.
///
/// This exists because the project is developed on one Mac. Fanless machines,
/// multi-fan machines, battery powered machines and every chip generation other
/// than the development one can only be exercised here. Without it those code
/// paths would ship untested — see the hardware coverage table in
/// `docs/development/testing.md`.
public actor MockSensorSource: SensorSource {

    public nonisolated let identifier = "mock"

    /// Scripted frames. Each `snapshot()` returns the next one and holds on the
    /// last, so a test can describe a temperature ramp and then let it settle.
    private let frames: [[SensorReading]]
    private var index = 0

    /// Error thrown instead of returning data, for exercising failure handling.
    private let failure: HardwareError?

    public init(frames: [[SensorReading]], failure: HardwareError? = nil) {
        self.frames = frames
        self.failure = failure
    }

    public init(readings: [SensorReading]) {
        self.init(frames: [readings])
    }

    /// A source that always fails, for testing graceful degradation.
    public static func failing(_ error: HardwareError = .serviceUnavailable("mock")) -> MockSensorSource {
        MockSensorSource(frames: [], failure: error)
    }

    public func snapshot() async throws -> [SensorReading] {
        if let failure { throw failure }
        guard !frames.isEmpty else { return [] }
        let frame = frames[min(index, frames.count - 1)]
        index += 1
        return frame
    }

    /// Rewinds so a scripted sequence can be replayed.
    public func reset() {
        index = 0
    }
}

extension MockSensorSource {

    /// A small, realistic set of readings for an Apple Silicon desktop.
    ///
    /// Names are the shapes this hardware actually reports, so the classifier
    /// is exercised against realistic input rather than tidy invented strings.
    public static func appleSiliconDesktop(hot: Bool = false) -> MockSensorSource {
        let offset: Double = hot ? 32 : 0
        let raw: [(String, Double)] = [
            ("pACC MTR Temp Sensor1", 58 + offset),
            ("pACC MTR Temp Sensor3", 61 + offset),
            ("eACC MTR Temp Sensor1", 47 + offset),
            ("GPU MTR Temp Sensor1", 52 + offset),
            ("PMGR SOC Die Temp", 55 + offset),
            ("NAND CH0 temp", 41 + offset),
            ("TQ4X mystery probe", 39 + offset),
        ]
        return MockSensorSource(
            readings: raw.map { SensorClassifier.makeReading(rawName: $0.0, celsius: $0.1) }
        )
    }
}
