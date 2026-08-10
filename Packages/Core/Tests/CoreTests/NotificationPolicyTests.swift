import Foundation
import Testing

@testable import Core

/// The notification noise control (P7.01).
///
/// The failure this subsystem exists to prevent is a user turning notifications
/// off entirely after a sensor oscillating around a threshold buried them. So
/// most of these tests are about *not* delivering. The one that runs the other
/// way is the most important: **no mechanism here may swallow a panic**, and it
/// is checked against every mechanism at once rather than one at a time.
@Suite("Notification policy (suppression, session rule, coalescing, quiet hours)")
struct NotificationPolicyTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // Fixed, or the quiet-hours tests would pass or fail depending on where
        // the machine running them happens to be.
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let noon = Date(timeIntervalSince1970: 1_800_000_000)

    private static func at(hour: Int, minute: Int = 0) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: noon)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? noon
    }

    private static func on() -> NotificationSettings {
        NotificationSettings(isEnabled: true)
    }

    // MARK: - The rule nothing may break

    @Test("a panic survives every noise-control mechanism at once")
    func panicIsAlwaysDelivered() {
        // Everything stacked against it: notifications off entirely, the kind
        // deselected, inside quiet hours, already delivered this session, and
        // inside the suppression window. G2's reasoning one level up — the panic
        // layer cannot be switched off, so the notification cannot be either.
        var policy = NotificationPolicy()
        let hostile = NotificationSettings(
            isEnabled: false,
            suppressionWindowMinutes: 120,
            enabledKinds: [],
            quietHours: QuietHours(startMinuteOfDay: 0, endMinuteOfDay: 1_439))
        let panic = [NotificationEvent(kind: .panicEngaged)]

        for repetition in 0..<5 {
            let decision = policy.decide(
                on: panic, settings: hostile,
                now: Self.at(hour: 3).addingTimeInterval(Double(repetition)),
                calendar: Self.calendar)
            #expect(decision.deliver.map(\.kind) == [.panicEngaged], "dropped on pass \(repetition)")
            #expect(decision.withheld.isEmpty)
        }
    }

    @Test("exactly one kind is always delivered, and it is the panic")
    func onlyPanicIsExempt() {
        // A guard on the exemption itself. Widening `isAlwaysDelivered` is how
        // this subsystem would quietly become un-silenceable, so adding a case
        // has to come here and argue for itself.
        let exempt = NotificationKind.allCases.filter(\.isAlwaysDelivered)
        #expect(exempt == [.panicEngaged])
    }

    // MARK: - The master switch and the per-kind switches

    @Test("nothing ordinary is delivered while notifications are off")
    func disabledDeliversNothing() {
        var policy = NotificationPolicy()
        let events = NotificationKind.allCases
            .filter { !$0.isAlwaysDelivered }
            .map { NotificationEvent(kind: $0) }
        let decision = policy.decide(
            on: events, settings: NotificationSettings(isEnabled: false),
            now: Self.noon, calendar: Self.calendar)
        #expect(decision.deliver.isEmpty)
        #expect(decision.withheld.allSatisfy { $0.reason == .notificationsDisabled })
    }

    @Test("a kind the user switched off stays off even when everything else allows it")
    func deselectedKindIsWithheld() {
        var policy = NotificationPolicy()
        let settings = NotificationSettings(isEnabled: true, enabledKinds: [.thermalState])
        let decision = policy.decide(
            on: [
                NotificationEvent(kind: .thermalState),
                NotificationEvent(kind: .profileChanged),
            ],
            settings: settings, now: Self.noon, calendar: Self.calendar)
        #expect(decision.deliver.map(\.kind) == [.thermalState])
        #expect(decision.withheld.map(\.reason) == [.kindDisabled])
    }

    @Test("the shipped defaults leave the subsystem off but its triggers chosen")
    func defaultsAreOffWithTriggersChosen() {
        // The distinction the document's table does not make explicit: the
        // triggers are on, the subsystem is not, so nothing asks for a
        // permission until the user does.
        let defaults = NotificationSettings()
        #expect(defaults.isEnabled == false)
        #expect(defaults.enabledKinds == NotificationKind.defaultEnabled)
        #expect(defaults.enabledKinds.contains(.panicEngaged))
        #expect(defaults.enabledKinds.contains(.profileChanged) == false)
    }

    // MARK: - Suppression window

    @Test("the same kind and subject does not repeat inside the window")
    func suppressionWindowHolds() {
        var policy = NotificationPolicy()
        let settings = NotificationSettings(
            isEnabled: true, suppressionWindowMinutes: 15,
            enabledKinds: [.thresholdCrossed])
        let event = NotificationEvent(kind: .thresholdCrossed, subject: "compute")

        let first = policy.decide(
            on: [event], settings: settings, now: Self.noon, calendar: Self.calendar)
        #expect(first.deliver.count == 1)

        let tooSoon = policy.decide(
            on: [event], settings: settings,
            now: Self.noon.addingTimeInterval(14 * 60 + 59), calendar: Self.calendar)
        #expect(tooSoon.deliver.isEmpty)
        #expect(tooSoon.withheld.map(\.reason) == [.suppressionWindow])

        let afterwards = policy.decide(
            on: [event], settings: settings,
            now: Self.noon.addingTimeInterval(15 * 60), calendar: Self.calendar)
        #expect(afterwards.deliver.count == 1)
    }

    @Test("a suppressed notification does not extend its own window")
    func suppressionDoesNotSelfExtend() {
        // The bug this forbids turns a fifteen minute silence into a permanent
        // one: if a withheld event refreshed the timestamp, a sensor oscillating
        // faster than the window would suppress itself forever and the user
        // would never hear about the threshold again.
        var policy = NotificationPolicy()
        let settings = NotificationSettings(
            isEnabled: true, suppressionWindowMinutes: 15,
            enabledKinds: [.thresholdCrossed])
        let event = NotificationEvent(kind: .thresholdCrossed, subject: "compute")

        _ = policy.decide(
            on: [event], settings: settings, now: Self.noon, calendar: Self.calendar)
        // Hammered every minute for the whole window.
        for minute in 1..<15 {
            let decision = policy.decide(
                on: [event], settings: settings,
                now: Self.noon.addingTimeInterval(Double(minute) * 60),
                calendar: Self.calendar)
            #expect(decision.deliver.isEmpty)
        }
        let afterwards = policy.decide(
            on: [event], settings: settings,
            now: Self.noon.addingTimeInterval(15 * 60), calendar: Self.calendar)
        #expect(afterwards.deliver.count == 1, "the window never reopened")
    }

    @Test("two subjects are two notifications, not one silencing the other")
    func subjectsAreSuppressedIndependently() {
        var policy = NotificationPolicy()
        let settings = NotificationSettings(isEnabled: true, enabledKinds: [.thresholdCrossed])
        _ = policy.decide(
            on: [NotificationEvent(kind: .thresholdCrossed, subject: "compute")],
            settings: settings, now: Self.noon, calendar: Self.calendar)
        let other = policy.decide(
            on: [NotificationEvent(kind: .thresholdCrossed, subject: "graphics")],
            settings: settings, now: Self.noon.addingTimeInterval(60),
            calendar: Self.calendar)
        #expect(other.deliver.count == 1)
    }

    @Test("the suppression window is clamped to the documented range")
    func windowIsClamped() {
        #expect(NotificationSettings(suppressionWindowMinutes: 0).suppressionWindowMinutes == 1)
        #expect(NotificationSettings(suppressionWindowMinutes: -5).suppressionWindowMinutes == 1)
        #expect(
            NotificationSettings(suppressionWindowMinutes: 9_999).suppressionWindowMinutes == 120)
        #expect(NotificationSettings(suppressionWindowMinutes: 30).suppressionWindowMinutes == 30)
    }

    // MARK: - Once per session

    @Test("a hardware health finding is delivered once per launch, whatever the window says")
    func oncePerSessionOutlastsTheWindow() {
        var policy = NotificationPolicy()
        let settings = NotificationSettings(
            isEnabled: true, suppressionWindowMinutes: 1, enabledKinds: [.fanAnomaly])
        let event = NotificationEvent(kind: .fanAnomaly)

        #expect(
            policy.decide(
                on: [event], settings: settings, now: Self.noon,
                calendar: Self.calendar
            ).deliver.count == 1)
        // A day later, and a suppression window of one minute long expired.
        let muchLater = policy.decide(
            on: [event], settings: settings,
            now: Self.noon.addingTimeInterval(86_400), calendar: Self.calendar)
        #expect(muchLater.deliver.isEmpty)
        #expect(muchLater.withheld.map(\.reason) == [.alreadyThisSession])
    }

    @Test("exactly the hardware health kinds are once per session")
    func oncePerSessionSetIsDeliberate() {
        let once = Set(NotificationKind.allCases.filter(\.isOncePerSession))
        #expect(once == [.fanAnomaly, .batteryHealth])
    }

    // MARK: - Coalescing

    @Test("several thresholds crossed together become one notification")
    func thresholdsCoalesce() {
        var policy = NotificationPolicy()
        let settings = NotificationSettings(isEnabled: true, enabledKinds: [.thresholdCrossed])
        let decision = policy.decide(
            on: [
                NotificationEvent(kind: .thresholdCrossed, subject: "compute"),
                NotificationEvent(kind: .thresholdCrossed, subject: "graphics"),
                NotificationEvent(kind: .thresholdCrossed, subject: "memory"),
            ],
            settings: settings, now: Self.noon, calendar: Self.calendar)
        #expect(decision.deliver.count == 1)
        #expect(decision.deliver.first?.subjects == ["compute", "graphics", "memory"])
    }

    @Test("different kinds never merge into one envelope")
    func differentKindsDoNotCoalesce() {
        // Merging kinds would let a profile change share an envelope with a
        // panic, which is how the important one gets buried.
        var policy = NotificationPolicy()
        let settings = NotificationSettings(
            isEnabled: true, enabledKinds: Set(NotificationKind.allCases))
        let decision = policy.decide(
            on: [
                NotificationEvent(kind: .thresholdCrossed, subject: "compute"),
                NotificationEvent(kind: .panicEngaged),
                NotificationEvent(kind: .profileChanged),
            ],
            settings: settings, now: Self.noon, calendar: Self.calendar)
        #expect(decision.deliver.count == 3)
    }

    @Test("only the threshold kind coalesces")
    func coalescingSetIsDeliberate() {
        let coalescing = NotificationKind.allCases.filter(\.coalesces)
        #expect(coalescing == [.thresholdCrossed])
    }

    @Test("a repeated subject in one batch is not counted twice")
    func repeatedSubjectIsMergedOnce() {
        var policy = NotificationPolicy()
        let settings = NotificationSettings(isEnabled: true, enabledKinds: [.thresholdCrossed])
        let decision = policy.decide(
            on: [
                NotificationEvent(kind: .thresholdCrossed, subject: "compute"),
                NotificationEvent(kind: .thresholdCrossed, subject: "compute"),
            ],
            settings: settings, now: Self.noon, calendar: Self.calendar)
        #expect(decision.deliver.first?.subjects == ["compute"])
    }

    // MARK: - Quiet hours

    @Test("a window that spans midnight silences the night, not the day")
    func quietHoursSpanMidnight() {
        // The case a naive `start <= now && now < end` gets exactly backwards,
        // silencing the whole day instead of the night.
        let night = QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 7 * 60)
        for hour in [22, 23, 0, 3, 6] {
            #expect(
                night.contains(Self.at(hour: hour), calendar: Self.calendar),
                "\(hour):00 should be quiet")
        }
        for hour in [7, 12, 18, 21] {
            #expect(
                !night.contains(Self.at(hour: hour), calendar: Self.calendar),
                "\(hour):00 should not be quiet")
        }
    }

    @Test("a daytime window behaves the ordinary way round")
    func quietHoursWithinOneDay() {
        let siesta = QuietHours(startMinuteOfDay: 13 * 60, endMinuteOfDay: 15 * 60)
        #expect(siesta.contains(Self.at(hour: 14), calendar: Self.calendar))
        #expect(!siesta.contains(Self.at(hour: 12), calendar: Self.calendar))
        #expect(!siesta.contains(Self.at(hour: 16), calendar: Self.calendar))
    }

    @Test("the window is half open, so a 22:00–07:00 night ends at 07:00")
    func quietHoursBoundaries() {
        let night = QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 7 * 60)
        #expect(night.contains(Self.at(hour: 22, minute: 0), calendar: Self.calendar))
        #expect(!night.contains(Self.at(hour: 7, minute: 0), calendar: Self.calendar))
        #expect(night.contains(Self.at(hour: 6, minute: 59), calendar: Self.calendar))
    }

    @Test("an empty window is empty, not a whole day of silence")
    func quietHoursDegenerateWindow() {
        // "Quiet from 22:00 to 22:00" reads as a mistake, and the safe reading
        // of a mistake in a *notification* system is to notify.
        let nothing = QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 22 * 60)
        for hour in 0..<24 {
            #expect(!nothing.contains(Self.at(hour: hour), calendar: Self.calendar))
        }
    }

    @Test("an out-of-range minute wraps rather than being clamped to midnight")
    func quietHoursWrap() {
        // A hand-edited file asking for minute 1500 means 01:00 the next day.
        // Clamping would silently move somebody's quiet hours to a different
        // time of night.
        #expect(QuietHours(startMinuteOfDay: 1_500, endMinuteOfDay: 0).startMinuteOfDay == 60)
        #expect(QuietHours(startMinuteOfDay: -60, endMinuteOfDay: 0).startMinuteOfDay == 1_380)
    }

    @Test("quiet hours withhold an ordinary notification and say so")
    func quietHoursWithhold() {
        var policy = NotificationPolicy()
        let settings = NotificationSettings(
            isEnabled: true, enabledKinds: [.thermalState],
            quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 7 * 60))
        let decision = policy.decide(
            on: [NotificationEvent(kind: .thermalState)], settings: settings,
            now: Self.at(hour: 3), calendar: Self.calendar)
        #expect(decision.deliver.isEmpty)
        #expect(decision.withheld.map(\.reason) == [.quietHours])
    }

    @Test("a withheld event is never silently dropped — every one carries a reason")
    func nothingVanishes() {
        // The accounting property: an event either arrives or is explained.
        // A subsystem that loses things is one nobody can debug, and the
        // diagnostics tab needs to be able to say which mechanism swallowed
        // what.
        var policy = NotificationPolicy()
        let settings = NotificationSettings(
            isEnabled: true, suppressionWindowMinutes: 30,
            enabledKinds: [.thermalState, .fanAnomaly],
            quietHours: QuietHours(startMinuteOfDay: 22 * 60, endMinuteOfDay: 7 * 60))

        let events = NotificationKind.allCases.map { NotificationEvent(kind: $0) }
        for hour in [3, 12, 23] {
            for _ in 0..<3 {
                let decision = policy.decide(
                    on: events, settings: settings, now: Self.at(hour: hour),
                    calendar: Self.calendar)
                let accounted =
                    decision.deliver.reduce(0) { $0 + Swift.max(1, $1.subjects.count) }
                    + decision.withheld.count
                #expect(accounted == events.count, "at \(hour):00")
            }
        }
    }
}
