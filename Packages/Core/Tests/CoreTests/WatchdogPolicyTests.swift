import Foundation
import Testing

@testable import Core

/// The invariant tests ADR 0009 declares may never be deleted.
@Suite("Watchdog policy (dead man's switch, invariant G3)")
struct WatchdogPolicyTests {

    // MARK: - G3: the timeout is locked to 10-60 s

    @Test("the watchdog timeout cannot be set outside 10 to 60 seconds")
    func timeoutIsClamped() {
        #expect(WatchdogPolicy(requestedTimeoutSeconds: 0).timeout == 10)
        #expect(WatchdogPolicy(requestedTimeoutSeconds: 9.9).timeout == 10)
        #expect(WatchdogPolicy(requestedTimeoutSeconds: 61).timeout == 60)
        #expect(WatchdogPolicy(requestedTimeoutSeconds: 3600).timeout == 60)
        // A negative request is the closest thing to "off" a caller can ask
        // for; it gets the minimum, not a disabled watchdog.
        #expect(WatchdogPolicy(requestedTimeoutSeconds: -1).timeout == 10)
    }

    @Test("values already inside the range are taken as they are")
    func timeoutInRangeIsKept() {
        #expect(WatchdogPolicy(requestedTimeoutSeconds: 10).timeout == 10)
        #expect(WatchdogPolicy(requestedTimeoutSeconds: 15).timeout == 15)
        #expect(WatchdogPolicy(requestedTimeoutSeconds: 60).timeout == 60)
    }

    @Test("the timeout derived from the heartbeat cadence is clamped too")
    func derivedTimeoutIsClamped() {
        // The shipped cadence: a 5 s beat, released after 3 misses.
        #expect(
            WatchdogPolicy(heartbeatIntervalSeconds: 5, missedHeartbeatsBeforeRelease: 3)
                .timeout == 15)
        // A cadence that would produce a 3 s window is pulled up to the floor…
        #expect(
            WatchdogPolicy(heartbeatIntervalSeconds: 1, missedHeartbeatsBeforeRelease: 3)
                .timeout == 10)
        // …and one that would produce 90 s is pulled down to the ceiling.
        #expect(
            WatchdogPolicy(heartbeatIntervalSeconds: 30, missedHeartbeatsBeforeRelease: 3)
                .timeout == 60)
    }

    // MARK: - The helper releases the fans when heartbeats stop

    @Test("the helper releases the fans when heartbeats stop")
    func silenceExpires() {
        let policy = WatchdogPolicy(requestedTimeoutSeconds: 15)
        let last = Date(timeIntervalSinceReferenceDate: 1000)

        #expect(policy.hasExpired(lastHeartbeat: last, now: last.addingTimeInterval(15.1)))
        #expect(policy.hasExpired(lastHeartbeat: last, now: last.addingTimeInterval(3600)))
    }

    @Test("a heartbeat inside the window keeps control alive")
    func recentHeartbeatDoesNotExpire() {
        let policy = WatchdogPolicy(requestedTimeoutSeconds: 15)
        let last = Date(timeIntervalSinceReferenceDate: 1000)

        #expect(!policy.hasExpired(lastHeartbeat: last, now: last))
        #expect(!policy.hasExpired(lastHeartbeat: last, now: last.addingTimeInterval(14.9)))
        // The boundary itself has not yet outlived the timeout.
        #expect(!policy.hasExpired(lastHeartbeat: last, now: last.addingTimeInterval(15)))
    }

    @Test("a heartbeat from the future does not trigger a release")
    func clockSkewDoesNotExpire() {
        let policy = WatchdogPolicy(requestedTimeoutSeconds: 15)
        let last = Date(timeIntervalSinceReferenceDate: 1000)

        // A clock adjustment can put the last heartbeat ahead of "now".
        // Expiry means proven silence; confusion is not proof.
        #expect(!policy.hasExpired(lastHeartbeat: last, now: last.addingTimeInterval(-3600)))
    }
}
