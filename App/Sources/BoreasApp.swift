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
        handleMaintenance() || handleDrills()
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

        if let index = arguments.firstIndex(of: "--render-setup"), index + 1 < arguments.count {
            renderSetupEvidence(into: URL(fileURLWithPath: arguments[index + 1], isDirectory: true))
            return true
        }

        if let index = arguments.firstIndex(of: "--render-design"), index + 1 < arguments.count {
            renderDesignEvidence(into: URL(fileURLWithPath: arguments[index + 1], isDirectory: true))
            return true
        }

        if let index = arguments.firstIndex(of: "--render-panel"), index + 1 < arguments.count {
            renderPanelEvidence(into: URL(fileURLWithPath: arguments[index + 1], isDirectory: true))
            return true
        }

        return false
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

    /// One frozen panel state for the render evidence.
    private struct PanelScene {
        let name: String
        let readings: [SensorReading]
        let rpm: Int
        let selection: ManualSelection
        let state: ControlState
        let layer: SafetyLayer?
        let installer: HelperInstaller.State
        let expanded: Set<SensorGroup>
        let dark: Bool
    }

    /// The P6.02 states worth freezing: firmware in charge, the engine
    /// driving (both appearances), panic, and no helper installed.
    private static func panelScenes() -> [PanelScene] {
        func reading(_ name: String, _ group: SensorGroup, _ celsius: Double) -> SensorReading {
            SensorReading(rawName: name, displayName: name, group: group, celsius: celsius)
        }
        let normal: [SensorReading] = [
            reading("PMU tdie5", .compute, 65.4),
            reading("PMU tdie1", .compute, 63.8),
            reading("PMU tdie2", .compute, 61.2),
            reading("PMU tdev1", .compute, 58.9),
            reading("GPU tdie0", .graphics, 57.6),
            reading("GPU tdie1", .graphics, 55.1),
            reading("PMU tdie9", .power, 52.3),
            reading("DDR temp", .memory, 49.2),
            reading("NAND CH0 temp", .storage, 41.8),
        ]
        var hot = normal
        hot[0] = reading("PMU tdie5", .compute, 96.8)

        return [
            PanelScene(
                name: "1-firmware", readings: normal, rpm: 1002,
                selection: ManualSelection(profileName: "System"),
                state: .monitoring, layer: nil, installer: .enabled,
                expanded: [.compute], dark: false),
            PanelScene(
                name: "2-driving", readings: normal, rpm: 2755,
                selection: ManualSelection(profileName: "Balanced"),
                state: .controlling, layer: nil, installer: .enabled,
                expanded: [.compute], dark: false),
            PanelScene(
                name: "3-driving-dark", readings: normal, rpm: 2755,
                selection: ManualSelection(profileName: "Balanced"),
                state: .controlling, layer: nil, installer: .enabled,
                expanded: [.compute], dark: true),
            PanelScene(
                name: "4-panic", readings: hot, rpm: 4900,
                selection: ManualSelection(profileName: "Balanced"),
                state: .panic, layer: .panic, installer: .enabled,
                expanded: [], dark: false),
            PanelScene(
                name: "5-not-installed", readings: normal, rpm: 998,
                selection: ManualSelection(profileName: "System"),
                state: .monitoring, layer: nil, installer: .notRegistered,
                expanded: [], dark: false),
        ]
    }

    /// Renders the menu bar panel in its P6.02 states on fixed data, same
    /// rationale as `renderSetupEvidence`: deterministic, permission-free.
    /// The control model in each scene runs real arbitration on the frozen
    /// selection, so no render can show a state arbitration would refuse.
    private static func renderPanelEvidence(into directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            report("cannot create \(directory.path): \(error)")
            return
        }

        for scene in panelScenes() {
            let fan = FanState(
                id: 0, name: "Fan 0", currentRPM: scene.rpm,
                minimumRPM: 1000, maximumRPM: 4900, isPoweredOff: false)
            let monitor = MonitorModel(fixedForRendering: scene.readings, fans: [fan])
            let control = ControlModel(
                fixedForRendering: monitor,
                selection: scene.selection,
                state: scene.state,
                layer: scene.layer)
            let setup = HelperSetupModel()
            setup.fixedInstallerStateForRendering = scene.installer

            let view = MenuBarPanel(
                model: monitor, setup: setup, control: control,
                initiallyExpanded: scene.expanded
            )
            .background(scene.dark ? Color(white: 0.14) : Color(white: 0.97))
            .environment(\.colorScheme, scene.dark ? .dark : .light)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 2

            guard let cgImage = renderer.cgImage,
                let data = NSBitmapImageRep(cgImage: cgImage)
                    .representation(using: .png, properties: [:])
            else {
                report("render failed: \(scene.name)")
                continue
            }

            let url = directory.appendingPathComponent("panel-\(scene.name).png")
            do {
                try data.write(to: url)
                report("wrote \(url.path)")
            } catch {
                report("write failed for \(scene.name): \(error)")
            }
        }
    }

    /// Renders the design-system swatch sheet in both appearances, same
    /// rationale as `renderSetupEvidence`: deterministic, permission-free.
    private static func renderDesignEvidence(into directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            report("cannot create \(directory.path): \(error)")
            return
        }

        for darkAppearance in [false, true] {
            let renderer = ImageRenderer(
                content: DesignEvidenceView(darkAppearance: darkAppearance))
            renderer.scale = 2

            guard let cgImage = renderer.cgImage,
                let data = NSBitmapImageRep(cgImage: cgImage)
                    .representation(using: .png, properties: [:])
            else {
                report("render failed: \(darkAppearance ? "dark" : "light")")
                continue
            }

            let url = directory.appendingPathComponent(
                "design-\(darkAppearance ? "dark" : "light").png")
            do {
                try data.write(to: url)
                report("wrote \(url.path)")
            } catch {
                report("write failed: \(error)")
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
    @State private var control: ControlModel

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
            MenuBarLabel(model: model)
                .task { model.start() }
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
