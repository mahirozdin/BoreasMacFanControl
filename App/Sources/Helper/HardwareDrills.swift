import Core
import Foundation
import HardwareKit
import SharedIPC

/// Evidence drills: reproducible command line runs that prove the hardware
/// paths on a real machine — heartbeats and the watchdog, take-over and
/// hand-back, key recon, release idempotency.
///
/// They live apart from the maintenance commands because they are the
/// project's measuring instruments, not its features; the run log quotes
/// their output verbatim.
@MainActor
enum HardwareDrills {

    /// Takes a fan over and streams heartbeats until this process dies.
    ///
    /// This is the ADR 0009 drill client: run it, then kill or freeze the
    /// process and watch the helper hand the hardware back. SIGKILL cannot
    /// be caught, so nothing here can fake the outcome. The take-over is at
    /// an observable speed on purpose — the fan returning to baseline is
    /// proof visible without root.
    static func pumpHeartbeats(report: (String) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let client = HelperClient()
                let fans = try await client.describeFans()
                guard let fan = fans.first else {
                    FileHandle.standardOutput.write(Data("no controllable fan\n".utf8))
                    exit(1)
                }
                let target = min(fan.minimumRPM + 400, fan.maximumRPM)
                let verdict = try await client.requestTargets(
                    fanIDs: [fan.id], targetRPM: [target])
                let lines = [
                    "watchdog armed (apply accepted=\(verdict.accepted), target \(target) rpm)",
                    "pumping a heartbeat every \(BoreasIPC.heartbeatIntervalSeconds)s",
                    "pid \(ProcessInfo.processInfo.processIdentifier) — kill -9 it to run the drill",
                ]
                FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
                await client.beginHeartbeats()
                // Keep `client` — and with it the heartbeat task, which holds
                // the actor weakly — alive for the whole process lifetime.
                // Without this the actor deallocates the moment this scope
                // ends and the pump dies silently.
                while true {
                    try await Task.sleep(for: .seconds(3600))
                }
            } catch {
                FileHandle.standardOutput.write(Data("drill setup failed: \(error)\n".utf8))
                exit(1)
            }
        }
        // Waits forever on purpose: the drill ends when someone kills us.
        semaphore.wait()
    }

    /// Calls releaseToFirmware three times in a row.
    ///
    /// ADR 0009 requires release to be idempotent — it runs on quit, sleep,
    /// shutdown and watchdog expiry, so calling it again must never be the
    /// thing that fails. Three consecutive successes over the real privileged
    /// path are the evidence.
    static func releaseThreeTimes(report: (String) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            var lines: [String] = []
            do {
                let client = HelperClient()
                for attempt in 1...3 {
                    try await client.releaseToFirmware()
                    lines.append("release \(attempt): ok")
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

    /// Read-only recon for the fan write path, plus one proof.
    ///
    /// Lists every SMC key in the fan namespace with its reported type, so
    /// the actuator is written against what this machine actually exposes
    /// rather than folklore. Then attempts to write one key its own current
    /// value: an unprivileged process must be refused by the kernel, which
    /// is the enforcement behind invariant M3. If that write ever succeeds
    /// it changed nothing (same value) — and it would be a finding worth a
    /// loud report.
    static func dumpFanKeys(report: (String) -> Void) {
        do {
            let smc = try SMCConnection()
            let count = try smc.keyCount()
            report("SMC exposes \(count) keys; fan namespace:")
            for index in 0..<count {
                guard let key = try? smc.key(at: index), key.hasPrefix("F") else { continue }
                guard let value = try? smc.readValue(key: key) else {
                    report("  \(key)  (unreadable)")
                    continue
                }
                let numeric = value.numericValue.map { String(format: "%.1f", $0) } ?? "-"
                let hex = value.bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
                report("  \(key)  type=\(value.type)  bytes=[\(hex)]  numeric=\(numeric)")
            }

            report("write-refusal proof (M3): writing F0Md back to itself, unprivileged")
            if let mode = try smc.readValue(key: "F0Md") {
                do {
                    try smc.writeValue(key: "F0Md", bytes: mode.bytes)
                    report("  UNEXPECTED: unprivileged SMC write SUCCEEDED — report this loudly")
                } catch {
                    report("  refused as expected: \(error)")
                }
            } else {
                report("  F0Md not readable on this machine")
            }
        } catch {
            report("recon failed: \(error)")
        }
    }

    /// Drives the real `ControlModel` end to end, headless: engage, watch
    /// the hardware follow the slider, move the slider, disengage, watch the
    /// firmware take back. The state machine transitions run and are logged
    /// on the way (P4.08/P4.09). The main run loop is pumped by hand because
    /// the model is main-actor bound and there is no app run loop here.
    static func controlDrill(report: (String) -> Void) {
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
            report("\(label): state=\(control.state.rawValue) mode=\(state.mode) rpm=\(state.rpm)")
        }

        monitor.start()
        pump(3)
        guard let fan = monitor.fans.first else {
            report("no controllable fan")
            exit(1)
        }

        line("baseline")
        let before = control.state

        control.manualDuty = 0.10
        control.engage()
        pump(7)
        line("engaged at 10%")
        if let problem = control.lastProblem {
            report("problem: \(problem)")
        }
        let lowRPM = hardware().rpm
        let modeWhileDriving = hardware().mode

        control.manualDuty = 0.30
        pump(6)
        line("slider to 30%")
        let highRPM = hardware().rpm

        control.disengage()
        pump(5)
        line("disengaged")
        let after = hardware()

        let expectedLow = Duty(0.10).rpm(for: fan)
        let expectedHigh = Duty(0.30).rpm(for: fan)
        let followedLow = abs(lowRPM - expectedLow) <= 150
        let followedHigh = abs(highRPM - expectedHigh) <= 150
        let passed =
            before == .monitoring && modeWhileDriving == "1"
            && followedLow && followedHigh
            && control.state == .monitoring && after.mode == "0"

        report(
            "expected \(expectedLow)/\(expectedHigh) rpm, measured \(lowRPM)/\(highRPM); "
                + "back to monitoring=\(control.state == .monitoring)")
        report(passed ? "CONTROL DRILL PASS" : "CONTROL DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    /// One line of unprivileged truth: the fan's mode byte and actual speed.
    /// The kill/freeze harnesses poll this to watch the helper hand the
    /// hardware back without needing root or the helper itself.
    static func printFanState(report: (String) -> Void) {
        guard let smc = try? SMCConnection() else {
            report("mode=? rpm=?")
            return
        }
        report("mode=\(modeByte(smc).map(String.init) ?? "?") rpm=\(Int(actualRPM(smc)))")
    }

    /// The full write-path drill on real hardware, in one reproducible run:
    /// K4 refuses an impossible target → a valid take-over → the actual speed
    /// converges (closed loop) → hand back → the firmware regains the fan →
    /// releasing again is free. Timings are printed for the run log.
    static func takeoverDrill(report: (String) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            let out: @Sendable (String) -> Void = { line in
                FileHandle.standardOutput.write(Data((line + "\n").utf8))
            }
            do {
                let smc = try SMCConnection()
                let client = HelperClient()
                let (baseline, target) = try await takeOverAndConverge(
                    client: client, smc: smc, out: out)
                let passed = try await releaseAndVerify(
                    client: client, smc: smc, baseline: baseline, target: target, out: out)
                out(passed ? "DRILL PASS" : "DRILL FAIL")
                exit(passed ? 0 : 1)
            } catch {
                out("drill failed: \(error)")
                exit(1)
            }
        }
        semaphore.wait()
    }

    // The async drill phases are nonisolated on purpose: `takeoverDrill`
    // blocks the main thread on a semaphore, so anything the detached task
    // awaits must never hop to the main actor — that is the deadlock the
    // P3.00 run log documents, and it bit again here before this annotation.
    private nonisolated static func actualRPM(_ smc: SMCConnection) -> Double {
        (try? smc.readValue(key: "F0Ac")?.numericValue ?? 0) ?? 0
    }

    private nonisolated static func modeByte(_ smc: SMCConnection) -> UInt8? {
        try? smc.readValue(key: "F0Md")?.bytes.first
    }

    /// Phase one: K4 refuses an impossible target, then a valid take-over is
    /// applied and the actual speed converges on it. Returns baseline and
    /// target for the release phase; exits on failure.
    private nonisolated static func takeOverAndConverge(
        client: HelperClient, smc: SMCConnection, out: @Sendable (String) -> Void
    ) async throws -> (baseline: Double, target: Int) {
        guard let fan = try await client.describeFans().first else {
            out("no controllable fan")
            exit(1)
        }
        let baseline = actualRPM(smc)
        out(
            "fan \(fan.id): baseline \(Int(baseline)) rpm, "
                + "limits \(fan.minimumRPM)-\(fan.maximumRPM), "
                + "mode \(modeByte(smc).map(String.init) ?? "?")")

        let impossible = fan.maximumRPM + 5000
        let refusal = try await client.requestTargets(fanIDs: [fan.id], targetRPM: [impossible])
        out(
            "K4 out-of-range (\(impossible) rpm): "
                + "accepted=\(refusal.accepted) reason=\(refusal.reason ?? "-")")
        guard !refusal.accepted else {
            out("FAIL: impossible target accepted")
            exit(1)
        }

        let target = min(Int(baseline) + 500, fan.maximumRPM)
        let verdict = try await client.requestTargets(fanIDs: [fan.id], targetRPM: [target])
        guard verdict.accepted else {
            out("FAIL: valid target refused: \(verdict.reason ?? "-")")
            exit(1)
        }
        await client.beginHeartbeats()
        out("took over: target \(target) rpm, mode now \(modeByte(smc).map(String.init) ?? "?")")

        let converge = Date()
        var reached = false
        while Date().timeIntervalSince(converge) < 30 {
            if actualRPM(smc) >= Double(target) - 75 {
                reached = true
                break
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        out(
            String(
                format: "closed loop: %@ %d rpm in %.1fs (target %d)",
                reached ? "reached" : "DID NOT reach",
                Int(actualRPM(smc)), Date().timeIntervalSince(converge), target
            ))
        guard reached else {
            _ = try? await client.releaseToFirmware()
            exit(1)
        }
        try await Task.sleep(for: .seconds(2))
        return (baseline, target)
    }

    /// Phase two: hand back, watch the firmware regain the fan, and prove a
    /// second release is free.
    private nonisolated static func releaseAndVerify(
        client: HelperClient, smc: SMCConnection, baseline: Double, target: Int,
        out: @Sendable (String) -> Void
    ) async throws -> Bool {
        try await client.releaseToFirmware()
        let releaseAt = Date()
        let modeAfter = modeByte(smc)
        out("released: mode now \(modeAfter.map(String.init) ?? "?")")

        var settled = false
        while Date().timeIntervalSince(releaseAt) < 60 {
            if actualRPM(smc) <= baseline + 120 {
                settled = true
                break
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        out(
            String(
                format: "firmware back in charge: %d rpm after %.1fs%@",
                Int(actualRPM(smc)), Date().timeIntervalSince(releaseAt),
                settled ? "" : " (still settling at timeout)"
            ))

        try await client.releaseToFirmware()
        out("second release: ok (idempotent over hardware)")
        return settled && modeAfter == 0
    }
}
