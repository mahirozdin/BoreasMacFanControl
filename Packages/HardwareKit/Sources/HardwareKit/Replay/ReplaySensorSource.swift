import Core
import Foundation

/// Replays a recorded session.
///
/// This is how a fault on hardware the maintainers do not own gets reproduced:
/// the user sends a log, it is replayed locally, and the control engine sees
/// exactly the readings that machine produced. Without it, a bug report from an
/// unfamiliar Mac is guesswork.
///
/// The format is JSON Lines, one frame per line, matching what the logging
/// subsystem writes.
public actor ReplaySensorSource: SensorSource {

    public nonisolated let identifier = "replay"

    public struct Frame: Sendable, Codable {
        public let timestamp: Date
        public let readings: [SensorReading]

        public init(timestamp: Date, readings: [SensorReading]) {
            self.timestamp = timestamp
            self.readings = readings
        }
    }

    private let frames: [Frame]
    private var index = 0
    private let loops: Bool

    public init(frames: [Frame], loops: Bool = false) {
        self.frames = frames
        self.loops = loops
    }

    /// Loads a JSON Lines recording. Malformed lines are skipped rather than
    /// failing the whole file: a truncated log from a crashed session is
    /// exactly when this is most useful.
    public init(contentsOf url: URL, loops: Bool = false) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var frames: [Frame] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8) else { continue }
            guard let frame = try? decoder.decode(Frame.self, from: data) else { continue }
            frames.append(frame)
        }

        guard !frames.isEmpty else {
            throw HardwareError.noData("no decodable frames in \(url.lastPathComponent)")
        }
        self.init(frames: frames, loops: loops)
    }

    public nonisolated var frameCount: Int { frames.count }

    public func snapshot() async throws -> [SensorReading] {
        guard !frames.isEmpty else {
            throw HardwareError.noData("replay source is empty")
        }
        if index >= frames.count {
            if loops { index = 0 } else { return frames[frames.count - 1].readings }
        }
        let frame = frames[index]
        index += 1
        return frame.readings
    }

    public func reset() {
        index = 0
    }
}
