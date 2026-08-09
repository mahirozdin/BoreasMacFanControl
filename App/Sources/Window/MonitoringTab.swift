import Core
import SwiftUI

/// The main window's Monitoring tab (P6.04).
///
/// Nothing but the scroll container: the content is `MonitoringContent`
/// because `ScrollView` is AppKit-backed and lays out nothing under
/// `ImageRenderer` — the third container found that way, after
/// `DisclosureGroup` and `LazyVStack` in P6.02. Keeping the container and
/// the content apart is what lets the render evidence photograph the tab.
struct MonitoringTab: View {
    let model: MonitorModel
    let control: ControlModel
    /// Frozen "now" for the render evidence; live otherwise.
    var now: Date = Date()

    var body: some View {
        ScrollView {
            MonitoringContent(model: model, control: control, now: now)
        }
    }
}

/// Summary strip, the two time-aligned charts, and the sensor table with
/// its filter and its "reset highest" action.
struct MonitoringContent: View {
    let model: MonitorModel
    let control: ControlModel
    var now: Date = Date()

    @State private var window: HistoryWindow = .fiveMinutes
    @State private var hiddenGroups: Set<SensorGroup> = []
    @State private var filter = ""
    @State private var column: SensorColumn = .current
    @State private var ascending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SummaryStrip(model: model, control: control)

            VStack(alignment: .leading, spacing: 10) {
                ChartControls(
                    groups: chartedGroups,
                    window: $window,
                    hiddenGroups: $hiddenGroups)
                MonitoringCharts(
                    model: model, window: window,
                    hiddenGroups: hiddenGroups, now: now)
            }

            tableSection
        }
        .padding(18)
    }

    private var chartedGroups: [SensorGroup] {
        SensorGroup.allCases.filter { model.groupHistory[$0] != nil }
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(
                    String(
                        localized: "monitoring.section.sensors", defaultValue: "Sensors",
                        comment: "Heading above the sensor table in the monitoring tab")
                )
                .font(.headline)

                Spacer()

                TextField(
                    String(
                        localized: "monitoring.filter.placeholder", defaultValue: "Filter",
                        comment: "Placeholder of the sensor table filter field"),
                    text: $filter
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

                Button {
                    model.resetMaximums()
                } label: {
                    Text(
                        String(
                            localized: "monitoring.reset", defaultValue: "Reset Highest",
                            comment: "Button that clears the session peak and average columns")
                    )
                }
            }

            SensorTable(rows: rows, column: $column, ascending: $ascending)
        }
    }

    private var rows: [SensorRow] {
        let needle = filter.trimmingCharacters(in: .whitespaces)
        return model.readings.compactMap { reading in
            if !needle.isEmpty {
                // Matching the group name too, so "storage" finds the SSD
                // sensors whatever the hardware chose to call them.
                let haystack = reading.displayName + " " + reading.group.displayName
                guard haystack.localizedCaseInsensitiveContains(needle) else { return nil }
            }
            let stats = model.statistics[reading.id]
            return SensorRow(
                id: reading.id,
                name: reading.displayName,
                group: reading.group,
                current: reading.celsius,
                maximum: stats?.maximum,
                mean: stats?.mean)
        }
    }
}

/// The summary strip: the five numbers worth seeing before anything else.
struct SummaryStrip: View {
    let model: MonitorModel
    let control: ControlModel

    var body: some View {
        HStack(spacing: 10) {
            SummaryCard(
                title: String(
                    localized: "summary.hottest", defaultValue: "Hottest",
                    comment: "Summary card: the highest current sensor reading"),
                value: model.hottest.map { String(format: "%.1f °C", $0.celsius) } ?? "—",
                accent: model.hottest.map { Color.temperature($0.celsius) })

            SummaryCard(
                title: String(
                    localized: "summary.average", defaultValue: "Average",
                    comment: "Summary card: the mean of the current sensor readings"),
                value: meanNow.map { String(format: "%.1f °C", $0) } ?? "—",
                accent: meanNow.map { Color.temperature($0) })

            SummaryCard(
                title: String(
                    localized: "summary.profile", defaultValue: "Profile",
                    comment: "Summary card: the profile currently active"),
                value: control.outcome?.profile.displayName ?? "—",
                accent: nil)

            SummaryCard(
                title: String(
                    localized: "summary.thermal", defaultValue: "Thermal state",
                    comment: "Summary card: the system's reported thermal pressure"),
                value: model.thermal.displayName,
                accent: model.thermal == .nominal ? nil : Color.warningAccent)

            SummaryCard(
                title: String(
                    localized: "summary.fans", defaultValue: "Fans",
                    comment: "Summary card: the average speed of the fans"),
                value: meanRPM.map { "\($0) rpm" } ?? "—",
                accent: nil)
        }
    }

    private var meanNow: Double? {
        let values = model.readings.filter(\.isPlausible).map(\.celsius)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var meanRPM: Int? {
        let running = model.fans.filter { !$0.isPoweredOff }
        guard !running.isEmpty else { return nil }
        return running.map(\.currentRPM).reduce(0, +) / running.count
    }
}

/// One card of the summary strip. Colour is an accent on the number, never
/// the number's only carrier — the text always says the value.
struct SummaryCard: View {
    let title: String
    let value: String
    let accent: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                if let accent {
                    Circle().fill(accent).frame(width: 8, height: 8)
                }
                Text(verbatim: value)
                    .font(.title3)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
