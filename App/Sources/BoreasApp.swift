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

        if arguments.contains("--helper-ping") {
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
            return true
        }

        return false
    }
}

/// Menu bar entry point.
///
/// Boreas runs as an `LSUIElement` app: no Dock icon, no window on launch.
/// Reading temperatures needs no privileges, so the monitor starts immediately
/// whether or not the privileged helper is ever installed (invariant İ4).
@main
struct BoreasApp: App {

    @State private var model = MonitorModel()

    init() {
        // Handled before any window exists so the commands can run from a
        // terminal without the menu bar item appearing.
        if MainActor.assumeIsolated({ HelperCommands.handleIfPresent() }) {
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model)
                .task { model.start() }
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
