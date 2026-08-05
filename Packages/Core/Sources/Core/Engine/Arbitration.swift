import Foundation

/// The user's explicit choice, possibly time-limited
/// ("quiet for the next hour").
public struct ManualSelection: Sendable, Hashable, Codable {
    public let profileName: String
    /// `nil` means until further notice.
    public let until: Date?

    public init(profileName: String, until: Date? = nil) {
        self.profileName = profileName
        self.until = until
    }

    public func isActive(at now: Date) -> Bool {
        guard let until else { return true }
        return now < until
    }
}

/// Why the active profile is active. Carried all the way to the interface
/// (P6.05): "which trigger held" is the transparency the control tab owes
/// the user.
public enum ActivationReason: Sendable, Hashable {
    case manual(until: Date?)
    case trigger(ProfileTrigger)
    case fallback
}

/// Chooses the active profile
/// (`docs/product/control-model.md`, arbitration rules):
///
/// 1. A live manual selection beats everything.
/// 2. Otherwise the highest priority among the profiles whose trigger holds.
/// 3. On a tie, the one earlier in the list.
/// 4. If nothing holds, the default profile.
///
/// Rule 5 — no jumps at transitions — is not decided here: every target the
/// engine emits passes through the rate limiter, whoever won.
public enum Arbitration {

    public struct Outcome: Sendable, Hashable {
        public let profile: Profile
        public let reason: ActivationReason
    }

    public static func activeProfile(
        among profiles: [Profile],
        manual: ManualSelection?,
        environment: ProfileTrigger.Environment,
        defaultName: String = BuiltInProfiles.defaultName,
        now: Date
    ) -> Outcome? {
        guard !profiles.isEmpty else { return nil }

        // Rule 1 — manual wins while it lasts. A manual selection naming a
        // profile that no longer exists is ignored rather than honoured
        // blindly; the automatic rules below still produce an answer.
        if let manual, manual.isActive(at: now),
            let chosen = profiles.first(where: { $0.name == manual.profileName })
        {
            return Outcome(profile: chosen, reason: .manual(until: manual.until))
        }

        // Rules 2 and 3 — highest priority among holding triggers; the
        // stable iteration order makes "earlier in the list" the tiebreak.
        var best: (profile: Profile, trigger: ProfileTrigger)?
        for profile in profiles {
            guard let trigger = profile.holdingTrigger(in: environment) else {
                continue
            }
            if let current = best, current.profile.priority >= profile.priority {
                continue
            }
            best = (profile, trigger)
        }
        if let best {
            return Outcome(profile: best.profile, reason: .trigger(best.trigger))
        }

        // Rule 4 — the default, and if even that name is missing, the first
        // profile: a machine with profiles configured always has an answer.
        let fallback = profiles.first(where: { $0.name == defaultName }) ?? profiles[0]
        return Outcome(profile: fallback, reason: .fallback)
    }
}
