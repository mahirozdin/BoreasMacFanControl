import Core
import Foundation

/// Entry point for hardware access.
///
/// Sensor and fan protocols, plus their `Live`, `Mock` and `Replay`
/// implementations, land in P2. This file exists so the package graph
/// compiles and the layer gate has something to check.
public enum HardwareKit: Sendable {

    /// Reading temperatures needs no privileges on Apple Silicon; only
    /// writing fan targets does. The whole privilege model rests on this.
    public static let temperatureReadingRequiresPrivileges = false
}
