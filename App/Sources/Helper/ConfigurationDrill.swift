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
