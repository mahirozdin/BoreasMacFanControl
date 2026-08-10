import Foundation

/// The configuration file as it exists on disk
/// (`docs/architecture/configuration.md`, `schema/config.schema.json`).
///
/// This is the wire model: field names match the published schema, and the
/// conversion into engine types is where validation happens. Everything the
/// engine consumes today is here. Notifications joined the model in P7.01 and
/// recording in P7.02, so every section the schema publishes is now typed.
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

    /// Global shortcuts, keyed by the action they perform (P6.10). Empty
    /// by default: a system-wide key combination is a shared resource, and
    /// taking two of them from someone who never asked is exactly the
    /// behaviour that makes menu bar utilities unwelcome.
    public var shortcuts: [HotKeyAction: HotKey]

    /// Notification triggers and noise control (P7.01).
    ///
    /// Optional and additive like `sensorOverrides`: a file written before this
    /// section existed decodes to the defaults, which is why it needs no schema
    /// version bump. The defaults leave the subsystem **off** — see
    /// `NotificationSettings.isEnabled`.
    public var notifications: NotificationSettings

    /// Measurement recording (P7.02).
    ///
    /// Optional and additive, like every section added after v1 of the schema: a
    /// file written before it existed decodes to the defaults, which leave
    /// recording **off**. `docs/operations/observability.md` calls it
    /// "measurement recording — at the user's request", and writing files to
    /// somebody's disk unasked is not that.
    public var recording: RecordingSettings

    /// Automation hooks (P7.10). Every switch inside it is off by default, so
    /// an existing file that has never heard of this section behaves exactly as
    /// it did — see [ADR 0015](../../../../../docs/architecture/adr/0015-automation-hooks-not-email.md).
    public var automation: AutomationSettings

    public init(
        schemaVersion: Int = ConfigurationFile.currentSchemaVersion,
        general: General = General(),
        safety: Safety = Safety(),
        profiles: [Profile] = BuiltInProfiles.all(),
        sensorOverrides: [String: SensorOverride] = [:],
        // Not `BuiltInProfiles.defaultName`: the *fallback* is what runs
        // when nothing else does, and a fresh install falling back to a
        // driving profile would take the fans over before anyone asked.
        // The user chooses when that changes.
        defaultProfileName: String = "System",
        shortcuts: [HotKeyAction: HotKey] = [:],
        notifications: NotificationSettings = NotificationSettings(),
        recording: RecordingSettings = RecordingSettings(),
        automation: AutomationSettings = AutomationSettings()
    ) {
        self.schemaVersion = schemaVersion
        self.general = general
        self.safety = safety
        self.profiles = profiles
        self.sensorOverrides = sensorOverrides
        self.defaultProfileName = defaultProfileName
        self.shortcuts = shortcuts
        self.notifications = notifications
        self.recording = recording
        self.automation = automation
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
        case shortcuts
        case notifications
        case recording
        case automation
    }

    /// `shortcuts`, as an object keyed by action name — **corrected in P7.10**.
    ///
    /// It used to be written as Swift's alternating array for a dictionary with
    /// an enum key, `["boost", {…}]`. That round-trips correctly and is
    /// unpleasant to edit by hand, which matters for a file this project
    /// expects people to edit. Nobody noticed in P6.10 because all four
    /// shortcuts ship unset, so it had never been written to a real file.
    ///
    /// Encoding is hand-written for this one field, the same way
    /// `notifications.thresholds` already does it.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(general, forKey: .general)
        try container.encode(safety, forKey: .safety)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(sensorOverrides, forKey: .sensorOverrides)
        try container.encode(defaultProfileName, forKey: .defaultProfileName)
        var namedShortcuts: [String: HotKey] = [:]
        for (action, key) in shortcuts { namedShortcuts[action.rawValue] = key }
        try container.encode(namedShortcuts, forKey: .shortcuts)
        try container.encode(notifications, forKey: .notifications)
        try container.encode(recording, forKey: .recording)
        try container.encode(automation, forKey: .automation)
    }

    /// Reads either shape (P7.10).
    ///
    /// The object form is what this build writes. The alternating array is what
    /// older builds wrote, and it is still accepted — a file on somebody's disk
    /// does not stop being valid because the writer improved. Only a genuine
    /// `typeMismatch` falls through, so a *malformed object* still fails as an
    /// object rather than being retried as an array and reported confusingly.
    ///
    /// An unrecognised action name is **refused**, taking the section to its
    /// defaults rather than being silently dropped — the P6.10 rule, unchanged:
    /// a configuration that says one thing and does another is what the loader
    /// exists to prevent.
    private static func decodeShortcuts(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [HotKeyAction: HotKey] {
        do {
            guard
                let named = try container.decodeIfPresent(
                    [String: HotKey].self, forKey: .shortcuts)
            else { return [:] }
            var result: [HotKeyAction: HotKey] = [:]
            for (name, key) in named {
                guard let action = HotKeyAction(rawValue: name) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .shortcuts, in: container,
                        debugDescription: "unknown shortcut action '\(name)'")
                }
                result[action] = key
            }
            return result
        } catch DecodingError.typeMismatch {
            return try container.decodeIfPresent(
                [HotKeyAction: HotKey].self, forKey: .shortcuts) ?? [:]
        }
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
                    String.self, forKey: .defaultProfileName) ?? "System",
                // A shortcut the model refuses takes the whole section
                // down with it rather than being silently dropped: a
                // configuration that says one thing and does another is
                // what the loader exists to prevent.
                shortcuts: try Self.decodeShortcuts(from: container),
                notifications: try container.decodeIfPresent(
                    NotificationSettings.self, forKey: .notifications) ?? NotificationSettings(),
                recording: try container.decodeIfPresent(
                    RecordingSettings.self, forKey: .recording) ?? RecordingSettings(),
                // Optional and additive, like `recording` before it: a file
                // written by an older build is complete, and its defaults leave
                // every hook off.
                automation: try container.decodeIfPresent(
                    AutomationSettings.self, forKey: .automation) ?? AutomationSettings()
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
