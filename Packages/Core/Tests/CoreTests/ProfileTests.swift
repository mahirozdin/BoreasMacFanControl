import Foundation
import Testing

@testable import Core

@Suite("Profile triggers")
struct ProfileTriggerTests {

    @Test("every trigger type evaluates against the environment")
    func triggerSemantics() {
        var environment = ProfileTrigger.Environment(
            power: PowerContext(source: .battery, batteryPercentage: 18),
            foregroundBundleIdentifier: "com.example.studio",
            runningBundleIdentifiers: ["com.example.studio", "com.example.encoder"],
            minuteOfDay: 10 * 60,
            externalDisplayConnected: true,
            thermal: .serious
        )

        #expect(ProfileTrigger.powerSource(.battery).holds(in: environment))
        #expect(!ProfileTrigger.powerSource(.adapter).holds(in: environment))

        #expect(
            ProfileTrigger.application(
                bundleIdentifier: "com.example.encoder", foregroundOnly: false
            ).holds(in: environment))
        #expect(
            !ProfileTrigger.application(
                bundleIdentifier: "com.example.encoder", foregroundOnly: true
            ).holds(in: environment))
        #expect(
            ProfileTrigger.application(
                bundleIdentifier: "com.example.studio", foregroundOnly: true
            ).holds(in: environment))

        #expect(ProfileTrigger.batteryAtOrBelow(percent: 20).holds(in: environment))
        #expect(!ProfileTrigger.batteryAtOrBelow(percent: 15).holds(in: environment))
        // A desktop is not "at 0 percent": no battery, never holds.
        environment.power = .desktop
        #expect(!ProfileTrigger.batteryAtOrBelow(percent: 99).holds(in: environment))

        #expect(ProfileTrigger.externalDisplay(connected: true).holds(in: environment))
        #expect(ProfileTrigger.thermalStateAtLeast(.serious).holds(in: environment))
        #expect(ProfileTrigger.thermalStateAtLeast(.fair).holds(in: environment))
        #expect(!ProfileTrigger.thermalStateAtLeast(.critical).holds(in: environment))
    }

    @Test("a time window that wraps midnight means evening or morning")
    func midnightWrap() {
        // The blueprint's own example: 23:00-08:00.
        let night = ProfileTrigger.timeWindow(startMinute: 23 * 60, endMinute: 8 * 60)

        func at(_ hour: Int, _ minute: Int = 0) -> ProfileTrigger.Environment {
            ProfileTrigger.Environment(minuteOfDay: hour * 60 + minute)
        }

        #expect(night.holds(in: at(23, 30)))
        #expect(night.holds(in: at(2)))
        #expect(night.holds(in: at(7, 59)))
        #expect(!night.holds(in: at(8)))
        #expect(!night.holds(in: at(12)))
        #expect(!night.holds(in: at(22, 59)))

        // A plain window is end-exclusive, and an empty one never holds.
        let office = ProfileTrigger.timeWindow(startMinute: 9 * 60, endMinute: 17 * 60)
        #expect(office.holds(in: at(9)))
        #expect(!office.holds(in: at(17)))
        #expect(!ProfileTrigger.timeWindow(startMinute: 600, endMinute: 600).holds(in: at(10)))
    }
}

@Suite("Arbitration (manual > priority > order > default)")
struct ArbitrationTests {

    private let t0 = Date(timeIntervalSinceReferenceDate: 50_000)
    private let profiles = BuiltInProfiles.all()

    private func withTriggers() -> [Profile] {
        let input = SensorInput(group: .compute)
        return [
            Profile(
                name: "Night",
                binding: FanBinding(curve: BuiltInProfiles.quietCurve, input: input),
                trigger: .timeWindow(startMinute: 0, endMinute: 24 * 60),
                priority: 5),
            Profile(
                name: "OnBattery",
                binding: FanBinding(curve: BuiltInProfiles.quietCurve, input: input),
                trigger: .powerSource(.battery),
                priority: 10),
            Profile(
                name: "AlsoNight",
                binding: FanBinding(curve: BuiltInProfiles.balancedCurve, input: input),
                trigger: .timeWindow(startMinute: 0, endMinute: 24 * 60),
                priority: 5),
            Profile(
                name: BuiltInProfiles.defaultName,
                binding: FanBinding(curve: BuiltInProfiles.balancedCurve, input: input)),
        ]
    }

    @Test("a live manual selection beats every trigger")
    func manualWins() {
        let outcome = Arbitration.activeProfile(
            among: withTriggers(),
            manual: ManualSelection(profileName: "AlsoNight", until: t0.addingTimeInterval(60)),
            environment: ProfileTrigger.Environment(
                power: PowerContext(source: .battery, batteryPercentage: 50)),
            now: t0)
        #expect(outcome?.profile.name == "AlsoNight")
        #expect(outcome?.reason == .manual(until: t0.addingTimeInterval(60)))
    }

    @Test("an expired or dangling manual selection falls through to the triggers")
    func manualExpiryAndDangling() {
        let expired = Arbitration.activeProfile(
            among: withTriggers(),
            manual: ManualSelection(profileName: "AlsoNight", until: t0.addingTimeInterval(-1)),
            environment: ProfileTrigger.Environment(
                power: PowerContext(source: .battery, batteryPercentage: 50)),
            now: t0)
        #expect(expired?.profile.name == "OnBattery")

        let dangling = Arbitration.activeProfile(
            among: withTriggers(),
            manual: ManualSelection(profileName: "Deleted"),
            environment: ProfileTrigger.Environment(),
            now: t0)
        // The named profile is gone; arbitration still answers.
        #expect(dangling?.profile.name == "Night")
    }

    @Test("highest priority wins among holding triggers; ties go to the earlier profile")
    func priorityAndOrder() {
        let onBattery = Arbitration.activeProfile(
            among: withTriggers(), manual: nil,
            environment: ProfileTrigger.Environment(
                power: PowerContext(source: .battery, batteryPercentage: 80)),
            now: t0)
        #expect(onBattery?.profile.name == "OnBattery")
        #expect(onBattery?.reason == .trigger(.powerSource(.battery)))

        // On the adapter only the two always-on windows hold; equal
        // priority, so the earlier one in the list wins.
        let tie = Arbitration.activeProfile(
            among: withTriggers(), manual: nil,
            environment: ProfileTrigger.Environment(),
            now: t0)
        #expect(tie?.profile.name == "Night")
    }

    @Test("with nothing holding, the default profile answers with the fallback reason")
    func fallbackToDefault() {
        let outcome = Arbitration.activeProfile(
            among: profiles, manual: nil,
            environment: ProfileTrigger.Environment(),
            now: t0)
        #expect(outcome?.profile.name == BuiltInProfiles.defaultName)
        #expect(outcome?.reason == .fallback)
    }

    @Test("per-fan bindings override the profile default")
    func perFanBinding() throws {
        let input = SensorInput(group: .compute)
        let special = FanBinding(curve: BuiltInProfiles.performanceCurve, input: input)
        let profile = Profile(
            name: "Split",
            binding: FanBinding(curve: BuiltInProfiles.quietCurve, input: input),
            perFan: [1: special])
        #expect(profile.binding(forFan: 0).curve == BuiltInProfiles.quietCurve)
        #expect(profile.binding(forFan: 1).curve == BuiltInProfiles.performanceCurve)
    }

    @Test("the built-ins hold their promises")
    func builtInShape() {
        let all = BuiltInProfiles.all()
        #expect(all.map(\.name) == ["Quiet", "Balanced", "Performance", "System"])
        #expect(all.first(where: { $0.name == "System" })?.enginePaused == true)
        // Every built-in reaches full duty by 88 degrees: no profile is a
        // way of never cooling hard.
        for profile in all {
            #expect(profile.binding.curve.duty(at: 88) == Duty(1))
        }
        // Quiet stays below Balanced, Performance above, across the range
        // where they differ.
        for celsius in stride(from: 45.0, through: 80.0, by: 5) {
            let quiet = BuiltInProfiles.quietCurve.duty(at: celsius)
            let balanced = BuiltInProfiles.balancedCurve.duty(at: celsius)
            let performance = BuiltInProfiles.performanceCurve.duty(at: celsius)
            #expect(quiet <= balanced, "at \(celsius)")
            #expect(balanced <= performance, "at \(celsius)")
        }
    }

    @Test("a curve decoded from configuration is validated or refused (G6 groundwork)")
    func curveDecodingValidates() throws {
        let valid = try JSONDecoder().decode(
            Curve.self,
            from: Data(#"[{"celsius":35,"duty":0},{"celsius":88,"duty":1}]"#.utf8))
        #expect(valid.duty(at: 88) == Duty(1))

        let downhill = Data(#"[{"celsius":35,"duty":0.9},{"celsius":88,"duty":0.1}]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Curve.self, from: downhill)
        }
    }
}
