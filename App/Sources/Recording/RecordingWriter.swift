import Core
import Foundation
import os

/// Writes recordings to disk (P7.02).
///
/// **Everything that decides anything is in `Core`.** Rotation, retention and the
/// disk ceiling are `RecordingPolicy`; the record's shape and both formats are
/// `RecordingSerializer`. What is left here is the file system work, and it is
/// deliberately small enough to read in one sitting — because this is the part
/// that cannot be tested without a disk, so it is the part that has to be
/// obvious.
///
/// An actor: it appends to a file from a background task while the interface asks
/// it for its status, and those must not race.
actor RecordingWriter {

    /// Where recordings live. Beside the configuration, not in it — a directory
    /// of data files inside a directory somebody might hand-edit invites
    /// accidents.
    private let directory: URL
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "recording")
    private let calendar: Calendar

    /// What the interface shows. Recomputed on every write rather than derived on
    /// demand, so reading it costs nothing and cannot itself touch the disk.
    private(set) var status = RecordingStatus()

    private var handle: FileHandle?
    private var currentFile: RecordingFile?
    /// The CSV column order, fixed for the lifetime of a file — a header written
    /// once cannot describe a set of sensors that changed underneath it.
    private var csvSensors: [String] = []
    private var csvFans: [Int] = []

    init(directory: URL? = nil, calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.directory =
            directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Boreas/Recordings", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Boreas/Recordings", isDirectory: true)
        self.calendar = calendar
    }

    /// Appends one record, rotating and pruning as the policy says.
    ///
    /// Errors are logged and swallowed **here and only here**, deliberately: a
    /// recording is a convenience, and a full disk or a permission problem must
    /// not take down temperature monitoring or fan control. The state is surfaced
    /// in `status` so the interface can say so rather than the failure being
    /// invisible — which is the difference between degrading and lying.
    func append(_ record: RecordingRecord, settings: RecordingSettings) async {
        guard settings.isEnabled else { return }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try rotateIfNeeded(settings: settings, now: record.timestamp, record: record)
            try write(record, settings: settings)
            prune(settings: settings, now: record.timestamp)
            status.lastError = nil
        } catch {
            // The message, not the path: P3 forbids a file path in a log line.
            logger.error("recording write failed: \(error.localizedDescription, privacy: .public)")
            status.lastError = error.localizedDescription
        }
        status.totalBytes = existingFiles().reduce(0) { $0 + $1.byteCount }
        status.fileCount = existingFiles().count
    }

    /// Closes the current file. Called on quit so the last line is on disk.
    func flush() {
        try? handle?.close()
        handle = nil
        currentFile = nil
    }

    /// Everything the recorder has written, for the interface and the pruner.
    func inventory() -> [RecordingFile] { existingFiles() }

    var recordingDirectory: URL { directory }

    // MARK: - Rotation

    private func rotateIfNeeded(
        settings: RecordingSettings, now: Date, record: RecordingRecord
    ) throws {
        let destination = RecordingPolicy.destination(
            existing: existingFiles(), settings: settings, now: now, calendar: calendar)
        if let currentFile, currentFile.day == destination.day,
            currentFile.sequence == destination.sequence, handle != nil
        {
            return
        }

        try? handle?.close()
        handle = nil

        let url = directory.appendingPathComponent(
            destination.name(format: settings.format, calendar: calendar))
        let isNew = !FileManager.default.fileExists(atPath: url.path)
        if isNew {
            // The CSV header is written once, with the column order this file
            // will keep. Discovered from the first record, because the set of
            // sensors is only known at runtime.
            var contents = Data()
            if settings.format == .csv {
                csvSensors = record.sensors.keys.sorted()
                csvFans = record.fans.keys.sorted()
                contents = Data(
                    (RecordingSerializer.csvHeader(sensors: csvSensors, fans: csvFans) + "\n")
                        .utf8)
            }
            try contents.write(to: url)
        } else if settings.format == .csv, csvSensors.isEmpty {
            // Reopening an existing CSV after a relaunch: the header on disk is
            // the authority on column order, not this run's sensors.
            try readCSVColumnOrder(from: url)
        }

        let opened = try FileHandle(forWritingTo: url)
        try opened.seekToEnd()
        handle = opened
        currentFile = destination
        status.currentFileName = url.lastPathComponent
    }

    /// Recovers the column order from a header already on disk.
    ///
    /// Without this, relaunching mid-day and appending would write rows in *this*
    /// run's sensor order under *that* run's header — a file that looks fine and
    /// is wrong, which is the worst kind of wrong for data somebody will trust.
    private func readCSVColumnOrder(from url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let chunk = try handle.read(upToCount: 64_000),
            let text = String(bytes: chunk, encoding: .utf8),
            let header = text.split(separator: "\n").first
        else { return }
        csvSensors = []
        csvFans = []
        for column in header.split(separator: ",") {
            let name = column.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if name.hasPrefix("sensor:") {
                csvSensors.append(String(name.dropFirst("sensor:".count)))
            } else if name.hasPrefix("fan:"), let id = Int(name.dropFirst("fan:".count)) {
                csvFans.append(id)
            }
        }
    }

    private func write(_ record: RecordingRecord, settings: RecordingSettings) throws {
        guard let handle else { return }
        let line: String
        switch settings.format {
        case .jsonl:
            line = try RecordingSerializer.jsonlLine(record)
        case .csv:
            line = RecordingSerializer.csvRow(record, sensors: csvSensors, fans: csvFans)
        }
        try handle.write(contentsOf: Data((line + "\n").utf8))
        status.recordsThisSession += 1
        // The in-memory size follows the write, so the next rotation decision
        // does not need to stat the file.
        if let currentFile {
            self.currentFile = RecordingFile(
                day: currentFile.day, sequence: currentFile.sequence,
                byteCount: currentFile.byteCount + line.utf8.count + 1)
        }
    }

    // MARK: - Pruning

    private func prune(settings: RecordingSettings, now: Date) {
        let pruning = RecordingPolicy.prune(
            files: existingFiles(), settings: settings, now: now, calendar: calendar)
        guard !pruning.all.isEmpty else { return }
        for file in pruning.all {
            let url = directory.appendingPathComponent(
                file.name(format: settings.format, calendar: calendar))
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                logger.error(
                    "recording prune failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        status.expiredCount += pruning.expired.count
        if pruning.ceilingHadToAct {
            // Surfaced, not notified: a ceiling doing its configured job is a
            // standing condition rather than an event. The interface shows it and
            // keeps showing it, which is what a user needs in order to raise the
            // ceiling or shorten retention.
            status.ceilingDeletedCount += pruning.overCeiling.count
            logger.notice(
                "disk ceiling deleted \(pruning.overCeiling.count, privacy: .public) recording(s)")
        }
    }

    /// Reads the directory into policy input. Metadata only — this never opens a
    /// recording.
    private func existingFiles() -> [RecordingFile] {
        guard
            let names = try? FileManager.default.contentsOfDirectory(
                atPath: directory.path)
        else { return [] }
        return names.compactMap { parse(name: $0) }
    }

    /// `boreas-YYYY-MM-DD-NNN.<ext>` back into a `RecordingFile`.
    ///
    /// A name that does not parse is ignored rather than guessed at: the pruner
    /// deletes what this returns, so anything it is unsure about is something it
    /// must not touch. A stray file in the directory survives.
    private func parse(name: String) -> RecordingFile? {
        guard name.hasPrefix("boreas-") else { return nil }
        let stem = name.split(separator: ".").first.map(String.init) ?? name
        let parts = stem.split(separator: "-")
        guard parts.count == 5,
            let year = Int(parts[1]), let month = Int(parts[2]), let dayNumber = Int(parts[3]),
            let sequence = Int(parts[4])
        else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = dayNumber
        guard let day = calendar.date(from: components) else { return nil }
        let url = directory.appendingPathComponent(name)
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? Int ?? 0
        return RecordingFile(day: day, sequence: sequence, byteCount: size)
    }
}

/// What the interface says about recording.
struct RecordingStatus: Sendable, Equatable {
    var currentFileName: String?
    var recordsThisSession = 0
    var fileCount = 0
    var totalBytes = 0
    var expiredCount = 0

    /// How many files the **ceiling** removed, as opposed to retention.
    ///
    /// Kept apart because they mean different things to a user: retention
    /// deleting a fortnight-old file is the setting working, and the ceiling
    /// deleting a file they asked to keep is data they lost to a limit they may
    /// not remember setting.
    var ceilingDeletedCount = 0
    var lastError: String?
}
