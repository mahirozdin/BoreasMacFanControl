import Foundation

/// What a fan is doing right now.
public struct FanState: Sendable, Hashable, Identifiable, Codable {

    public let id: Int

    /// Name as reported by the hardware, for example "Left Side".
    public let name: String

    public let currentRPM: Int
    public let minimumRPM: Int
    public let maximumRPM: Int

    /// True when the firmware has parked the fan.
    ///
    /// Some Macs stop the fans entirely at low load. No software can drive a
    /// fan that the hardware has switched off, so the user is told plainly
    /// rather than being shown a control that silently does nothing.
    public let isPoweredOff: Bool

    public init(
        id: Int,
        name: String,
        currentRPM: Int,
        minimumRPM: Int,
        maximumRPM: Int,
        isPoweredOff: Bool = false
    ) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.minimumRPM = minimumRPM
        self.maximumRPM = maximumRPM
        self.isPoweredOff = isPoweredOff
    }

    /// Usable speed span. Never negative, even if the hardware reports nonsense.
    public var span: Int {
        max(0, maximumRPM - minimumRPM)
    }

    /// Where the current speed sits between minimum and maximum, as 0...1.
    public var currentDuty: Duty {
        guard span > 0 else { return Duty.minimum }
        return Duty(Double(currentRPM - minimumRPM) / Double(span))
    }
}
