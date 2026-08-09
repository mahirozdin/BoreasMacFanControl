import Core
import Foundation
import HardwareKit
import OSLog

/// Polls the hardware and publishes what it finds to the interface.
///
/// Reading needs no privileges, so this runs whether or not the privileged
/// helper is installed. A machine with no helper is a fully working monitor,
/// which is the behaviour invariant I4 requires.
@MainActor
@Observable
public final class MonitorModel {

    public private(set) var readings: [SensorReading] = []
    public private(set) var fans: [FanState] = []
    public private(set) var power: PowerContext = .desktop

    /// The system's own thermal pressure, sampled rather than read at the
    /// point of display: a live read inside a view body would make the
    /// render evidence depend on how warm the rendering machine happens to
    /// be. K2 reads the same official API in the safety chain.
    public private(set) var thermal: ThermalPressure = .nominal

    /// Non-nil when sensors cannot be read at all. The interface shows this
    /// instead of an empty list, so "no data" is never mistaken for "cool".
    public private(set) var sensorProblem: String?

    /// Non-nil when readings come from a degraded path.
    public private(set) var degradedReason: String?

    /// The hottest reading over time, feeding the status item's mini chart.
    public private(set) var overallHistory = TimeSeries()

    /// Per group, the hottest reading of that group over time — one chart
    /// series each. Groups are the granularity curves are bound to, so a
    /// chart series answers the question a curve asks.
    public private(set) var groupHistory: [SensorGroup: TimeSeries] = [:]

    /// Per fan, its speed over time. Same clock as the temperatures, which
    /// is what lets the two charts share an axis and show cause next to
    /// effect.
    public private(set) var fanHistory: [Int: TimeSeries] = [:]

    /// Session peak and average per sensor, keyed by sensor id. Reset by
    /// `resetMaximums()`.
    public private(set) var statistics: [String: ReadingStatistics] = [:]

    /// The last three minutes of the hottest reading — the menu bar
    /// sparkline. Derived rather than stored: two copies of the same
    /// history would eventually disagree.
    ///
    /// The window is anchored to the newest sample rather than to the wall
    /// clock, so a stalled sensor leaves the last known shape on screen
    /// instead of silently emptying the chart. That a sensor has stopped
    /// answering is `sensorProblem`'s job to say, in words.
    public var sparkline: [Double] {
        guard let newest = overallHistory.samples.last else { return [] }
        return overallHistory.window(180, endingAt: newest.time).map(\.value)
    }

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

    /// Render support (`--render-panel`, `--render-status`): a monitor
    /// frozen on fixed data, never started. Follows the `--render-setup`
    /// precedent — deterministic evidence needs deterministic inputs.
    init(
        fixedForRendering readings: [SensorReading],
        fans: [FanState],
        history: [(Date, Double)] = [],
        groupHistory: [SensorGroup: [(Date, Double)]] = [:],
        fanHistory: [Int: [(Date, Double)]] = [:]
    ) {
        self.readings = readings
        self.fans = fans
        for (time, value) in history {
            overallHistory.record(value, at: time)
        }
        for (group, samples) in groupHistory {
            var series = TimeSeries()
            for (time, value) in samples { series.record(value, at: time) }
            self.groupHistory[group] = series
        }
        for (fanID, samples) in fanHistory {
            var series = TimeSeries()
            for (time, value) in samples { series.record(value, at: time) }
            self.fanHistory[fanID] = series
        }
        for reading in readings {
            statistics[reading.id, default: ReadingStatistics()].record(reading.celsius)
        }
    }

    /// Clears the session peaks and averages behind the sensor table's
    /// "highest" and "average" columns. The chart history is a separate
    /// record and is deliberately left alone — the action resets the
    /// session's statistics, not the machine's past.
    public func resetMaximums() {
        for key in statistics.keys {
            statistics[key]?.reset()
        }
    }

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
        thermal = ThermalPressure(ProcessInfo.processInfo.thermalState)

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

        recordHistory(at: Date())
    }

    /// Files this sample into every series and statistic.
    ///
    /// Implausible readings are excluded throughout: Apple Silicon parks
    /// unused clusters and their sensors then report values far outside
    /// anything physical, and a chart or an average that swallowed those
    /// would be describing the parking, not the machine.
    private func recordHistory(at now: Date) {
        let usable = readings.filter(\.isPlausible)

        if let hottest = usable.map(\.celsius).max() {
            overallHistory.record(hottest, at: now)
        }

        for (group, items) in Dictionary(grouping: usable, by: \.group) {
            guard let peak = items.map(\.celsius).max() else { continue }
            groupHistory[group, default: TimeSeries()].record(peak, at: now)
        }

        for fan in fans where !fan.isPoweredOff {
            fanHistory[fan.id, default: TimeSeries()].record(Double(fan.currentRPM), at: now)
        }

        for reading in usable {
            statistics[reading.id, default: ReadingStatistics()].record(reading.celsius)
        }
    }
}
