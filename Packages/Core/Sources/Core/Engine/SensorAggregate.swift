import Foundation

/// How a group of sensor readings collapses into the one temperature a
/// curve consumes (`docs/product/control-model.md`, input selection).
public enum SensorAggregate: String, Sendable, Hashable, Codable, CaseIterable {

    /// The default, biased towards safety: the hottest sensor decides.
    case max
    /// Smoother behaviour; a single hot spot pulls less.
    case mean
    /// The 95th percentile: ignores one outlier sensor without ignoring a
    /// genuinely hot cluster.
    case p95

    /// Collapses the readings. `nil` for an empty list — no data is not a
    /// temperature, and inventing one here would feed the curve fiction.
    /// Non-finite readings are dropped before aggregating.
    public func value(of readings: [Double]) -> Double? {
        let usable = readings.filter(\.isFinite)
        guard !usable.isEmpty else { return nil }

        switch self {
        case .max:
            return usable.max()
        case .mean:
            return usable.reduce(0, +) / Double(usable.count)
        case .p95:
            // Nearest-rank on the sorted list: the smallest value with at
            // least 95 % of the readings at or below it.
            let sorted = usable.sorted()
            let rank = Int((0.95 * Double(sorted.count)).rounded(.up))
            let index = Swift.min(Swift.max(rank - 1, 0), sorted.count - 1)
            return sorted[index]
        }
    }
}
