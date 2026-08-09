import Charts
import Core
import SwiftUI

/// The monitoring tab's two charts (P6.04).
///
/// **They share one x domain, computed once and handed to both.** That is
/// the point of the pair: the fan chart sitting under the temperature chart
/// on the same clock is what lets a user see a rise and the response to it
/// as cause and effect rather than as two unrelated pictures. Letting each
/// chart infer its own domain from its own data would break the alignment
/// precisely when the series have different lengths — which is whenever a
/// fan was parked or a sensor dropped out.
struct MonitoringCharts: View {
    let model: MonitorModel
    let window: HistoryWindow
    /// Groups the user has switched off in the legend.
    let hiddenGroups: Set<SensorGroup>
    /// Frozen "now" for the render evidence; live otherwise.
    let now: Date

    private var domain: ClosedRange<Date> {
        now.addingTimeInterval(-window.span)...now
    }

    /// Groups that have history, in a stable order so a series keeps its
    /// colour between redraws.
    private var visibleGroups: [SensorGroup] {
        SensorGroup.allCases
            .filter { model.groupHistory[$0] != nil && !hiddenGroups.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            temperatureChart
            fanChart
        }
    }

    private var temperatureChart: some View {
        Chart {
            ForEach(Array(visibleGroups.enumerated()), id: \.element) { index, group in
                ForEach(sampleRange(model.groupHistory[group]), id: \.time) { sample in
                    LineMark(
                        x: .value("Time", sample.time),
                        y: .value("Temperature", sample.value)
                    )
                    .foregroundStyle(Color.series(index))
                    .interpolationMethod(.monotone)
                }
                .foregroundStyle(by: .value("Group", group.displayName))
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: temperatureDomain)
        .chartForegroundStyleScale(
            domain: visibleGroups.map(\.displayName),
            range: visibleGroups.indices.map { Color.series($0) }
        )
        .chartYAxisLabel(
            String(
                localized: "chart.axis.temperature", defaultValue: "°C",
                comment: "Y axis label of the temperature chart")
        )
        // The series toggles above the chart already name every series and
        // carry its colour; a second legend underneath would be the same
        // information twice.
        .chartLegend(.hidden)
        .frame(height: 190)
        .accessibilityLabel(
            String(
                localized: "chart.temperature.accessibility",
                defaultValue: "Temperature over the last \(window.displayName)",
                comment: "VoiceOver label for the temperature time series chart"))
    }

    private var fanChart: some View {
        Chart {
            ForEach(model.fans) { fan in
                ForEach(sampleRange(model.fanHistory[fan.id]), id: \.time) { sample in
                    LineMark(
                        x: .value("Time", sample.time),
                        y: .value("Speed", sample.value)
                    )
                    // Fans stay neutral: hue belongs to temperature
                    // (docs/product/ui.md), and a fan chart with its own
                    // axis needs no hue to say how fast.
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: fanDomain)
        .chartYAxisLabel(
            String(
                localized: "chart.axis.fan", defaultValue: "rpm",
                comment: "Y axis label of the fan speed chart")
        )
        .frame(height: 120)
        .accessibilityLabel(
            String(
                localized: "chart.fan.accessibility",
                defaultValue: "Fan speed over the last \(window.displayName)",
                comment: "VoiceOver label for the fan speed time series chart"))
    }

    private func sampleRange(_ series: TimeSeries?) -> [TimeSeries.Sample] {
        series?.window(window.span, endingAt: now) ?? []
    }

    /// Fitted to the data with a margin, not anchored at zero. Zero is not
    /// a temperature any Mac reaches, and a scale that reserved two thirds
    /// of its height for temperatures that cannot happen would flatten the
    /// movement the chart exists to show.
    private var temperatureDomain: ClosedRange<Double> {
        let values = visibleGroups.flatMap { sampleRange(model.groupHistory[$0]).map(\.value) }
        guard let low = values.min(), let high = values.max() else { return 30...90 }
        // A margin, plus a floor on the height so a dead-flat idle machine
        // does not get its sensor noise magnified into drama.
        let padded = (low - 3)...(high + 3)
        guard padded.upperBound - padded.lowerBound < 12 else { return padded }
        let middle = (padded.lowerBound + padded.upperBound) / 2
        return (middle - 6)...(middle + 6)
    }

    /// The fan's own usable range, so the line's height answers "how hard
    /// is this fan working, out of everything it could do" rather than
    /// "how far is it from stopped" — which it never is.
    private var fanDomain: ClosedRange<Double> {
        let minimum = model.fans.map(\.minimumRPM).min() ?? 0
        let maximum = model.fans.map(\.maximumRPM).max() ?? 5_000
        guard maximum > minimum else { return 0...5_000 }
        return Double(minimum)...Double(maximum)
    }
}

/// The window picker and the series toggles that sit above the charts.
struct ChartControls: View {
    let groups: [SensorGroup]
    @Binding var window: HistoryWindow
    @Binding var hiddenGroups: Set<SensorGroup>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hand-rolled chips rather than a segmented Picker: the
            // AppKit-backed control renders as a placeholder in the
            // evidence, and these match the profile chips the rest of the
            // product already uses.
            HStack(spacing: 6) {
                ForEach(HistoryWindow.allCases, id: \.self) { choice in
                    windowChip(choice)
                }
            }
            .accessibilityLabel(
                String(
                    localized: "chart.window.label", defaultValue: "Chart time window",
                    comment: "Accessibility label of the chart time window chips"))

            if groups.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(groups.enumerated()), id: \.element) { index, group in
                        seriesToggle(group, index: index)
                    }
                }
            }
        }
    }

    private func windowChip(_ choice: HistoryWindow) -> some View {
        let selected = window == choice
        return Button {
            window = choice
        } label: {
            Text(verbatim: choice.displayName)
                .font(.caption)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    selected ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.05),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        selected ? Color.accentColor : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// A legend entry that is also the switch for its series. The checkmark
    /// state is carried by opacity *and* by the strikethrough-free label,
    /// never by colour alone.
    private func seriesToggle(_ group: SensorGroup, index: Int) -> some View {
        let hidden = hiddenGroups.contains(group)
        return Button {
            if hidden {
                hiddenGroups.remove(group)
            } else {
                hiddenGroups.insert(group)
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.series(index))
                    .frame(width: 8, height: 8)
                    .opacity(hidden ? 0.25 : 1)
                Text(verbatim: group.displayName)
                    .font(.caption)
                    .foregroundStyle(hidden ? .tertiary : .primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(
            String(
                localized: "chart.series.toggle.help",
                defaultValue: "Show or hide this series",
                comment: "Tooltip on a chart legend entry that toggles its series"))
    }
}
