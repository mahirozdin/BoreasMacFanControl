import Core
import Foundation
import HardwareKit
import OSLog

/// Polls the hardware and publishes what it finds to the interface.
///
/// Reading needs no privileges, so this runs whether or not the privileged
/// helper is installed. A machine with no helper is a fully working monitor,
/// which is the behaviour invariant İ4 requires.
@MainActor
@Observable
public final class MonitorModel {

    public private(set) var readings: [SensorReading] = []
    public private(set) var fans: [FanState] = []
    public private(set) var power: PowerContext = .desktop

    /// Non-nil when sensors cannot be read at all. The interface shows this
    /// instead of an empty list, so "no data" is never mistaken for "cool".
    public private(set) var sensorProblem: String?

    /// Non-nil when readings come from a degraded path.
    public private(set) var degradedReason: String?

    public private(set) var isRunning = false

    private var sensors: LiveSensorSource?
    private var fanSource: LiveFanSource?
    private let powerSource = LivePowerSource()
    private var task: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "ui")

    /// How often the hardware is sampled. Two seconds keeps the display close
    /// to live while leaving the process essentially idle in between.
    private let interval: Duration = .seconds(2)

    public init() {}

    public var hottest: SensorReading? {
        readings.max { $0.celsius < $1.celsius }
    }

    /// Readings grouped for display, with empty groups omitted.
    public var grouped: [(group: SensorGroup, readings: [SensorReading])] {
        let byGroup = Dictionary(grouping: readings, by: \.group)
        return SensorGroup.allCases.compactMap { group in
            guard let items = byGroup[group], !items.isEmpty else { return nil }
            return (group, items.sorted { $0.celsius > $1.celsius })
        }
    }

    public func start() {
        guard task == nil else { return }
        isRunning = true
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sample()
                try? await Task.sleep(for: self?.interval ?? .seconds(2))
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func sample() async {
        power = powerSource.current()

        do {
            if sensors == nil { sensors = try LiveSensorSource() }
            if let sensors {
                readings = try await sensors.snapshot()
                degradedReason = await sensors.degradedReason
                sensorProblem = nil
            }
        } catch {
            // Degrade rather than fail: fans and power are still shown, and the
            // user is told exactly what is missing.
            readings = []
            sensorProblem = String(
                localized: "monitor.sensors.unavailable",
                defaultValue: "Temperature sensors are not responding on this Mac.",
                comment: "Shown when no sensor backend answers; the rest of the app keeps working"
            )
            logger.error("sensor read failed: \(String(describing: error), privacy: .public)")
        }

        do {
            if fanSource == nil { fanSource = try LiveFanSource() }
            if let fanSource {
                fans = try await fanSource.fans()
            }
        } catch {
            fans = []
            logger.error("fan read failed: \(String(describing: error), privacy: .public)")
        }
    }
}
