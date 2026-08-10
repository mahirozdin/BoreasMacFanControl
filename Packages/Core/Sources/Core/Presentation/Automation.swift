import Foundation

/// Automation hooks (P7.10, [ADR 0015](docs/architecture/adr/0015-automation-hooks-not-email.md)).
///
/// No SMTP client is written. Instead the user wires their own integration to
/// two generic mechanisms — an HTTP request, or a command on their own machine.
/// Everything here is the **decision**: which hooks may run, what a template
/// expands to, what the limits are. The doing lives in `App/Sources/Automation/`,
/// the only place `gate-privacy` permits a network API.
public enum AutomationHook: Sendable, Hashable, Codable {

    /// An HTTP request the user points wherever they like.
    case webhook(url: String, method: String, template: String)

    /// A command **on the user's own machine**, run with the user's own
    /// privileges. Never the daemon's: the daemon spawns no subprocess at all
    /// and `make gate-daemon` keeps it that way.
    case command(path: String, arguments: [String])

    /// True for the kind that can run arbitrary code. Named as a question about
    /// privilege rather than about the case, because that is the property the
    /// gate on it is actually protecting.
    public var executesCode: Bool {
        if case .command = self { return true }
        return false
    }

    private enum CodingKeys: String, CodingKey {
        case type, url, method, template, path, arguments
    }

    private enum Kind: String, Codable {
        case webhook, command
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .webhook:
            self = .webhook(
                url: try container.decode(String.self, forKey: .url),
                // POST is the default because a webhook without a body is
                // usually not what somebody wanted; naming it is still allowed.
                method: try container.decodeIfPresent(String.self, forKey: .method) ?? "POST",
                template: try container.decodeIfPresent(String.self, forKey: .template) ?? "")
        case .command:
            self = .command(
                path: try container.decode(String.self, forKey: .path),
                arguments: try container.decodeIfPresent([String].self, forKey: .arguments) ?? [])
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .webhook(let url, let method, let template):
            try container.encode(Kind.webhook, forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encode(method, forKey: .method)
            try container.encode(template, forKey: .template)
        case .command(let path, let arguments):
            try container.encode(Kind.command, forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(arguments, forKey: .arguments)
        }
    }
}

/// What a hook's placeholders are filled from.
///
/// Deliberately small: an automation payload is something a user pipes into
/// somebody else's service, so it carries what the event *was* and nothing
/// about who owns the machine — the same allowlist reasoning as the support
/// report and the unknown-sensor link.
public struct AutomationContext: Sendable, Hashable {
    public let kind: NotificationKind
    public let subject: String?
    public let celsius: Double?
    public let timestamp: Date

    public init(
        kind: NotificationKind, subject: String? = nil, celsius: Double? = nil, timestamp: Date
    ) {
        self.kind = kind
        self.subject = subject
        self.celsius = celsius
        self.timestamp = timestamp
    }
}

public struct AutomationSettings: Sendable, Hashable, Codable {

    /// The main switch. Off by default: an automation that ran before anybody
    /// asked for it is the thing this design is most careful about.
    public var isEnabled: Bool

    /// **The command hook's own switch, and it is separate on purpose.**
    /// A command hook sitting in the list does nothing until this is true, so
    /// "off by default" is a property of the data rather than something the
    /// runner has to remember to check. ADR 0015 requires an explicit warning
    /// when it is turned on; the interface owns that warning, this owns the
    /// fact that nothing runs without it.
    public var commandHooksAllowed: Bool

    public var hooks: [AutomationHook]

    /// How long any one hook may take before it is abandoned.
    public var timeoutSeconds: Double

    /// How many hooks may be in flight at once. A runaway build-up of
    /// processes is the failure ADR 0015 names.
    public var maximumConcurrent: Int

    public static let defaultTimeoutSeconds: Double = 10
    public static let timeoutRange: ClosedRange<Double> = 1...60
    public static let defaultMaximumConcurrent = 2
    public static let concurrencyRange: ClosedRange<Int> = 1...8

    public init(
        isEnabled: Bool = false,
        commandHooksAllowed: Bool = false,
        hooks: [AutomationHook] = [],
        timeoutSeconds: Double = defaultTimeoutSeconds,
        maximumConcurrent: Int = defaultMaximumConcurrent
    ) {
        self.isEnabled = isEnabled
        self.commandHooksAllowed = commandHooksAllowed
        self.hooks = hooks
        self.timeoutSeconds = Self.clamp(timeoutSeconds, to: Self.timeoutRange)
        self.maximumConcurrent = Self.clamp(maximumConcurrent, to: Self.concurrencyRange)
    }

    private static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }

    /// Clamped on the way in, like every other limit in this file: a hostile
    /// document asking for a 600 second timeout gets 60 rather than a refusal.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            commandHooksAllowed: try container.decodeIfPresent(
                Bool.self, forKey: .commandHooksAllowed) ?? false,
            hooks: try container.decodeIfPresent([AutomationHook].self, forKey: .hooks) ?? [],
            timeoutSeconds: try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds)
                ?? Self.defaultTimeoutSeconds,
            maximumConcurrent: try container.decodeIfPresent(
                Int.self, forKey: .maximumConcurrent) ?? Self.defaultMaximumConcurrent)
    }

    /// The hooks that may run for an event — **the whole gate, in one pure
    /// function**, so what runs is a test rather than a code path somebody has
    /// to read carefully.
    ///
    /// Nothing runs while the main switch is off, and a command hook needs
    /// its own permission on top. Both are checked here rather than at the call
    /// site, because a call site can be added later without the check.
    public func runnable() -> [AutomationHook] {
        guard isEnabled else { return [] }
        return hooks.filter { commandHooksAllowed || !$0.executesCode }
    }

    /// Command hooks present in the file but held back by their own switch.
    /// Surfaced so the interface can say "configured but not permitted" rather
    /// than leaving the user to wonder why nothing happened.
    public func withheldCommandHooks() -> [AutomationHook] {
        guard isEnabled else { return hooks }
        return commandHooksAllowed ? [] : hooks.filter(\.executesCode)
    }
}

/// Placeholder expansion for hook templates and arguments.
public enum AutomationTemplate {

    /// The names a template may use. `sensor` is an alias for `subject`
    /// because that is the name [ADR 0015](docs/architecture/adr/0015-automation-hooks-not-email.md)
    /// uses in its example, and an example somebody copies has to work.
    public static let placeholders = ["kind", "subject", "sensor", "celsius", "timestamp"]

    /// Expands `${…}` against the event.
    ///
    /// **An unknown placeholder is left exactly as written**, not replaced with
    /// an empty string. A typo that silently expands to nothing produces a
    /// webhook body that looks deliberate and is wrong; one that arrives as
    /// `${sesnor}` tells the user what they mistyped.
    ///
    /// A placeholder with no value *this time* — `${celsius}` on a profile
    /// change — expands to empty, because that is a fact about the event rather
    /// than a mistake in the template.
    public static func expand(_ template: String, with context: AutomationContext) -> String {
        var output = template
        for name in placeholders {
            guard output.contains("${\(name)}") else { continue }
            output = output.replacingOccurrences(
                of: "${\(name)}", with: value(for: name, in: context))
        }
        return output
    }

    private static func value(for name: String, in context: AutomationContext) -> String {
        switch name {
        case "kind": return context.kind.rawValue
        case "subject", "sensor": return context.subject ?? ""
        case "celsius":
            guard let celsius = context.celsius else { return "" }
            // Fixed one decimal rather than `Locale`-aware: this string is
            // parsed by somebody's script, not read by a person, and a comma
            // decimal separator would break it on half the machines that run it.
            return String(format: "%.1f", celsius)
        case "timestamp": return ISO8601DateFormatter().string(from: context.timestamp)
        default: return ""
        }
    }
}
