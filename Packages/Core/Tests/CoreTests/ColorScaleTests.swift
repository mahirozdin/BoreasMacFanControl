import Foundation
import Testing

@testable import Core

@Suite("Colour scales (continuous temperature ramp, fan fill, red exclusion)")
struct ColorScaleTests {

    /// The sweep used by every property test: comfortably past both clamp
    /// points, in steps fine enough that a hidden band edge cannot slip
    /// between two samples.
    private static let sweep = stride(from: -20.0, through: 130.0, by: 0.1)

    // MARK: - The binding decisions, as properties

    @Test("the ramp is continuous — no step anywhere exceeds what linearity allows")
    func rampIsContinuous() {
        // Steepest legal slope: the neutral→warm green channel covers
        // |0.55 − 0.62| … the widest span is red's 0.36 over 25 °C ≈ 0.015
        // per degree. 0.01 per 0.1 °C step is six times that — loose enough
        // to survive stop retuning, tight enough that any discrete band edge
        // (a jump of tens of points) is unmissable.
        var previous: ScaleColor?
        var worstStep = 0.0
        for celsius in Self.sweep {
            let color = TemperatureScale.color(for: celsius)
            if let last = previous {
                let step = max(
                    abs(color.red - last.red),
                    abs(color.green - last.green),
                    abs(color.blue - last.blue)
                )
                worstStep = max(worstStep, step)
            }
            previous = color
        }
        #expect(worstStep <= 0.01, "largest per-0.1° channel step was \(worstStep)")
    }

    @Test("warmth only ever rises with temperature")
    func warmthIsMonotone() {
        // "Warmth" made measurable: red minus blue. Cool stop ≈ −0.62,
        // warm stop ≈ +0.88; if any segment ordering or stop value ever
        // reversed the visual reading, this catches it.
        var previousWarmth = -Double.infinity
        for celsius in Self.sweep {
            let color = TemperatureScale.color(for: celsius)
            let warmth = color.red - color.blue
            #expect(
                warmth >= previousWarmth - 1e-12,
                "warmth reversed at \(celsius) °C"
            )
            previousWarmth = warmth
        }
    }

    @Test("red never appears on the ramp — red is reserved for panic/error")
    func redIsExcluded() {
        // Near the neutral stop saturation collapses and hue becomes noise,
        // so the guard applies wherever a hue is actually *visible*
        // (saturation ≥ 0.15). There the hue must stay between orange and
        // blue; true red (hue < 15° at full saturation) is far outside.
        for celsius in Self.sweep {
            let color = TemperatureScale.color(for: celsius)
            if color.saturation >= 0.15 {
                #expect(
                    color.hueDegrees >= 22 && color.hueDegrees <= 250,
                    "visible hue \(color.hueDegrees)° at \(celsius) °C leaves the blue–orange corridor"
                )
            }
        }
    }

    @Test("the middle of the ramp is neutral, not a saturated in-between hue")
    func midpointIsNeutral() {
        // This is the test that forbids replacing the three-stop ramp with a
        // direct blue→orange blend: that blend's midpoint has saturation
        // ≈ 0.20 and would fail here. The middle of the range means "nothing
        // remarkable" and must look like it.
        let midpoint = TemperatureScale.color(for: TemperatureScale.neutralCelsius)
        #expect(midpoint.saturation <= 0.05)
    }

    @Test("both ends clamp and an unreadable temperature reads hot")
    func endsClampAndNaNReadsHot() {
        #expect(TemperatureScale.color(for: -50) == TemperatureScale.color(for: 40))
        #expect(TemperatureScale.color(for: 120) == TemperatureScale.color(for: 85))
        // Same rule as Curve: of the two misreadings, "too alarming" is the
        // recoverable one.
        #expect(TemperatureScale.color(for: .nan) == TemperatureScale.color(for: 200))
    }

    // MARK: - ADR 0010 kept measurable (the P5.09 pattern)

    @Test("a discrete three-band scale would jump at an edge; the ramp does not")
    func discreteBandsWouldJump() {
        // The rejected design, built here so the difference stays a
        // measurement: cool below 60, neutral to 80, warm above.
        func banded(_ celsius: Double) -> ScaleColor {
            if celsius < 60 { return TemperatureScale.coolStop }
            if celsius < 80 { return TemperatureScale.neutralStop }
            return TemperatureScale.warmStop
        }

        let below = 79.95
        let above = 80.05

        let bandJump = abs(banded(above).red - banded(below).red)
        let continuousStep = abs(
            TemperatureScale.color(for: above).red - TemperatureScale.color(for: below).red
        )

        // Crossing the band edge by a tenth of a degree recolours the band
        // model by a third of the channel range; the ramp moves by less than
        // a hundredth. Continuous data, visualised continuously.
        #expect(bandJump >= 0.3)
        #expect(continuousStep <= 0.01)
    }

    // MARK: - Component identity helpers

    @Test("hue and saturation answer the classic anchors")
    func hueAndSaturationAnchors() {
        let red = ScaleColor(red: 1, green: 0, blue: 0)
        #expect(red.hueDegrees == 0)
        #expect(red.saturation == 1)

        let grey = ScaleColor(red: 0.5, green: 0.5, blue: 0.5)
        #expect(grey.hueDegrees == 0)
        #expect(grey.saturation == 0)

        let black = ScaleColor(red: 0, green: 0, blue: 0)
        #expect(black.saturation == 0)

        // The scale's own stops, so a retune that drifts out of "blue" or
        // "orange" is caught by name.
        let cool = TemperatureScale.coolStop
        #expect(cool.hueDegrees > 200 && cool.hueDegrees < 230)

        let warm = TemperatureScale.warmStop
        #expect(warm.hueDegrees > 25 && warm.hueDegrees < 40)
    }

    // MARK: - Fan fill

    @Test("fan fill is monotone, floored for visibility, and full at full duty")
    func fanFillProperties() {
        #expect(FanScale.fillFraction(for: Duty(0)) == FanScale.visibilityFloor)
        #expect(FanScale.fillFraction(for: Duty(1)) == 1)

        var previous = -Double.infinity
        for step in 0...100 {
            let fraction = FanScale.fillFraction(for: Duty(Double(step) / 100))
            #expect(fraction >= FanScale.visibilityFloor && fraction <= 1)
            #expect(fraction >= previous)
            previous = fraction
        }
    }
}
