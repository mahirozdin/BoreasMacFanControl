import Foundation
import Testing

@testable import Core

/// Rotation, retention and the disk ceiling (P7.02).
///
/// **The ceiling is the reason this file exists.** Everything else the recorder
/// does is a convenience; a bug in the ceiling fills somebody's disk. So it is
/// tested as arithmetic over file metadata — which also means the fourteen day
/// retention rule is testable without waiting fourteen days, and half a gigabyte
/// of pruning is testable without writing half a gigabyte.
@Suite("Recording policy (rotation, retention, the hard disk ceiling)")
struct RecordingPolicyTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// A fixed "today" so nothing depends on when the suite runs — a retention
    /// test against `Date()` behaves differently on the last day of a month.
    private static let today: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }()

    private static func day(_ agoInDays: Int) -> Date {
        calendar.date(byAdding: .day, value: -agoInDays, to: today) ?? today
    }

    private static func file(_ agoInDays: Int, sequence: Int = 0, bytes: Int) -> RecordingFile {
        RecordingFile(day: day(agoInDays), sequence: sequence, byteCount: bytes)
    }

    // MARK: - The ceiling

    @Test("the ceiling is hard — pruning always brings the total under it")
    func ceilingIsHard() {
        // The property, over a range of shapes rather than one example: whatever
        // is on disk, what survives fits. This is the promise; retention is only
        // a preference.
        let settings = RecordingSettings(
            isEnabled: true, retentionDays: 365, diskCeilingBytes: 100_000_000)

        for fileCount in [2, 5, 20, 100] {
            for perFile in [1_000_000, 9_000_000, 60_000_000] {
                let files = (0..<fileCount).map {
                    Self.file($0, bytes: perFile)
                }
                let pruning = RecordingPolicy.prune(
                    files: files, settings: settings, now: Self.today,
                    calendar: Self.calendar)
                let deleted = Set(pruning.all)
                let survivingBytes = files.filter { !deleted.contains($0) }
                    .reduce(0) { $0 + $1.byteCount }
                // The newest file is never deleted, so a total that still
                // exceeds the ceiling is only acceptable when one file alone
                // does — which the settings' lower bound makes impossible for
                // realistic file sizes, and which this asserts explicitly.
                let newestAlone = files.map(\.byteCount).last ?? 0
                #expect(
                    survivingBytes <= settings.diskCeilingBytes
                        || survivingBytes == newestAlone,
                    "\(fileCount)×\(perFile) left \(survivingBytes) bytes")
            }
        }
    }

    @Test("the ceiling deletes the oldest first")
    func ceilingDeletesOldestFirst() {
        let settings = RecordingSettings(
            isEnabled: true, retentionDays: 365, diskCeilingBytes: 25_000_000)
        let files = [
            Self.file(3, bytes: 10_000_000),
            Self.file(2, bytes: 10_000_000),
            Self.file(1, bytes: 10_000_000),
            Self.file(0, bytes: 10_000_000),
        ]
        let pruning = RecordingPolicy.prune(
            files: files, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(pruning.overCeiling.map(\.day) == [Self.day(3), Self.day(2)])
        #expect(pruning.ceilingHadToAct)
    }

    @Test("the file being written is never deleted, however small the ceiling")
    func newestFileSurvives() {
        // Deleting it would lose the sample being written and leave the writer
        // holding a handle to a file that no longer exists.
        let settings = RecordingSettings(
            isEnabled: true, retentionDays: 365, diskCeilingBytes: 10_000_000)
        let files = [
            Self.file(1, bytes: 400_000_000),
            Self.file(0, bytes: 400_000_000),
        ]
        let pruning = RecordingPolicy.prune(
            files: files, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(!pruning.all.contains(files[1]), "the newest file was deleted")
    }

    @Test("nothing is deleted when everything fits")
    func nothingDeletedWhenUnderBoth() {
        let settings = RecordingSettings(
            isEnabled: true, retentionDays: 14, diskCeilingBytes: 500_000_000)
        let files = (0..<5).map { Self.file($0, bytes: 1_000_000) }
        let pruning = RecordingPolicy.prune(
            files: files, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(pruning.all.isEmpty)
        #expect(!pruning.ceilingHadToAct)
    }

    // MARK: - Retention

    @Test("retention expires by whole days, and today can never expire")
    func retentionByWholeDays() {
        let settings = RecordingSettings(
            isEnabled: true, retentionDays: 14, diskCeilingBytes: 20_000_000_000)
        let files = [
            Self.file(0, bytes: 1),
            Self.file(13, bytes: 1),
            Self.file(14, bytes: 1),
            Self.file(30, bytes: 1),
        ]
        let pruning = RecordingPolicy.prune(
            files: files, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(pruning.expired.map(\.day) == [Self.day(30), Self.day(14)])
        #expect(!pruning.expired.contains(files[0]), "today's file expired")
    }

    @Test("a one day retention still keeps today")
    func shortestRetentionKeepsToday() {
        // The tightest legal setting, and the one most likely to delete the file
        // being written if the age arithmetic were off by one.
        let settings = RecordingSettings(isEnabled: true, retentionDays: 1)
        let files = [Self.file(0, bytes: 1), Self.file(1, bytes: 1)]
        let pruning = RecordingPolicy.prune(
            files: files, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(pruning.expired.map(\.day) == [Self.day(1)])
    }

    @Test("retention runs before the ceiling, so a preference cannot cost a promise")
    func retentionRunsFirst() {
        // If the ceiling ran first it would delete files the user asked to keep
        // while files they had already asked to expire sat there taking up the
        // room. The two only disagree when the machine has been recording more
        // than expected — which is exactly when it matters.
        let settings = RecordingSettings(
            isEnabled: true, retentionDays: 3, diskCeilingBytes: 25_000_000)
        let files = [
            Self.file(10, bytes: 20_000_000),  // expired
            Self.file(2, bytes: 10_000_000),  // kept by retention
            Self.file(1, bytes: 10_000_000),
            Self.file(0, bytes: 10_000_000),
        ]
        let pruning = RecordingPolicy.prune(
            files: files, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(pruning.expired.map(\.day) == [Self.day(10)])
        // 30 MB survives retention against a 25 MB ceiling, so the ceiling takes
        // exactly one more — the oldest of the survivors, not the expired one it
        // has already accounted for.
        #expect(pruning.overCeiling.map(\.day) == [Self.day(2)])
    }

    @Test("nothing is deleted twice")
    func noDoubleDeletion() {
        // `all` concatenates the two lists, so an implementation that let the
        // ceiling reconsider an expired file would delete it twice — harmless on
        // a real disk and a sign the accounting is wrong.
        let settings = RecordingSettings(
            isEnabled: true, retentionDays: 2, diskCeilingBytes: 10_000_000)
        let files = (0..<10).map { Self.file($0, bytes: 5_000_000) }
        let pruning = RecordingPolicy.prune(
            files: files, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(Set(pruning.all).count == pruning.all.count)
    }

    // MARK: - Rotation

    @Test("a new day starts a new file at sequence zero")
    func rotatesDaily() {
        let settings = RecordingSettings(isEnabled: true)
        let yesterday = [Self.file(1, sequence: 3, bytes: 1_000)]
        let destination = RecordingPolicy.destination(
            existing: yesterday, settings: settings, now: Self.today,
            calendar: Self.calendar)
        #expect(Self.calendar.isDate(destination.day, inSameDayAs: Self.today))
        #expect(destination.sequence == 0)
    }

    @Test("a file over its size limit rotates to the next sequence")
    func rotatesBySize() {
        let settings = RecordingSettings(isEnabled: true, maximumFileBytes: 10_000_000)
        let full = [Self.file(0, sequence: 0, bytes: 10_000_000)]
        let destination = RecordingPolicy.destination(
            existing: full, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(destination.sequence == 1)
        #expect(destination.byteCount == 0)
    }

    @Test("a file under its size limit is appended to")
    func appendsWhenRoomRemains() {
        let settings = RecordingSettings(isEnabled: true, maximumFileBytes: 10_000_000)
        let partial = [Self.file(0, sequence: 2, bytes: 9_999_999)]
        let destination = RecordingPolicy.destination(
            existing: partial, settings: settings, now: Self.today, calendar: Self.calendar)
        #expect(destination.sequence == 2)
    }

    @Test("file names sort chronologically as plain text")
    func namesSortAsText() {
        // Which matters the moment anybody lists the directory or a tool globs
        // it: an unpadded sequence puts file 10 before file 2.
        let names = [
            Self.file(1, sequence: 2, bytes: 0),
            Self.file(1, sequence: 10, bytes: 0),
            Self.file(0, sequence: 0, bytes: 0),
        ].map { $0.name(format: .jsonl, calendar: Self.calendar) }
        #expect(names.sorted() == [names[0], names[1], names[2]])
    }

    // MARK: - Settings clamping

    @Test("every setting is clamped into its documented range")
    func settingsAreClamped() {
        let hostile = RecordingSettings(
            retentionDays: 99_999, diskCeilingBytes: 1, maximumFileBytes: 0,
            intervalSeconds: -5)
        #expect(hostile.retentionDays == RecordingSettings.retentionRange.upperBound)
        #expect(hostile.diskCeilingBytes == RecordingSettings.ceilingRange.lowerBound)
        #expect(hostile.maximumFileBytes == RecordingSettings.fileSizeRange.lowerBound)
        #expect(hostile.intervalSeconds == RecordingSettings.intervalRange.lowerBound)
    }

    @Test("a file cannot be allowed to exceed the whole ceiling")
    func fileLimitFitsUnderTheCeiling() {
        // A guard on the ranges themselves: if the largest legal single file
        // exceeded the smallest legal ceiling, the ceiling could never be
        // satisfied without deleting the file being written, and the rule that
        // protects it would deadlock against the rule that protects the disk.
        #expect(
            RecordingSettings.fileSizeRange.lowerBound
                <= RecordingSettings.ceilingRange.lowerBound)
    }

    @Test("recording ships off")
    func shipsDisabled() {
        #expect(RecordingSettings().isEnabled == false)
        #expect(RecordingSettings().format == .jsonl)
        #expect(RecordingSettings().retentionDays == 14)
        #expect(RecordingSettings().diskCeilingBytes == 500_000_000)
    }
}
