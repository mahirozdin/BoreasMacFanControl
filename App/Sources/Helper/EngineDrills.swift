import Core
import Foundation
import HardwareKit
import SharedIPC

/// The P6.05 override drill, split from `HardwareDrills` so that file stays
/// inside the lint budget. Same instrument, same rules.
extension HardwareDrills {

    /// P6.09 on real hardware: the diagnostics tell the truth about a Mac
    /// that is working properly.
    ///
    /// The risk this drill exists for is **false positives**. A fan
    /// response check with the tolerance set too tight would tell every
    /// healthy owner their fan is not following commands, and the honesty
    /// rule's whole argument is that a wrong diagnosis costs more than no
    /// diagnosis. So the drill drives a known-good fan properly and
    /// insists the check comes back healthy.
    static func diagnosticsDrill(report: (String) -> Void) {
        let monitor = MonitorModel()
        let control = ControlModel(monitor: monitor)

        func pump(_ seconds: Double) {
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
        }

        monitor.start()
        pump(3)
        guard !monitor.fans.isEmpty else {
            report("no controllable fan")
            exit(1)
        }

        // Before driving, the honest answer is "not yet".
        let before = DiagnosticChecks.fanResponse(samples: control.fanResponseSamples)
        report("before driving: \(before.verdict.rawValue) — \(before.finding.text)")

        control.select(profileName: "Balanced")
        // Long enough to collect well past the minimum sample count at the
        // two second cycle, including the ramp the rate limiter imposes.
        pump(40)

        let driving = DiagnosticChecks.fanResponse(samples: control.fanResponseSamples)
        report(
            "after \(control.fanResponseSamples.count) samples: "
                + "\(driving.verdict.rawValue) — \(driving.finding.text)")

        let sensors = DiagnosticChecks.sensorValidity(
            outOfRange: monitor.allReadings.filter { !$0.isPlausible }.map(\.displayName),
            stuck: [],
            totalSensors: monitor.allReadings.count)
        report("sensors: \(sensors.verdict.rawValue) — \(sensors.finding.text)")

        let balance = DiagnosticChecks.fanBalance(
            speeds: monitor.fans.filter { !$0.isPoweredOff }.map(\.currentRPM))
        report("balance: \(balance.verdict.rawValue) — \(balance.finding.text)")

        control.select(profileName: "System")
        pump(6)

        let passed =
            before.verdict == .indeterminate
            && control.fanResponseSamples.count >= DiagnosticChecks.minimumSamples
            // The point of the drill: a healthy fan must not be accused.
            && driving.verdict == .healthy
            && sensors.verdict == .healthy
            && balance.verdict == .notApplicable

        report(passed ? "DIAGNOSTICS DRILL PASS" : "DIAGNOSTICS DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    /// P6.06 on real hardware: an edited curve reaches the fans.
    ///
    /// The curve editor is only an instrument if what it draws changes what
    /// the machine does within a cycle or two. Here the drill edits the
    /// active profile exactly as a drag would — `updateActiveProfile` is
    /// the call the editor makes — and watches the fan move to the new
    /// curve's answer for the temperature the machine is actually at.
    static func curveDrill(report: (String) -> Void) {
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
        func computeMax() -> Double {
            monitor.readings.filter { $0.group == .compute }.map(\.celsius).max() ?? .nan
        }
        func line(_ label: String) {
            let state = hardware()
            report(
                "\(label): state=\(control.state.rawValue) "
                    + "mode=\(state.mode) rpm=\(state.rpm)")
        }

        monitor.start()
        pump(3)
        guard let fan = monitor.fans.first else {
            report("no controllable fan")
            exit(1)
        }

        control.select(profileName: "Balanced")
        pump(9)
        line("stock Balanced curve")
        let stock = hardware()

        // A deliberately steeper curve around wherever the machine sits, so
        // the change is unambiguous at the temperature it is actually at
        // rather than one it might reach.
        let here = computeMax()
        guard
            let steep = try? Curve(points: [
                CurvePoint(celsius: Swift.max(0, here - 12), duty: Duty(0.55)),
                CurvePoint(celsius: Swift.min(120, here + 12), duty: Duty(0.95)),
            ])
        else {
            report("could not build the test curve")
            exit(1)
        }

        control.updateActiveProfile(curve: steep)
        // Long enough for a cycle to notice and for the rate limiter to
        // carry the fan the whole way: 600 rpm/s over a ~2000 rpm rise.
        pump(16)
        line("after editing the curve")
        let edited = hardware()
        let expected = steep.duty(at: computeMax()).rpm(for: fan)

        control.select(profileName: "System")
        pump(6)
        line("system selected")
        let released = hardware()

        // **This comparison is weakest exactly where it matters most, and the
        // 350 rpm tolerance is a coincidence of where the test curve saturates.**
        // Measured in P7.01 across three machine temperatures:
        //
        //   52.6 °C → 4691 vs 4705 expected (14 rpm)
        //   59.1 °C → 4153 vs 3774 expected (379 rpm)  FAIL
        //   63.9 °C → 3766 vs 3395 expected (371 rpm)  FAIL
        //
        // Cool, the steep curve asks for ~100% duty, so the fan sits pinned at
        // its ceiling and matches to within a rounding error — but any steep
        // curve would give that answer, so it confirms very little. On the
        // curve's *slope*, the fan's own cooling lowers the temperature during
        // the 16 settling cycles, so `expected` is recomputed at a temperature
        // the fan has already left and the fan legitimately sits above it.
        //
        // The honest fix is the P6.09 insight — compare against the temperature
        // that *drove* the final target, sampled a cycle late, rather than the
        // one measured after the fan has already changed it. That is a change to
        // this drill's pass condition and is tracked as **P7.11**, not smuggled
        // into the task that happened to notice it.
        let passed =
            stock.mode == "1" && edited.mode == "1"
            && abs(edited.rpm - expected) <= 350
            && edited.rpm > stock.rpm + 400
            && released.mode == "0"

        report(
            "stock \(stock.rpm) rpm → edited \(edited.rpm) rpm "
                + "(curve expects ~\(expected) at \(String(format: "%.1f", here)) °C); "
                + "released mode=\(released.mode)")
        report(passed ? "CURVE DRILL PASS" : "CURVE DRILL FAIL")
        exit(passed ? 0 : 1)
    }

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
