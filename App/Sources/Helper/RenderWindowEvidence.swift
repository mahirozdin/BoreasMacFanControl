import Charts
import Core
import SwiftUI

/// The panel and main-window render evidence, split from the rest so each
/// file stays inside the lint budget. Same camera, same rules — see
/// `RenderEvidence`.
extension RenderEvidence {

    /// What one main-window render needs. A struct rather than a tuple:
    /// three unlabelled members crossing a return boundary is exactly the
    /// shape that gets transposed in a refactor.
    struct WindowFixture {
        let monitor: MonitorModel
        let control: ControlModel
        let setup: HelperSetupModel
    }

    /// Forty minutes of plausible history, with the fan following the
    /// Balanced curve of the temperature that drives it.
    ///
    /// The fan series is *derived from the same curve the engine uses*
    /// rather than drawn freehand, so the pair of charts in the evidence
    /// shows a real cause and its real effect. A hand-drawn fan line could
    /// look right while proving nothing about the alignment the tab exists
    /// to demonstrate.
    /// Forty minutes of series, one entry every two seconds.
    ///
    /// The fan series goes through the **rate limiter**, not straight off
    /// the curve: the engine's own output lags its target, and that lag is
    /// exactly what the curve editor's trail layer exists to show. A
    /// fixture sitting perfectly on the curve would prove the layer draws,
    /// and nothing about what it means.
    private static func windowSeries(fan: FanState) -> [SensorGroup: [(Date, Double)]] {
        let curve = BuiltInProfiles.all().first { $0.name == "Balanced" }?.binding.curve
        var compute: [(Date, Double)] = []
        var graphics: [(Date, Double)] = []
        var memory: [(Date, Double)] = []
        var storage: [(Date, Double)] = []
        var fanSpeeds: [(Date, Double)] = []
        var previousRPM: Int?

        for index in 0..<windowSampleCount {
            let time = fixedNow.addingTimeInterval(Double(index - windowSampleCount + 1) * windowStep)
            let phase = Double(index) / Double(windowSampleCount)
            let hump = Swift.max(0, Foundation.sin(phase * .pi * 2.2))
            // A load that arrives late, so the default five minute window
            // shows a rise and the fan answering it rather than an idle
            // tail — the alignment is the thing being demonstrated.
            let finale = Swift.max(0, (phase - 0.72) / 0.28)
            let wobble = index.isMultiple(of: 3) ? 0.4 : -0.35
            let hot = 48 + 13 * hump + 27 * finale * finale + wobble

            compute.append((time, hot))
            graphics.append((time, hot - 7.5 + wobble))
            memory.append((time, 45 + 2 * hump + 3 * finale + wobble))
            storage.append((time, 41.5 + wobble))
            if let curve {
                let target = curve.duty(at: hot).rpm(for: fan)
                let limited = RateLimit.standard.limit(
                    previousRPM: previousRPM, targetRPM: target, elapsedSeconds: windowStep)
                previousRPM = limited
                fanSpeeds.append((time, Double(limited)))
            }
        }
        // The fan rides in under `uncategorized`, which no fixture group
        // uses, purely so one function can return both kinds of series.
        return [
            .compute: compute, .graphics: graphics, .memory: memory,
            .storage: storage, .uncategorized: fanSpeeds,
        ]
    }

    private static let windowStep = 2.0
    private static let windowSampleCount = 1_200

    private static func windowFixture() -> WindowFixture {
        let fan = FanState(
            id: 0, name: "Fan 0", currentRPM: 2_310,
            minimumRPM: 1_000, maximumRPM: 4_900, isPoweredOff: false)
        let series = windowSeries(fan: fan)
        let compute = series[.compute] ?? []
        let graphics = series[.graphics] ?? []
        let fanSpeeds = series[.uncategorized] ?? []

        let readings = [
            SensorReading(
                rawName: "PMU tdie5", displayName: "PMU tdie5", group: .compute,
                celsius: compute.last?.1 ?? 60),
            SensorReading(
                rawName: "PMU tdie1", displayName: "PMU tdie1", group: .compute, celsius: 61.2),
            SensorReading(
                rawName: "GPU tdie0", displayName: "GPU tdie0", group: .graphics,
                celsius: graphics.last?.1 ?? 52),
            SensorReading(
                rawName: "LPDDR temp", displayName: "LPDDR temp", group: .memory, celsius: 46.4),
            SensorReading(
                rawName: "NAND CH0 temp", displayName: "NAND CH0 temp", group: .storage,
                celsius: 41.5),
        ]

        // The displayed fan carries the speed its own history ends at: a
        // summary card disagreeing with the chart beside it would be a
        // small lie inside the evidence.
        let displayFan = FanState(
            id: fan.id, name: fan.name,
            currentRPM: Int(fanSpeeds.last?.1 ?? Double(fan.currentRPM)),
            minimumRPM: fan.minimumRPM, maximumRPM: fan.maximumRPM,
            isPoweredOff: false)

        let monitor = MonitorModel(
            fixedForRendering: readings, fans: [displayFan],
            groupHistory: series.filter { $0.key != .uncategorized },
            fanHistory: [0: fanSpeeds],
            // A session that started when the series did, and a spell of
            // real thermal pressure — the diagnostics evidence has to show
            // the "worth a look" wording, which is the whole point of the
            // honesty rule. A fixture where everything is fine proves only
            // that the healthy path renders.
            sessionStart: fixedNow.addingTimeInterval(-windowStep * Double(windowSampleCount)),
            thermalSeconds: [.serious: 96, .critical: 12])
        let control = ControlModel(
            fixedForRendering: monitor,
            selection: ManualSelection(profileName: "Balanced"),
            state: .controlling, layer: nil)
        let setup = HelperSetupModel()
        setup.fixedInstallerStateForRendering = .enabled
        return WindowFixture(monitor: monitor, control: control, setup: setup)
    }

    /// Renders the main window's tabs (P6.04, P6.05).
    ///
    /// The tabs are rendered individually rather than through `TabView`:
    /// the tab bar is AppKit-backed and would draw as a placeholder, the
    /// same class of finding the P6.02 evidence turned up. What matters
    /// here is each tab's content, and that is exactly what is captured.
    static func window(into directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            report("cannot create \(directory.path): \(error)")
            return
        }

        let fixture = windowFixture()

        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let background = dark ? Color(white: 0.13) : Color(white: 0.98)

            let monitoring = MonitoringContent(
                model: fixture.monitor, control: fixture.control, now: fixedNow
            )
            .frame(width: 860)
            .background(background)
            .environment(\.colorScheme, dark ? .dark : .light)
            write(monitoring, to: directory, named: "window-monitoring-\(suffix)", dark: dark)

            let controlTab = ControlContent(
                model: fixture.monitor, control: fixture.control, setup: fixture.setup,
                now: fixedNow
            )
            .frame(width: 860)
            .background(background)
            .environment(\.colorScheme, dark ? .dark : .light)
            write(controlTab, to: directory, named: "window-control-\(suffix)", dark: dark)

            let diagnostics = DiagnosticsContent(
                model: fixture.monitor, control: fixture.control, setup: fixture.setup,
                now: fixedNow
            )
            .frame(width: 860)
            .background(background)
            .environment(\.colorScheme, dark ? .dark : .light)
            write(diagnostics, to: directory, named: "window-diagnostics-\(suffix)", dark: dark)
        }
    }

    /// Renders one view to a PNG, through a real (offscreen) window.
    ///
    /// **This replaced `ImageRenderer`, and the reason is the finding that
    /// ran through five phases of run log.** `ImageRenderer` draws SwiftUI
    /// primitives and nothing else: every AppKit-backed control —
    /// `ScrollView`, `TabView`, `DisclosureGroup`, `.link` buttons,
    /// `Slider`, `Picker`, `TextField` — came out as a blank or a
    /// placeholder. The workaround had been to hand-roll controls, which is
    /// fine when the hand-rolled version is genuinely better and wrong when
    /// it is not: a settings window should use the system's own slider,
    /// with its accessibility and its familiar behaviour, and the camera
    /// should be the thing that adapts.
    ///
    /// Hosting the view in an offscreen `NSWindow` and asking the view
    /// hierarchy to draw itself (`cacheDisplay`) is how AppKit has always
    /// photographed itself. It needs no screen recording permission — the
    /// window is ours and the bitmap is ours — so invariant I2 is untouched.
    /// `appearance` overrides the `dark` choice when given. It exists for the
    /// P6.12 accessibility renders: `Increase Contrast` cannot be set through
    /// the SwiftUI environment (`\.colorSchemeContrast` is a get-only key path
    /// — the compiler refuses to write it), but AppKit has carried a real
    /// high-contrast appearance since 10.14, and the window is already how this
    /// camera controls appearance.
    static func write(
        _ view: some View,
        to directory: URL,
        named name: String,
        dark: Bool = false,
        appearance: NSAppearance.Name? = nil
    ) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)

        let window = NSWindow(
            contentRect: hosting.frame, styleMask: [.borderless],
            backing: .buffered, defer: false)
        window.contentView = hosting
        // Set on the window, not only in the SwiftUI environment: AppKit
        // controls take their appearance from the window, which is why the
        // old renders could not show a dark slider even when the SwiftUI
        // around it was dark.
        window.appearance = NSAppearance(named: appearance ?? (dark ? .darkAqua : .aqua))
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()

        let bounds = hosting.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            report("render failed: \(name)")
            return
        }

        // A bitmap twice the size in pixels but the same size in points.
        // The offscreen window is on no screen, so it would otherwise draw
        // at 1x, and the rest of the evidence is 2x.
        let scale = 2
        guard
            let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(bounds.width) * scale,
                pixelsHigh: Int(bounds.height) * scale,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else {
            report("render failed: \(name)")
            return
        }
        representation.size = bounds.size

        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            report("render failed: \(name)")
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        hosting.displayIgnoringOpacity(bounds, in: context)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = representation.representation(using: .png, properties: [:]) else {
            report("render failed: \(name)")
            return
        }
        let url = directory.appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
            report("wrote \(url.path)")
        } catch {
            report("write failed for \(name): \(error)")
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

            write(view, to: directory, named: "panel-\(scene.name)", dark: scene.dark)
        }
    }

}
