import Testing

@testable import Core

@Suite("Fan target guard (safety chain K4)")
struct FanTargetGuardTests {

    private let guardrail = FanTargetGuard(limits: [
        .init(id: 0, minimumRPM: 1000, maximumRPM: 4900),
        .init(id: 1, minimumRPM: 2160, maximumRPM: 5927),
    ])

    @Test("a speed inside the hardware range is allowed")
    func withinRange() {
        #expect(guardrail.evaluate(fanID: 0, requestedRPM: 2500) == .allowed(fanID: 0, rpm: 2500))
        #expect(guardrail.evaluate(fanID: 0, requestedRPM: 1000).isAllowed)
        #expect(guardrail.evaluate(fanID: 0, requestedRPM: 4900).isAllowed)
    }

    @Test("a speed below the hardware minimum is rejected, not clamped")
    func belowMinimum() {
        let verdict = guardrail.evaluate(fanID: 0, requestedRPM: 400)
        #expect(verdict.isAllowed == false)
        // Clamping would hide the bug that produced the request.
        if case .rejected(let reason) = verdict {
            #expect(reason.contains("below"))
        }
    }

    @Test("a speed above the hardware maximum is rejected")
    func aboveMaximum() {
        #expect(guardrail.evaluate(fanID: 0, requestedRPM: 9000).isAllowed == false)
    }

    @Test("an unknown fan is rejected rather than ignored")
    func unknownFan() {
        // Silently ignoring would let a caller believe a fan was set.
        #expect(guardrail.evaluate(fanID: 99, requestedRPM: 2000).isAllowed == false)
    }

    @Test("a fan reporting an inverted or empty range accepts nothing")
    func brokenRange() {
        let broken = FanTargetGuard(limits: [.init(id: 0, minimumRPM: 5000, maximumRPM: 1000)])
        #expect(broken.evaluate(fanID: 0, requestedRPM: 3000).isAllowed == false)
    }

    @Test("each fan is judged against its own limits, not a shared range")
    func perFanLimits() {
        // 2000 rpm is fine for fan 0 and below the minimum for fan 1.
        #expect(guardrail.evaluate(fanID: 0, requestedRPM: 2000).isAllowed)
        #expect(guardrail.evaluate(fanID: 1, requestedRPM: 2000).isAllowed == false)
    }

    @Test("a batch is rejected whole if any single target is out of range")
    func batchIsAllOrNothing() {
        let verdict = guardrail.evaluateBatch([(fanID: 0, rpm: 2500), (fanID: 1, rpm: 100)])
        #expect(verdict.isAllowed == false, "a partly applied batch is a state nobody asked for")
    }

    @Test("an empty batch is rejected rather than treated as success")
    func emptyBatch() {
        #expect(guardrail.evaluateBatch([]).isAllowed == false)
    }
}
