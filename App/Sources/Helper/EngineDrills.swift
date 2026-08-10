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

        // The two checks P7.03 added, on this machine's real readings.
        let battery = DiagnosticChecks.batteryHealth(monitor.batteryReading)
        report("battery: \(battery.verdict.rawValue) — \(battery.finding.text)")
        let storage = DiagnosticChecks.storageHealth(monitor.storageReading)
        report("storage: \(storage.verdict.rawValue) — \(storage.finding.text)")
        if let smart = DiagnosticChecks.storageSmart(monitor.storageReading) {
            report("wear   : \(smart.verdict.rawValue) — \(smart.finding.text)")
        }

        // **This machine has no battery, and that is the assertion.** A desktop
        // must come back `notApplicable` with `batteryAbsent` — not
        // `indeterminate`, which would mean the read failed, and certainly not a
        // concern about a battery that does not exist. It is the one battery
        // branch this hardware can verify (R8); the rest live in
        // `MockHealthSource` and in the Core tests.
        let batteryIsHonestlyAbsent =
            battery.verdict == .notApplicable && battery.finding == .batteryAbsent

        // Storage must produce a real verdict rather than degrade: capacity is
        // readable without privileges, so `indeterminate` here would mean the
        // reader is broken.
        let storageAnswered = storage.verdict == .healthy || storage.verdict == .needsAttention

        let passed =
            before.verdict == .indeterminate
            && control.fanResponseSamples.count >= DiagnosticChecks.minimumSamples
            // The point of the drill: a healthy fan must not be accused.
            && driving.verdict == .healthy
            && sensors.verdict == .healthy
            && balance.verdict == .notApplicable
            && batteryIsHonestlyAbsent
            && storageAnswered

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

        // Every compute temperature this run observes, from the moment the
        // engine starts driving (P7.11).
        //
        // Collected from the Balanced settle onward rather than from the edit,
        // because the engine smooths its input: the value it acts on just after
        // the edit still carries history from before it, and a band built only
        // from post-edit samples can sit *below* a target that was legitimately
        // derived from a temperature the machine had a moment earlier.
        var observed: [Double] = []

        control.select(profileName: "Balanced")
        observed += settleSampling(seconds: 9, monitor: monitor)
        line("stock Balanced curve")
        let stock = hardware()

        let here = computeMax()
        guard let steep = steepTestCurve(around: here) else {
            report("could not build the test curve")
            exit(1)
        }

        control.updateActiveProfile(curve: steep)

        // Long enough for a cycle to notice and for the rate limiter to carry
        // the fan the whole way: 600 rpm/s over a ~2000 rpm rise. Sampled
        // throughout rather than read once at the end — the fan is cooling the
        // machine while it settles, so a single reading taken afterwards
        // describes a temperature the engine never acted on. That was the bug.
        observed += settleSampling(seconds: 16, monitor: monitor)

        line("after editing the curve")
        let edited = hardware()

        // Read before selecting System: the samples only exist while driving.
        let settled = Array(control.fanResponseSamples.suffix(6))

        control.select(profileName: "System")
        pump(6)
        line("system selected")
        let released = hardware()

        let verdict = judgeCurveEdit(
            curve: steep, fan: fan, observed: observed, fallback: here, settled: settled)

        let passed =
            stock.mode == "1" && edited.mode == "1"
            && verdict.inBand
            && verdict.tracked
            && edited.rpm > stock.rpm + 400
            && released.mode == "0"

        report(
            "stock \(stock.rpm) rpm → edited \(edited.rpm) rpm; "
                + "released mode=\(released.mode)")
        verdict.lines.forEach(report)
        report(passed ? "CURVE DRILL PASS" : "CURVE DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    /// A deliberately steeper curve around wherever the machine sits, so the
    /// change is unambiguous at the temperature it is actually at rather than
    /// one it might reach.
    private static func steepTestCurve(around here: Double) -> Curve? {
        try? Curve(points: [
            CurvePoint(celsius: Swift.max(0, here - 12), duty: Duty(0.55)),
            CurvePoint(celsius: Swift.min(120, here + 12), duty: Duty(0.95)),
        ])
    }

    /// Runs the loop for `seconds`, returning every compute temperature seen.
    ///
    /// Polls faster than the control loop's own cycle so the set it returns is
    /// a superset of what the engine acted on — which is what makes the band in
    /// `judgeCurveEdit` an upper bound rather than a guess.
    private static func settleSampling(seconds: Double, monitor: MonitorModel) -> [Double] {
        var observed: [Double] = []
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            let sample = monitor.readings
                .filter { $0.group == .compute }.map(\.celsius).max()
            if let sample, sample.isFinite { observed.append(sample) }
        }
        return observed
    }

    private struct CurveVerdict {
        let inBand: Bool
        let tracked: Bool
        let lines: [String]
    }

    /// Did the edited curve produce the command, and did the hardware obey it?
    ///
    /// **P7.11 — what this replaced and why.** The old condition recomputed
    /// `curve.duty(at: temperatureNow)` *after* the settle and required the fan
    /// within 350 rpm of it. But the fan had spent those 16 seconds cooling the
    /// machine, so the expectation was rebuilt at a temperature the engine never
    /// acted on and the fan legitimately sat above it. Measured in P7.01:
    ///
    ///     52.6 °C → 4691 vs 4705 expected (14 rpm)   — passed, proving little
    ///     59.1 °C → 4153 vs 3774 expected (379 rpm)  FAIL
    ///     63.9 °C → 3766 vs 3395 expected (371 rpm)  FAIL
    ///
    /// Cool, the steep test curve saturates, the fan pins at its ceiling and any
    /// steep curve would have matched. On the slope it failed for being right.
    ///
    /// Two separable claims were tangled into that one number, so they are now
    /// asked separately:
    ///
    /// 1. **Provenance.** The engine's command must fall inside the band the
    ///    edited curve spans over the temperatures observed during the run. The
    ///    curve is monotone, so that band is exactly the set of answers it could
    ///    have given — no single instant has to be guessed at.
    /// 2. **Tracking.** Whether the hardware obeyed is what `fanResponseSamples`
    ///    already answers, and correctly: it pairs each cycle's target with the
    ///    speed measured on the *next* one (P6.09) — the "sampled a cycle late"
    ///    this task was told to reuse. Nothing is recomputed from temperature.
    ///
    /// The 350 rpm fudge falls out, as predicted. Proven to still discriminate:
    /// with the edit removed the engine commands the stock curve's answer and
    /// the band check reports OUT OF BAND while tracking passes at 2 rpm — the
    /// fan obeying perfectly, just the wrong curve.
    private static func judgeCurveEdit(
        curve: Curve, fan: FanState, observed: [Double], fallback: Double,
        settled: [(target: Int, actual: Int)]
    ) -> CurveVerdict {
        let coolest = observed.min() ?? fallback
        let hottest = observed.max() ?? fallback
        let bandLow = curve.duty(at: coolest).rpm(for: fan)
        let bandHigh = curve.duty(at: hottest).rpm(for: fan)

        // Not rounding alone, and the first version of this comment said it was.
        // The drill polls twice a second while the control loop runs on its own
        // two-second tick over an exponentially smoothed input, so the value the
        // engine acts on is never exactly one of these samples. The margin covers
        // that aliasing; sampling the whole run rather than only the post-edit
        // window is what keeps it this small. Measured: a 5 rpm overshoot before
        // the band was widened, none in three runs after.
        let bandMargin = 50
        let commanded = settled.last?.target ?? -1
        let inBand = commanded >= bandLow - bandMargin && commanded <= bandHigh + bandMargin

        // Asserted on the last three samples, not the whole tail. At a two second
        // cycle the tail still contains the end of the ramp, where the fan is
        // *supposed* to lag — and a drill that failed on a longer ramp would be
        // failing for being right, which is the exact defect P7.11 removes.
        // Measured across three runs: 4, 1 and 4 rpm on the settled three, while
        // the full tail reached 1073, 457 and 194 — two of the three would have
        // failed the 400 tolerance on the wider window.
        let deviations = settled.map { abs($0.actual - $0.target) }
        let tailWorst = deviations.max() ?? Int.max
        let settledWorst = deviations.suffix(3).max() ?? Int.max
        let tracked = !settled.isEmpty && settledWorst <= DiagnosticChecks.fanToleranceRPM

        return CurveVerdict(
            inBand: inBand,
            tracked: tracked,
            lines: [
                "  observed \(String(format: "%.1f", coolest))–"
                    + "\(String(format: "%.1f", hottest)) °C over \(observed.count) samples",
                "  the edited curve spans \(bandLow)–\(bandHigh) rpm there; "
                    + "the engine commanded \(commanded) → "
                    + "\(inBand ? "in band" : "OUT OF BAND")",
                "  hardware tracked to \(settledWorst) rpm worst over the settled 3 "
                    + "(\(tailWorst) over the whole tail of \(settled.count), which still "
                    + "contains the ramp); tolerance \(DiagnosticChecks.fanToleranceRPM)",
            ])
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
