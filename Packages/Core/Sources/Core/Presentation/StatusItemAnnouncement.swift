import Foundation

/// What the menu bar item says to a user who is not looking at it (P6.12).
///
/// `docs/product/ui.md` requires the menu bar item to carry a meaningful
/// accessibility label, and left to itself it does the opposite: the item is a
/// row of loose glyphs and numbers, so VoiceOver reads "fan, B, 62, 1608" —
/// four fragments, no sentence, and the one thing the item is *for* (whether
/// this application is driving the fans right now) is carried by the icon's
/// **colour alone**. Colour alone is exactly what the interface rules forbid.
///
/// So the item's spoken content is a decision, and decisions live in `Core`
/// under test. This type is the P6.11 `DiagnosticFinding` pattern applied
/// again: `Core` settles *which facts* are announced and in what order, the
/// App turns them into a localised sentence, and the switch over the parts is
/// exhaustive — a new part is a compile error until somebody writes its words.
public struct StatusItemAnnouncement: Sendable, Equatable {

    /// Who is deciding fan speed. The first thing announced, because it is
    /// the question the item exists to answer and the one currently encoded
    /// as a tint.
    public enum Control: Sendable, Equatable {

        /// The firmware owns the fans; this application is only watching.
        case firmware

        /// The engine is driving, under the named profile.
        case driving(profileName: String)

        /// The engine is driving under a choice that expires.
        case drivingTemporarily(profileName: String)

        /// The panic layer has the fans at full. Its own case rather than a
        /// flag on `driving`: panic is not a louder version of driving, it is
        /// a different answer to "why is the fan doing that", and a listener
        /// must not have to infer it from a profile name.
        case panicking

        /// Decides which answer the item is giving.
        ///
        /// Split from `StatusItemAnnouncement.make` along the real seam: who is
        /// in charge is one decision and what the sensors read is another, and
        /// putting both in one function needed seven arguments — which the lint
        /// budget refused, correctly. Two four-argument decisions are also
        /// easier to test one at a time.
        public static func make(
            isEngaged: Bool,
            isPanicking: Bool,
            profileName: String?,
            expires: Bool
        ) -> Control {
            if isPanicking {
                // Checked before `isEngaged` on purpose. Panic implies engaged,
                // so testing engagement first would hide it behind a profile
                // name — true, and useless at the one moment it matters most.
                return .panicking
            }
            guard isEngaged, let profileName else {
                return .firmware
            }
            return expires
                ? .drivingTemporarily(profileName: profileName)
                : .driving(profileName: profileName)
        }
    }

    public let control: Control

    /// The hottest reading, or `nil` when nothing has been sampled yet.
    public let hottestCelsius: Double?

    /// The leading fan's speed, or `nil` when there is no fan to report —
    /// which includes a parked one, because "0 rpm" and "not reporting" are
    /// different facts and only one of them is true.
    public let fanRPM: Int?

    public init(control: Control, hottestCelsius: Double?, fanRPM: Int?) {
        self.control = control
        self.hottestCelsius = hottestCelsius
        self.fanRPM = fanRPM
    }

    /// Builds the announcement from what the interface already knows.
    ///
    /// Deliberately takes plain values rather than the App's models: the point
    /// of putting this in `Core` is that it can be tested without a view, a
    /// window, or a running engine.
    public static func make(
        control: Control,
        hottestCelsius: Double?,
        fanRPM: Int?,
        fanIsPoweredOff: Bool
    ) -> StatusItemAnnouncement {
        StatusItemAnnouncement(
            control: control,
            hottestCelsius: hottestCelsius,
            // A parked fan is silent about its speed rather than claiming zero:
            // "0 rpm" is a measurement and a parked fan is a state.
            fanRPM: fanIsPoweredOff ? nil : fanRPM)
    }
}
