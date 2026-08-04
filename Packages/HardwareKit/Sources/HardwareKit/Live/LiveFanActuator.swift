import Core
import Foundation

/// Drives fans through the SMC. Root only — the kernel refuses these writes
/// from anything else (verified: `kIOReturnNotPrivileged`).
///
/// ## The sequence, and why the order matters
///
/// Take-over (per fan, first time): read and **save the original mode and
/// target bytes** → force the mode → write the target → read the target back.
/// Hand-back: write the saved target back → write the saved mode back →
/// verify, with up to five attempts and exponential backoff.
///
/// The original state is saved as raw bytes and restored verbatim: the goal
/// is to leave the machine exactly as found, not as we assume it was.
///
/// ## Synchronous core
///
/// The real work is synchronous on purpose. The helper's exit paths (watchdog
/// expiry, SIGTERM, last client gone) must finish the release *before*
/// calling `exit()`, and an async hop there would race process death.
/// `FanActuator`'s async methods wrap the sync core for everyone else.
public final class LiveFanActuator: FanActuator, @unchecked Sendable {

    public let identifier = "smc"

    /// SMC fan mode byte: firmware in charge.
    static let automaticMode: UInt8 = 0
    /// SMC fan mode byte: software target honoured.
    static let forcedMode: UInt8 = 1

    static let releaseAttempts = 5
    /// First retry delay; doubles each attempt (0.1, 0.2, 0.4, 0.8, 1.6 s).
    static let releaseBackoffSeconds: TimeInterval = 0.1

    private struct SavedFan {
        let modeBytes: [UInt8]
        /// Nil when the original target is unknown (the amnesia guard):
        /// restoring the mode alone suffices, the firmware rewrites its own
        /// target the moment it is back in charge.
        let targetBytes: [UInt8]?
    }

    private let port: any SMCPort
    private let lock = NSLock()
    private var saved: [Int: SavedFan] = [:]

    /// Injectable sleep so the backoff schedule is testable without waiting.
    private let sleeper: @Sendable (TimeInterval) -> Void

    public convenience init() throws {
        try self.init(port: SMCConnection())
    }

    init(
        port: any SMCPort,
        sleeper: @escaping @Sendable (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) {
        self.port = port
        self.sleeper = sleeper
    }

    // MARK: - FanActuator

    public func apply(_ targets: [FanTarget]) async throws {
        try applyNow(targets)
    }

    public func releaseToFirmware() async throws {
        try releaseNow()
    }

    // MARK: - Synchronous core

    /// Takes over and writes the given targets.
    public func applyNow(_ targets: [FanTarget]) throws {
        lock.lock()
        defer { lock.unlock() }

        for target in targets {
            try takeOverIfNeeded(fanID: target.fanID)
            let key = "F\(target.fanID)Tg"
            try port.writeValue(key: key, bytes: Self.floatBytes(Float(target.rpm)))

            // Write verification with the same patience as the mode byte:
            // this SMC generation applies writes asynchronously (measured —
            // the mode readback lags the accepted write by ~100 ms), so the
            // target readback gets three attempts over 300 ms too. The
            // convergence of the actual speed is the caller's closed loop;
            // this only catches a write that never stuck at all.
            var accepted = false
            for _ in 0..<3 {
                if let echoed = try port.readValue(key: key),
                    let value = echoed.numericValue,
                    abs(value - Double(target.rpm)) < 1
                {
                    accepted = true
                    break
                }
                sleeper(0.1)
            }
            guard accepted else {
                let modeNow =
                    (try? port.readValue(key: "F\(target.fanID)Md")?.bytes.first)
                    .map { "\($0)" } ?? "?"
                let targetNow =
                    (try? port.readValue(key: key))?.numericValue
                    .map { "\($0)" } ?? "?"
                throw HardwareError.noData(
                    "\(key) did not accept \(target.rpm) rpm "
                        + "(mode now \(modeNow), target now \(targetNow))")
            }
        }
    }

    /// Hands every taken-over fan back to the firmware. Idempotent.
    public func releaseNow() throws {
        lock.lock()
        defer { lock.unlock() }

        var lastFailure: (any Error)?
        for (fanID, original) in saved {
            do {
                try restore(fanID: fanID, original: original)
                saved.removeValue(forKey: fanID)
            } catch {
                // Keep the saved state: a later attempt must still know what
                // to restore. One fan failing must not stop the others.
                lastFailure = error
            }
        }

        // Amnesia guard. The bookkeeping above lives in process memory, and
        // a helper that died mid-control takes it to the grave — the next
        // helper would happily report "nothing to release" while the fan
        // stays forced. This was not hypothetical: the freeze drill produced
        // exactly that state on real hardware. So release also asks the
        // hardware itself: any fan still reporting a forced mode is returned
        // to automatic, saved state or not. Automatic is always safe — it is
        // the firmware taking back its own fan.
        do {
            try releaseAnyForcedFan()
        } catch {
            lastFailure = lastFailure ?? error
        }

        if let lastFailure { throw lastFailure }
    }

    private func releaseAnyForcedFan() throws {
        guard let countValue = try port.readValue(key: "FNum"),
            let rawCount = countValue.numericValue
        else { return }

        for fanID in 0..<Int(rawCount) {
            let modeKey = "F\(fanID)Md"
            guard let mode = try port.readValue(key: modeKey),
                mode.type.hasPrefix("ui8"),
                mode.bytes.first != Self.automaticMode
            else { continue }
            try restore(
                fanID: fanID,
                original: SavedFan(modeBytes: [Self.automaticMode], targetBytes: nil))
        }
    }

    /// True while at least one fan is taken over. For diagnostics.
    public var isHoldingFans: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !saved.isEmpty
    }

    // MARK: - Internals

    private func takeOverIfNeeded(fanID: Int) throws {
        guard saved[fanID] == nil else { return }

        let modeKey = "F\(fanID)Md"
        let targetKey = "F\(fanID)Tg"

        // The types are read, checked and never assumed — an unexpected tag
        // means this machine speaks a dialect this build has not met, and
        // writing blind into it is how firmware gets confused.
        guard let mode = try port.readValue(key: modeKey), mode.type.hasPrefix("ui8") else {
            throw HardwareError.noData("\(modeKey) missing or not ui8; refusing to take over")
        }
        guard let target = try port.readValue(key: targetKey), target.type.hasPrefix("flt") else {
            throw HardwareError.noData("\(targetKey) missing or not flt; refusing to take over")
        }

        saved[fanID] = SavedFan(modeBytes: mode.bytes, targetBytes: target.bytes)
        try port.writeValue(key: modeKey, bytes: [Self.forcedMode])

        // The SMC applies some writes asynchronously; give the mode byte a
        // moment before deciding it was ignored. Three reads over 300 ms.
        var engaged = false
        for _ in 0..<3 {
            if let echoed = try port.readValue(key: modeKey),
                echoed.bytes.first == Self.forcedMode
            {
                engaged = true
                break
            }
            sleeper(0.1)
        }
        guard engaged else {
            let now = (try? port.readValue(key: modeKey)?.bytes.first).map { "\($0)" } ?? "?"
            throw HardwareError.noData(
                "\(modeKey): wrote \(Self.forcedMode), hardware still reports \(now) — "
                    + "manual mode did not engage")
        }
    }

    private func restore(fanID: Int, original: SavedFan) throws {
        let modeKey = "F\(fanID)Md"
        let targetKey = "F\(fanID)Tg"

        var delay = Self.releaseBackoffSeconds
        var lastError: (any Error)?

        for attempt in 1...Self.releaseAttempts {
            do {
                // Target first, then mode: the moment the mode byte goes back
                // the firmware is in charge, and it should wake up to its own
                // last target, not to ours.
                if let targetBytes = original.targetBytes {
                    try port.writeValue(key: targetKey, bytes: targetBytes)
                }
                try port.writeValue(key: modeKey, bytes: original.modeBytes)

                // The SMC applies writes asynchronously (~100 ms, measured).
                // The verification waits for the write to land instead of
                // rewriting immediately — every rewrite restarts the apply
                // pipeline, and an impatient loop here defeats itself
                // forever. That exact loop left a fan stuck in forced mode
                // during the freeze drill.
                var verified = false
                for _ in 0..<3 {
                    if let echoed = try port.readValue(key: modeKey),
                        echoed.bytes == original.modeBytes
                    {
                        verified = true
                        break
                    }
                    sleeper(0.1)
                }
                guard verified else {
                    throw HardwareError.noData("\(modeKey) readback does not match after restore")
                }
                return
            } catch {
                lastError = error
                if attempt < Self.releaseAttempts {
                    sleeper(delay)
                    delay *= 2
                }
            }
        }
        throw lastError
            ?? HardwareError.noData("release failed for fan \(fanID) with no underlying error")
    }

    /// Little endian IEEE 754 bytes, matching how the SMC's `flt` reads
    /// decode (verified against live keys: 1000.0 is `00 00 7a 44`).
    static func floatBytes(_ value: Float) -> [UInt8] {
        let raw = value.bitPattern
        return [
            UInt8(truncatingIfNeeded: raw),
            UInt8(truncatingIfNeeded: raw >> 8),
            UInt8(truncatingIfNeeded: raw >> 16),
            UInt8(truncatingIfNeeded: raw >> 24),
        ]
    }
}
