import Foundation

/// Turns raw hardware sensor names into something a person can read, and files
/// them into groups a fan curve can bind to.
///
/// Two decisions shape this type:
///
/// The mapping is **pattern based, not a per-model table**. Sensor names change
/// between chip generations, and a table would need a release for every new
/// Mac. Patterns describe what the names mean, so a new generation that follows
/// existing conventions works without a code change.
///
/// Anything unmatched is **surfaced, not swallowed**. An unmapped sensor lands
/// in ``SensorGroup/uncategorized`` and stays visible in the interface. It is
/// the only signal that hardware support is incomplete, and hiding it would
/// trade a small cosmetic win for the ability to ever find out.
public enum SensorClassifier: Sendable {

    // MARK: - Normalisation

    /// Expansions applied to whole words, longest first so that a short entry
    /// never eats the prefix of a longer one.
    private static let expansions: [(pattern: String, replacement: String)] = [
        ("pmgr", "Power Manager"),
        ("pacc", "Performance Cluster"),
        ("eacc", "Efficiency Cluster"),
        ("gpu", "GPU"),
        ("cpu", "CPU"),
        ("soc", "SoC"),
        ("ssd", "SSD"),
        ("nand", "NAND"),
        ("pmu", "PMU"),
        ("mtr", "Sensor"),
        ("prox", "Proximity"),
        ("amb", "Ambient"),
        ("temp", "Temperature"),
        ("tdev", "Device"),
        ("tdie", "Die"),
        ("batt", "Battery"),
        ("wifi", "Wi-Fi"),
        ("nw", "Network"),
    ]

    /// Produces a readable name from whatever the hardware reported.
    ///
    /// Raw names arrive in several shapes — `pACC MTR Temp Sensor1`,
    /// `gas gauge battery`, `TG0D` — so the transform stays conservative:
    /// split, expand known abbreviations, tidy spacing. It never invents
    /// meaning it cannot support.
    public static func normalize(rawName: String) -> String {
        // A bare SMC key means something to whoever reports it. Expanding it
        // would invent meaning the code cannot support.
        if looksLikeSMCKey(rawName) { return rawName }

        let separated =
            rawName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        let words =
            separated
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        let expanded = words.map { word -> String in
            let lowered = word.lowercased()
            if let match = expansions.first(where: { $0.pattern == lowered }) {
                return match.replacement
            }
            // Trailing digits read better with a space: "Sensor1" -> "Sensor 1"
            if let split = splitTrailingDigits(word) {
                let head = expansions.first { $0.pattern == split.head.lowercased() }
                return (head?.replacement ?? capitalizeIfPlain(split.head)) + " " + split.digits
            }
            return capitalizeIfPlain(word)
        }

        let joined = expanded.joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)

        return joined.isEmpty ? rawName : joined
    }

    private static func splitTrailingDigits(_ word: String) -> (head: String, digits: String)? {
        let digits = word.reversed().prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count < word.count else { return nil }
        let head = String(word.dropLast(digits.count))
        return (head, String(digits.reversed()))
    }

    /// Leaves names that already carry their own casing alone. `TG0D` and
    /// `PMGR` mean something to whoever reports them; "Tg0d" means nothing.
    private static func capitalizeIfPlain(_ word: String) -> String {
        let hasInnerUppercase = word.dropFirst().contains { $0.isUppercase }
        if hasInnerUppercase { return word }
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst().lowercased()
    }

    // MARK: - SMC key heuristics

    /// Two character prefixes used by Apple Silicon SMC temperature keys.
    ///
    /// The SMC namespace is opaque: keys look like `TpMz` or `Tg0D`, not
    /// `pACC MTR Temp Sensor1`. Readable names come from the HID sensor
    /// interface; the SMC is the fallback, and without these prefixes every
    /// sensor on that path would land in ``SensorGroup/uncategorized`` — 174 of
    /// them on the development machine, which is technically honest and
    /// practically useless.
    ///
    /// Prefixes are a documented convention rather than a per-model table, so
    /// they survive new chip generations that follow the same scheme. They are
    /// a *heuristic*: a key that does not match still shows up uncategorised
    /// rather than being forced into a group it may not belong to.
    private static let smcPrefixes: [(prefix: String, group: SensorGroup)] = [
        ("Tp", .computePerformance),  // performance cluster
        ("TP", .computePerformance),
        ("Te", .computeEfficiency),  // efficiency cluster
        ("TE", .computeEfficiency),
        ("Tg", .graphics),  // graphics
        ("TG", .graphics),
        ("Ts", .chassis),  // skin and enclosure
        ("TS", .chassis),
        ("Tm", .memory),
        ("TM", .memory),
        ("TH", .storage),  // NAND and disk
        ("TB", .battery),
        ("Tb", .battery),
        ("TW", .wireless),
        ("TA", .airflow),  // ambient and airflow
        ("Ta", .airflow),
        ("TV", .power),  // regulators
        ("TR", .power),
        ("TC", .computePerformance),  // legacy CPU naming
        ("TZ", .chassis),
        ("Tz", .chassis),
    ]

    /// True when a name looks like a bare SMC key rather than a description:
    /// exactly four characters, starting with `T`, no spaces.
    static func looksLikeSMCKey(_ name: String) -> Bool {
        name.count == 4
            && name.hasPrefix("T")
            && !name.contains(" ")
            && name.allSatisfy { $0.isLetter || $0.isNumber }
    }

    private static func smcGroup(for key: String) -> SensorGroup? {
        let prefix = String(key.prefix(2))
        return smcPrefixes.first { $0.prefix == prefix }?.group
    }

    // MARK: - Grouping

    /// Substring patterns checked in order. First match wins, so the more
    /// specific entries come first — `efficiency` has to be tested before the
    /// generic `cpu`, or every efficiency cluster would be filed as performance.
    private static let rules: [(needles: [String], group: SensorGroup)] = [
        (["eacc", "efficiency", "ecpu", "e-core"], .computeEfficiency),
        (["pacc", "performance", "pcpu", "p-core"], .computePerformance),
        (["gpu", "graphics"], .graphics),
        (["dram", "memory", "lpddr"], .memory),
        (["ssd", "nand", "nvme", "flash", "disk", "drive"], .storage),
        (["battery", "gas gauge", "charger"], .battery),
        (["pmgr", "pmu", "power", "vrm"], .power),
        (["airflow", "fin stack", "heatsink", "exhaust", "intake"], .airflow),
        (["wifi", "wi-fi", "wireless", "airport", "bluetooth"], .wireless),
        (["palm", "trackpad", "keyboard", "enclosure", "case", "chassis", "ambient"], .chassis),
        (["cpu", "soc", "die", "core"], .computePerformance),
    ]

    /// Files a sensor into a group. Matching is done on the raw name because
    /// normalisation can expand an abbreviation the rules rely on.
    public static func group(rawName: String) -> SensorGroup {
        // Descriptive names are matched first: they carry real meaning, and a
        // four letter code that happens to look like a word should not win.
        let haystack = rawName.lowercased()
        for rule in rules where rule.needles.contains(where: haystack.contains) {
            return rule.group
        }
        if looksLikeSMCKey(rawName), let group = smcGroup(for: rawName) {
            return group
        }
        return .uncategorized
    }

    // MARK: - Combined

    /// Builds a reading, applying both normalisation and grouping.
    ///
    /// `overrides` lets a user rename or re-file any sensor from configuration,
    /// which is how someone with unusual hardware fixes their own machine
    /// without waiting for a release.
    public static func makeReading(
        rawName: String,
        celsius: Double,
        overrides: [String: SensorOverride] = [:]
    ) -> SensorReading {
        let override = overrides[rawName]
        return SensorReading(
            rawName: rawName,
            displayName: override?.displayName ?? normalize(rawName: rawName),
            group: override?.group ?? group(rawName: rawName),
            celsius: celsius
        )
    }
}

/// User supplied correction for a single sensor.
public struct SensorOverride: Sendable, Hashable, Codable {
    public let displayName: String?
    public let group: SensorGroup?

    public init(displayName: String? = nil, group: SensorGroup? = nil) {
        self.displayName = displayName
        self.group = group
    }
}
