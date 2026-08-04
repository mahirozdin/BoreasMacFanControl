import CoreServices
import Foundation
import SharedIPC

/// Removes everything the product ever put on the machine.
///
/// `SMAppService` resolves the daemon plist against the *calling* process's
/// bundle, so a bare command line tool cannot unregister the helper itself.
/// The command therefore locates the installed application and runs its
/// maintenance entry point, then removes the user data directory when asked.
///
/// The registration is the only system-side record: `SMAppService` copies
/// nothing into `/Library`, so once it is gone there is no file left to hunt
/// down (see `docs/architecture/privilege-model.md`).
enum UninstallCommand {

    /// - Parameter removeUserData: also delete the application support
    ///   directory (`--all`).
    static func run(removeUserData: Bool) -> Int32 {
        guard let app = AppBundle.locate() else {
            FileHandle.standardError.write(
                Data(
                    """
                    cannot find the application for \(BoreasIPC.clientBundleIdentifier).
                    If the app is already gone but the helper entry survives, switch it
                    off under System Settings > General > Login Items & Extensions.

                    """.utf8))
            return 1
        }

        var output = "app      : \(app.bundleURL.path)\n"
        var failed = false

        // Asking first keeps the command idempotent: removing an absent
        // helper is a success, not an error worth a nonzero exit.
        let statusBefore = app.run(argument: "--helper-status") ?? "no answer"
        output += "before   : \(statusBefore)\n"

        if statusBefore.contains("not registered") || statusBefore.contains("not found") {
            output += "helper   : nothing registered, nothing to remove\n"
        } else if let answer = app.run(argument: "--unregister-helper") {
            output += "helper   : \(answer.replacingOccurrences(of: "\n", with: " · "))\n"
            failed = answer.contains("failed")
        } else {
            output += "helper   : the app did not answer\n"
            failed = true
        }

        if removeUserData {
            output += removeSupportDirectory(for: app)
        }

        FileHandle.standardOutput.write(Data(output.utf8))
        return failed ? 1 : 0
    }

    /// Deletes `~/Library/Application Support/<app name>` if it exists.
    ///
    /// The directory name comes from the located bundle at runtime — the
    /// product name is never hard-coded (invariant K2).
    private static func removeSupportDirectory(for app: AppBundle) -> String {
        guard
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first,
            let name = app.displayName
        else {
            return "userdata : cannot resolve the application support directory\n"
        }

        let directory = support.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return "userdata : \(directory.path) — not present\n"
        }

        do {
            try FileManager.default.removeItem(at: directory)
            return "userdata : removed \(directory.path)\n"
        } catch {
            return "userdata : cannot remove \(directory.path): \(error)\n"
        }
    }
}

/// The installed application, found through Launch Services.
struct AppBundle {

    let bundleURL: URL
    private let executableURL: URL

    var displayName: String? {
        let bundle = Bundle(url: bundleURL)
        return bundle?.infoDictionary?["CFBundleName"] as? String
    }

    /// Finds the app by bundle identifier. Prefers a copy under
    /// `/Applications`; a development build in DerivedData is accepted so the
    /// command works before the app is ever "installed" properly.
    static func locate() -> AppBundle? {
        let identifier = BoreasIPC.clientBundleIdentifier as CFString
        guard
            let urls = LSCopyApplicationURLsForBundleIdentifier(identifier, nil)?
                .takeRetainedValue() as? [URL],
            !urls.isEmpty
        else { return nil }

        let preferred =
            urls.first { $0.path.hasPrefix("/Applications/") } ?? urls[0]
        return AppBundle(bundleURL: preferred)
    }

    init?(bundleURL: URL) {
        guard
            let bundle = Bundle(url: bundleURL),
            let executable = bundle.executableURL,
            FileManager.default.isExecutableFile(atPath: executable.path)
        else { return nil }
        self.bundleURL = bundleURL
        self.executableURL = executable
    }

    /// Runs the app binary with one maintenance flag and returns its output.
    /// The app handles these flags before any interface exists and exits, so
    /// this never leaves a stray menu bar item behind.
    func run(argument: String) -> String? {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [argument]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let decoded = String(bytes: data, encoding: .utf8) else { return nil }
        let text = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
