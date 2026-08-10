import AppKit
import Core
import Foundation

/// Gathers the facts the unknown-sensor report is allowed to carry and opens
/// the pre-filled issue (P7.09).
///
/// The decision about *what may be shared* is `Core.SensorReportLink`, under
/// unit test. This type only collects the values and hands them over, which is
/// the same split the rest of the application uses: `Core` decides, the App
/// measures and presents.
///
/// **Nothing here reads a name, a serial or a path.** Two public `sysctl`
/// values and the hardware's own sensor keys, all of them properties of a model
/// rather than of a machine.
enum SensorReportAction {

    /// Info.plist key written by `project.yml`. Reading it from the bundle
    /// keeps the product name out of the source (K2), and an application built
    /// without it simply offers no button rather than guessing an address.
    static let repositoryURLKey = "BORepositoryURL"

    static var repositoryURL: String {
        Bundle.main.object(forInfoDictionaryKey: repositoryURLKey) as? String ?? ""
    }

    /// A public `sysctl` string, or empty when it cannot be decoded.
    ///
    /// Bytes from a system call are not a promise of UTF-8, so the decode is
    /// failable and an unreadable value goes unreported rather than being
    /// guessed at — the same rule the diagnostics summary follows.
    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        return String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) ?? ""
    }

    /// e.g. `Mac16,10`.
    static var modelIdentifier: String { sysctlString("hw.model") }

    /// e.g. `Apple M4`. The issue form asks for the chip and this is the
    /// public answer; the diagnostics summary deliberately shows the model
    /// identifier and a core count instead, because *that* section promises not
    /// to name anything it did not read. Here the field exists, so filling it
    /// from a real reading beats leaving the user to type it.
    static var chip: String { sysctlString("machdep.cpu.brand_string") }

    /// The link for the sensors this classifier could not place, or `nil` when
    /// there is nothing to report.
    static func link(unrecognised: [SensorReading], fanCount: Int) -> SensorReportLink.Link? {
        SensorReportLink.link(
            base: repositoryURL,
            facts: SensorReportLink.Facts(
                modelIdentifier: modelIdentifier,
                chip: chip,
                sensorNames: unrecognised.map(\.rawName),
                fanCount: fanCount))
    }

    /// Hands the URL to the user's browser. The application itself opens no
    /// connection — `gate-privacy` still holds, and P2 is about what this
    /// process does, not about where the user chooses to go next.
    static func open(_ link: SensorReportLink.Link) {
        guard let url = URL(string: link.url) else { return }
        NSWorkspace.shared.open(url)
    }
}
