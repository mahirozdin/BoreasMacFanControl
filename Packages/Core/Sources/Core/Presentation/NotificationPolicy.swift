import Foundation

/// What a notification is *about* (P7.01).
///
/// The triggers in `docs/operations/notifications.md`, as a type. Notification
/// *wording* is not here: `Core` has no bundle in this application, so a string
/// living here is invisible to both the String Catalog and `make gate-i18n` —
/// the blind spot P6.11 found the hard way. `Core` decides which events are
/// delivered; the App layer writes what they say.
public enum NotificationKind: String, Sendable, Hashable, Codable, CaseIterable {

    /// A sensor group crossed a threshold the user set.
    case thresholdCrossed

    /// The system's thermal state reached `serious` or above.
    case thermalState

    /// The K3 panic layer engaged.
    case panicEngaged

    /// A fan check raised a concern.
    case fanAnomaly

    /// The privileged helper's connection dropped, or the watchdog handed the
    /// fans back.
    case daemonLost

    /// The active profile changed.
    case profileChanged

    /// Battery health degraded.
    case batteryHealth

    /// **No noise-control mechanism may drop this.**
    ///
    /// The reasoning is G2's, one level up: the panic layer cannot be switched
    /// off, so a notification saying it engaged cannot be silently swallowed
    /// either. A machine that is cooling at full speed because a sensor crossed
    /// the panic threshold is telling its owner something they need to know at
    /// three in the morning as much as at three in the afternoon — so quiet
    /// hours, the suppression window and the once-per-session rule all step
    /// aside for these, and a test sweeps every mechanism to prove it.
    ///
    /// Deliberately narrow. Everything else is noise-controllable, because the
    /// failure this whole subsystem exists to prevent is a user turning
    /// notifications off entirely after being drowned in them.
    public var isAlwaysDelivered: Bool {
        switch self {
        case .panicEngaged: true
        case .thresholdCrossed, .thermalState, .fanAnomaly, .daemonLost, .profileChanged,
            .batteryHealth:
            false
        }
    }

    /// Hardware health findings, which the document limits to once per launch.
    ///
    /// These describe a *condition*, not an event: a fan that is not tracking
    /// its targets will still not be tracking them in fifteen minutes, so
    /// repeating it every suppression window would be nagging about something
    /// the user has already been told and cannot fix from a notification.
    public var isOncePerSession: Bool {
        switch self {
        case .fanAnomaly, .batteryHealth: true
        case .thresholdCrossed, .thermalState, .panicEngaged, .daemonLost, .profileChanged:
            false
        }
    }

    /// Whether several of these arriving together become one notification.
    ///
    /// Only threshold crossings coalesce, and the restriction is the point: the
    /// document's example is several thresholds crossed at the same moment, and
    /// merging *different* kinds would let a profile change bury a panic in the
    /// same envelope.
    public var coalesces: Bool {
        self == .thresholdCrossed
    }

    /// The triggers that are on once the user has enabled notifications.
    ///
    /// Straight from the table in `docs/operations/notifications.md`. Note what
    /// this is *not*: it is not a claim that notifications are on. The subsystem
    /// itself starts disabled — see `NotificationSettings.isEnabled`.
    public static let defaultEnabled: Set<NotificationKind> = [
        .thermalState, .panicEngaged, .fanAnomaly, .daemonLost, .batteryHealth,
    ]
}

/// A window of the day in which ordinary notifications are held back.
public struct QuietHours: Sendable, Hashable, Codable {

    /// Minutes from midnight, `0..<1440`.
    public let startMinuteOfDay: Int
    public let endMinuteOfDay: Int

    public init(startMinuteOfDay: Int, endMinuteOfDay: Int) {
        self.startMinuteOfDay = Self.wrap(startMinuteOfDay)
        self.endMinuteOfDay = Self.wrap(endMinuteOfDay)
    }

    /// Out-of-range minutes wrap rather than clamp: a hand-edited file asking
    /// for minute 1500 means 01:00 the next day, and clamping it to 23:59 would
    /// silently move somebody's quiet hours to a different time of night.
    private static func wrap(_ minute: Int) -> Int {
        ((minute % 1_440) + 1_440) % 1_440
    }

    /// Whether an instant falls inside the window.
    ///
    /// **Spans midnight when it needs to**, which is the case that matters:
    /// 22:00–07:00 is the shape almost everybody wants and the shape a naive
    /// `start <= now && now < end` gets exactly backwards, silencing the whole
    /// day instead of the night.
    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return false }
        let minuteOfDay = hour * 60 + minute

        if startMinuteOfDay == endMinuteOfDay {
            // An empty window, not a whole day. "Quiet from 22:00 to 22:00"
            // reads as a mistake, and the safe reading of a mistake here is
            // "notify", not "stay silent".
            return false
        }
        if startMinuteOfDay < endMinuteOfDay {
            return minuteOfDay >= startMinuteOfDay && minuteOfDay < endMinuteOfDay
        }
        return minuteOfDay >= startMinuteOfDay || minuteOfDay < endMinuteOfDay
    }
}

/// The user's notification settings, as they persist.
public struct NotificationSettings: Sendable, Hashable, Codable {

    /// **Off until the user asks.**
    ///
    /// Delivering a notification needs the user's permission, and asking for a
    /// permission at first launch is what this project has spent six phases not
    /// doing. The trigger defaults in the document describe which triggers fire
    /// *once notifications are on*; they are not a claim that the subsystem is.
    /// Same call as P6.10's shortcuts, which all start unset.
    public var isEnabled: Bool

    /// A notification of the same kind and subject does not repeat inside this
    /// window. Clamped to the document's 1–120 minutes by the type.
    public var suppressionWindowMinutes: Int

    public var enabledKinds: Set<NotificationKind>

    public var quietHours: QuietHours?

    /// Per-group temperature thresholds, in °C.
    ///
    /// **Empty by default, and that is the whole design of this trigger.** The
    /// document's table says the threshold trigger is off because *the user sets
    /// the threshold* — there is no sensible default, since what counts as hot
    /// depends on the machine and on what its owner is doing with it. A shipped
    /// default here would be the application inventing an opinion and then
    /// interrupting somebody with it.
    ///
    /// Clamped into the same range a curve accepts, so a hand-edited file cannot
    /// ask to be told about −40 °C.
    public var thresholds: [SensorGroup: Double]

    public static let suppressionWindowRange = 1...120

    /// The range a threshold may sit in — the published temperature range, so a
    /// threshold can be set anywhere a curve can have a point.
    public static let thresholdRange = Curve.temperatureRange

    public init(
        isEnabled: Bool = false,
        suppressionWindowMinutes: Int = 15,
        enabledKinds: Set<NotificationKind> = NotificationKind.defaultEnabled,
        quietHours: QuietHours? = nil,
        thresholds: [SensorGroup: Double] = [:]
    ) {
        self.isEnabled = isEnabled
        self.suppressionWindowMinutes = Self.clamp(suppressionWindowMinutes)
        self.enabledKinds = enabledKinds
        self.quietHours = quietHours
        self.thresholds = thresholds.mapValues {
            Swift.min(
                Self.thresholdRange.upperBound,
                Swift.max(Self.thresholdRange.lowerBound, $0))
        }
    }

    static func clamp(_ minutes: Int) -> Int {
        Swift.min(
            Self.suppressionWindowRange.upperBound,
            Swift.max(Self.suppressionWindowRange.lowerBound, minutes))
    }

    /// Declared rather than synthesised: writing `encode(to:)` by hand (see
    /// below) stops the compiler generating these.
    enum CodingKeys: String, CodingKey {
        case isEnabled
        case suppressionWindowMinutes
        case enabledKinds
        case quietHours
        case thresholds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Every field optional and defaulted: a file written before this
        // section existed has to decode, which is what keeps the schema
        // addition from needing a version bump.
        let rawThresholds =
            try container.decodeIfPresent([String: Double].self, forKey: .thresholds) ?? [:]
        var thresholds: [SensorGroup: Double] = [:]
        for (name, celsius) in rawThresholds {
            guard let group = SensorGroup(rawValue: name) else {
                // Refused, not dropped — the P6.10 rule for shortcuts, and for
                // the same reason: a threshold this build cannot honour would
                // otherwise produce silence with no explanation, and a
                // configuration that says one thing and does another is exactly
                // what the loader exists to prevent.
                throw DecodingError.dataCorruptedError(
                    forKey: .thresholds, in: container,
                    debugDescription: "unknown sensor group '\(name)'")
            }
            thresholds[group] = celsius
        }
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            suppressionWindowMinutes: try container.decodeIfPresent(
                Int.self, forKey: .suppressionWindowMinutes) ?? 15,
            enabledKinds: try container.decodeIfPresent(
                Set<NotificationKind>.self, forKey: .enabledKinds)
                ?? NotificationKind.defaultEnabled,
            quietHours: try container.decodeIfPresent(QuietHours.self, forKey: .quietHours),
            thresholds: thresholds
        )
    }

    /// Written as a JSON **object**, keyed by group name.
    ///
    /// Swift's synthesised `Codable` would encode `[SensorGroup: Double]` as an
    /// unkeyed alternating array — `["compute", 88]` — because a dictionary only
    /// becomes a JSON object when its key is literally `String` or `Int`. That
    /// round-trips perfectly and reads terribly, and this file is meant to be
    /// hand-editable: P6.14's finding was precisely that automatic profile
    /// switching had been reachable *only* by hand-editing it. So the mapping is
    /// written out by hand here.
    ///
    /// `shortcuts` has the same problem and predates this; it is recorded as a
    /// finding rather than changed here, because changing a shipped section's
    /// format is its own task.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(suppressionWindowMinutes, forKey: .suppressionWindowMinutes)
        try container.encode(enabledKinds, forKey: .enabledKinds)
        try container.encodeIfPresent(quietHours, forKey: .quietHours)
        var named: [String: Double] = [:]
        for (group, celsius) in thresholds {
            named[group.rawValue] = celsius
        }
        try container.encode(named, forKey: .thresholds)
    }
}

/// One thing that happened and might be worth telling the user about.
public struct NotificationEvent: Sendable, Hashable {

    public let kind: NotificationKind

    /// What the event is about, when the kind can be about more than one thing
    /// — the sensor group for a threshold crossing, the fan for an anomaly.
    ///
    /// Part of the suppression key, so two different groups crossing their
    /// thresholds are two notifications rather than one silencing the other.
    public let subject: String?

    public init(kind: NotificationKind, subject: String? = nil) {
        self.kind = kind
        self.subject = subject
    }
}

/// Why an event was not delivered. Kept rather than discarded: a subsystem that
/// silently drops things is one nobody can debug, and the diagnostics tab and
/// the drill both need to be able to say *which* mechanism swallowed what.
public enum NotificationWithholdReason: String, Sendable, Hashable {
    case notificationsDisabled
    case kindDisabled
    case suppressionWindow
    case alreadyThisSession
    case quietHours
}

/// What a batch of events turns into.
public struct NotificationDecision: Sendable, Equatable {

    /// One notification to post. `subjects` holds more than one entry only for
    /// a coalesced kind.
    public struct Delivery: Sendable, Equatable {
        public let kind: NotificationKind
        public let subjects: [String]
    }

    public struct Withheld: Sendable, Equatable {
        public let event: NotificationEvent
        public let reason: NotificationWithholdReason
    }

    public let deliver: [Delivery]
    public let withheld: [Withheld]
}

/// The noise control (P7.01).
///
/// **Why this is a value in `Core` and not logic in the notifier.** The
/// mechanisms in `docs/operations/notifications.md` — a suppression window, a
/// once-per-session rule, coalescing, quiet hours — are the whole substance of
/// the feature, and every one of them is a decision about *time* and *history*.
/// Testing them against a real `UNUserNotificationCenter` would mean waiting
/// fifteen minutes to find out whether the window works. Here it is a pure
/// function of (events, history, settings, now), and the fifteen minutes is one
/// line in a test.
///
/// The order the mechanisms run in is load-bearing and stated once, here:
///
/// 1. `isAlwaysDelivered` short-circuits everything below.
/// 2. The master switch, then the per-kind switch — a user who turned something
///    off should never see it, whatever the timing says.
/// 3. Quiet hours, then once-per-session, then the suppression window.
/// 4. Coalescing, over what survived.
///
/// Coalescing comes **last** on purpose: merging first would let one suppressed
/// event drag its surviving neighbours into a single envelope, and the
/// suppression key would then be ambiguous.
public struct NotificationPolicy: Sendable, Equatable {

    /// When each (kind, subject) was last delivered.
    private var lastDelivered: [String: Date]

    /// Kinds already delivered since launch, for the once-per-session rule.
    private var deliveredThisSession: Set<NotificationKind>

    public init() {
        lastDelivered = [:]
        deliveredThisSession = []
    }

    /// Decides a batch, and records what it delivered.
    ///
    /// `mutating` because the suppression window and the once-per-session rule
    /// are memory: the decision for the next batch depends on this one. Still
    /// deterministic — the same policy state and the same inputs give the same
    /// answer, which is what the tests rely on.
    public mutating func decide(
        on events: [NotificationEvent],
        settings: NotificationSettings,
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> NotificationDecision {
        var surviving: [NotificationEvent] = []
        var withheld: [NotificationDecision.Withheld] = []

        for event in events {
            if let reason = reasonToWithhold(
                event, settings: settings, now: now, calendar: calendar)
            {
                withheld.append(.init(event: event, reason: reason))
            } else {
                surviving.append(event)
            }
        }

        let deliveries = coalesce(surviving)

        // Recorded only for what is actually delivered. Recording a withheld
        // event would let a suppressed notification extend its own suppression
        // window — the bug that turns a fifteen minute silence into a permanent
        // one whenever a sensor oscillates faster than the window.
        for delivery in deliveries {
            deliveredThisSession.insert(delivery.kind)
            if delivery.subjects.isEmpty {
                lastDelivered[Self.key(kind: delivery.kind, subject: nil)] = now
            }
            for subject in delivery.subjects {
                lastDelivered[Self.key(kind: delivery.kind, subject: subject)] = now
            }
        }

        return NotificationDecision(deliver: deliveries, withheld: withheld)
    }

    private func reasonToWithhold(
        _ event: NotificationEvent,
        settings: NotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> NotificationWithholdReason? {
        // 1. Nothing below applies to these. See `isAlwaysDelivered`.
        if event.kind.isAlwaysDelivered { return nil }

        // 2. What the user switched off.
        guard settings.isEnabled else { return .notificationsDisabled }
        guard settings.enabledKinds.contains(event.kind) else { return .kindDisabled }

        // 3. Timing.
        if let quietHours = settings.quietHours, quietHours.contains(now, calendar: calendar) {
            return .quietHours
        }
        if event.kind.isOncePerSession, deliveredThisSession.contains(event.kind) {
            return .alreadyThisSession
        }
        if let last = lastDelivered[Self.key(kind: event.kind, subject: event.subject)] {
            let window = Double(settings.suppressionWindowMinutes) * 60
            if now.timeIntervalSince(last) < window { return .suppressionWindow }
        }
        return nil
    }

    /// Merges what merges, preserving first-seen order so the output is stable.
    private func coalesce(_ events: [NotificationEvent]) -> [NotificationDecision.Delivery] {
        var deliveries: [NotificationDecision.Delivery] = []
        var coalescedIndex: [NotificationKind: Int] = [:]

        for event in events {
            let subjects = event.subject.map { [$0] } ?? []
            guard event.kind.coalesces else {
                deliveries.append(.init(kind: event.kind, subjects: subjects))
                continue
            }
            if let index = coalescedIndex[event.kind] {
                var merged = deliveries[index].subjects
                // A repeated subject inside one batch is the same fact twice.
                for subject in subjects where !merged.contains(subject) {
                    merged.append(subject)
                }
                deliveries[index] = .init(kind: event.kind, subjects: merged)
            } else {
                coalescedIndex[event.kind] = deliveries.count
                deliveries.append(.init(kind: event.kind, subjects: subjects))
            }
        }
        return deliveries
    }

    private static func key(kind: NotificationKind, subject: String?) -> String {
        "\(kind.rawValue)|\(subject ?? "")"
    }
}
