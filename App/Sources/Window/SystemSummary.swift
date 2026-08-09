import Core
import Foundation
import SwiftUI

/// What Boreas has actually discovered about this Mac (P6.09).
///
/// Facts, not inferences: the chip and system version come from the system
/// itself, and everything else is what the application found when it looked
/// — how many sensors answered, how many it could not place, what the fan
/// interface reports, whether the helper is installed. This is also the
/// section a support conversation starts from, which is why it is
/// selectable text rather than a picture.
struct SystemSummary: View {
    let model: MonitorModel
    let setup: HelperSetupModel
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "diagnostics.summary", defaultValue: "This Mac",
                    comment: "Heading above the discovered system and hardware summary")
            )
            .font(.headline)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(rows, id: \.label) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(verbatim: row.label)
                            .frame(width: 170, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        Text(verbatim: row.value)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .font(.callout)
        }
    }

    private var rows: [(label: String, value: String)] {
        [
            (
                String(
                    localized: "diagnostics.summary.chip", defaultValue: "Chip",
                    comment: "Summary row: the processor this Mac reports"),
                Self.chipDescription
            ),
            (
                String(
                    localized: "diagnostics.summary.system", defaultValue: "macOS",
                    comment: "Summary row: the operating system version"),
                ProcessInfo.processInfo.operatingSystemVersionString
            ),
            (
                String(
                    localized: "diagnostics.summary.sensors", defaultValue: "Sensors found",
                    comment: "Summary row: how many sensors answered"),
                sensorsDescription
            ),
            (
                String(
                    localized: "diagnostics.summary.fans", defaultValue: "Fans found",
                    comment: "Summary row: how many fans the hardware reports"),
                fansDescription
            ),
            (
                String(
                    localized: "diagnostics.summary.power", defaultValue: "Power",
                    comment: "Summary row: mains or battery"),
                powerDescription
            ),
            (
                String(
                    localized: "diagnostics.summary.helper", defaultValue: "Fan control helper",
                    comment: "Summary row: whether the privileged helper is installed"),
                setup.installerState.summary
            ),
            (
                String(
                    localized: "diagnostics.summary.session", defaultValue: "Session",
                    comment: "Summary row: how long this run has been observing"),
                sessionDescription
            ),
        ]
    }

    /// The marketing name is not available without a private interface, so
    /// the machine identifier and core count are reported as they are.
    /// Naming the chip we did not read would be inventing a fact in the one
    /// section that promises not to.
    private static var chipDescription: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: Swift.max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        // sysctl returns a null-terminated string; the terminator is
        // dropped rather than decoded into the identifier. A failable
        // decode, because bytes from a system call are not a promise of
        // UTF-8 — an unreadable identifier simply goes unreported.
        let identifier = String(bytes: model.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        let cores = ProcessInfo.processInfo.processorCount
        return identifier.isEmpty ? "\(cores) cores" : "\(identifier) · \(cores) cores"
    }

    private var sensorsDescription: String {
        let total = model.allReadings.count
        let unknown = model.allReadings.filter { $0.group == .uncategorized }.count
        guard total > 0 else {
            return String(
                localized: "diagnostics.summary.sensors.none", defaultValue: "none answering",
                comment: "Shown when no sensor can be read")
        }
        guard unknown > 0 else {
            return String(
                localized: "diagnostics.summary.sensors.all",
                defaultValue: "\(total), all recognised",
                comment: "Shown when every sensor was classified")
        }
        return String(
            localized: "diagnostics.summary.sensors.some",
            defaultValue: "\(total), of which \(unknown) unrecognised",
            comment: "Shown when some sensors could not be classified")
    }

    private var fansDescription: String {
        guard let fan = model.fans.first else {
            return String(
                localized: "diagnostics.summary.fans.none", defaultValue: "none",
                comment: "Shown on a Mac with no controllable fan")
        }
        let range = "\(fan.minimumRPM)–\(fan.maximumRPM) rpm"
        return model.fans.count == 1
            ? "1 · \(range)"
            : "\(model.fans.count) · \(range)"
    }

    private var powerDescription: String {
        switch model.power.source {
        case .adapter:
            return String(
                localized: "diagnostics.summary.power.adapter", defaultValue: "mains",
                comment: "Power source: plugged in")
        case .battery:
            guard let percentage = model.power.batteryPercentage else {
                return String(
                    localized: "diagnostics.summary.power.battery", defaultValue: "battery",
                    comment: "Power source: on battery, charge unknown")
            }
            return String(
                localized: "diagnostics.summary.power.batterypercent",
                defaultValue: "battery, \(percentage)%",
                comment: "Power source: on battery with a known charge")
        }
    }

    private var sessionDescription: String {
        let seconds = Int(now.timeIntervalSince(model.sessionStart))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
    }
}
