import Core
import SwiftUI

/// The words VoiceOver reads for things that are otherwise pictures (P6.12).
///
/// Same split as `DiagnosticWording`, and for the same reason: `Core` decides
/// *which facts* are announced (`StatusItemAnnouncement`), and the words live
/// here in the App layer where the String Catalog and `make gate-i18n` can see
/// them. Every switch is exhaustive over a `Core` enum, so a new case is a
/// compile error until somebody writes its sentence.
///
/// **These strings are not decoration.** A label read aloud is the only version
/// of the interface some users get, so it is written as a sentence a person
/// would say — not as a comma-separated dump of the values on screen.
extension StatusItemAnnouncement {

    /// The whole menu bar item as one spoken sentence.
    ///
    /// One element, not four: left as separate glyphs the item reads as
    /// "fan, B, 62, 1608", which is every fact and no meaning. The control
    /// state leads because it is the question the item exists to answer.
    var spokenLabel: String {
        var parts = [control.spokenText]
        if let hottestCelsius {
            parts.append(
                String(
                    localized: "status.accessibility.hottest",
                    defaultValue: "Hottest sensor \(Int(hottestCelsius.rounded())) degrees Celsius",
                    comment:
                        "Part of the menu bar item's VoiceOver label: the hottest temperature"))
        }
        if let fanRPM {
            parts.append(
                String(
                    localized: "status.accessibility.fan",
                    defaultValue: "Fan \(fanRPM) rpm",
                    comment: "Part of the menu bar item's VoiceOver label: the fan speed"))
        }
        // A full stop and a space between clauses: VoiceOver pauses at
        // sentence boundaries, and without them the whole label runs together
        // as one breathless string.
        return parts.joined(separator: ". ")
    }
}

extension StatusItemAnnouncement.Control {

    var spokenText: String {
        switch self {
        case .firmware:
            return String(
                localized: "status.accessibility.firmware",
                defaultValue: "Monitoring only, the system is controlling the fans",
                comment:
                    "Menu bar item VoiceOver label when the firmware owns the fans")

        case .driving(let profileName):
            return String(
                localized: "status.accessibility.driving",
                defaultValue: "Controlling the fans, profile \(profileName)",
                comment: "Menu bar item VoiceOver label when the engine drives the fans")

        case .drivingTemporarily(let profileName):
            return String(
                localized: "status.accessibility.driving.temporary",
                defaultValue: "Controlling the fans for a set time, profile \(profileName)",
                comment:
                    "Menu bar item VoiceOver label when the engine drives under a choice that expires")

        case .panicking:
            return String(
                localized: "status.accessibility.panic",
                defaultValue: "Cooling at full speed, the panic threshold was reached",
                comment: "Menu bar item VoiceOver label while the panic layer is acting")
        }
    }
}

/// The curve as a spoken value (P6.12).
///
/// `docs/product/ui.md` requires the curve to be presented as a list of points,
/// and the numeric table (P6.07) is that list — reachable by keyboard, one
/// labelled field per value. What the *plot* owes is a summary, so a listener
/// arriving at it learns what the picture holds and that there is a table
/// beside it, rather than meeting an unlabelled canvas with a scatter of
/// unlabelled circles inside it.
extension Curve {

    /// Every control point as one sentence, in order.
    var spokenPointList: String {
        let points = self.points.enumerated().map { index, point in
            String(
                localized: "curve.accessibility.point",
                defaultValue: """
                    Point \(index + 1), \(Int(point.celsius.rounded())) degrees, \
                    \(point.duty.percent) percent
                    """,
                comment: "One curve control point read aloud: its number, temperature and duty")
        }
        return points.joined(separator: ". ")
    }
}
