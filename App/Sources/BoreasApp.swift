import AppKit
import Foundation
import SwiftUI

/// Command line entry points used to exercise the privileged helper without
/// driving the interface.
///
/// These exist because registering a root daemon is a step that has to be
/// *proved*, not assumed, and proving it needs a reproducible command rather
/// than a button somebody remembers to press.
@MainActor
enum HelperCommands {

    static func handleIfPresent() -> Bool {
        let arguments = CommandLine.arguments
        let installer = HelperInstaller()

        func report(_ text: String) {
            FileHandle.standardOutput.write(Data((text + "\n").utf8))
        }

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

        if let index = arguments.firstIndex(of: "--render-setup"), index + 1 < arguments.count {
            renderSetupEvidence(into: URL(fileURLWithPath: arguments[index + 1], isDirectory: true))
            return true
        }

        if arguments.contains("--helper-ping") {
            pingHelper(report: report)
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

    /// Renders the setup window in every phase to PNG files.
    ///
    /// Screenshots would need the screen recording permission, which this
    /// project promises never to ask for (invariant I2). Rendering the view
    /// directly produces the same evidence without any permission, and it is
    /// deterministic, which a screenshot never is.
    private static func renderSetupEvidence(into directory: URL) {
        let phases: [(name: String, phase: HelperSetupModel.Phase)] = [
            ("1-before-install", .idle),
            ("2-awaiting-approval", .awaitingApproval),
            ("3-verifying", .verifying),
            ("4-ready", .ready(fanCount: 1)),
            ("5-removed", .removed),
            ("6-failed", .failed("Operation not permitted")),
        ]

        func report(_ text: String) {
            FileHandle.standardOutput.write(Data((text + "\n").utf8))
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            report("cannot create \(directory.path): \(error)")
            return
        }

        for entry in phases {
            let view = HelperSetupView(
                model: HelperSetupModel(), fixedPhaseForRendering: entry.phase)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2

            guard let cgImage = renderer.cgImage,
                let data = NSBitmapImageRep(cgImage: cgImage)
                    .representation(using: .png, properties: [:])
            else {
                report("render failed: \(entry.name)")
                continue
            }

            let url = directory.appendingPathComponent("setup-\(entry.name).png")
            do {
                try data.write(to: url)
                report("wrote \(url.path)")
            } catch {
                report("write failed for \(entry.name): \(error)")
            }
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

    init() {
        // Handled before any window exists so the commands can run from a
        // terminal without the menu bar item appearing.
        if MainActor.assumeIsolated({ HelperCommands.handleIfPresent() }) {
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model, setup: setup)
                .task { model.start() }
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

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
