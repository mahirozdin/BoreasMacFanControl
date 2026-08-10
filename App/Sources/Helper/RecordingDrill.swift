import Core
import Foundation

/// The P7.02 drill: recordings really land on disk, rotate, and **the ceiling
/// really deletes**.
///
/// **What this adds over `RecordingPolicyTests`.** Those prove the arithmetic —
/// which files should go, and when — over fake metadata, which is the right place
/// for it. What they cannot see is whether the writer acts on that decision:
/// whether the file it opens is the file the policy named, whether a CSV
/// reopened after a relaunch keeps its column order, and whether `removeItem`
/// actually runs. That is the half that needs a disk, and this is it.
///
/// It works in a throwaway directory. A drill that could delete the owner's own
/// recordings is not a drill — the same rule `--config-drill` follows.
@MainActor
enum RecordingDrill {

    static func run(report: (String) -> Void) {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("boreas-recording-drill", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt

        runChecks(directory: directory, calendar: calendar, check: check, report: report)

        try? FileManager.default.removeItem(at: directory)
        report(passed ? "RECORDING DRILL PASS" : "RECORDING DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    private static func runChecks(
        directory: URL,
        calendar: Calendar,
        check: (String, Bool) -> Void,
        report: (String) -> Void
    ) {
        let writer = RecordingWriter(directory: directory, calendar: calendar)

        // 1. Off by default: nothing is written, and no directory is created.
        let disabled = RecordingSettings(isEnabled: false)
        let firstRecord = sample(at: 0)
        waitFor { await writer.append(firstRecord, settings: disabled) }
        check(
            "with recording off, nothing is written",
            !FileManager.default.fileExists(atPath: directory.path))

        // 2. On, JSONL: a file appears and every line is a complete JSON object.
        let jsonl = RecordingSettings(isEnabled: true, format: .jsonl, intervalSeconds: 1)
        for offset in 0..<5 {
            let record = sample(at: Double(offset))
            waitFor { await writer.append(record, settings: jsonl) }
        }
        let files = contents(of: directory)
        let writeStatus = waitFor { await writer.status } ?? RecordingStatus()
        // Reported rather than only asserted: "no file appeared" has several
        // causes and the writer already knows which one it was.
        if files.isEmpty {
            report("      records written: \(writeStatus.recordsThisSession)")
            report("      last error: \(writeStatus.lastError ?? "none")")
        }
        check("a JSONL file was created", files.count == 1)
        if let name = files.first {
            let text =
                (try? String(
                    contentsOf: directory.appendingPathComponent(name),
                    encoding: .utf8)) ?? ""
            let lines = text.split(separator: "\n").map(String.init)
            check("five records became five lines", lines.count == 5)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodable = lines.allSatisfy {
                (try? decoder.decode(RecordingRecord.self, from: Data($0.utf8))) != nil
            }
            check("every line decodes on its own", decodable)
            let carriesLayer = lines.contains { $0.contains("panic") }
            check("the engaged safety layer is in the file", carriesLayer)
            report("      \(name): \(lines.count) lines")
        }

        // 3. The ceiling deletes, for real. Files are planted directly so the
        //    drill does not have to write 500 MB to find out.
        checkCeiling(directory: directory, calendar: calendar, check: check, report: report)

        // 4. CSV: a header once, then rows, and the column order survives a
        //    reopen — the failure that would look fine and be wrong.
        checkCSV(directory: directory, calendar: calendar, check: check, report: report)
    }

    // MARK: - The ceiling, on a real disk

    private static func checkCeiling(
        directory: URL,
        calendar: Calendar,
        check: (String, Bool) -> Void,
        report: (String) -> Void
    ) {
        let ceilingDirectory = directory.appendingPathComponent("ceiling", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: ceilingDirectory, withIntermediateDirectories: true)

        // Four days of 4 MB files against a 10 MB ceiling. Real bytes on a real
        // disk, small enough to be quick and large enough that the arithmetic is
        // not rounding.
        let block = Data(repeating: 0x41, count: 4_000_000)
        var planted: [String] = []
        for daysAgo in [3, 2, 1, 0] {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let file = RecordingFile(day: calendar.startOfDay(for: day), sequence: 0, byteCount: 0)
            let name = file.name(format: .jsonl, calendar: calendar)
            try? block.write(to: ceilingDirectory.appendingPathComponent(name))
            planted.append(name)
        }
        check("four 4 MB files were planted", contents(of: ceilingDirectory).count == 4)

        let writer = RecordingWriter(directory: ceilingDirectory, calendar: calendar)
        let tight = RecordingSettings(
            isEnabled: true, format: .jsonl, retentionDays: 365,
            diskCeilingBytes: 10_000_000, intervalSeconds: 1)
        let ceilingRecord = sample(at: 0)
        waitFor { await writer.append(ceilingRecord, settings: tight) }

        let remaining = contents(of: ceilingDirectory)
        let totalBytes = remaining.reduce(0) { total, name in
            let url = ceilingDirectory.appendingPathComponent(name)
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            return total + (attributes?[.size] as? Int ?? 0)
        }
        check(
            "the ceiling brought the total under its limit "
                + "(\(totalBytes / 1_000_000) MB of 10 MB)",
            totalBytes <= tight.diskCeilingBytes)
        check(
            "the oldest file was the one deleted",
            !remaining.contains(planted[0]))
        check(
            "today's file — the one being written — survived",
            remaining.contains { $0.contains(todayStamp(calendar)) })
        let status = waitFor { await writer.status } ?? RecordingStatus()
        check("the interface is told the ceiling acted", status.ceilingDeletedCount > 0)
        report("      \(remaining.count) file(s) left, \(totalBytes / 1_000_000) MB")
    }

    // MARK: - CSV

    private static func checkCSV(
        directory: URL,
        calendar: Calendar,
        check: (String, Bool) -> Void,
        report: (String) -> Void
    ) {
        let csvDirectory = directory.appendingPathComponent("csv", isDirectory: true)
        let settings = RecordingSettings(
            isEnabled: true, format: .csv, intervalSeconds: 1)

        let first = RecordingWriter(directory: csvDirectory, calendar: calendar)
        let rowOne = sample(at: 0)
        let rowTwo = sample(at: 1)
        waitFor { await first.append(rowOne, settings: settings) }
        waitFor { await first.append(rowTwo, settings: settings) }
        waitFor { await first.flush() }

        // A second writer over the same directory: a relaunch in everything but
        // name. Its sample carries the sensors in a different order.
        let second = RecordingWriter(directory: csvDirectory, calendar: calendar)
        let reordered = sample(at: 2, reorderedSensors: true)
        waitFor { await second.append(reordered, settings: settings) }
        waitFor { await second.flush() }

        guard let name = contents(of: csvDirectory).first else {
            check("a CSV file was created", false)
            return
        }
        let text =
            (try? String(
                contentsOf: csvDirectory.appendingPathComponent(name),
                encoding: .utf8)) ?? ""
        let lines = text.split(separator: "\n").map(String.init)
        check("one header and three rows", lines.count == 4)
        check("the header names the sensor columns", lines.first?.contains("sensor:") ?? false)
        let headerFields = lines.first?.split(separator: ",").count ?? 0
        let everyRowMatches = lines.dropFirst().allSatisfy {
            $0.split(separator: ",", omittingEmptySubsequences: false).count == headerFields
        }
        // The one that would look fine and be wrong: a relaunch writing this
        // run's sensor order under the previous run's header.
        check("every row has exactly as many fields as the header", everyRowMatches)
        check("only one header was written", lines.filter { $0.contains("timestamp") }.count == 1)
        report("      \(name): \(headerFields) columns, \(lines.count - 1) rows")
    }

    // MARK: - Fixtures and helpers

    private static func sample(
        at offset: Double, reorderedSensors: Bool = false
    )
        -> RecordingRecord
    {
        let sensors =
            reorderedSensors
            ? ["GPU tdie0": 55.8, "PMU tdie5": 62.4]
            : ["PMU tdie5": 62.4, "GPU tdie0": 55.8]
        return RecordingRecord(
            timestamp: Date().addingTimeInterval(offset),
            sensors: sensors,
            fans: [0: 1_608],
            profileName: "Balanced",
            // Deliberately set: the safety layer is the field
            // docs/operations/observability.md calls critical, so the drill has
            // to see it reach the file rather than assume it.
            safetyLayer: .panic,
            thermal: .serious)
    }

    private static func contents(of directory: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasPrefix("boreas-") }
            .sorted()
    }

    private static func todayStamp(_ calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// Waits for an actor call from the drill's synchronous flow.
    ///
    /// The writer is an actor because it appends from a background task while the
    /// interface reads its status; a drill is a script and wants to go in order.
    ///
    /// **Every value the closure needs must be built before it, on the main
    /// actor.** `Task.detached` escapes *inherited* isolation, not isolation the
    /// closure body demands: referencing a `@MainActor` member inside it — even
    /// something as innocent as this file's `sample(at:)` — makes the whole
    /// closure need a hop back to the main actor, which `semaphore.wait` below is
    /// blocking. That deadlocks until the timeout, and the first version of this
    /// drill took **200 seconds** to run ten of them before reporting that
    /// nothing had been written. `BoreasApp.pingHelper` carries a comment about
    /// the plain-`Task` version of the same trap; detached fixes the inheritance
    /// and not the body.
    @discardableResult
    private static func waitFor<Value: Sendable>(
        _ operation: @escaping @Sendable () async -> Value
    ) -> Value? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = DrillBox<Value>()
        Task.detached {
            box.value = await operation()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 20)
        return box.value
    }
}

/// A one-slot holder so an actor's answer can cross back into the drill's
/// synchronous flow. Declared at file scope because Swift will not nest a
/// generic type inside a generic function.
private final class DrillBox<Wrapped>: @unchecked Sendable {
    var value: Wrapped?
}
