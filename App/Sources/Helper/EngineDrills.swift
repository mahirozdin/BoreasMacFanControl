import Core
import Foundation
import HardwareKit
import SharedIPC

/// The P6.05 override drill, split from `HardwareDrills` so that file stays
/// inside the lint budget. Same instrument, same rules.
extension HardwareDrills {

    /// P6.05 on real hardware: a timed manual override takes the wheel,
    /// and when it expires the **engine** takes it back — not the firmware.
    ///
    /// That distinction is the whole design decision, and it is only
    /// observable on hardware: a released fan and an engine-driven fan
    /// differ by the mode byte and by which number the speed matches.
    static func overrideDrill(report: (String) -> Void) {
        let monitor = MonitorModel()
        let control = ControlModel(monitor: monitor)
        let smc = try? SMCConnection()

        func pump(_ seconds: Double) {
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        }
        func hardware() -> (mode: String, rpm: Int) {
            guard let smc else { return ("?", -1) }
            return (modeByte(smc).map(String.init) ?? "?", Int(actualRPM(smc)))
        }
        func line(_ label: String) {
            let state = hardware()
            report(
                "\(label): state=\(control.state.rawValue) "
                    + "override=\(control.isDutyOverridden) "
                    + "mode=\(state.mode) rpm=\(state.rpm)")
        }

        monitor.start()
        pump(3)
        guard let fan = monitor.fans.first,
            let balanced = control.profiles.first(where: { $0.name == "Balanced" })
        else {
            report("no controllable fan or no Balanced profile")
            exit(1)
        }

        control.select(profileName: "Balanced")
        pump(8)
        line("engine driving")

        control.overrideDuty(0.30, until: Date().addingTimeInterval(10))
        pump(8)
        line("override at 30%")
        let overridden = hardware()
        let expectedOverride = Duty(0.30).rpm(for: fan)

        // Past the expiry, plus a cycle to notice it and a moment for the
        // hardware to settle at the engine's number.
        pump(14)
        line("after expiry")
        let afterExpiry = hardware()
        let computeMax =
            monitor.readings
            .filter { $0.group == .compute }
            .map(\.celsius).max() ?? .nan
        let expectedEngine = balanced.binding.curve.duty(at: computeMax).rpm(for: fan)

        control.select(profileName: "System")
        pump(6)
        line("system selected")
        let released = hardware()

        let passed =
            overridden.mode == "1" && abs(overridden.rpm - expectedOverride) <= 200
            && !control.isDutyOverridden
            // Still driving — the expiry handed over, it did not hand back.
            && afterExpiry.mode == "1" && abs(afterExpiry.rpm - expectedEngine) <= 350
            && released.mode == "0"

        report(
            "override expected ~\(expectedOverride) rpm, measured \(overridden.rpm); "
                + "engine expected ~\(expectedEngine) rpm, measured \(afterExpiry.rpm); "
                + "released mode=\(released.mode)")
        report(passed ? "OVERRIDE DRILL PASS" : "OVERRIDE DRILL FAIL")
        exit(passed ? 0 : 1)
    }
}
