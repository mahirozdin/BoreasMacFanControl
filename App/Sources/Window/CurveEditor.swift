import Core
import SwiftUI

/// The curve editor's plot (P6.06) — the product's signature interface.
///
/// Drawn with `Canvas` and plain shapes rather than a chart framework for
/// two reasons: the layers underneath the curve (the hysteresis band, the
/// sixty-second trail, the live operating point) are not a chart's idea of
/// marks, and every AppKit-backed container found so far renders blank in
/// the evidence. What is drawn here is what the evidence photographs.
///
/// **The editor cannot produce an invalid curve.** Not because it checks
/// afterwards, but because every edit goes through `Core`'s total editing
/// operations, which clamp the input into the legal region. The view
/// contributes the gesture and nothing else.
struct CurveEditor: View {

    let curve: Curve
    let hysteresis: Hysteresis
    /// Where the machine is right now: bound-group temperature against the
    /// fan's actual duty.
    let operatingPoint: (celsius: Double, duty: Double)?
    /// The last sixty seconds of operating points.
    let trail: [(celsius: Double, duty: Double)]
    let onChange: (Curve) -> Void
    /// Fired once at the start of each gesture, before the first change.
    /// Undo is per *gesture*, not per frame: a drag that filled the undo
    /// stack with one entry per pixel would make undo useless.
    let onBeginEdit: () -> Void

    @State private var dragging: Int?

    /// The plot shows the *whole* published temperature range rather than a
    /// flattering slice, so every position the model allows can be reached
    /// by hand. The cost is that the interesting 35–90 °C band uses the
    /// middle two thirds; the numeric table (P6.07) is the answer when
    /// precision matters more than reach.
    private var temperatureRange: ClosedRange<Double> { Curve.temperatureRange }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    draw(in: &context, size: canvasSize)
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture(count: 2).onEnded { value in
                        onBeginEdit()
                        onChange(
                            curve.inserting(
                                atCelsius: celsius(fromX: value.location.x, in: size)))
                    }
                )

                ForEach(Array(curve.points.enumerated()), id: \.offset) { index, point in
                    handle(index: index, point: point, size: size)
                }
            }
        }
        .frame(height: 260)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(
            String(
                localized: "curve.editor.accessibility",
                defaultValue: "Fan curve editor",
                comment: "VoiceOver label for the curve editor plot"))
    }

    // MARK: - Handles

    private func handle(index: Int, point: CurvePoint, size: CGSize) -> some View {
        let position = CGPoint(x: xPosition(point.celsius, in: size), y: yPosition(point.duty, in: size))
        return Circle()
            .fill(Color.accentColor)
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1))
            .frame(width: dragging == index ? 15 : 11, height: dragging == index ? 15 : 11)
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragging != index { onBeginEdit() }
                        dragging = index
                        onChange(
                            curve.moving(
                                pointAt: index,
                                toCelsius: celsius(fromX: value.location.x, in: size),
                                duty: duty(fromY: value.location.y, in: size)))
                    }
                    .onEnded { _ in dragging = nil }
            )
            .contextMenu {
                Button {
                    onBeginEdit()
                    onChange(curve.removing(at: index))
                } label: {
                    Text(
                        String(
                            localized: "curve.point.delete", defaultValue: "Delete Point",
                            comment: "Context menu entry that removes a curve control point"))
                }
                // Refused rather than hidden: a menu entry that vanishes is
                // harder to understand than one that explains itself.
                .disabled(curve.points.count <= Curve.minimumPoints)
            }
            .help(
                String(
                    localized: "curve.point.help",
                    defaultValue: "\(Int(point.celsius)) °C at \(point.duty.percent)%",
                    comment: "Tooltip on a curve control point: its temperature and duty"))
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        drawGrid(in: &context, size: size)
        drawHysteresisBand(in: &context, size: size)
        drawTrail(in: &context, size: size)

        context.stroke(
            path(of: curve, in: size),
            with: .color(.accentColor),
            style: StrokeStyle(lineWidth: 2, lineJoin: .round))

        if let operatingPoint {
            drawOperatingPoint(operatingPoint, in: &context, size: size)
        }
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        var grid = Path()
        for celsius in stride(
            from: temperatureRange.lowerBound, through: temperatureRange.upperBound, by: 20)
        {
            let positionX = xPosition(celsius, in: size)
            grid.move(to: CGPoint(x: positionX, y: 0))
            grid.addLine(to: CGPoint(x: positionX, y: size.height))
        }
        for fraction in stride(from: 0.0, through: 1.0, by: 0.25) {
            let positionY = yPosition(Duty(fraction), in: size)
            grid.move(to: CGPoint(x: 0, y: positionY))
            grid.addLine(to: CGPoint(x: size.width, y: positionY))
        }
        context.stroke(grid, with: .color(.primary.opacity(0.08)), lineWidth: 1)
    }

    /// The band between the rising curve and the falling one — the region
    /// inside which the engine deliberately does not react. Shown as a
    /// shadow because it is not a value, it is a tolerance.
    private func drawHysteresisBand(in context: inout GraphicsContext, size: CGSize) {
        guard hysteresis.band > 0 else { return }
        let falling = curve.shiftedLeft(by: hysteresis.band)

        var band = path(of: curve, in: size)
        // Back along the falling curve to close the ribbon.
        for point in falling.points.reversed() {
            band.addLine(
                to: CGPoint(x: xPosition(point.celsius, in: size), y: yPosition(point.duty, in: size)))
        }
        band.closeSubpath()
        context.fill(band, with: .color(.accentColor.opacity(0.13)))
    }

    /// Sixty seconds of where the machine actually was. The cloud sits near
    /// the curve, not on it: smoothing, hysteresis and the rate limiter all
    /// live in between, and seeing that distance is the point.
    private func drawTrail(in context: inout GraphicsContext, size: CGSize) {
        guard trail.count > 1 else { return }
        for (index, sample) in trail.enumerated() {
            // Older points fade, so direction is readable without motion.
            let age = Double(index) / Double(trail.count - 1)
            let dot = Path(
                ellipseIn: CGRect(
                    x: xPosition(sample.celsius, in: size) - 2.5,
                    y: yPosition(Duty(sample.duty), in: size) - 2.5,
                    width: 5, height: 5))
            context.fill(dot, with: .color(.primary.opacity(0.20 + 0.40 * age)))
        }
    }

    private func drawOperatingPoint(
        _ point: (celsius: Double, duty: Double),
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let centre = CGPoint(
            x: xPosition(point.celsius, in: size),
            y: yPosition(Duty(point.duty), in: size))
        let halo = Path(
            ellipseIn: CGRect(x: centre.x - 7, y: centre.y - 7, width: 14, height: 14))
        context.fill(halo, with: .color(.primary.opacity(0.15)))
        let dot = Path(
            ellipseIn: CGRect(x: centre.x - 4, y: centre.y - 4, width: 8, height: 8))
        // The operating point takes the temperature scale's own colour: it
        // is one value's magnitude, which is exactly what that scale is for.
        context.fill(dot, with: .color(Color.temperature(point.celsius)))
    }

    private func path(of curve: Curve, in size: CGSize) -> Path {
        var path = Path()
        for (index, point) in curve.points.enumerated() {
            let position = CGPoint(
                x: xPosition(point.celsius, in: size), y: yPosition(point.duty, in: size))
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }
        return path
    }

    // MARK: - Coordinates

    private func xPosition(_ celsius: Double, in size: CGSize) -> CGFloat {
        let span = temperatureRange.upperBound - temperatureRange.lowerBound
        let fraction = (celsius - temperatureRange.lowerBound) / span
        return CGFloat(fraction) * size.width
    }

    private func yPosition(_ duty: Duty, in size: CGSize) -> CGFloat {
        size.height - CGFloat(duty.value) * size.height
    }

    private func celsius(fromX positionX: CGFloat, in size: CGSize) -> Double {
        guard size.width > 0 else { return temperatureRange.lowerBound }
        let span = temperatureRange.upperBound - temperatureRange.lowerBound
        return temperatureRange.lowerBound + Double(positionX / size.width) * span
    }

    private func duty(fromY positionY: CGFloat, in size: CGSize) -> Duty {
        guard size.height > 0 else { return Duty.minimum }
        return Duty(Double((size.height - positionY) / size.height))
    }
}
