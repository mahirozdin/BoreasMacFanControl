import AppKit
import Core
import Foundation
import OSLog
import os

/// Assembles the support report from the running application (P7.05).
///
/// `Core.SupportReport` decides what a report *is* and what it may never carry;
/// this gathers the values and writes the file. The split matters here more than
/// usual: the redaction rules and the leak audit are testable without a machine,
/// and what is left is a list of system lookups short enough to read.
///
/// **Nothing is uploaded, and there is no code here that could.** `gate-privacy`
/// enforces that no network API exists outside `App/Sources/Automation/`, so the
/// promise in the report's own first line is checked by a gate rather than kept
/// by intention.
@MainActor
enum SupportReportBuilder {

    /// Writes a report and returns where it went.
    static func write(
        model: MonitorModel,
        control: ControlModel,
        store: ConfigurationStore?,
        diagnostics: [String],
        now: Date = Date()
    ) -> URL? {
        let report = build(
            model: model, control: control, store: store, diagnostics: diagnostics, now: now)
        var text = report.markdown()

        // The audit runs on the finished text, as a second line of defence behind
        // the allowlist. If anything did slip through, the *report* says so rather
        // than the user discovering it after posting the file — a report that
        // quietly contained a serial number would be worse than no report.
        let found = SupportReport.leaks(in: text, forbidden: forbiddenValues())
        if !found.isEmpty {
            Logger(subsystem: "com.bubiapps.boreas", category: "ui")
                .error("support report withheld \(found.count, privacy: .public) value(s)")
            for value in found {
                text = text.replacingOccurrences(of: value, with: "<redacted>")
            }
            text += "\n> \(found.count) value(s) were redacted by the privacy audit.\n"
        }

        guard
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first?.appendingPathComponent("Boreas", isDirectory: true)
        else { return nil }

        let stamp = now.formatted(
            Date.ISO8601FormatStyle(dateSeparator: .omitted, timeZone: .gmt)
                .year().month().day())
        let url = directory.appendingPathComponent("boreas-support-\(stamp).md")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url)
            return url
        } catch {
            Logger(subsystem: "com.bubiapps.boreas", category: "ui")
                .error("support report write failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Gathering

    static func build(
        model: MonitorModel,
        control: ControlModel,
        store: ConfigurationStore?,
        diagnostics: [String],
        now: Date
    ) -> SupportReport {
        SupportReport(
            generatedAt: now,
            system: systemSummary(),
            hardware: hardwareMap(model: model),
            configurationJSON: configurationJSON(store: store),
            // Redacted on the way *in*, which is the rule: a value that was never
            // allowed in cannot be missed on the way out.
            diagnosticLines: diagnostics.map(SupportReport.redacted),
            logLines: recentLogLines().map(SupportReport.redacted))
    }

    /// Only values that describe a *class* of machine.
    ///
    /// No `Host.current().localizedName` — that is almost always a person's name —
    /// and no serial number, which is what makes this summary anonymous rather
    /// than merely short.
    private static func systemSummary() -> SupportReport.System {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buffer = [UInt8](repeating: 0, count: max(size, 1))
        if size > 0 {
            buffer.withUnsafeMutableBytes { raw in
                _ = sysctlbyname("hw.model", raw.baseAddress, &size, nil, 0)
            }
        }
        // Truncated at the null terminator rather than handed to
        // `String(cString:)`, which is deprecated for exactly this reason.
        let identifier =
            String(bytes: buffer.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""

        let version = ProcessInfo.processInfo.operatingSystemVersion
        let appVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

        return SupportReport.System(
            modelIdentifier: identifier.isEmpty ? "unknown" : identifier,
            macOSVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            appVersion: appVersion,
            coreCount: ProcessInfo.processInfo.processorCount,
            memoryGigabytes: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    /// The discovered hardware map — the section that actually helps somebody
    /// reading a report from a Mac this project cannot test (R8).
    private static func hardwareMap(model: MonitorModel) -> SupportReport.Hardware {
        SupportReport.Hardware(
            sensorCount: model.allReadings.count,
            // Raw hardware names, not the user's renames: the point of this
            // section is what the machine calls its sensors.
            sensors: model.allReadings.map {
                SupportReport.ReportedSensor(
                    rawName: $0.rawName, group: $0.group, celsius: $0.celsius)
            },
            fans: model.fans.map {
                SupportReport.ReportedFan(
                    id: $0.id, minimumRPM: $0.minimumRPM, maximumRPM: $0.maximumRPM,
                    currentRPM: $0.currentRPM)
            },
            driveModel: driveIdentity()?.model,
            driveFirmware: driveIdentity()?.firmware)
    }

    /// The drive's model and firmware — **and nothing else from that service.**
    ///
    /// Its serial number sits in the same property dictionary, which is exactly
    /// why this returns two named fields instead of the dictionary.
    private static func driveIdentity() -> (model: String, firmware: String?)? {
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
            let properties = unmanaged?.takeRetainedValue() as? [String: Any],
            let modelName = properties["Model Number"] as? String
        else { return nil }
        return (modelName, properties["Firmware Revision"] as? String)
    }

    private static func configurationJSON(store: ConfigurationStore?) -> String {
        guard let store else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(store.configuration),
            let text = String(bytes: data, encoding: .utf8)
        else { return "{}" }
        // Through the same redaction as everything else: a profile name is the
        // user's own text and could be anything.
        return SupportReport.redacted(text)
    }

    /// Recent log lines from this process's own subsystem.
    ///
    /// `OSLogStore` reading the current process needs no permission. It is
    /// deliberately scoped to this application's subsystem — a report carrying
    /// other applications' log lines would be collecting data about software that
    /// has nothing to do with this one.
    private static func recentLogLines(limit: Int = 200) -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let since = store.position(timeIntervalSinceLatestBoot: 0)
            let entries = try store.getEntries(at: since)
            var lines: [String] = []
            for case let entry as OSLogEntryLog in entries
            where entry.subsystem == "com.bubiapps.boreas" {
                lines.append("[\(entry.category)] \(entry.composedMessage)")
            }
            return Array(lines.suffix(limit))
        } catch {
            return []
        }
    }

    /// The values that must never appear, built from this machine.
    ///
    /// Assembled at report time rather than hard-coded: the audit has to know
    /// *this* user's account name and *this* drive's serial in order to check for
    /// them, and neither is knowable in advance.
    private static func forbiddenValues() -> [String] {
        var forbidden: [String] = []
        let account = NSUserName()
        if !account.isEmpty { forbidden.append(account) }
        let machine = Host.current().localizedName ?? ""
        if !machine.isEmpty { forbidden.append(machine) }
        if let serial = driveSerialForAuditOnly(), !serial.isEmpty { forbidden.append(serial) }
        return forbidden
    }

    /// Reads the drive serial **only so the audit can check it is absent.**
    ///
    /// Uncomfortable and correct: to prove a value is not in a file you have to
    /// know the value. It is never stored, never rendered, and never leaves this
    /// function except as a needle for `SupportReport.leaks(in:forbidden:)`.
    private static func driveSerialForAuditOnly() -> String? {
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
