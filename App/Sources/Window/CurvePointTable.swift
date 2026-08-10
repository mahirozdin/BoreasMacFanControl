import Core
import SwiftUI

/// The curve as numbers (P6.07).
///
/// Two reasons it exists, and neither is decoration. **Precision:** a drag
/// resolves to whatever a pixel is worth, and the plot shows the whole
/// 0–120 °C range, so "68 °C at 55%" is a sentence the mouse cannot quite
/// say. **Accessibility:** a curve is a picture, and a picture is not
/// reachable by keyboard or legible to VoiceOver. The blueprint requires
/// the curve to be presented as a list of points, and this is that list —
/// not a read-only echo of it, but the same curve, editable.
///
/// Every edit goes through the same `Core` operations the drag does, so the
/// two entry points cannot disagree about what is legal.
struct CurvePointTable: View {
    let curve: Curve
    let onChange: (Curve) -> Void
    let onBeginEdit: () -> Void

    /// The two column widths, named so the P6.13 layout drill can measure the
    /// headers against them rather than against numbers copied by hand — a
    /// copied constant is one that goes stale the first time a column is
    /// resized, and silently.
    ///
    /// Widened in P7.06: Russian "Вентилятор" wanted 91.7 pt of 76, and Spanish
    /// "Ventilador" 80.9 — the drill named both before either shipped.
    static let temperatureColumnWidth: CGFloat = 112
    static let dutyColumnWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            ForEach(Array(curve.points.enumerated()), id: \.offset) { index, point in
                row(index: index, point: point)
            }

            Button {
                addPoint()
            } label: {
                Label {
                    Text(
                        String(
                            localized: "curve.table.add", defaultValue: "Add Point",
                            comment: "Button that adds a control point from the numeric table"))
                } icon: {
                    Image(systemName: "plus")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .disabled(curve.points.count >= Curve.maximumPoints)
            .padding(.top, 2)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(
                String(
                    localized: "curve.table.temperature", defaultValue: "Temperature",
                    comment: "Numeric curve table column: a control point's temperature")
            )
            .frame(width: Self.temperatureColumnWidth, alignment: .leading)

            Text(
                String(
                    localized: "curve.table.duty", defaultValue: "Fan",
                    comment: "Numeric curve table column: a control point's fan duty")
            )
            .frame(width: Self.dutyColumnWidth, alignment: .leading)

            Spacer(minLength: 0)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
    }

    private func row(index: Int, point: CurvePoint) -> some View {
        HStack(spacing: 8) {
            TextField(
                String(
                    localized: "curve.table.temperature", defaultValue: "Temperature",
                    comment: "Numeric curve table column: a control point's temperature"),
                value: temperatureBinding(index: index, point: point),
                format: .number.precision(.fractionLength(0...1))
            )
            .labelsHidden()
            .monospacedDigit()
            .frame(width: Self.temperatureColumnWidth)
            .accessibilityLabel(
                String(
                    localized: "curve.table.temperature.accessibility",
                    defaultValue: "Point \(index + 1) temperature in degrees Celsius",
                    comment: "VoiceOver label for a curve point's temperature field"))

            TextField(
                String(
                    localized: "curve.table.duty", defaultValue: "Fan",
                    comment: "Numeric curve table column: a control point's fan duty"),
                value: dutyBinding(index: index, point: point),
                format: .number.precision(.fractionLength(0))
            )
            .labelsHidden()
            .monospacedDigit()
            .frame(width: Self.dutyColumnWidth)
            .accessibilityLabel(
                String(
                    localized: "curve.table.duty.accessibility",
                    defaultValue: "Point \(index + 1) fan speed in percent",
                    comment: "VoiceOver label for a curve point's duty field"))

            Text(verbatim: "%")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                onBeginEdit()
                onChange(curve.removing(at: index))
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(curve.points.count <= Curve.minimumPoints)
            .accessibilityLabel(
                String(
                    localized: "curve.table.remove.accessibility",
                    defaultValue: "Remove point \(index + 1)",
                    comment: "VoiceOver label for the button removing a curve point"))

            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    // MARK: - Editing

    /// Typing a value out of order is clamped exactly as dragging past a
    /// neighbour is — the two entry points share one rule, so a number the
    /// table accepts is a number the plot could have produced.
    private func temperatureBinding(index: Int, point: CurvePoint) -> Binding<Double> {
        Binding(
            get: { point.celsius },
            set: { newValue in
                onBeginEdit()
                onChange(curve.moving(pointAt: index, toCelsius: newValue, duty: point.duty))
            })
    }

    private func dutyBinding(index: Int, point: CurvePoint) -> Binding<Double> {
        Binding(
            get: { point.duty.value * 100 },
            set: { newValue in
                onBeginEdit()
                onChange(
                    curve.moving(
                        pointAt: index, toCelsius: point.celsius, duty: Duty(newValue / 100)))
            })
    }

    /// Adds a point in the middle of the widest gap, which is where there
    /// is room for one and where a user reaching for "add" almost always
    /// means.
    private func addPoint() {
        var widest: (celsius: Double, span: Double)?
        for (earlier, later) in zip(curve.points, curve.points.dropFirst()) {
            let span = later.celsius - earlier.celsius
            if span > (widest?.span ?? 0) {
                widest = ((earlier.celsius + later.celsius) / 2, span)
            }
        }
        guard let widest else { return }
        onBeginEdit()
        onChange(curve.inserting(atCelsius: widest.celsius))
    }
}
