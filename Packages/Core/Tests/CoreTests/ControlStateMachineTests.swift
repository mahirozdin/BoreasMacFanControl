import Testing

@testable import Core

@Suite("Control state machine (MONITORING/CONTROLLING/PANIC/RELEASING)")
struct ControlStateMachineTests {

    @Test("the documented happy path walks in order")
    func happyPath() {
        var state = ControlState.monitoring
        for (event, expected) in [
            (ControlEvent.controlEngaged, ControlState.controlling),
            (.panicRaised, .panic),
            (.panicCleared, .controlling),
            (.releaseRequested, .releasing),
            (.released, .monitoring),
        ] {
            let next = ControlStateMachine.next(from: state, on: event)
            #expect(next == expected, "\(state) on \(event)")
            state = next ?? state
        }
    }

    @Test("release is reachable from every active state, including panic")
    func releaseFromAnywhereActive() {
        #expect(ControlStateMachine.next(from: .controlling, on: .releaseRequested) == .releasing)
        #expect(ControlStateMachine.next(from: .panic, on: .releaseRequested) == .releasing)
    }

    @Test("requesting release while idle or already releasing changes nothing")
    func releaseIsIdempotentAtTheStateLevel() {
        #expect(ControlStateMachine.next(from: .monitoring, on: .releaseRequested) == .monitoring)
        #expect(ControlStateMachine.next(from: .releasing, on: .releaseRequested) == .releasing)
    }

    @Test("illegal jumps are refused, not bent into place")
    func illegalTransitionsAreNil() {
        // Panic without control, control without monitoring, release
        // completion out of nowhere: the table answers nil and the caller
        // logs it. A machine that bends is not a machine.
        #expect(ControlStateMachine.next(from: .monitoring, on: .panicRaised) == nil)
        #expect(ControlStateMachine.next(from: .monitoring, on: .released) == nil)
        #expect(ControlStateMachine.next(from: .controlling, on: .controlEngaged) == nil)
        #expect(ControlStateMachine.next(from: .controlling, on: .released) == nil)
        #expect(ControlStateMachine.next(from: .panic, on: .controlEngaged) == nil)
        #expect(ControlStateMachine.next(from: .releasing, on: .panicRaised) == nil)
        #expect(ControlStateMachine.next(from: .releasing, on: .controlEngaged) == nil)
    }
}
