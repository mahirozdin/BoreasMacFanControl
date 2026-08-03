import Core
import Foundation

/// Reads fan state from the SMC. Read only; nothing here can change a speed.
public struct LiveFanSource: FanSource {

    public let identifier = "smc"

    private let connection: SMCConnection

    public init() throws {
        self.connection = try SMCConnection()
    }

    public func fans() async throws -> [FanState] {
        guard
            let countValue = try connection.readValue(key: "FNum"),
            let rawCount = countValue.numericValue
        else {
            // No fan count key at all means this machine has no SMC fan
            // interface. That is a fanless Mac, not a failure.
            return []
        }

        let count = Int(rawCount)
        guard count > 0 else { return [] }

        var fans: [FanState] = []
        for index in 0..<count {
            guard let fan = try? readFan(index: index) else { continue }
            fans.append(fan)
        }
        return fans
    }

    private func readFan(index: Int) throws -> FanState? {
        func number(_ suffix: String) -> Double? {
            try? connection.readValue(key: "F\(index)\(suffix)")?.numericValue
        }

        guard
            let actual = number("Ac"),
            let minimum = number("Mn"),
            let maximum = number("Mx")
        else { return nil }

        return FanState(
            id: index,
            name: fanName(index: index),
            currentRPM: Int(actual),
            minimumRPM: Int(minimum),
            maximumRPM: Int(maximum),
            // A fan reporting zero while the hardware still lists it means the
            // firmware has parked it. No software can drive it in that state,
            // and the interface says so rather than offering a dead control.
            isPoweredOff: actual < 1
        )
    }

    /// The SMC carries a human name for each fan on most models.
    private func fanName(index: Int) -> String {
        if let value = try? connection.readValue(key: "F\(index)ID"),
            let name = Self.decodeFanName(value.bytes),
            !name.isEmpty
        {
            return name
        }
        return "Fan \(index + 1)"
    }

    /// The `FxID` payload carries a short ASCII label after a four byte header.
    static func decodeFanName(_ bytes: [UInt8]) -> String? {
        guard bytes.count > 4 else { return nil }
        let printable = bytes.dropFirst(4).prefix { $0 >= 32 && $0 < 127 }
        guard !printable.isEmpty else { return nil }
        guard let name = String(bytes: printable, encoding: .utf8) else { return nil }
        return name.trimmingCharacters(in: .whitespaces)
    }
}
