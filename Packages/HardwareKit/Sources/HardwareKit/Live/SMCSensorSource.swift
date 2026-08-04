import Core
import Foundation

/// Reads temperatures from the SMC. This is the **fallback** backend.
///
/// The SMC always answers, which is why it is the safety net, but it reports
/// opaque four character keys rather than names. ``SensorClassifier`` recovers
/// most of the meaning from key prefixes; the readable names come from
/// ``HIDSensorSource`` when that interface is available.
///
/// Key discovery is done at runtime by walking the namespace and keeping
/// anything that decodes to a plausible temperature. No per-model key table
/// exists on purpose: those need a release for every new Mac, and this project
/// is developed on a single machine (see the hardware coverage note in
/// `docs/development/testing.md`).
public struct SMCSensorSource: SensorSource {

    public let identifier = "smc"

    private let connection: SMCConnection
    private let overrides: [String: SensorOverride]

    public init(overrides: [String: SensorOverride] = [:]) throws {
        self.connection = try SMCConnection()
        self.overrides = overrides
    }

    public func snapshot() async throws -> [SensorReading] {
        let keys = try temperatureKeys()
        guard !keys.isEmpty else {
            throw HardwareError.noData("no temperature keys found in the SMC namespace")
        }

        var readings: [SensorReading] = []
        readings.reserveCapacity(keys.count)

        for key in keys {
            guard
                let value = try? connection.readValue(key: key),
                let celsius = value.numericValue
            else { continue }

            let reading = SensorClassifier.makeReading(
                rawName: key,
                celsius: celsius,
                overrides: overrides
            )
            // A parked cluster reports values far outside anything physical.
            // Those are dropped here rather than being handed to a fan curve.
            guard reading.isPlausible else { continue }
            readings.append(reading)
        }

        return readings.sorted { $0.displayName < $1.displayName }
    }

    /// Temperature keys start with `T`. The namespace also holds fan, voltage
    /// and current keys, which are read elsewhere or not at all.
    private func temperatureKeys() throws -> [String] {
        let count = try connection.keyCount()
        var result: [String] = []
        for index in 0..<count {
            guard let key = try? connection.key(at: index) else { continue }
            if key.hasPrefix("T") { result.append(key) }
        }
        return result
    }
}
