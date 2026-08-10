import Foundation

/// The user's recording settings, as they persist (P7.02).
public struct RecordingSettings: Sendable, Hashable, Codable {

    /// **Off until asked.** `docs/operations/observability.md` calls this
    /// "measurement recording — at the user's request", and writing files
    /// continuously to somebody's disk without being asked is not this project's
    /// behaviour. Same call as notifications and global shortcuts.
    public var isEnabled: Bool

    public var format: RecordingFormat

    /// How long a file is kept. Clamped to the documented range by the type.
    public var retentionDays: Int

    /// The **hard** ceiling on everything the recorder has written, in bytes.
    ///
    /// Hard means hard: when the total exceeds it the oldest files are deleted
    /// until it does not, whatever the retention setting says. Retention is a
    /// preference; this is a promise not to fill somebody's disk, and the two
    /// disagree exactly when the machine has been recording more than expected —
    /// which is when the promise matters.
    public var diskCeilingBytes: Int

    /// A single file is rotated once it passes this size, so no one file grows
    /// unbounded within a day.
    public var maximumFileBytes: Int

    /// How often a sample is written, in seconds. Independent of the monitor's
    /// sampling interval: a two second sample rate is right for a live chart and
    /// wasteful for a file somebody will read a week later.
    public var intervalSeconds: Int

    public static let retentionRange = 1...365
    public static let ceilingRange = 10_000_000...20_000_000_000
    public static let fileSizeRange = 1_000_000...1_000_000_000
    public static let intervalRange = 1...3_600

    public init(
        isEnabled: Bool = false,
        format: RecordingFormat = .jsonl,
        retentionDays: Int = 14,
        diskCeilingBytes: Int = 500_000_000,
        maximumFileBytes: Int = 50_000_000,
        intervalSeconds: Int = 10
    ) {
        self.isEnabled = isEnabled
        self.format = format
        self.retentionDays = Self.clamp(retentionDays, to: Self.retentionRange)
        self.diskCeilingBytes = Self.clamp(diskCeilingBytes, to: Self.ceilingRange)
        self.maximumFileBytes = Self.clamp(maximumFileBytes, to: Self.fileSizeRange)
        self.intervalSeconds = Self.clamp(intervalSeconds, to: Self.intervalRange)
    }

    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, value))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Optional and defaulted throughout, so a file written before this
        // section existed decodes and needs no schema version bump.
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            format: try container.decodeIfPresent(RecordingFormat.self, forKey: .format)
                ?? .jsonl,
            retentionDays: try container.decodeIfPresent(Int.self, forKey: .retentionDays)
                ?? 14,
            diskCeilingBytes: try container.decodeIfPresent(
                Int.self, forKey: .diskCeilingBytes) ?? 500_000_000,
            maximumFileBytes: try container.decodeIfPresent(
                Int.self, forKey: .maximumFileBytes) ?? 50_000_000,
            intervalSeconds: try container.decodeIfPresent(Int.self, forKey: .intervalSeconds)
                ?? 10
        )
    }
}

/// One recording file as the policy sees it — metadata only, never contents.
public struct RecordingFile: Sendable, Hashable {

    /// The day the file records, at midnight in the recorder's calendar.
    public let day: Date

    /// Which file of that day this is; `0` is the first.
    public let sequence: Int

    public let byteCount: Int

    public init(day: Date, sequence: Int, byteCount: Int) {
        self.day = day
        self.sequence = sequence
        self.byteCount = byteCount
    }

    /// The name on disk. Sortable as text because the date leads and the
    /// sequence is zero padded — which matters the moment anybody lists the
    /// directory or a tool globs it.
    public func name(format: RecordingFormat, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let stamp = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0)
        return "boreas-\(stamp)-\(String(format: "%03d", sequence)).\(format.fileExtension)"
    }
}

/// What the recorder should do about its files (P7.02).
///
/// **Why this is a pure decision and not code inside the writer.** The two rules
/// worth being sure about are the ones that are hardest to observe: a retention
/// rule that fires after fourteen days, and a ceiling that only matters once
/// half a gigabyte has been written. Testing either against a real disk means
/// either waiting or filling it. Here they are arithmetic over a list of
/// `(day, sequence, byteCount)`, so both are ordinary tests.
///
/// The order is deliberate and the reason is the difference between a preference
/// and a promise: **retention runs first, then the ceiling.** Retention is what
/// the user asked for; the ceiling is what the application guarantees regardless.
/// Running the ceiling first would delete files the user wanted kept while files
/// they had already asked to expire sat there taking up room.
public enum RecordingPolicy {

    /// Files to delete, oldest first, and why the ceiling had to act.
    public struct Pruning: Sendable, Equatable {
        public let expired: [RecordingFile]
        public let overCeiling: [RecordingFile]

        public var all: [RecordingFile] { expired + overCeiling }

        /// True when the ceiling deleted something retention would have kept.
        ///
        /// This is the state the interface surfaces: retention deleting a
        /// fortnight-old file is the setting working, but the ceiling deleting a
        /// file the user asked to keep is data loss they chose without
        /// necessarily realising, and they should be able to see it.
        public var ceilingHadToAct: Bool { !overCeiling.isEmpty }
    }

    /// Decides which files to delete.
    ///
    /// `now` and the calendar are parameters rather than ambient state — a
    /// retention rule tested against `Date()` is a test that behaves differently
    /// on the last day of a month.
    public static func prune(
        files: [RecordingFile],
        settings: RecordingSettings,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> Pruning {
        let ordered = files.sorted {
            ($0.day, $0.sequence) < ($1.day, $1.sequence)
        }

        // Retention, in whole days: a file for today is age 0 and can never
        // expire, whatever retention is set to. Deleting the file currently
        // being written would be a bug the ceiling below has to be careful about
        // too.
        let today = calendar.startOfDay(for: now)
        var expired: [RecordingFile] = []
        var surviving: [RecordingFile] = []
        for file in ordered {
            let age = calendar.dateComponents([.day], from: file.day, to: today).day ?? 0
            if age >= settings.retentionDays {
                expired.append(file)
            } else {
                surviving.append(file)
            }
        }

        // The ceiling, over what retention left. Oldest first, and **never the
        // newest file**: that is the one being appended to, and deleting it
        // would lose the sample being written and leave the writer holding a
        // handle to nothing. A ceiling small enough to demand it is a
        // misconfiguration the type's lower bound already prevents.
        var total = surviving.reduce(0) { $0 + $1.byteCount }
        var overCeiling: [RecordingFile] = []
        var index = 0
        while total > settings.diskCeilingBytes, index < surviving.count - 1 {
            overCeiling.append(surviving[index])
            total -= surviving[index].byteCount
            index += 1
        }

        return Pruning(expired: expired, overCeiling: overCeiling)
    }

    /// Which file the next record belongs in.
    ///
    /// Rotates on two conditions, and the document names both: a new **day**, or
    /// the current file passing `maximumFileBytes`.
    public static func destination(
        existing: [RecordingFile],
        settings: RecordingSettings,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> RecordingFile {
        let today = calendar.startOfDay(for: now)
        let todaysFiles = existing.filter { calendar.isDate($0.day, inSameDayAs: today) }

        guard let latest = todaysFiles.max(by: { $0.sequence < $1.sequence }) else {
            return RecordingFile(day: today, sequence: 0, byteCount: 0)
        }
        guard latest.byteCount >= settings.maximumFileBytes else {
            return latest
        }
        return RecordingFile(day: today, sequence: latest.sequence + 1, byteCount: 0)
    }
}
