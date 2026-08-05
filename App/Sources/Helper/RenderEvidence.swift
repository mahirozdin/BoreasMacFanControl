import AppKit
import Core
import SwiftUI

/// The render evidence commands: deterministic, permission-free PNGs of the
/// interface in frozen states.
///
/// Screenshots would need the screen recording permission, which this
/// project promises never to ask for (invariant I2). Rendering views
/// directly produces the same evidence without any permission, and it is
/// deterministic, which a screenshot never is. Separate from
/// `HelperCommands` because these are the project's camera, not its
/// features.
@MainActor
enum RenderEvidence {

    private static func report(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }

    /// Renders the setup window in every phase to PNG files.
    ///
    /// Screenshots would need the screen recording permission, which this
    /// project promises never to ask for (invariant I2). Rendering the view
    /// directly produces the same evidence without any permission, and it is
    /// deterministic, which a screenshot never is.
    static func setup(into directory: URL) {
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

    private struct StatusVariant {
        let name: String
        let style: StatusItemStyle
        let control: ControlModel
    }

    /// The P6.03 states worth freezing: every layout and mark on one fixed
    /// monitor — layouts, compact mode, secondary group, mini chart, the
    /// driving and timed-override marks.
    private static func statusFixture() -> (monitor: MonitorModel, variants: [StatusVariant]) {
        let readings = [
            SensorReading(
                rawName: "PMU tdie5", displayName: "PMU tdie5", group: .compute, celsius: 62.4),
            SensorReading(
                rawName: "GPU tdie0", displayName: "GPU tdie0", group: .graphics, celsius: 55.8),
        ]
        let fan = FanState(
            id: 0, name: "Fan 0", currentRPM: 1608,
            minimumRPM: 1000, maximumRPM: 4900, isPoweredOff: false)
        // A believable three minutes: a slow climb with wobble.
        let history = (0..<90).map { step in
            48.0 + Double(step) * 0.15 + (step.isMultiple(of: 2) ? 0.6 : -0.6)
        }
        let monitor = MonitorModel(fixedForRendering: readings, fans: [fan], history: history)

        let system = ControlModel(
            fixedForRendering: monitor,
            selection: ManualSelection(profileName: "System"),
            state: .monitoring, layer: nil)
        let driving = ControlModel(
            fixedForRendering: monitor,
            selection: ManualSelection(profileName: "Balanced"),
            state: .controlling, layer: nil)
        let overridden = ControlModel(
            fixedForRendering: monitor,
            selection: ManualSelection(
                profileName: "Quiet", until: Date().addingTimeInterval(1800)),
            state: .controlling, layer: nil)

        var chartStyle = StatusItemStyle()
        chartStyle.showChart = true
        var secondaryStyle = StatusItemStyle()
        secondaryStyle.secondaryGroup = .graphics
        var verticalStyle = StatusItemStyle()
        verticalStyle.vertical = true
        var compactStyle = StatusItemStyle()
        compactStyle.compact = true

        let variants: [StatusVariant] = [
            StatusVariant(name: "1-default", style: StatusItemStyle(), control: system),
            StatusVariant(name: "2-driving", style: StatusItemStyle(), control: driving),
            StatusVariant(name: "3-override", style: StatusItemStyle(), control: overridden),
            StatusVariant(name: "4-secondary", style: secondaryStyle, control: system),
            StatusVariant(name: "5-chart", style: chartStyle, control: system),
            StatusVariant(name: "6-vertical", style: verticalStyle, control: system),
            StatusVariant(name: "7-compact", style: compactStyle, control: driving),
        ]
        return (monitor, variants)
    }

    /// Renders the status item label in its P6.03 variants on fixed data.
    /// Same rationale as every render command: deterministic,
    /// permission-free.
    static func status(into directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            report("cannot create \(directory.path): \(error)")
            return
        }

        let (monitor, variants) = statusFixture()

        for variant in variants {
            let label = MenuBarLabel(
                model: monitor, control: variant.control,
                fixedStyleForRendering: variant.style
            )
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Color(white: 0.92))

            let renderer = ImageRenderer(content: label)
            renderer.scale = 2

            guard let cgImage = renderer.cgImage,
                let data = NSBitmapImageRep(cgImage: cgImage)
                    .representation(using: .png, properties: [:])
            else {
                report("render failed: \(variant.name)")
                continue
            }

            let url = directory.appendingPathComponent("status-\(variant.name).png")
            do {
                try data.write(to: url)
                report("wrote \(url.path)")
            } catch {
                report("write failed for \(variant.name): \(error)")
            }
        }

        // The space warning's content, same evidence rules as the states.
        let warning = StatusItemSpaceWarningView(visibility: StatusItemVisibilityModel())
            .background(Color(white: 0.97))
        let warningRenderer = ImageRenderer(content: warning)
        warningRenderer.scale = 2
        if let cgImage = warningRenderer.cgImage,
            let data = NSBitmapImageRep(cgImage: cgImage)
                .representation(using: .png, properties: [:])
        {
            let url = directory.appendingPathComponent("status-8-warning.png")
            try? data.write(to: url)
            report("wrote \(url.path)")
        } else {
            report("render failed: warning")
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
    /// rationale as `setup`: deterministic, permission-free.
    /// The control model in each scene runs real arbitration on the frozen
    /// selection, so no render can show a state arbitration would refuse.
    static func panel(into directory: URL) {
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
    /// rationale as `setup`: deterministic, permission-free.
    static func design(into directory: URL) {
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
