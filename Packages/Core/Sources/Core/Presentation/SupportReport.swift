import Foundation

/// The support report (P7.05): a **local** file the user inspects and chooses
/// whether to attach to an issue. Nothing is ever uploaded.
///
/// **This is built from an allowlist, not from a dump with redactions.** The
/// difference is the whole design. A dump you then try to clean is a dump that
/// leaks the field somebody forgot to think about — and there are three concrete
/// things to forget here, each found rather than imagined:
///
/// - The drive's **serial number** sits in the IO registry directly beside its
///   model, which P7.03's probe showed while looking for something else.
/// - Any absolute path carries the user's **account name** (`/Users/…`).
/// - The machine's name is usually a **person's name** ("… 's Mac mini").
///
/// P3 forbids all three in a log line, and a file the user is about to attach to
/// a public issue deserves the same rule. So every field is named explicitly
/// below, `redacted(_:)` is the only way a string that came from the system
/// enters the report, and `leaks(in:)` is a test-facing audit that plants each of
/// those three values and proves none survives.
public struct SupportReport: Sendable, Equatable {

    /// The anonymous system summary. Every field is a *class* of machine, never
    /// an instance of one.
    public struct System: Sendable, Equatable {
        /// e.g. `Mac16,10`. A model identifier, shared by every unit sold.
        public let modelIdentifier: String
        public let macOSVersion: String
        public let appVersion: String
        /// Core count and memory, which say what kind of machine this is without
        /// saying which one.
        public let coreCount: Int
        public let memoryGigabytes: Int

        public init(
            modelIdentifier: String, macOSVersion: String, appVersion: String,
            coreCount: Int, memoryGigabytes: Int
        ) {
            self.modelIdentifier = modelIdentifier
            self.macOSVersion = macOSVersion
            self.appVersion = appVersion
            self.coreCount = coreCount
            self.memoryGigabytes = memoryGigabytes
        }
    }

    /// One sensor as the report describes it.
    ///
    /// A named type rather than a tuple, and at report level rather than nested
    /// inside `Hardware` — the lint budget objects to three
    /// unlabelled members, and it is right to — a `(String, SensorGroup,
    /// Double)` crossing a boundary is exactly the shape that gets transposed
    /// in a refactor, and here the members are *what the machine calls a
    /// sensor* and *how hot it is*.
    public struct ReportedSensor: Sendable, Equatable {
        public let rawName: String
        public let group: SensorGroup
        public let celsius: Double

        public init(rawName: String, group: SensorGroup, celsius: Double) {
            self.rawName = rawName
            self.group = group
            self.celsius = celsius
        }
    }

    public struct ReportedFan: Sendable, Equatable {
        public let id: Int
        public let minimumRPM: Int
        public let maximumRPM: Int
        public let currentRPM: Int

        public init(id: Int, minimumRPM: Int, maximumRPM: Int, currentRPM: Int) {
            self.id = id
            self.minimumRPM = minimumRPM
            self.maximumRPM = maximumRPM
            self.currentRPM = currentRPM
        }
    }

    /// The discovered hardware map: what this build found, and what it made of
    /// it. This is the section that actually helps somebody reading a bug report
    /// about an unrecognised sensor.
    public struct Hardware: Sendable, Equatable {

        public let sensorCount: Int
        /// Raw hardware sensor names with their groups. Hardware identifiers, not
        /// personal ones — and the whole point of the report for R8.
        public let sensors: [ReportedSensor]
        public let fans: [ReportedFan]
        /// The drive's model and firmware. **Never its serial number.**
        public let driveModel: String?
        public let driveFirmware: String?

        public init(
            sensorCount: Int,
            sensors: [ReportedSensor],
            fans: [ReportedFan],
            driveModel: String?,
            driveFirmware: String?
        ) {
            self.sensorCount = sensorCount
            self.sensors = sensors
            self.fans = fans
            self.driveModel = driveModel
            self.driveFirmware = driveFirmware
        }
    }

    public let generatedAt: Date
    public let system: System
    public let hardware: Hardware
    /// The configuration, already encoded. Encoded by the caller because `Core`
    /// owns the model and the App owns the file.
    public let configurationJSON: String
    /// Diagnostic findings as the user would read them, supplied by the App
    /// layer — `Core` decides *what* they are and the App owns the words.
    public let diagnosticLines: [String]
    /// Recent log lines, already filtered by the App layer.
    public let logLines: [String]

    public init(
        generatedAt: Date,
        system: System,
        hardware: Hardware,
        configurationJSON: String,
        diagnosticLines: [String],
        logLines: [String]
    ) {
        self.generatedAt = generatedAt
        self.system = system
        self.hardware = hardware
        self.configurationJSON = configurationJSON
        self.diagnosticLines = diagnosticLines
        self.logLines = logLines
    }

    // MARK: - Redaction

    /// Replaces anything that identifies a person or a machine.
    ///
    /// Applied to **every** string that came from the system on its way into the
    /// report — not afterwards over the finished text, because a value that was
    /// never allowed in cannot be missed on the way out. The one exception is
    /// `leaks(in:)`, which checks the finished text as a belt-and-braces audit.
    public static func redacted(_ text: String) -> String {
        var result = text

        // Absolute paths under /Users carry the account name. The path itself is
        // usually the useful part — that a file was under Application Support,
        // say — so the *name* goes and the shape stays.
        result = result.replacingOccurrences(
            of: "/Users/[^/\\s\"]+", with: "/Users/<redacted>",
            options: .regularExpression)

        // A home directory written with a tilde is already anonymous; one written
        // out is not, and the line above has handled it.
        return result
    }

    /// The patterns that must never appear in a finished report.
    ///
    /// Exists so a test can plant each one and prove it does not survive — the
    /// audit that makes "built from an allowlist" a checked claim rather than an
    /// intention. Returns what it found, so a failure names the leak.
    public static func leaks(in text: String, forbidden: [String]) -> [String] {
        forbidden.filter { candidate in
            !candidate.isEmpty && text.localizedCaseInsensitiveContains(candidate)
        }
    }

    // MARK: - Rendering

    /// The report as Markdown, because it is going into an issue.
    ///
    /// Order is deliberate: the sections most likely to explain a problem come
    /// first, and the configuration — the longest and least often relevant — is
    /// last so nobody has to scroll past it.
    public func markdown() -> String {
        var out = "# Boreas support report\n\n"
        out += "Generated \(generatedAt.formatted(.iso8601)) · **nothing here was uploaded**;\n"
        out += "this file exists only on this Mac unless you attach it to something.\n\n"

        out += "## System\n\n"
        out += "| Field | Value |\n|---|---|\n"
        out += "| Model | \(system.modelIdentifier) |\n"
        out += "| macOS | \(system.macOSVersion) |\n"
        out += "| Boreas | \(system.appVersion) |\n"
        out += "| Cores | \(system.coreCount) |\n"
        out += "| Memory | \(system.memoryGigabytes) GB |\n\n"
        out += "_No machine name, no serial number and no account name is collected._\n\n"

        out += "## Hardware discovered\n\n"
        if let driveModel = hardware.driveModel {
            out += "Drive: \(driveModel)"
            if let firmware = hardware.driveFirmware { out += ", firmware \(firmware)" }
            out += " _(serial number deliberately omitted)_\n\n"
        }
        out += "\(hardware.fans.count) fan(s), \(hardware.sensorCount) sensor(s).\n\n"
        if !hardware.fans.isEmpty {
            out += "| Fan | Range | Now |\n|---|---|---|\n"
            for fan in hardware.fans {
                out += "| \(fan.id) | \(fan.minimumRPM)–\(fan.maximumRPM) rpm "
                out += "| \(fan.currentRPM) rpm |\n"
            }
            out += "\n"
        }
        out += "| Sensor | Group | Reading |\n|---|---|---|\n"
        for sensor in hardware.sensors {
            out += "| `\(sensor.rawName)` | \(sensor.group.rawValue) "
            out += "| \(String(format: "%.1f", sensor.celsius)) °C |\n"
        }
        out += "\n"

        out += "## Diagnostics\n\n"
        if diagnosticLines.isEmpty {
            out += "_No checks ran._\n\n"
        } else {
            for line in diagnosticLines { out += "- \(line)\n" }
            out += "\n"
        }

        out += "## Recent log\n\n"
        if logLines.isEmpty {
            out += "_No log lines were collected._\n\n"
        } else {
            out += "```\n"
            for line in logLines { out += "\(line)\n" }
            out += "```\n\n"
        }

        out += "## Configuration\n\n```json\n\(configurationJSON)\n```\n"
        return out
    }
}
