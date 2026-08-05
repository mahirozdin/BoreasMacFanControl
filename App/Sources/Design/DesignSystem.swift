import Core
import SwiftUI

/// The SwiftUI face of the design system.
///
/// Every colour *decision* lives in `Core` (`TemperatureScale`, `FanScale`),
/// where it sits under unit tests; this file only realises those decisions as
/// SwiftUI values. Views never pick colours ad hoc: if a view needs a colour
/// this file does not offer, that is a design-system change, not a view
/// change. The binding rules are in `docs/product/ui.md` — separate
/// continuous scales for temperature and fans, red reserved for panic/error.
extension Color {

    /// The continuous temperature colour: cool blue → neutral → warm orange.
    ///
    /// Appearance-independent on purpose — a temperature must look the same
    /// temperature in light and dark, the way a chart series keeps its
    /// identity. Legibility against both appearances is what the mid-range
    /// luminance of the underlying stops is for.
    static func temperature(_ celsius: Double) -> Color {
        let components = TemperatureScale.color(for: celsius)
        return Color(
            red: components.red,
            green: components.green,
            blue: components.blue
        )
    }

    /// Fan gauge fill: the appearance-adaptive neutral, weighted by duty.
    ///
    /// Hue belongs to the temperature scale alone; a fan communicates only
    /// *how much*, so it modulates the system's own foreground grey and
    /// stays legible in both appearances for free.
    static func fanFill(_ duty: Duty) -> Color {
        Color.primary.opacity(FanScale.fillFraction(for: duty))
    }

    /// The only red in the product. Panic and error states — nothing else.
    ///
    /// The system red adapts to appearance and to the user's accessibility
    /// settings (Increase Contrast), which a fixed component value would not.
    static var panicAccent: Color { .red }

    /// Warnings and safety-layer overrides that are not panic: degraded
    /// sensors, raised floors, approvals pending. Deliberately distinct from
    /// `panicAccent` so red keeps its one meaning.
    static var warningAccent: Color { .orange }
}
