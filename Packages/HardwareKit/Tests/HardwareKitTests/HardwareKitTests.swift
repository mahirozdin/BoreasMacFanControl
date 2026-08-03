import Testing

@testable import HardwareKit

@Suite("HardwareKit invariants")
struct HardwareKitTests {

    @Test("temperature reading is documented as privilege-free")
    func readingNeedsNoPrivileges() {
        #expect(HardwareKit.temperatureReadingRequiresPrivileges == false)
    }
}
