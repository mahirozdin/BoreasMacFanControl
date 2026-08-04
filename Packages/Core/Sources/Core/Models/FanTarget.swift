import Foundation

/// A requested speed for one fan.
///
/// The pair crosses the privilege boundary and feeds the safety chain, so it
/// is a named type rather than a tuple: two unlabelled integers are exactly
/// the kind of thing that gets transposed in a refactor.
public struct FanTarget: Sendable, Hashable, Codable {

    public let fanID: Int
    public let rpm: Int

    public init(fanID: Int, rpm: Int) {
        self.fanID = fanID
        self.rpm = rpm
    }
}
