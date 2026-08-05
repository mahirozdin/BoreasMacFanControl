import Core
import SwiftUI

/// A deterministic swatch sheet of the design system, for render evidence.
///
/// Follows the `--render-setup` precedent: screenshots would need a
/// permission this project promises never to request (invariant I2), while
/// rendering the view directly is permission-free and reproducible. The
/// sheet is developer evidence, not product UI, so its labels are verbatim
/// numerals and fixed English words outside the localisation catalogue.
struct DesignEvidenceView: View {

    /// Rendered against a fixed background per appearance so the PNG judges
    /// contrast honestly even where dynamic colours resolve late.
    let darkAppearance: Bool

    private let rampRange = stride(from: 30.0, through: 95.0, by: 0.5)
    private let sampleCelsius: [Double] = [35, 45, 55, 60, 70, 80, 85, 95]
    private let sampleDuties: [Double] = [0, 0.25, 0.5, 0.75, 1]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(verbatim: "Design system — \(darkAppearance ? "dark" : "light")")
                .font(.headline)

            ramp
            temperatureChips
            fanRow
            semanticRow
        }
        .padding(24)
        .frame(width: 560)
        .background(darkAppearance ? Color(white: 0.12) : Color(white: 0.97))
        .environment(\.colorScheme, darkAppearance ? .dark : .light)
    }

    /// The continuous ramp with its three anchors marked. Any banding would
    /// be visible here as a hard vertical edge.
    private var ramp: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionCaption("temperature ramp, 30-95 °C")
            HStack(spacing: 0) {
                ForEach(Array(rampRange), id: \.self) { celsius in
                    Color.temperature(celsius)
                }
            }
            .frame(height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            HStack {
                anchorTick(TemperatureScale.coolCeilingCelsius, alignment: .leading)
                Spacer()
                anchorTick(TemperatureScale.neutralCelsius, alignment: .center)
                Spacer()
                anchorTick(TemperatureScale.warmFloorCelsius, alignment: .trailing)
            }
        }
    }

    /// Colour never carries information alone — every swatch is paired with
    /// its number, exactly as product views must pair them.
    private var temperatureChips: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionCaption("sampled readings")
            HStack(spacing: 8) {
                ForEach(sampleCelsius, id: \.self) { celsius in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.temperature(celsius))
                            .frame(width: 10, height: 10)
                        Text(verbatim: "\(Int(celsius))°")
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var fanRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionCaption("fan fill — neutral grey, duty decides how much")
            HStack(spacing: 12) {
                ForEach(sampleDuties, id: \.self) { raw in
                    let duty = Duty(raw)
                    VStack(spacing: 3) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(Color.fanFill(duty))
                                    .frame(width: geometry.size.width * duty.value)
                            }
                        }
                        .frame(width: 72, height: 10)
                        Text(verbatim: "\(duty.percent)%")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var semanticRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionCaption("semantic accents — the only red in the product")
            HStack(spacing: 12) {
                semanticChip(color: .panicAccent, label: "panic / error")
                semanticChip(color: .warningAccent, label: "warning / override")
            }
        }
    }

    private func semanticChip(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(verbatim: label)
                .font(.caption)
        }
    }

    private func anchorTick(_ celsius: Double, alignment: Alignment) -> some View {
        Text(verbatim: "\(Int(celsius))°")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(alignment: alignment)
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
