import Foundation

/// A bounded measurement history that **loses resolution rather than the
/// past**.
///
/// The monitoring tab offers windows from five minutes to twenty four hours.
/// Storing every two-second sample for a day would be 43 200 points per
/// series, and dropping the oldest samples to stay inside a budget would
/// quietly amputate exactly the long window the user asked for. So the
/// series keeps its whole span and halves its own resolution whenever it
/// fills up: the history always reaches back as far as the application has
/// been running, and only the fine detail of old data fades.
///
/// Pure and value-typed, so the whole retention policy is unit testable —
/// the interface only draws what this decides to keep.
public struct TimeSeries: Sendable, Hashable {

    public struct Sample: Sendable, Hashable {
        public let time: Date
        public let value: Double

        public init(time: Date, value: Double) {
            self.time = time
            self.value = value
        }
    }

    /// The most samples that will ever be held. Reaching it triggers a
    /// halving, so the count oscillates between capacity/2 and capacity.
    public let capacity: Int

    public private(set) var samples: [Sample] = []

    /// The current minimum spacing accepted between stored samples. It
    /// starts at the sampling cadence and doubles on every halving, which
    /// is what stops a refilled buffer from halving again immediately.
    public private(set) var interval: TimeInterval

    public init(capacity: Int = 1800, baseInterval: TimeInterval = 2) {
        // A capacity below two cannot express a series at all, and a
        // non-positive interval would accept every sample forever.
        self.capacity = Swift.max(2, capacity)
        self.interval = Swift.max(0.001, baseInterval)
    }

    /// Offers a measurement. Samples arriving faster than `interval` are
    /// declined — the caller may poll as often as it likes.
    ///
    /// A non-finite reading is refused outright: a chart gap is honest
    /// about a sensor that stopped answering, whereas a substituted number
    /// would be a temperature nobody measured.
    public mutating func record(_ value: Double, at time: Date) {
        guard value.isFinite else { return }
        if let last = samples.last {
            guard time.timeIntervalSince(last.time) >= interval else { return }
        }
        samples.append(Sample(time: time, value: value))
        if samples.count > capacity {
            halveResolution()
        }
    }

    /// Keeps, from each adjacent pair, the sample with the **higher** value
    /// — carrying its own timestamp with it.
    ///
    /// Two consequences are deliberate. Every surviving point is a real
    /// measurement that really happened at that moment; nothing is averaged
    /// into existence. And peaks survive thinning, which matters here more
    /// than anywhere: a chart of a machine's thermal history whose spikes
    /// smooth themselves away with age is a chart that hides the events the
    /// user opened it to find. It is the same bias as `SensorAggregate.max`
    /// being the safety default.
    private mutating func halveResolution() {
        var kept: [Sample] = []
        kept.reserveCapacity(samples.count / 2 + 1)
        var index = 0
        while index < samples.count {
            if index + 1 < samples.count {
                let first = samples[index]
                let second = samples[index + 1]
                kept.append(first.value >= second.value ? first : second)
                index += 2
            } else {
                kept.append(samples[index])
                index += 1
            }
        }
        samples = kept
        interval *= 2
    }

    /// The samples inside a window ending at a given moment.
    public func window(_ span: TimeInterval, endingAt end: Date) -> [Sample] {
        let start = end.addingTimeInterval(-span)
        return samples.filter { $0.time >= start && $0.time <= end }
    }

    /// The whole span currently covered, or zero while there is nothing to
    /// cover.
    public var coveredSpan: TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return last.time.timeIntervalSince(first.time)
    }

    public mutating func clear() {
        samples.removeAll()
    }
}

/// The time windows the monitoring chart offers (blueprint §9.3).
public enum HistoryWindow: String, Sendable, Hashable, CaseIterable, Codable {
    case fiveMinutes
    case oneHour
    case sixHours
    case twentyFourHours

    public var span: TimeInterval {
        switch self {
        case .fiveMinutes: return 5 * 60
        case .oneHour: return 60 * 60
        case .sixHours: return 6 * 60 * 60
        case .twentyFourHours: return 24 * 60 * 60
        }
    }
}

/// Session statistics for one sensor: what the table's "highest" and
/// "average" columns mean, and what "reset maximums" resets.
///
/// The mean is kept as a running sum rather than over the retained samples
/// on purpose — `TimeSeries` deliberately biases towards peaks when it
/// thins itself, so a mean computed from it would drift upwards the longer
/// the session ran.
public struct ReadingStatistics: Sendable, Hashable {

    public private(set) var maximum: Double?
    private var sum: Double = 0
    private var samplesSeen: Int = 0

    public init() {}

    public var mean: Double? {
        samplesSeen == 0 ? nil : sum / Double(samplesSeen)
    }

    public mutating func record(_ value: Double) {
        guard value.isFinite else { return }
        maximum = maximum.map { Swift.max($0, value) } ?? value
        sum += value
        samplesSeen += 1
    }

    /// The "reset maximums" action clears the whole session record, not
    /// only the peak: a maximum reset next to a mean still averaging over
    /// the discarded period would be two numbers describing different
    /// sessions.
    public mutating func reset() {
        maximum = nil
        sum = 0
        samplesSeen = 0
    }
}
