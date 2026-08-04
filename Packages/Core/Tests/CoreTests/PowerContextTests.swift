import Foundation
import Testing

@testable import Core

@Suite("Power context")
struct PowerContextTests {

    @Test("a desktop reports mains power and no battery level")
    func desktop() {
        #expect(PowerContext.desktop.source == .adapter)
        #expect(PowerContext.desktop.batteryPercentage == nil)
    }

    @Test(
        "battery percentage is clamped into 0...100",
        arguments: [(-40, 0), (0, 0), (55, 55), (100, 100), (231, 100)]
    )
    func clamping(input: Int, expected: Int) {
        #expect(PowerContext(source: .battery, batteryPercentage: input).batteryPercentage == expected)
    }

    @Test("a missing battery level stays missing rather than becoming zero")
    func nilStaysNil() {
        // Zero would read as "empty battery" and could trigger a low battery
        // profile on a machine that simply has no battery.
        #expect(PowerContext(source: .adapter, batteryPercentage: nil).batteryPercentage == nil)
    }

    @Test("the context round trips through Codable")
    func codable() throws {
        let original = PowerContext(source: .battery, batteryPercentage: 62)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PowerContext.self, from: data)
        #expect(decoded == original)
    }
}
