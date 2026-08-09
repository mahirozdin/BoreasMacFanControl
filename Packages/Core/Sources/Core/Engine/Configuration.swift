import Foundation

/// The configuration file as it exists on disk
/// (`docs/architecture/configuration.md`, `schema/config.schema.json`).
///
/// This is the wire model: field names match the published schema, and the
/// conversion into engine types is where validation happens. Everything the
/// engine consumes today is here; sections that belong to later phases
/// (notifications, logging, sensor overrides) pass through untouched as raw
/// JSON so a file carrying them round-trips without loss.
public struct ConfigurationFile: Sendable, Hashable, Codable {

    /// The version this build reads and writes.
    public static let currentSchemaVersion = 1

    public struct General: Sendable, Hashable, Codable {
        public var samplingIntervalSeconds: Int

        public init(samplingIntervalSeconds: Int = 2) {
            self.samplingIntervalSeconds = Self.clamp(samplingIntervalSeconds)
        }

        static func clamp(_ seconds: Int) -> Int {
            Swift.min(60, Swift.max(1, seconds))
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let raw = try container.decodeIfPresent(Int.self, forKey: .samplingIntervalSeconds)
            self.init(samplingIntervalSeconds: raw ?? 2)
        }
    }

    public struct Safety: Sendable, Hashable, Codable {
        /// Clamped into [70, 95] by the type (G2, ADR 0022).
        public var panicThreshold: PanicThreshold
        /// Locked into [10, 60] via `WatchdogPolicy` (G3).
        public var watchdogTimeoutSeconds: Double

        public init(
            panicThreshold: PanicThreshold = .standard,
            watchdogTimeoutSeconds: Double = 15
        ) {
            self.panicThreshold = panicThreshold
            self.watchdogTimeoutSeconds =
                WatchdogPolicy(requestedTimeoutSeconds: watchdogTimeoutSeconds).timeout
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: SafetyCodingKeys.self)
            let panic = try container.decodeIfPresent(
                Double.self, forKey: .panicTemperatureCelsius)
            let watchdog = try container.decodeIfPresent(
                Double.self, forKey: .watchdogTimeoutSeconds)
            self.init(
                panicThreshold: panic.map { PanicThreshold(celsius: $0) } ?? .standard,
                watchdogTimeoutSeconds: watchdog ?? 15
            )
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: SafetyCodingKeys.self)
            try container.encode(panicThreshold.celsius, forKey: .panicTemperatureCelsius)
            try container.encode(watchdogTimeoutSeconds, forKey: .watchdogTimeoutSeconds)
        }
    }

    fileprivate enum SafetyCodingKeys: String, CodingKey {
        case panicTemperatureCelsius
        case watchdogTimeoutSeconds
    }

    public var schemaVersion: Int
    public var general: General
    public var safety: Safety
    public var profiles: [Profile]

    /// Per-sensor corrections, keyed by the sensor's raw hardware name
    /// (P6.08). Optional and additive: a file written before this section
    /// existed decodes to an empty dictionary, which is why adding it needs
    /// no schema version bump.
    public var sensorOverrides: [String: SensorOverride]

    /// The name of the profile arbitration falls back to.
    public var defaultProfileName: String

    public init(
        schemaVersion: Int = ConfigurationFile.currentSchemaVersion,
        general: General = General(),
        safety: Safety = Safety(),
        profiles: [Profile] = BuiltInProfiles.all(),
        sensorOverrides: [String: SensorOverride] = [:],
        defaultProfileName: String = BuiltInProfiles.defaultName
    ) {
        self.schemaVersion = schemaVersion
        self.general = general
        self.safety = safety
        self.profiles = profiles
        self.sensorOverrides = sensorOverrides
        self.defaultProfileName = defaultProfileName
    }

    /// The defaults this build starts from.
    public static let standard = ConfigurationFile()

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case general
        case safety
        case profiles
        case sensorOverrides
        case defaultProfileName
    }

    /// Missing sections mean their defaults — a minimal file is a valid
    /// file — and the version is read even from an otherwise foreign
    /// document, so "too new" can be reported as exactly that.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version =
            try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        if version == Self.currentSchemaVersion {
            self.init(
                schemaVersion: version,
                general: try container.decodeIfPresent(General.self, forKey: .general)
                    ?? General(),
                safety: try container.decodeIfPresent(Safety.self, forKey: .safety) ?? Safety(),
                profiles: try container.decodeIfPresent([Profile].self, forKey: .profiles)
                    ?? BuiltInProfiles.all(),
                sensorOverrides: try container.decodeIfPresent(
                    [String: SensorOverride].self, forKey: .sensorOverrides) ?? [:],
                defaultProfileName: try container.decodeIfPresent(
                    String.self, forKey: .defaultProfileName) ?? BuiltInProfiles.defaultName
            )
        } else {
            // A foreign version: do not try to interpret the rest.
            self.init(schemaVersion: version, profiles: [])
        }
    }
}

/// What went wrong with a configuration, phrased for a human. The G6 rule
/// wants the user told *which field* is at fault, and `DecodingError`
/// already carries the path — this keeps it.
public struct ConfigurationProblem: Sendable, Hashable, Error {
    public let fieldPath: String
    public let detail: String

    /// Public so the application layer can report a problem the decoder
    /// never saw — an unreadable file, for one, which fails before there
    /// is anything to decode.
    public init(fieldPath: String, detail: String) {
        self.fieldPath = fieldPath
        self.detail = detail
    }

    static func from(_ error: any Error) -> ConfigurationProblem {
        guard let decoding = error as? DecodingError else {
            return ConfigurationProblem(fieldPath: "-", detail: String(describing: error))
        }
        let context: DecodingError.Context?
        switch decoding {
        case .dataCorrupted(let ctx), .keyNotFound(_, let ctx),
            .typeMismatch(_, let ctx), .valueNotFound(_, let ctx):
            context = ctx
        @unknown default:
            context = nil
        }
        let path =
            context?.codingPath.map(\.stringValue).joined(separator: ".") ?? "-"
        return ConfigurationProblem(
            fieldPath: path.isEmpty ? "(top level)" : path,
            detail: context?.debugDescription ?? String(describing: decoding)
        )
    }
}

/// Loads configurations without ever letting a broken one crash anything —
/// the G6 behaviour as a pure function: the caller passes the candidate
/// bytes and the last valid configuration, and always gets a configuration
/// back, plus the problem when the candidate was refused.
public enum ConfigurationLoader {

    public struct Outcome: Sendable {
        public let configuration: ConfigurationFile
        /// Non-nil when the candidate was refused and `configuration` is
        /// the fallback. The interface shows this; the fans stay with the
        /// firmware while it does.
        public let problem: ConfigurationProblem?
        /// Migration happened: the caller should write the returned
        /// configuration back and keep `backupOfOriginal` beside it.
        public let migratedFromVersion: Int?
        public let backupOfOriginal: Data?
    }

    public static func load(
        candidate: Data?,
        lastValid: ConfigurationFile = .standard
    ) -> Outcome {
        guard let candidate else {
            return Outcome(
                configuration: lastValid, problem: nil,
                migratedFromVersion: nil, backupOfOriginal: nil)
        }

        let migration = ConfigurationMigrator.migrateIfNeeded(candidate)

        do {
            let decoded = try JSONDecoder().decode(ConfigurationFile.self, from: migration.data)
            guard decoded.schemaVersion == ConfigurationFile.currentSchemaVersion else {
                return Outcome(
                    configuration: lastValid,
                    problem: ConfigurationProblem(
                        fieldPath: "schemaVersion",
                        detail:
                            "version \(decoded.schemaVersion) is newer than this build understands"
                    ),
                    migratedFromVersion: nil, backupOfOriginal: nil)
            }
            return Outcome(
                configuration: decoded, problem: nil,
                migratedFromVersion: migration.fromVersion,
                backupOfOriginal: migration.fromVersion == nil ? nil : candidate)
        } catch {
            return Outcome(
                configuration: lastValid,
                problem: .from(error),
                migratedFromVersion: nil, backupOfOriginal: nil)
        }
    }
}

/// Schema migrations. Versioned, forward-only, and each one is proven
/// lossless by a test before it ships.
public enum ConfigurationMigrator {

    public struct Result: Sendable {
        public let data: Data
        /// Nil when the input was already current.
        public let fromVersion: Int?
    }

    /// Upgrades older documents to the current version. A document that is
    /// already current — or unreadable, which the loader will report — comes
    /// back untouched.
    public static func migrateIfNeeded(_ data: Data) -> Result {
        guard
            var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else {
            return Result(data: data, fromVersion: nil)
        }

        let version = object["schemaVersion"] as? Int ?? 0
        guard version < ConfigurationFile.currentSchemaVersion else {
            return Result(data: data, fromVersion: nil)
        }

        // v0 -> v1: the pre-release draft had no schemaVersion field and
        // allowed a panic threshold above the default; ADR 0022 narrowed
        // the range. Everything else carries over byte for byte.
        if version == 0 {
            object["schemaVersion"] = 1
            if var safety = object["safety"] as? [String: Any],
                let panic = safety["panicTemperatureCelsius"] as? Double
            {
                safety["panicTemperatureCelsius"] = PanicThreshold(celsius: panic).celsius
                object["safety"] = safety
            }
        }

        guard
            let upgraded = try? JSONSerialization.data(
                withJSONObject: object, options: [.sortedKeys])
        else {
            return Result(data: data, fromVersion: nil)
        }
        return Result(data: upgraded, fromVersion: version)
    }
}
