import Core
import Foundation

/// The P7.05 drill: a real report from this real machine, checked for the three
/// values it must never contain.
///
/// **`SupportReportTests` proves the rules; this proves the machine.** Those tests
/// plant fake secrets in fake inputs, which is the right way to test a redaction
/// rule. What they cannot do is read *this* Mac's drive serial and *this* account
/// name out of the system and confirm neither reached the file — and those are the
/// values that would actually be leaked.
@MainActor
enum SupportReportDrill {

    static func run(report: (String) -> Void) {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        let monitor = MonitorModel()
        let control = ControlModel(monitor: monitor)
        monitor.start()
        RunLoop.main.run(until: Date().addingTimeInterval(4))
        monitor.stop()

        check("the monitor read sensors to describe", !monitor.allReadings.isEmpty)

        let built = SupportReportBuilder.build(
            model: monitor, control: control, store: nil,
            diagnostics: ["Fan response: nothing to judge yet"], now: Date())
        let text = built.markdown()
        report("      report is \(text.utf8.count) bytes, \(text.split(separator: "\n").count) lines")

        // The three real values, read from this machine expressly so their absence
        // can be asserted rather than assumed.
        let account = NSUserName()
        let machine = Host.current().localizedName ?? ""
        let serial = driveSerial() ?? ""

        report("      checking for: account name, machine name, drive serial")
        check(
            "the account name does not appear (\(account.isEmpty ? "none to check" : "checked"))",
            account.isEmpty || !text.localizedCaseInsensitiveContains(account))
        check(
            "the machine name does not appear (\(machine.isEmpty ? "none to check" : "checked"))",
            machine.isEmpty || !text.localizedCaseInsensitiveContains(machine))
        check(
            "the drive serial does not appear (\(serial.isEmpty ? "none to check" : "checked"))",
            serial.isEmpty || !text.localizedCaseInsensitiveContains(serial))

        // The audit agrees, over the same needles the builder uses.
        let leaks = SupportReport.leaks(
            in: text, forbidden: [account, machine, serial])
        check("the privacy audit finds nothing", leaks.isEmpty)
        if !leaks.isEmpty {
            report("      LEAKED: \(leaks.joined(separator: ", "))")
        }

        // And the report is actually useful: the sections that make it worth
        // attaching to an issue have to be there.
        check("the hardware map lists this Mac's sensors", text.contains("PMU tdie"))
        check("the drive model is included", built.hardware.driveModel != nil)
        check("no serial field exists on the hardware map to fill in", !text.contains("Serial"))
        check("the report states that nothing was uploaded", text.contains("nothing here was uploaded"))
        check(
            "the model identifier is a class of machine, not this unit",
            built.system.modelIdentifier.hasPrefix("Mac"))
        report("      model: \(built.system.modelIdentifier), macOS \(built.system.macOSVersion)")

        // Written for real, then removed: proving the file lands is part of it.
        if let url = SupportReportBuilder.write(
            model: monitor, control: control, store: nil,
            diagnostics: [], now: Date())
        {
            let exists = FileManager.default.fileExists(atPath: url.path)
            check("the report was written to disk", exists)
            report("      wrote \(url.lastPathComponent)")
            try? FileManager.default.removeItem(at: url)
        } else {
            check("the report was written to disk", false)
        }

        passed =
            checkSensorLink(
                monitor: monitor, needles: [account, machine, serial], report: report) && passed

        report(passed ? "SUPPORT REPORT DRILL PASS" : "SUPPORT REPORT DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    /// The unknown-sensor link (P7.09) — the other thing that can leave this
    /// machine, and the one with less protection.
    ///
    /// A pre-filled issue URL reaches the server **on page load**, so unlike the
    /// support report there is no moment where the user reads the payload and
    /// then decides. It is checked in this drill rather than its own because the
    /// needles are the same three, already read from the system by the caller.
    private static func checkSensorLink(
        monitor: MonitorModel, needles: [String], report: (String) -> Void
    ) -> Bool {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        report("    unknown-sensor link:")
        let unrecognised = monitor.allReadings.filter { $0.group == .uncategorized }
        report(
            "      \(unrecognised.count) unrecognised of \(monitor.allReadings.count) sensors, "
                + "\(monitor.fans.count) fan(s)")

        // This Mac classifies every sensor it has, so the populated branch would
        // never run here and the privacy assertions below would silently test
        // nothing. A stand-in name is substituted when the list is empty: the
        // three needles, the model and the chip are still **this machine's**,
        // which is what the assertions are about — only the hardware key, which
        // is the one field that could never carry an identity, is synthetic.
        let standIn = SensorReading(
            rawName: "DRILL synthetic key", displayName: "DRILL synthetic key",
            group: .uncategorized, celsius: 42)
        if unrecognised.isEmpty {
            report("      nothing unrecognised on this Mac — using a stand-in sensor key")
        }

        if let link = SensorReportAction.link(
            unrecognised: unrecognised.isEmpty ? [standIn] : unrecognised,
            fanCount: monitor.fans.count)
        {
            let leaked = SupportReport.leaks(
                in: link.url.removingPercentEncoding ?? link.url, forbidden: needles)
            check("the link leaks none of the three needles", leaked.isEmpty)
            if !leaked.isEmpty {
                report("      LEAKED: \(leaked.joined(separator: ", "))")
            }
            check(
                "the link carries the model as a class of machine",
                link.url.contains("model=Mac"))
            check("the link targets the unknown-sensor template", link.url.contains(".yml"))
            check(
                "the link stays inside its length budget",
                link.url.count <= SensorReportLink.maximumURLLength)
            report("      \(link.url.count) chars, \(link.omittedSensorCount) name(s) omitted")
            report("      chip read as: \(SensorReportAction.chip)")
        } else {
            // Reachable only if the bundle carries no repository address, which
            // is a build fault rather than a state of this Mac.
            check("a link could be built", false)
            report("      no link — is \(SensorReportAction.repositoryURLKey) in Info.plist?")
        }

        // The empty case is a real branch too, and it must offer nothing rather
        // than a link to an issue with no content in it.
        check(
            "an empty sensor list yields no link at all",
            SensorReportAction.link(unrecognised: [], fanCount: monitor.fans.count) == nil)

        return passed
    }

    /// Reads the serial **only so its absence can be asserted.** Never rendered,
    /// never stored — the same uncomfortable-but-correct trick the builder's audit
    /// uses: proving a value is absent requires knowing it.
    private static func driveSerial() -> String? {
        guard let matching = IOServiceMatching("IONVMeController") else { return nil }
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
                == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard
            IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
                == KERN_SUCCESS,
            let properties = unmanaged?.takeRetainedValue() as? [String: Any]
        else { return nil }
        return properties["Serial Number"] as? String
    }
}
