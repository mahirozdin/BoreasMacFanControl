import Foundation
import Testing

@testable import Core

@Suite("Time series (bounded history that keeps its span)")
struct TimeSeriesTests {

    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    /// Feeds `count` samples two seconds apart, `shape` deciding the value.
    private func filled(
        capacity: Int,
        count: Int,
        shape: (Int) -> Double
    ) -> TimeSeries {
        var series = TimeSeries(capacity: capacity, baseInterval: 2)
        for step in 0..<count {
            series.record(shape(step), at: epoch.addingTimeInterval(Double(step) * 2))
        }
        return series
    }

    // MARK: - The retention promise

    @Test("the sample count never exceeds capacity")
    func neverExceedsCapacity() {
        let series = filled(capacity: 100, count: 5_000) { Double($0 % 37) }
        #expect(series.samples.count <= 100)
    }

    @Test("the covered span keeps growing — resolution is what is spent")
    func spanGrowsWhileResolutionFades() {
        let series = filled(capacity: 100, count: 1_000) { Double($0 % 37) }
        let recordedSpan = 999.0 * 2

        // This is the assertion that names the design decision: a
        // drop-the-oldest buffer of this capacity would cover 100 samples
        // at the base cadence — 200 seconds — and the "24 hour" window
        // would quietly become "the last few minutes".
        #expect(series.coveredSpan > 100 * 2 * 5)

        // Up to one (now much longer) interval can be lost at each end
        // when a pair straddles the boundary, so the coverage is near
        // total rather than exactly total.
        #expect(series.coveredSpan >= recordedSpan * 0.9)
        #expect(series.interval > 2)
    }

    @Test("timestamps stay strictly increasing through repeated thinning")
    func timestampsStayOrdered() {
        let series = filled(capacity: 64, count: 2_000) { Double(($0 * 7) % 91) }
        for (earlier, later) in zip(series.samples, series.samples.dropFirst()) {
            #expect(earlier.time < later.time)
        }
    }

    @Test("thinning never invents a value — every point was really measured")
    func retainedValuesWereMeasured() {
        var recorded: Set<Double> = []
        var series = TimeSeries(capacity: 32, baseInterval: 2)
        for step in 0..<1_000 {
            // Distinct values, so a fabricated (averaged) point could not
            // masquerade as one of them.
            let value = Double(step) * 0.5
            recorded.insert(value)
            series.record(value, at: epoch.addingTimeInterval(Double(step) * 2))
        }
        for sample in series.samples {
            #expect(recorded.contains(sample.value))
        }
    }

    @Test("a spike survives repeated thinning")
    func peaksSurvive() {
        // The reason thinning keeps the higher of each pair: a thermal
        // history whose spikes fade with age hides the events the chart was
        // opened to find.
        var series = TimeSeries(capacity: 32, baseInterval: 2)
        for step in 0..<1_000 {
            let value = step == 3 ? 99.0 : 40.0
            series.record(value, at: epoch.addingTimeInterval(Double(step) * 2))
        }
        #expect(series.samples.contains { $0.value == 99 })
    }

    // MARK: - What is refused

    @Test("samples arriving faster than the interval are declined")
    func rateLimited() {
        var series = TimeSeries(capacity: 100, baseInterval: 2)
        for step in 0..<10 {
            // Every half second: only every fourth offer may land.
            series.record(50, at: epoch.addingTimeInterval(Double(step) * 0.5))
        }
        #expect(series.samples.count == 3)
    }

    @Test("an unreadable sensor leaves a gap, never a fabricated number")
    func nonFiniteRefused() {
        var series = TimeSeries(capacity: 100, baseInterval: 2)
        series.record(.nan, at: epoch)
        series.record(.infinity, at: epoch.addingTimeInterval(2))
        #expect(series.samples.isEmpty)
        series.record(42, at: epoch.addingTimeInterval(4))
        #expect(series.samples.count == 1)
    }

    // MARK: - Windowing

    @Test("a window returns exactly the samples inside it")
    func windowing() {
        let series = filled(capacity: 1_000, count: 100) { Double($0) }
        let now = epoch.addingTimeInterval(198)
        let lastMinute = series.window(60, endingAt: now)
        // 60 s at two seconds a sample, inclusive of both ends.
        #expect(lastMinute.count == 31)
        #expect(lastMinute.first?.value == 69)
        #expect(lastMinute.last?.value == 99)
    }

    @Test("an empty series answers with nothing, not with zero")
    func emptySeries() {
        let series = TimeSeries()
        #expect(series.samples.isEmpty)
        #expect(series.coveredSpan == 0)
        #expect(series.window(600, endingAt: epoch).isEmpty)
    }

    @Test("the window spans match the offered choices")
    func windowSpans() {
        #expect(HistoryWindow.fiveMinutes.span == 300)
        #expect(HistoryWindow.oneHour.span == 3_600)
        #expect(HistoryWindow.sixHours.span == 21_600)
        #expect(HistoryWindow.twentyFourHours.span == 86_400)
    }
}

@Suite("Reading statistics (the table's highest and average columns)")
struct ReadingStatisticsTests {

    @Test("maximum and mean track what was recorded")
    func tracksBoth() {
        var stats = ReadingStatistics()
        #expect(stats.maximum == nil)
        #expect(stats.mean == nil)

        for value in [40.0, 60.0, 50.0] { stats.record(value) }
        #expect(stats.maximum == 60)
        #expect(stats.mean == 50)
    }

    @Test("a mean over long sessions does not inherit the series' peak bias")
    func meanIsIndependentOfRetention() {
        // Every sample counts towards the mean even though TimeSeries would
        // have thinned most of them away keeping the peaks — which is why
        // the mean is a running sum and not computed from the samples.
        var stats = ReadingStatistics()
        for step in 0..<1_000 {
            stats.record(step == 500 ? 100 : 40)
        }
        #expect(stats.maximum == 100)
        #expect((stats.mean ?? .infinity) < 40.1)
    }

    @Test("reset clears the whole session record, not only the peak")
    func resetClearsEverything() {
        var stats = ReadingStatistics()
        for value in [90.0, 30.0] { stats.record(value) }
        stats.reset()
        #expect(stats.maximum == nil)
        #expect(stats.mean == nil)

        stats.record(55)
        #expect(stats.maximum == 55)
        #expect(stats.mean == 55)
    }

    @Test("an unreadable value does not enter the statistics")
    func nonFiniteIgnored() {
        var stats = ReadingStatistics()
        stats.record(.nan)
        stats.record(.infinity)
        #expect(stats.maximum == nil)
        #expect(stats.mean == nil)
    }
}
