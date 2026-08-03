import Core
import Foundation
import HardwareKit

/// `boreas` — command line companion.
///
/// Argument parsing is hand written on purpose: the project takes no runtime
/// dependencies (ADR 0013), and the surface here is small enough that a parser
/// library would cost more than it saves.
enum CommandLineEntry {

    static func run() async -> Int32 {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = arguments.first else {
            printUsage()
            return 1
        }

        switch command {
        case "version", "--version", "-v":
            write("boreas 0.1.0\n")
            return 0

        case "status":
            return await status()

        case "sensors":
            return await sensors(showRaw: arguments.contains("--raw"))

        case "help", "--help", "-h":
            printUsage()
            return 0

        default:
            writeError("unknown command: \(command)\n")
            printUsage()
            return 1
        }
    }

    // MARK: - Commands

    private static func status() async -> Int32 {
        var output = ""

        let power = LivePowerSource().current()
        output += "power    : \(power.source.rawValue)"
        if let percentage = power.batteryPercentage {
            output += " (\(percentage)%)"
        }
        output += "\n"

        do {
            let readings = try await LiveSensorSource().snapshot()
            let hottest = readings.max { $0.celsius < $1.celsius }
            output += "sensors  : \(readings.count)"
            if let hottest {
                output += String(format: "  hottest %@ %.1f C", hottest.displayName, hottest.celsius)
            }
            output += "\n"

            let unmapped = readings.filter { $0.group == .uncategorized }
            if !unmapped.isEmpty {
                output += "unmapped : \(unmapped.count)  (please report these, see CONTRIBUTING.md)\n"
            }
        } catch {
            // Monitoring degrades rather than failing: the user still gets fan
            // and power information, and is told exactly what is missing.
            output += "sensors  : unavailable — \(error)\n"
        }

        do {
            let fans = try await LiveFanSource().fans()
            if fans.isEmpty {
                output += "fans     : none (this Mac has no controllable fan)\n"
            } else {
                for fan in fans {
                    if fan.isPoweredOff {
                        output += "fan \(fan.id)    : \(fan.name) — parked by firmware\n"
                    } else {
                        output += String(
                            format: "fan %d    : %@ %d rpm (%d-%d, %d%%)\n",
                            fan.id, fan.name, fan.currentRPM,
                            fan.minimumRPM, fan.maximumRPM, fan.currentDuty.percent
                        )
                    }
                }
            }
        } catch {
            output += "fans     : unavailable — \(error)\n"
        }

        output += "control  : not available yet (privileged helper lands in P3)\n"
        write(output)
        return 0
    }

    private static func sensors(showRaw: Bool) async -> Int32 {
        do {
            let readings = try await LiveSensorSource().snapshot()
            let grouped = Dictionary(grouping: readings, by: \.group)

            var output = ""
            for group in SensorGroup.allCases {
                guard let items = grouped[group], !items.isEmpty else { continue }
                output += "\n\(group.rawValue)\n"
                for reading in items.sorted(by: { $0.celsius > $1.celsius }) {
                    let name = showRaw ? reading.rawName : reading.displayName
                    output += String(format: "  %-44@ %6.1f C\n", name as NSString, reading.celsius)
                }
            }
            output += "\n\(readings.count) sensors\n"
            write(output)
            return 0
        } catch {
            writeError("cannot read sensors: \(error)\n")
            return 1
        }
    }

    // MARK: - Output

    private static func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    private static func writeError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }

    private static func printUsage() {
        let usage = """
            usage: boreas <command>

            commands:
              status            temperatures, fans and power at a glance
              sensors [--raw]   every sensor, grouped; --raw shows hardware names
              version           print version
              help              print this message
            """
        writeError(usage + "\n")
    }
}

exit(await CommandLineEntry.run())
