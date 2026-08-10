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

    /// What the interface shows: hidden sensors removed.
    public private(set) var readings: [SensorReading] = []

    /// Every sensor read this cycle, hidden ones included. The settings
    /// list needs it (a sensor you cannot see is a sensor you cannot
    /// un-hide) and so does the safety chain, whose panic input is the
    /// hottest reading *anywhere*.
    public private(set) var allReadings: [SensorReading] = []
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

    /// When this monitor started sampling — the "session" the diagnostics
    /// and the sensor table both mean.
    public private(set) var sessionStart = Date()

    /// Seconds spent at each thermal pressure level. Accumulated from the
    /// samples rather than from a timer: the thermal history check should
    /// count time the application actually observed, not wall time it
    /// assumes it was watching.
    public private(set) var thermalSeconds: [ThermalPressure: Double] = [:]

    /// Battery and drive health, refreshed far more slowly than the sensors
    /// (P7.03).
    ///
    /// **Every two minutes, not every two seconds.** A cycle count changes a few
    /// hundred times over a machine's life and free space changes in megabytes;
    /// walking the IO registry on the sampling cycle would be work nobody asked
    /// for, forty times a minute, for numbers that had not moved.
    public private(set) var batteryReading: DiagnosticChecks.BatteryReading?
    public private(set) var storageReading: DiagnosticChecks.StorageReading?

    private var lastSampleAt: Date?

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
    /// Injected so the laptop path is reachable at all: this machine has no
    /// battery, so `MockHealthSource` is the only way those branches run (R8).
    private let healthSource: any HealthSource
    private var lastHealthReadAt: Date?
    private var task: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "ui")

    /// The configuration this model reads its sampling interval and sensor
    /// overrides from, when there is one. Optional for the same reason as
    /// `ControlModel`'s: drills and render fixtures build a monitor too.
    private let store: ConfigurationStore?

    /// How often the hardware is sampled. Two seconds keeps the display close
    /// to live while leaving the process essentially idle in between; the
    /// configuration may widen or narrow it, and the type clamps it.
    private var interval: Duration {
        .seconds(store?.configuration.general.samplingIntervalSeconds ?? 2)
    }

    public init(
        store: ConfigurationStore? = nil,
        healthSource: any HealthSource = LiveHealthSource()
    ) {
        self.store = store
        self.healthSource = healthSource
    }

    /// Render support (`--render-panel`, `--render-status`): a monitor
    /// frozen on fixed data, never started. Follows the `--render-setup`
    /// precedent — deterministic evidence needs deterministic inputs.
    init(
        fixedForRendering readings: [SensorReading],
        fans: [FanState],
        history: [(Date, Double)] = [],
        groupHistory: [SensorGroup: [(Date, Double)]] = [:],
        fanHistory: [Int: [(Date, Double)]] = [:],
        sessionStart: Date? = nil,
        thermalSeconds: [ThermalPressure: Double] = [:],
        // Defaults to the desktop mock, which is what the development machine
        // actually is — a render fixture that invented a battery would be
        // photographing a Mac nobody has.
        healthSource: any HealthSource = MockHealthSource.desktop
    ) {
        self.store = nil
        self.healthSource = healthSource
        self.batteryReading = healthSource.battery()
        self.storageReading = healthSource.storage(nandCelsius: nil)
        self.readings = readings
        self.allReadings = readings
        if let sessionStart { self.sessionStart = sessionStart }
        self.thermalSeconds = thermalSeconds
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

    /// The recent operating points — temperature against the duty the fan
    /// was actually running at — for the curve editor's trail (P6.06).
    ///
    /// This is the layer that lets a user compare the curve they drew with
    /// what the machine did: smoothing, hysteresis and the rate limiter all
    /// sit between the two, so the cloud sits *near* the curve rather than
    /// on it, and that gap is the information.
    ///
    /// The two series are recorded in the same sampling pass and therefore
    /// share timestamps, but each thins independently once it fills, so the
    /// pairing is by nearest time rather than by index.
    public func operatingTrail(
        group: SensorGroup,
        fanID: Int,
        seconds: TimeInterval,
        now: Date
    ) -> [(celsius: Double, duty: Double)] {
        guard let fan = fans.first(where: { $0.id == fanID }), fan.span > 0,
            let temperatures = groupHistory[group]?.window(seconds, endingAt: now),
            let speeds = fanHistory[fanID]?.window(seconds, endingAt: now),
            !speeds.isEmpty
        else { return [] }

        return temperatures.compactMap { sample in
            let nearest = speeds.min {
                abs($0.time.timeIntervalSince(sample.time))
                    < abs($1.time.timeIntervalSince(sample.time))
            }
            guard let nearest,
                abs(nearest.time.timeIntervalSince(sample.time)) <= 1.5
            else { return nil }
            let duty = (nearest.value - Double(fan.minimumRPM)) / Double(fan.span)
            return (sample.value, Swift.min(1, Swift.max(0, duty)))
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

    /// Called after every completed sample, on the main actor.
    ///
    /// Set by the app so `NotificationModel` can look for state transitions
    /// without the monitor depending on it. Optional so every drill and render
    /// fixture that builds a monitor keeps working untouched.
    public var onCycle: (() -> Void)?

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
                readings = applyOverrides(to: try await sensors.snapshot())
                degradedReason = await sensors.degradedReason
                sensorProblem = nil
            }
        } catch {
            // Degrade rather than fail: fans and power are still shown, and the
            // user is told exactly what is missing.
            readings = []
            allReadings = []
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
        refreshHealthIfDue(at: Date())
        // The notification model watches for *edges* in what this cycle
        // observed (P7.01). A closure rather than the model holding a
        // reference back: the monitor is the thing that knows when a sample
        // is complete, and it has no business knowing what a notification is.
        onCycle?()
    }

    /// Reads battery and drive health, at most once every `healthInterval`.
    ///
    /// The interval is the whole design: these are slow-moving facts and the read
    /// walks the IO registry, so doing it on the sampling cycle would be pure
    /// waste. The first sample happens immediately, so a diagnostics tab opened
    /// straight after launch has something to show.
    private func refreshHealthIfDue(at now: Date) {
        if let last = lastHealthReadAt, now.timeIntervalSince(last) < Self.healthInterval {
            return
        }
        lastHealthReadAt = now
        batteryReading = healthSource.battery()
        // The hottest storage-group reading, handed in rather than read again:
        // the sensor stack already has it, and a second reader would be a second
        // answer to the same question.
        let nand = allReadings.filter { $0.group == .storage }.map(\.celsius).max()
        storageReading = healthSource.storage(nandCelsius: nand)
    }

    /// How often health is re-read. Two minutes: often enough that a drive
    /// filling up during a long session is noticed, rare enough to be free.
    private static let healthInterval: TimeInterval = 120

    /// Re-derives every reading through the classifier with the user's
    /// corrections applied (P6.08).
    ///
    /// Applied here rather than deeper down because these readings feed the
    /// engine as well as the interface: a sensor re-filed into another
    /// group must change which curve can bind to it, not merely what the
    /// list says. Hidden sensors are dropped from the *published* list only
    /// after `allReadings` has kept a copy — the safety chain's panic input
    /// is the hottest reading anywhere, and hiding is a display choice.
    private func applyOverrides(to raw: [SensorReading]) -> [SensorReading] {
        let overrides = store?.configuration.sensorOverrides ?? [:]
        guard !overrides.isEmpty else {
            allReadings = raw
            return raw
        }
        let corrected = raw.map {
            SensorClassifier.makeReading(
                rawName: $0.rawName, celsius: $0.celsius, overrides: overrides)
        }
        allReadings = corrected
        return corrected.filter { !(overrides[$0.rawName]?.hidden ?? false) }
    }

    /// Files this sample into every series and statistic.
    ///
    /// Implausible readings are excluded throughout: Apple Silicon parks
    /// unused clusters and their sensors then report values far outside
    /// anything physical, and a chart or an average that swallowed those
    /// would be describing the parking, not the machine.
    private func recordHistory(at now: Date) {
        // Time is attributed to the level that held *during* the gap, which
        // is the level this sample reports. Attributing it to the next one
        // would credit a spike with the calm before it.
        if let last = lastSampleAt {
            let elapsed = now.timeIntervalSince(last)
            // A gap far longer than the cadence means the machine slept or
            // the process was stopped; counting it would invent observation
            // nobody made.
            if elapsed > 0, elapsed < 60 {
                thermalSeconds[thermal, default: 0] += elapsed
            }
        }
        lastSampleAt = now

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
