import Core
import Foundation
import OSLog

/// Runs a user's own command when a hook fires.
///
/// **Three things about privilege, because this is the riskiest feature in the
/// product.**
///
/// 1. It runs here, in the application, with **the user's own privileges**.
///    The daemon is the only thing on this machine running as root and it
///    spawns no subprocess at all — `make gate-daemon` fails the build if it
///    ever tries. There is no path from a hook to root.
/// 2. Arguments are passed as **argv, never through a shell**. `Process` takes
///    an array, so a template expanding to `; rm -rf ~` arrives as one literal
///    argument to the user's script rather than as a second command. There is
///    no shell to inject into.
/// 3. It only runs at all when the user set **two** separate switches, and
///    `AutomationSettings.runnable()` is where that is decided — under test,
///    rather than in this file where it would have to be remembered.
struct CommandRunner {

    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "automation")

    /// Runs the command and waits, up to `timeout`.
    ///
    /// Never throws at the caller: a hook that failed must not disturb fan
    /// control, which is the only thing on this machine that matters.
    func run(path: String, arguments: [String], timeout: Double) async -> String {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.isExecutableFile(atPath: expanded) else {
            // Named as the specific thing that is wrong. "Hook failed" would
            // send somebody looking at their script rather than at its mode.
            logger.error("command hook refused: not an executable file")
            return "refused: not an executable file"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: expanded)
        process.arguments = arguments
        // Output is discarded rather than captured: a hook that printed a
        // megabyte would otherwise be held entirely in memory, and what the
        // user's script says is the user's script's business.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("command hook could not start: \(error.localizedDescription, privacy: .public)")
            return "could not start"
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }

        if process.isRunning {
            // Terminated rather than left behind. A hook that hangs every time
            // would otherwise reach the concurrency limit and stay there,
            // silently disabling automation altogether.
            process.terminate()
            logger.error("command hook timed out after \(timeout, privacy: .public)s")
            return "timed out"
        }

        let status = process.terminationStatus
        logger.notice("command hook exited \(status, privacy: .public)")
        return "exit \(status)"
    }
}
