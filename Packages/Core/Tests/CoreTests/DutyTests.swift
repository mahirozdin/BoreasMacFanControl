import Foundation
import Testing

@testable import Core

@Suite("Duty")
struct DutyTests {

    @Test("clamps below zero and above one")
    func clamping() {
        #expect(Duty(-5).value == 0)
        #expect(Duty(1.7).value == 1)
        #expect(Duty(0.35).value == 0.35)
    }

    @Test("undefined input resolves upwards, never downwards")
    func nonFiniteIsSafetyBiased() {
        // Too much airflow is noise; too little is heat. The two failures are
        // not symmetric, so the type refuses to guess downwards.
        #expect(Duty(.infinity).value == 1)
        #expect(Duty(-.infinity).value == 0)
        #expect(Duty(.nan).value == 1, "NaN must not silently become minimum cooling")
    }

    @Test("no input can produce a value outside 0...1")
    func alwaysInRange() {
        let hostile: [Double] = [-.infinity, -1e300, -1, -0.0001, 0, 0.5, 1, 1.0001, 1e300, .infinity, .nan]
        for candidate in hostile {
            let duty = Duty(candidate)
            #expect(duty.value >= 0 && duty.value <= 1, "Duty(\(candidate)) escaped the range")
        }
    }

    @Test("duty maps onto a fan span with the documented formula")
    func rpmConversion() {
        let fan = FanState(id: 0, name: "Test", currentRPM: 2000, minimumRPM: 2000, maximumRPM: 6000)
        #expect(Duty(0).rpm(for: fan) == 2000)
        #expect(Duty(1).rpm(for: fan) == 6000)
        #expect(Duty(0.2).rpm(for: fan) == 2800)
        #expect(Duty(0.5).rpm(for: fan) == 4000)
    }

    @Test("zero duty is the hardware minimum, never a stopped fan")
    func zeroIsMinimumNotOff() {
        let fan = FanState(id: 0, name: "Test", currentRPM: 3000, minimumRPM: 1800, maximumRPM: 5000)
        #expect(Duty.minimum.rpm(for: fan) == 1800)
        #expect(Duty.minimum.rpm(for: fan) > 0)
    }

    @Test("a fan reporting an inverted range cannot produce a negative span")
    func invertedRange() {
        let broken = FanState(id: 0, name: "Broken", currentRPM: 0, minimumRPM: 5000, maximumRPM: 1000)
        #expect(broken.span == 0)
        #expect(Duty(1).rpm(for: broken) == 5000)
        #expect(broken.currentDuty == Duty.minimum)
    }

    @Test("percent rounds to the nearest whole number")
    func percentRounding() {
        #expect(Duty(0.555).percent == 56)
        #expect(Duty(0).percent == 0)
        #expect(Duty(1).percent == 100)
    }
}

@Suite("Fan state")
struct FanStateTests {

    @Test("current duty reflects where the speed sits in the range")
    func currentDuty() {
        let fan = FanState(id: 0, name: "Fan 1", currentRPM: 3000, minimumRPM: 1000, maximumRPM: 5000)
        #expect(fan.currentDuty.percent == 50)
    }

    @Test("a parked fan is identified as such rather than as running slowly")
    func parked() {
        let fan = FanState(
            id: 0, name: "Fan 1", currentRPM: 0,
            minimumRPM: 1200, maximumRPM: 4800, isPoweredOff: true
        )
        #expect(fan.isPoweredOff)
        #expect(fan.currentDuty == Duty.minimum)
    }

    @Test("fan state round trips through Codable")
    func codable() throws {
        let original = FanState(
            id: 1, name: "Right Side", currentRPM: 2100, minimumRPM: 2000, maximumRPM: 5400)
        let decoded = try JSONDecoder().decode(FanState.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test("a reading round trips through Codable")
    func readingCodable() throws {
        let original = SensorClassifier.makeReading(rawName: "PMU tdie1", celsius: 44.5)
        let decoded = try JSONDecoder().decode(SensorReading.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
        #expect(decoded.group == .compute)
    }
}
