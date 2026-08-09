import Core
import SwiftUI

/// What sits in the menu bar itself (P6.03).
///
/// Content is configurable through `StatusItemStyle` — primary and
/// secondary temperature, fan speed, mini chart, in a horizontal line or
/// two stacked micro rows, with a compact numbers-only mode. The item stays
/// deliberately small either way: the menu bar is shared with every other
/// application, and a status item that sprawls is one the user ends up
/// hiding — which is exactly the failure the visibility probe then warns
/// about.
struct MenuBarLabel: View {
    let model: MonitorModel
    let control: ControlModel
    var fixedStyleForRendering: StatusItemStyle?

    init(
        model: MonitorModel,
        control: ControlModel,
        fixedStyleForRendering: StatusItemStyle? = nil
    ) {
        self.model = model
        self.control = control
        self.fixedStyleForRendering = fixedStyleForRendering
    }

    @AppStorage(StatusItemStyle.Keys.showTemperature) private var showTemperature = true
    @AppStorage(StatusItemStyle.Keys.secondaryGroup) private var secondaryGroupRaw = ""
    @AppStorage(StatusItemStyle.Keys.showFan) private var showFan = true
    @AppStorage(StatusItemStyle.Keys.showChart) private var showChart = false
    @AppStorage(StatusItemStyle.Keys.vertical) private var vertical = false
    @AppStorage(StatusItemStyle.Keys.compact) private var compact = false

    private var style: StatusItemStyle {
        fixedStyleForRendering
            ?? StatusItemStyle(
                showTemperature: showTemperature,
                secondaryGroup: SensorGroup(rawValue: secondaryGroupRaw),
                showFan: showFan,
                showChart: showChart,
                vertical: vertical,
                compact: compact)
    }

    var body: some View {
        HStack(spacing: style.compact ? 3 : 4) {
            Image(systemName: "fan")
                // The visible-but-unobtrusive mark that control is active:
                // the icon takes the accent while the engine drives, and
                // nothing else about the item changes.
                .foregroundStyle(control.isEngaged ? Color.accentColor : Color.primary)

            profileMark

            if style.vertical {
                stackedContent
            } else {
                inlineContent
            }

            if style.showChart {
                let recent = model.sparkline
                if recent.count >= 2 {
                    TemperatureSparkline(values: recent)
                }
            }
        }
    }

    /// The active profile's initial while the engine drives, and a clock
    /// when the selection is a timed override — the blueprint's
    /// "distinguishing mark". Firmware mode shows nothing: the plain icon
    /// already is the System state.
    @ViewBuilder
    private var profileMark: some View {
        if control.isEngaged, let profile = control.outcome?.profile {
            Text(verbatim: String(profile.displayName.prefix(1)))
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.secondary)
            if case .manual(let until) = control.outcome?.reason, until != nil {
                Image(systemName: "clock")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var inlineContent: some View {
        if style.showTemperature, let hottest = model.hottest {
            Text(verbatim: temperatureText(hottest.celsius))
                .monospacedDigit()
        }
        if let secondary = secondaryReading {
            Text(verbatim: temperatureText(secondary))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        if style.showFan, let fan = model.fans.first, !fan.isPoweredOff {
            Text(verbatim: "\(fan.currentRPM)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    /// Two micro rows: temperatures above, fan speed below. Types stay
    /// dynamic-size-safe — the rows scale with the menu bar's own metrics
    /// rather than a fixed pixel box (Y3).
    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                if style.showTemperature, let hottest = model.hottest {
                    Text(verbatim: temperatureText(hottest.celsius))
                        .monospacedDigit()
                }
                if let secondary = secondaryReading {
                    Text(verbatim: temperatureText(secondary))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            if style.showFan, let fan = model.fans.first, !fan.isPoweredOff {
                Text(verbatim: "\(fan.currentRPM)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 9, weight: .medium))
    }

    private var secondaryReading: Double? {
        guard let group = style.secondaryGroup else { return nil }
        return model.grouped.first(where: { $0.group == group })?.readings.first?.celsius
    }

    /// Compact mode is the blueprint's "numbers only, no units": the degree
    /// mark goes, the digits stay.
    private func temperatureText(_ celsius: Double) -> String {
        let value = Int(celsius.rounded())
        return style.compact ? "\(value)" : "\(value)°"
    }
}

/// The mini chart: three minutes of the hottest reading as a single line.
///
/// Monochrome on purpose — the menu bar renders items in its own template
/// style, and a hue that would not survive shouldn't pretend to carry
/// information there. The shape is the message.
struct TemperatureSparkline: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2,
                let low = values.min(), let high = values.max()
            else { return }

            // A flat history still deserves a line — pin it to the middle
            // instead of dividing by a zero range.
            let range = max(high - low, 0.5)
            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (index, value) in values.enumerated() {
                let positionX = CGFloat(index) * stepX
                let normalized = (value - low) / range
                let positionY = size.height - CGFloat(normalized) * size.height
                if index == 0 {
                    path.move(to: CGPoint(x: positionX, y: positionY))
                } else {
                    path.addLine(to: CGPoint(x: positionX, y: positionY))
                }
            }
            context.stroke(
                path, with: .style(HierarchicalShapeStyle.primary), lineWidth: 1)
        }
        .frame(width: 26, height: 12)
    }
}
