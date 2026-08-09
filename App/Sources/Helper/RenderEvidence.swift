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
///
/// **The camera draws through a real window** (`write`, in
/// `RenderWindowEvidence`). It used to use `ImageRenderer`, which draws
/// SwiftUI primitives and nothing else: `DisclosureGroup`, `LazyVStack`,
/// `.link` buttons, `ScrollView`, `TabView`, `Slider`, `Picker` and
/// `TextField` all came out blank or as placeholders, and five phases of
/// run log carried that as a known limitation. Hosting the view offscreen
/// and asking AppKit to draw itself removed it. Views are still structured
/// with scroll containers and their content apart — that turned out to be
/// the better shape anyway — and the evidence renders the content.
@MainActor
enum RenderEvidence {

    static func report(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }

    /// The instant every fixture pretends it is. A frozen clock is what
    /// makes a chart's own x axis reproducible; anchoring the fixtures to
    /// the wall clock would make every render differ from the last by the
    /// time printed on the axis.
    static let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

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
            write(view, to: directory, named: "setup-\(entry.name)")
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
        // A believable three minutes: a slow climb with wobble. Built with
        // an explicit loop — the tuple-returning map defeated the type
        // checker's time budget.
        var history: [(Date, Double)] = []
        for step in 0..<90 {
            let time = Self.fixedNow.addingTimeInterval(Double(step - 89) * 2)
            let wobble: Double = step.isMultiple(of: 2) ? 0.6 : -0.6
            history.append((time, 48.0 + Double(step) * 0.15 + wobble))
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

            write(label, to: directory, named: "status-\(variant.name)")
        }

        // The space warning's content, same evidence rules as the states.
        let warning = StatusItemSpaceWarningView(visibility: StatusItemVisibilityModel())
            .background(Color(white: 0.97))
        write(warning, to: directory, named: "status-8-warning")
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
            write(
                DesignEvidenceView(darkAppearance: darkAppearance), to: directory,
                named: "design-\(darkAppearance ? "dark" : "light")", dark: darkAppearance)
        }
    }
}
