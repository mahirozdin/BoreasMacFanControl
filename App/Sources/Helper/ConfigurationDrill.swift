import Core
import Foundation

/// The P6.08 persistence drill: settings survive a restart, a broken file
/// cannot break the application, and nothing is ever overwritten without a
/// copy of what was there.
///
/// It runs against a throwaway directory rather than the owner's real
/// configuration — a drill that could damage what it is testing is not a
/// drill. Everything it exercises is the same code the application runs.
@MainActor
enum ConfigurationDrill {

    static func run(report: (String) -> Void) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("boreas-config-drill-\(ProcessInfo.processInfo.processIdentifier)")
        defer { try? FileManager.default.removeItem(at: directory) }

        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        // 1. A first run writes the defaults, so the documented path names
        //    a file that actually exists.
        let first = ConfigurationStore(directory: directory)
        first.load()
        check("first run creates the file", FileManager.default.fileExists(atPath: first.fileURL.path))
        check("first run reports no problem", first.problem == nil)

        // 2. A change is written, and written *whole*.
        first.update {
            $0.general = ConfigurationFile.General(samplingIntervalSeconds: 7)
            $0.safety = ConfigurationFile.Safety(
                panicThreshold: PanicThreshold(celsius: 84), watchdogTimeoutSeconds: 15)
            $0.defaultProfileName = "Quiet"
            $0.sensorOverrides = [
                "PMU tdie5": SensorOverride(displayName: "Main die", group: .computePerformance)
            ]
        }
        first.save(immediately: true)

        // 3. A second store — a restart in everything but name — sees it.
        let second = ConfigurationStore(directory: directory)
        second.load()
        check("sampling interval survived", second.configuration.general.samplingIntervalSeconds == 7)
        check("panic threshold survived", second.configuration.safety.panicThreshold.celsius == 84)
        check("default profile survived", second.configuration.defaultProfileName == "Quiet")
        check(
            "sensor override survived",
            second.configuration.sensorOverrides["PMU tdie5"]?.group == .computePerformance)
        check("profiles survived", second.configuration.profiles.count == 4)

        // 4. Every write leaves the previous bytes beside the file.
        second.update { $0.general = ConfigurationFile.General(samplingIntervalSeconds: 9) }
        second.save(immediately: true)
        check(
            "a backup is kept beside the file",
            FileManager.default.fileExists(atPath: second.backupURL.path))

        // 5. G6: a corrupt file cannot break anything. The last valid
        //    configuration stays in force and the problem is reported with
        //    the field that caused it.
        try? Data("{ this is not json".utf8).write(to: second.fileURL)
        let third = ConfigurationStore(directory: directory)
        third.load()
        check("a broken file is refused", third.problem != nil)
        check(
            "a broken file falls back to a working configuration",
            third.configuration.general.samplingIntervalSeconds
                == ConfigurationFile.standard.general.samplingIntervalSeconds)

        // 6. A value outside the published range is clamped by the type on
        //    the way in, not trusted because it was in a file (G2).
        let hostile = """
            {"schemaVersion":1,"safety":{"panicTemperatureCelsius":140,"watchdogTimeoutSeconds":900}}
            """
        try? Data(hostile.utf8).write(to: second.fileURL)
        let fourth = ConfigurationStore(directory: directory)
        fourth.load()
        check(
            "an out-of-range panic threshold is clamped",
            fourth.configuration.safety.panicThreshold.celsius == PanicThreshold.defaultCelsius)
        check(
            "an out-of-range watchdog timeout is clamped",
            WatchdogPolicy.allowedTimeout.contains(
                fourth.configuration.safety.watchdogTimeoutSeconds))

        report(passed ? "CONFIG DRILL PASS" : "CONFIG DRILL FAIL")
        exit(passed ? 0 : 1)
    }
}

/// The P6.14 drill: a trigger created the way the editor creates one is a
/// trigger arbitration actually honours.
///
/// It exists because building the editor exposed something the editor
/// alone could not have shown: the application used to hold a standing
/// manual `System` selection, and arbitration's first rule is that a
/// manual choice beats everything. Every trigger anyone created would have
/// been vetoed forever, silently. So the drill checks the *whole* path —
/// automatic mode, the trigger firing, and the manual veto still winning
/// when a user does choose.
@MainActor
enum TriggerDrill {

    static func run(report: (String) -> Void) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("boreas-trigger-drill-\(ProcessInfo.processInfo.processIdentifier)")
        defer { try? FileManager.default.removeItem(at: directory) }

        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        let store = ConfigurationStore(directory: directory)
        store.load()
        let monitor = MonitorModel(store: store)
        let control = ControlModel(monitor: monitor, store: store)

        // 1. Out of the box nothing is taken over, and nothing is selected
        //    — the state that lets triggers work at all.
        check("no standing manual selection", control.manualSelection == nil)
        check(
            "the shipped fallback leaves the fans with the firmware",
            control.outcome?.profile.enginePaused == true)

        // 2. A trigger, added exactly as the editor adds one. This machine
        //    is a desktop, so "plugged in" is a condition that holds.
        store.update { configuration in
            guard let index = configuration.profiles.firstIndex(where: { $0.name == "Quiet" })
            else { return }
            let old = configuration.profiles[index]
            configuration.profiles[index] = Profile(
                name: old.name, binding: old.binding, perFan: old.perFan,
                triggers: [.powerSource(.adapter)], priority: 5,
                smoothing: old.smoothing, hysteresis: old.hysteresis,
                slew: old.slew, enginePaused: old.enginePaused)
        }
        control.reloadFromConfiguration()

        let chosen = control.outcome
        check("the trigger selected its profile", chosen?.profile.name == "Quiet")
        if case .trigger(let trigger) = chosen?.reason {
            check("and the reason names the trigger", trigger == .powerSource(.adapter))
        } else {
            check("and the reason names the trigger", false)
        }

        // 3. A manual choice still beats it — rule 1, unchanged.
        control.select(profileName: "Performance")
        check("a manual choice overrides the trigger", control.outcome?.profile.name == "Performance")

        // 4. And going back to automatic hands the decision to the trigger
        //    again. Without this the manual choice would be permanent.
        control.selectAutomatic()
        check("automatic returns the decision to the trigger", control.outcome?.profile.name == "Quiet")

        // 5. It survives a restart, because it went through the store.
        //    The flush is what the application does on termination — the
        //    write is coalesced, and this drill is the reason that exit
        //    exists at all.
        store.save(immediately: true)
        let second = ConfigurationStore(directory: directory)
        second.load()
        let reloaded = second.configuration.profiles.first { $0.name == "Quiet" }
        check("the trigger was persisted", reloaded?.triggers == [.powerSource(.adapter)])
        check("the priority was persisted", reloaded?.priority == 5)

        report(passed ? "TRIGGER DRILL PASS" : "TRIGGER DRILL FAIL")
        exit(passed ? 0 : 1)
    }
}
