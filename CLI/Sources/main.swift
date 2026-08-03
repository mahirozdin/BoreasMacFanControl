import Core
import Foundation
import HardwareKit

/// `boreas` — command line companion.
///
/// Subcommands land in P7. Argument parsing is hand written on purpose:
/// the project takes no runtime dependencies (ADR 0013), and the surface
/// here is small enough that a parser library would cost more than it saves.
enum CommandLineEntry {

    static func run() -> Int32 {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = arguments.first else {
            printUsage()
            return 1
        }

        switch command {
        case "version", "--version", "-v":
            FileHandle.standardOutput.write(Data("boreas 0.1.0\n".utf8))
            return 0

        case "status":
            var out = "Boreas CLI scaffold\n"
            out += "  config schema  : v\(Boreas.configSchemaVersion)\n"
            out += "  privileged read: \(HardwareKit.temperatureReadingRequiresPrivileges)\n"
            out += "  note           : sensor and fan output land in P7\n"
            FileHandle.standardOutput.write(Data(out.utf8))
            return 0

        case "help", "--help", "-h":
            printUsage()
            return 0

        default:
            FileHandle.standardError.write(Data("unknown command: \(command)\n".utf8))
            printUsage()
            return 1
        }
    }

    private static func printUsage() {
        let usage = """
            usage: boreas <command>

            commands:
              status     show current state
              version    print version
              help       print this message
            """
        FileHandle.standardError.write(Data((usage + "\n").utf8))
    }
}

exit(CommandLineEntry.run())
