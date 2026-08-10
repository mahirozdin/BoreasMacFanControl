import Core
import Foundation

/// `boreas export` and `boreas import` (P7.04).
///
/// Both go through **`Core`'s validating loader**, which is the whole point of
/// having one: a file this command writes must be a file the application will
/// read, and a file it accepts must be one the application would accept. A CLI
/// that could install a configuration the app then refused would be a CLI that
/// breaks the app from the outside, and the user would have no way to tell which
/// of the two was wrong.
enum ConfigCommands {

    // MARK: - Export

    static func export(arguments: [String]) -> Int32 {
        guard let source = ProfileCommand.configurationURL() else {
            writeError("cannot resolve the application support directory\n")
            return 1
        }
        guard let configuration = ProfileCommand.loadedConfiguration() else {
            writeError(
                """
                no readable configuration at \(source.lastPathComponent).
                start the app once to write one.

                """)
            return 1
        }

        // Re-encoded from the loaded model rather than copied byte for byte.
        // Copying would carry across anything the loader had corrected — a
        // clamped panic threshold, a migrated field — so the file on the way out
        // would disagree with the settings actually in force.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(configuration) else {
            writeError("cannot encode the configuration\n")
            return 1
        }

        guard let destination = destinationURL(arguments: arguments) else {
            // No path given: to standard output, so it can be piped.
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            return 0
        }
        do {
            try data.write(to: destination)
            write("exported \(data.count) bytes to \(destination.lastPathComponent)\n")
            return 0
        } catch {
            writeError("cannot write \(destination.lastPathComponent): \(error)\n")
            return 1
        }
    }

    // MARK: - Import

    static func importConfiguration(arguments: [String]) -> Int32 {
        guard let source = destinationURL(arguments: arguments) else {
            writeError("usage: boreas import <file>\n")
            return 1
        }
        guard let data = try? Data(contentsOf: source) else {
            writeError("cannot read \(source.lastPathComponent)\n")
            return 1
        }

        // Validated **before** anything is written. The loader reports the field
        // at fault (G6), and passing that on is the difference between "your file
        // is wrong" and a user guessing.
        let outcome = ConfigurationLoader.load(candidate: data)
        if let problem = outcome.problem {
            writeError(
                """
                \(source.lastPathComponent) was refused, and nothing was changed.
                  field : \(problem.fieldPath)
                  detail: \(problem.detail)

                """)
            return 1
        }
        if let from = outcome.migratedFromVersion {
            write("migrated from schema version \(from)\n")
        }

        guard let destination = ProfileCommand.configurationURL() else {
            writeError("cannot resolve the application support directory\n")
            return 1
        }

        // The existing file is kept beside the new one, under the same name the
        // application's own store uses — so a user who imports the wrong file has
        // the previous one to go back to, and it is where they would already look.
        let backup = destination.deletingLastPathComponent()
            .appendingPathComponent("config.backup.json")
        if let existing = try? Data(contentsOf: destination) {
            try? existing.write(to: backup)
        }

        // Written from the **loaded model**, so what lands on disk is exactly
        // what the application will act on — clamped values and all — rather
        // than the user's original text.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let normalized = try? encoder.encode(outcome.configuration) else {
            writeError("cannot encode the imported configuration\n")
            return 1
        }
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try normalized.write(to: destination)
        } catch {
            writeError("cannot write the configuration: \(error)\n")
            return 1
        }

        write(
            """
            imported \(outcome.configuration.profiles.count) profile(s).
            the previous configuration is at \(backup.lastPathComponent).
            a running app keeps its current settings until it is restarted.

            """)
        return 0
    }

    // MARK: - Install

    /// Delegates to the application, which owns the helper's registration.
    ///
    /// Not reimplemented here, and that is deliberate: `SMAppService` registers a
    /// helper **on behalf of a bundle**, so a command line tool doing it itself
    /// would either fail or register something the app does not know about. The
    /// app already answers `--register-helper`; asking it is the honest path.
    static func install() -> Int32 {
        guard let app = AppBundle.locate() else {
            writeError(
                """
                cannot find the application. Fan control is installed by the app,
                which owns the helper's registration.

                """)
            return 1
        }
        write("app      : \(app.bundleURL.path)\n")
        let before = app.run(argument: "--helper-status") ?? "no answer"
        write("before   : \(before)\n")
        if before.contains("enabled") {
            write("helper   : already installed, nothing to do\n")
            return 0
        }
        guard let answer = app.run(argument: "--register-helper") else {
            writeError("the app did not answer\n")
            return 1
        }
        write("helper   : \(answer.replacingOccurrences(of: "\n", with: " · "))\n")
        // An administrator prompt appears once, and only for this (I3). If the
        // user declines, that is a refusal rather than a failure of the tool.
        return answer.contains("failed") ? 1 : 0
    }

    // MARK: - Helpers

    private static func destinationURL(arguments: [String]) -> URL? {
        guard let path = arguments.first(where: { !$0.hasPrefix("-") }) else { return nil }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    private static func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    private static func writeError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }
}
