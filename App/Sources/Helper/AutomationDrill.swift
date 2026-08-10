import Core
import Foundation

/// P7.10 on this machine: the hooks really fire, and the one that can execute
/// code really does not until it is allowed to.
///
/// **The tests in `Core` prove the rules; this proves the runner.** A unit test
/// can assert that `runnable()` withholds a command hook. It cannot assert that
/// no process was spawned — and "no process was spawned" is the property the
/// whole design is built around, so it is checked here against a real script
/// that would leave a real file behind.
///
/// The webhook leg needs somewhere to send to. Pass a local listener's port as
/// `--automation-drill <port>`; without one that leg reports SKIP rather than
/// pretending, because a webhook nobody received proves nothing.
enum AutomationDrill {

    static func run(report: (String) -> Void) {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("boreas-automation-drill", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("fired.txt")
        let script = directory.appendingPathComponent("hook.sh")
        let slowScript = directory.appendingPathComponent("slow.sh")

        // A script that records the arguments it was handed, so the drill can
        // check the expansion as well as the fact that it ran.
        write("#!/bin/sh\nprintf '%s' \"$1\" > \(marker.path)\n", to: script)
        write("#!/bin/sh\nsleep 30\n", to: slowScript)

        let context = AutomationContext(
            kind: .thresholdCrossed, subject: "compute", celsius: 81.6,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000))
        let commandHook = AutomationHook.command(
            path: script.path, arguments: ["${sensor}=${celsius}"])
        let runner = AutomationRunner()

        // ------------------------------------------------------------------
        // The property that matters most: withheld means no process.
        // ------------------------------------------------------------------
        report("    command hook, permission withheld:")
        let withheld = AutomationSettings(
            isEnabled: true, commandHooksAllowed: false, hooks: [commandHook])
        runBlocking { await runner.fire(context, settings: withheld) }
        check(
            "nothing ran — no file was written",
            !FileManager.default.fileExists(atPath: marker.path))

        report("    command hook, permitted:")
        let permitted = AutomationSettings(
            isEnabled: true, commandHooksAllowed: true, hooks: [commandHook])
        runBlocking { await runner.fire(context, settings: permitted) }
        let written = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""
        check("the script ran", !written.isEmpty)
        // The stable identifier, not the localised display name: on this
        // machine running a translated interface the notification shows the
        // translated group name, and the hook must still receive `compute`
        // (P7.10, the P7.14 lesson applied before it could ship).
        check("placeholders expanded to machine-readable values", written == "compute=81.6")
        report("      script received: \(written)")

        // ------------------------------------------------------------------
        // The limits ADR 0015 asks for.
        // ------------------------------------------------------------------
        report("    limits:")
        let slowHook = AutomationHook.command(path: slowScript.path, arguments: [])
        let started = Date()
        let timed = AutomationSettings(
            isEnabled: true, commandHooksAllowed: true, hooks: [slowHook], timeoutSeconds: 2)
        runBlocking { await runner.fire(context, settings: timed) }
        let elapsed = Date().timeIntervalSince(started)
        check("a hanging hook is abandoned near its timeout", elapsed < 8)
        report("      returned after \(String(format: "%.1f", elapsed))s against a 30s sleep")

        passed = webhookLeg(context: context, runner: runner, report: report) && passed

        try? FileManager.default.removeItem(at: directory)
        report(passed ? "AUTOMATION DRILL PASS" : "AUTOMATION DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    /// The webhook leg, split out because it is the only part that needs
    /// somewhere to send to — and because `run` was over the 60-line body limit,
    /// which is the lint rule doing its job.
    private static func webhookLeg(
        context: AutomationContext, runner: AutomationRunner, report: (String) -> Void
    ) -> Bool {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        report("    webhook:")
        if let port = portArgument() {
            let hook = AutomationHook.webhook(
                url: "http://127.0.0.1:\(port)/hook", method: "POST",
                template: "{\"kind\":\"${kind}\",\"sensor\":\"${sensor}\",\"c\":${celsius}}")
            let settings = AutomationSettings(isEnabled: true, hooks: [hook])
            runBlocking { await runner.fire(context, settings: settings) }
            let last = (blockingValue(default: []) { await runner.recent }).last ?? ""
            check("the request reached the listener", last.contains("http 2"))
            report("      \(last)")
        } else {
            report("      SKIP — no listener port given; pass --automation-drill <port>")
        }

        // A webhook to something that is not http is refused rather than tried.
        let bogus = AutomationSettings(
            isEnabled: true,
            hooks: [.webhook(url: "file:///etc/passwd", method: "GET", template: "")])
        runBlocking { await runner.fire(context, settings: bogus) }
        check(
            "a non-http URL is refused",
            ((blockingValue(default: []) { await runner.recent }).last ?? "").contains("refused"))
        return passed
    }

    private static func portArgument() -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--automation-drill"),
            index + 1 < arguments.count,
            Int(arguments[index + 1]) != nil
        else { return nil }
        return arguments[index + 1]
    }

    private static func write(_ contents: String, to url: URL) {
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    /// Runs an async call to completion from this synchronous drill.
    ///
    /// The run loop is pumped while waiting rather than blocking outright: the
    /// runner's work hops through an actor, and a thread parked on a semaphore
    /// would keep it from ever getting there.
    private static func runBlocking(_ work: @escaping @Sendable () async -> Void) {
        let done = DispatchSemaphore(value: 0)
        Task {
            await work(); done.signal()
        }
        while done.wait(timeout: .now() + 0.05) == .timedOut {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private static func blockingValue<T: Sendable>(
        default fallback: T, _ work: @escaping @Sendable () async -> T
    ) -> T {
        let box = Box<T>()
        let done = DispatchSemaphore(value: 0)
        Task {
            box.value = await work(); done.signal()
        }
        while done.wait(timeout: .now() + 0.05) == .timedOut {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return box.value ?? fallback
    }

    private final class Box<T>: @unchecked Sendable {
        var value: T?
    }
}
