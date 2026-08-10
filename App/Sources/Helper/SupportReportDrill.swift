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

        report(passed ? "SUPPORT REPORT DRILL PASS" : "SUPPORT REPORT DRILL FAIL")
        exit(passed ? 0 : 1)
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
