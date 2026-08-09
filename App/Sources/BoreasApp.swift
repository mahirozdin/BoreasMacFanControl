import AppKit
import Core
import Foundation
import HardwareKit
import SharedIPC
import SwiftUI

/// Command line entry points used to exercise the privileged helper without
/// driving the interface.
///
/// These exist because registering a root daemon is a step that has to be
/// *proved*, not assumed, and proving it needs a reproducible command rather
/// than a button somebody remembers to press. The hardware evidence drills
/// live in `HardwareDrills`.
@MainActor
enum HelperCommands {

    static func handleIfPresent() -> Bool {
        handleMaintenance() || handleRenders() || handleDrills()
    }

    /// The render evidence arguments, kept apart from the helper
    /// maintenance ones: they are the project's camera, and folding them
    /// into the same switch pushed it past the complexity budget.
    private static func handleRenders() -> Bool {
        let arguments = CommandLine.arguments
        let commands: [(flag: String, run: (URL) -> Void)] = [
            ("--render-setup", RenderEvidence.setup),
            ("--render-design", RenderEvidence.design),
            ("--render-panel", RenderEvidence.panel),
            ("--render-status", RenderEvidence.status),
            ("--render-window", RenderEvidence.window),
        ]
        for command in commands {
            if let index = arguments.firstIndex(of: command.flag), index + 1 < arguments.count {
                command.run(URL(fileURLWithPath: arguments[index + 1], isDirectory: true))
                return true
            }
        }
        return false
    }

    private static func report(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }

    private static func handleMaintenance() -> Bool {
        let arguments = CommandLine.arguments
        let installer = HelperInstaller()

        if arguments.contains("--helper-status") {
            report("helper status: \(installer.state.summary)")
            return true
        }

        if arguments.contains("--register-helper") {
            report("registering the privileged helper…")
            if let failure = installer.register() {
                report("failed: \(failure)")
            } else {
                report("registered")
            }
            report("helper status: \(installer.state.summary)")
            return true
        }

        if arguments.contains("--unregister-helper") {
            if let failure = installer.unregister() {
                report("failed: \(failure)")
            } else {
                report("removed")
            }
            report("helper status: \(installer.state.summary)")
            return true
        }

        if let index = arguments.firstIndex(of: "--crowd-menubar"), index + 1 < arguments.count {
            crowdMenuBar(seconds: Double(arguments[index + 1]) ?? 10)
            return true
        }

        return false
    }

    /// Floods the menu bar with throwaway status items so the running app
    /// instance's visibility probe can be watched detecting a real squeeze.
    /// The items die with this process; the bar heals itself.
    private static func crowdMenuBar(seconds: Double) {
        var items: [NSStatusItem] = []
        for _ in 0..<40 {
            let item = NSStatusBar.system.statusItem(withLength: 80)
            item.button?.title = "▮▮▮▮"
            items.append(item)
        }
        report("crowding the menu bar with \(items.count) items for \(Int(seconds))s")
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        items.removeAll()
        report("crowding done, items removed")
    }

    private static func handleDrills() -> Bool {
        let arguments = CommandLine.arguments

        if arguments.contains("--helper-ping") {
            pingHelper(report: report)
            return true
        }
        if arguments.contains("--pump-heartbeats") {
            HardwareDrills.pumpHeartbeats(report: report)
            return true
        }
        if arguments.contains("--helper-release") {
            HardwareDrills.releaseThreeTimes(report: report)
            return true
        }
        if arguments.contains("--fan-keys") {
            HardwareDrills.dumpFanKeys(report: report)
            return true
        }
        if arguments.contains("--takeover-drill") {
            HardwareDrills.takeoverDrill(report: report)
            return true
        }
        if arguments.contains("--fan-state") {
            HardwareDrills.printFanState(report: report)
            return true
        }
        if arguments.contains("--control-drill") {
            HardwareDrills.controlDrill(report: report)
            return true
        }
        if arguments.contains("--profile-drill") {
            HardwareDrills.profileDrill(report: report)
            return true
        }
        if arguments.contains("--override-drill") {
            HardwareDrills.overrideDrill(report: report)
            return true
        }

        return false
    }

    private static func pingHelper(report: (String) -> Void) {
        // The result is produced inside the task and printed there. An
        // outer `var` captured by the closure is not sendable, and making
        // it sendable would only be working around the fact that the value
        // belongs to the task in the first place.
        let semaphore = DispatchSemaphore(value: 0)
        // Detached is required, not stylistic: a plain `Task` would inherit
        // this main actor context and could never run while the semaphore
        // below blocks the main thread.
        Task.detached {
            var lines: [String] = []
            do {
                let client = HelperClient()
                let answered = try await client.ping()
                lines.append(
                    answered
                        ? "helper answered, signatures matched on both sides"
                        : "nonce mismatch"
                )
                let fans = try await client.describeFans()
                lines.append("helper sees \(fans.count) fan(s)")
                for fan in fans {
                    lines.append(
                        "  fan \(fan.id): \(fan.currentRPM) rpm "
                            + "(\(fan.minimumRPM)-\(fan.maximumRPM))"
                    )
                }
            } catch {
                lines.append("failed: \(error)")
            }
            FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 20) == .timedOut {
            report("timed out waiting for the helper")
        }
    }

}

/// Menu bar entry point.
///
/// Boreas runs as an `LSUIElement` app: no Dock icon, no window on launch.
/// Reading temperatures needs no privileges, so the monitor starts immediately
/// whether or not the privileged helper is ever installed (invariant I4).
@main
struct BoreasApp: App {

    @State private var model = MonitorModel()
    @State private var setup = HelperSetupModel()
    @State private var control: ControlModel
    @State private var visibility = StatusItemVisibilityModel()

    init() {
        let monitor = MonitorModel()
        _model = State(initialValue: monitor)
        _control = State(initialValue: ControlModel(monitor: monitor))
        // Handled before any window exists so the commands can run from a
        // terminal without the menu bar item appearing.
        if MainActor.assumeIsolated({ HelperCommands.handleIfPresent() }) {
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model, setup: setup, control: control)
        } label: {
            // The label is on screen from launch, so sampling starts here —
            // the status item shows live numbers before the panel is ever
            // opened, and the loop never depends on the panel being open.
            MenuBarLabel(model: model, control: control)
                .task {
                    model.start()
                    // The visibility monitor lives at app level: the label
                    // itself is rendered to an image by MenuBarExtra, so
                    // nothing inside it can ever measure a window.
                    visibility.beginMonitoring()
                }
        }
        .menuBarExtraStyle(.window)

        Window(
            String(
                localized: "window.main.title",
                defaultValue: "Boreas",
                comment: "Title of the main window"
            ),
            id: MainWindow.windowID
        ) {
            MainWindow(model: model, control: control, setup: setup)
        }
        .defaultPosition(.center)

        Window(
            String(
                localized: "setup.window.title",
                defaultValue: "Fan Control",
                comment: "Title of the fan control setup window"
            ),
            id: HelperSetupView.windowID
        ) {
            HelperSetupView(model: setup)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
