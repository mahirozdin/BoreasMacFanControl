import Foundation
import Testing

@testable import Core

/// The menu bar item's spoken content (P6.12).
///
/// The property worth defending is that **nothing the item signals with colour
/// is missing from what it says**. The icon takes the accent colour while the
/// engine drives; if the announcement could ever come back `.firmware` while
/// the engine drives, a user who cannot see the tint would be told the
/// opposite of the truth.
@Suite("Status item announcement (nothing signalled by colour alone)")
struct StatusItemAnnouncementTests {

    private static func make(
        isEngaged: Bool = false,
        isPanicking: Bool = false,
        profileName: String? = nil,
        expires: Bool = false,
        hottestCelsius: Double? = 62.4,
        fanRPM: Int? = 1_608,
        fanIsPoweredOff: Bool = false
    ) -> StatusItemAnnouncement {
        StatusItemAnnouncement.make(
            control: .make(
                isEngaged: isEngaged, isPanicking: isPanicking,
                profileName: profileName, expires: expires),
            hottestCelsius: hottestCelsius, fanRPM: fanRPM,
            fanIsPoweredOff: fanIsPoweredOff)
    }

    @Test("the engine driving is always announced, never left to the tint")
    func drivingIsAlwaysAnnounced() {
        let announcement = Self.make(isEngaged: true, profileName: "Balanced")
        #expect(announcement.control == .driving(profileName: "Balanced"))
    }

    @Test("firmware in charge is announced as such")
    func firmwareIsAnnounced() {
        #expect(Self.make(isEngaged: false).control == .firmware)
    }

    @Test("a timed choice is distinguishable from a standing one")
    func timedChoiceIsDistinct() {
        // The clock glyph beside the icon is the visual form of this. Without
        // its own case a listener could not tell a choice that expires from
        // one that does not, which is the difference between "it will go back
        // on its own" and "I have to put it back".
        let timed = Self.make(isEngaged: true, profileName: "Quiet", expires: true)
        let standing = Self.make(isEngaged: true, profileName: "Quiet", expires: false)
        #expect(timed.control == .drivingTemporarily(profileName: "Quiet"))
        #expect(standing.control == .driving(profileName: "Quiet"))
        #expect(timed.control != standing.control)
    }

    @Test("panic outranks the profile name it would otherwise hide behind")
    func panicOutranksDriving() {
        // Panic implies engaged, so an implementation that tested engagement
        // first would announce "driving under Balanced" during a panic — true
        // but useless, and the one moment the user most needs the real answer.
        let announcement = Self.make(
            isEngaged: true, isPanicking: true, profileName: "Balanced")
        #expect(announcement.control == .panicking)
    }

    @Test("engaged with no profile cannot announce a profile it does not have")
    func engagedWithoutProfileFallsBackToFirmware() {
        // Reachable: the drills and the render fixtures build a control model
        // with no arbitration outcome. Announcing an empty profile name would
        // read aloud as a hole in the sentence.
        #expect(Self.make(isEngaged: true, profileName: nil).control == .firmware)
    }

    @Test("a parked fan is silent about its speed rather than claiming zero")
    func parkedFanReportsNoSpeed() {
        // "0 rpm" is a measurement; a parked fan is a state. Announcing the
        // former for the latter is the kind of small lie the honesty rule in
        // docs/operations/diagnostics.md exists to prevent.
        let parked = Self.make(fanRPM: 0, fanIsPoweredOff: true)
        #expect(parked.fanRPM == nil)
        #expect(Self.make(fanRPM: 1_608, fanIsPoweredOff: false).fanRPM == 1_608)
    }

    @Test("nothing sampled yet is absent, not zero")
    func nothingSampledIsAbsent() {
        let fresh = Self.make(hottestCelsius: nil, fanRPM: nil)
        #expect(fresh.hottestCelsius == nil)
        #expect(fresh.fanRPM == nil)
        #expect(fresh.control == .firmware)
    }
}
