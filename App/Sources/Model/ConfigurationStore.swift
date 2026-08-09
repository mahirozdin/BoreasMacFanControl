import AppKit
import Core
import Foundation
import OSLog
import Observation

/// Reads and writes `~/Library/Application Support/Boreas/config.json`
/// (P6.08).
///
/// `Core.ConfigurationLoader` already decides *what* a candidate document
/// means — including the G6 rule that a broken file can only ever fall back
/// to the last valid one. This type does the part `Core` must not: touching
/// the disk. It contributes no policy, so a broken configuration behaves the
/// same here as it does in the tests.
@MainActor
@Observable
public final class ConfigurationStore {

    public private(set) var configuration: ConfigurationFile = .standard

    /// Non-nil when the file on disk was refused. The interface shows it
    /// and keeps running on the last valid configuration — a corrupt file
    /// is a message, not a crash.
    public private(set) var problem: ConfigurationProblem?

    /// Set once when an older document was upgraded on load, so the
    /// interface can say so rather than silently rewriting a user's file.
    public private(set) var migratedFromVersion: Int?

    /// Non-nil when a write failed. Recorded rather than swallowed: a
    /// settings window that appears to save and does not is a bug the user
    /// finds out about at the worst possible moment.
    public private(set) var writeProblem: String?

    private let directory: URL
    private var saveTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "config")

    /// Writes are coalesced: a slider drag would otherwise rewrite the file
    /// sixty times a second.
    private static let writeDelay: Duration = .milliseconds(600)

    public var fileURL: URL { directory.appendingPathComponent("config.json") }
    public var backupURL: URL { directory.appendingPathComponent("config.backup.json") }

    public init(directory: URL? = nil) {
        self.directory =
            directory
            ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Boreas", isDirectory: true)
    }

    /// Writes anything still pending before the process goes away.
    ///
    /// Found by the P6.14 drill, which read a second store immediately
    /// after a change and saw the old file: the write is coalesced by 600
    /// ms, so a setting changed and then followed by a quit was simply
    /// lost. Coalescing is still right — a slider drag must not rewrite the
    /// file sixty times a second — but it needs an exit that flushes.
    func flushOnTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.save(immediately: true) }
        }
    }

    // MARK: - Loading

    /// Reads the file if there is one. A machine with no configuration is
    /// the normal first run, not an error: the defaults are a complete,
    /// valid configuration.
    public func load() {
        let candidate = try? Data(contentsOf: fileURL)
        if candidate == nil {
            // First run: write the defaults out. The settings window points
            // at this path and the documentation invites hand editing, so a
            // path that names nothing would be an invitation to a file that
            // does not exist.
            save(immediately: true)
        }
        let outcome = ConfigurationLoader.load(candidate: candidate, lastValid: configuration)
        configuration = outcome.configuration
        problem = outcome.problem
        migratedFromVersion = outcome.migratedFromVersion

        if let problem {
            let summary = "\(problem.fieldPath): \(problem.detail)"
            logger.error("configuration refused at \(summary, privacy: .public)")
        }
        if let from = outcome.migratedFromVersion, let original = outcome.backupOfOriginal {
            // The pre-migration bytes are kept before the upgraded document
            // replaces them — a migration nobody can undo is a migration
            // nobody should trust.
            writeBackup(original)
            logger.notice("configuration migrated from version \(from, privacy: .public)")
            save(immediately: true)
        }
    }

    // MARK: - Changing

    /// The only way to change the configuration: mutate and schedule a
    /// write. Every setting goes through here, so nothing can be changed
    /// without also being saved.
    public func update(_ transform: (inout ConfigurationFile) -> Void) {
        var edited = configuration
        transform(&edited)
        guard edited != configuration else { return }
        configuration = edited
        save()
    }

    public func resetToDefaults() {
        configuration = .standard
        problem = nil
        save(immediately: true)
    }

    // MARK: - Writing

    public func save(immediately: Bool = false) {
        saveTask?.cancel()
        guard !immediately else {
            writeNow()
            return
        }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.writeDelay)
            guard !Task.isCancelled else { return }
            self?.writeNow()
        }
    }

    private func writeNow() {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)

            // Backup first, then an atomic replace: at no instant is the
            // only copy of a user's configuration a half written file.
            if let existing = try? Data(contentsOf: fileURL) {
                writeBackup(existing)
            }
            try data.write(to: fileURL, options: .atomic)
            writeProblem = nil
        } catch {
            writeProblem = String(describing: error)
            logger.error(
                "configuration write failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func writeBackup(_ data: Data) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try data.write(to: backupURL, options: .atomic)
        } catch {
            logger.error(
                "configuration backup failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Export and import

    public func export(to url: URL) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(configuration).write(to: url, options: .atomic)
            return true
        } catch {
            writeProblem = String(describing: error)
            return false
        }
    }

    /// Imports a document through exactly the same loader the startup path
    /// uses — including migration — so an imported file cannot reach a
    /// state a loaded one could not.
    @discardableResult
    public func importFrom(_ url: URL) -> Bool {
        guard let candidate = try? Data(contentsOf: url) else {
            problem = ConfigurationProblem(fieldPath: "-", detail: "the file could not be read")
            return false
        }
        let outcome = ConfigurationLoader.load(candidate: candidate, lastValid: configuration)
        guard outcome.problem == nil else {
            problem = outcome.problem
            return false
        }
        configuration = outcome.configuration
        problem = nil
        migratedFromVersion = outcome.migratedFromVersion
        save(immediately: true)
        return true
    }
}
