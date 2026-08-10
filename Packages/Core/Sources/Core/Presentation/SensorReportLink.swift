import Foundation

/// The one-click unknown-sensor report (P7.09): a pre-filled issue URL the
/// application hands to the user's browser.
///
/// **Why this is built from an allowlist, like `SupportReport` and for a
/// sharper reason.** A pre-filled issue URL is not a document the user reads
/// and then decides to send — the query string reaches the server **the moment
/// the page loads**, before anything is submitted and whether or not the form
/// is ever completed. So "the user can review it first" is not a privacy
/// control here; the only control is what goes into the URL in the first place.
///
/// Every field below is therefore a **class of machine, never an instance of
/// one**: a model identifier every unit of that model shares, the chip's brand
/// string, the hardware's own sensor keys, and a fan count. The three values
/// P7.05 found worth naming — the drive serial, the account name inside every
/// path, and the machine name that is usually a person's — have no field here
/// and cannot be added to the query by accident, because the query is built
/// from this type and nothing else.
public enum SensorReportLink {

    /// Everything permitted to enter the URL. Adding a field here is a
    /// deliberate act and should be questioned in review, exactly as adding a
    /// `gate-names:policy-doc` marker is.
    public struct Facts: Sendable, Equatable {
        /// e.g. `Mac16,10` — shared by every unit sold.
        public let modelIdentifier: String
        /// The chip brand string, e.g. `Apple M4`. A class, not a serial.
        public let chip: String
        /// Raw hardware keys for the sensors the classifier could not place.
        /// `SensorReading.rawName` exists for this: it is what a maintainer
        /// needs, and it names a hardware register rather than a person.
        public let sensorNames: [String]
        public let fanCount: Int

        public init(
            modelIdentifier: String, chip: String, sensorNames: [String], fanCount: Int
        ) {
            self.modelIdentifier = modelIdentifier
            self.chip = chip
            self.sensorNames = sensorNames
            self.fanCount = fanCount
        }
    }

    /// The built link, plus what did not fit.
    public struct Link: Sendable, Equatable {
        public let url: String
        /// Sensor names dropped to stay inside the length budget. The caller
        /// must **say so** rather than let the report look complete — a
        /// truncation nobody mentions is the silent cap this project refuses
        /// everywhere else.
        public let omittedSensorCount: Int

        public init(url: String, omittedSensorCount: Int) {
            self.url = url
            self.omittedSensorCount = omittedSensorCount
        }
    }

    /// The issue form's field identifiers. They are the `id:` values in
    /// `.github/ISSUE_TEMPLATE/unknown_sensor.yml`; a form field is pre-filled
    /// by passing its id as a query parameter. Renaming one there without
    /// renaming it here silently stops pre-filling that field, which is what
    /// `templateFieldIdentifiers` lets a test pin.
    public static let templateName = "unknown_sensor.yml"
    public static let templateFieldIdentifiers = ["model", "chip", "sensors", "fans"]

    /// Practical ceiling for the whole URL.
    ///
    /// Servers commonly refuse a request line beyond 8 KB with `414`, and a
    /// silently rejected report is worse than a short one. 6 000 leaves room
    /// for the origin and the encoding overhead the sensor list attracts.
    public static let maximumURLLength = 6000

    /// Unreserved characters per RFC 3986. Everything else is escaped —
    /// including the comma in `Mac16,10`, the newline between sensor names and
    /// any `&` or `=` a hardware key might contain, none of which may be
    /// allowed to punctuate the query.
    private static let unreserved: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private static func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// Builds the pre-filled issue URL.
    ///
    /// - Parameter base: the repository address, supplied by the caller rather
    ///   than written here: the product name lives in `project.yml` and the
    ///   localisation catalogue, never in code (K2).
    /// - Returns: `nil` when there is nothing to report or no usable base, so
    ///   the caller cannot offer a button that would file an empty issue.
    public static func link(base: String, facts: Facts) -> Link? {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty, !facts.sensorNames.isEmpty else { return nil }

        let origin = trimmedBase.hasSuffix("/") ? String(trimmedBase.dropLast()) : trimmedBase
        var prefix = "\(origin)/issues/new?template=\(escape(templateName))"
        prefix += "&model=\(escape(facts.modelIdentifier))"
        prefix += "&chip=\(escape(facts.chip))"
        prefix += "&fans=\(escape(String(facts.fanCount)))"
        prefix += "&sensors="

        // Fit as many sensor names as the budget allows, in the order the
        // hardware reported them. Dropping the tail keeps the list a prefix of
        // the truth rather than a sample of it, so what is there can be trusted
        // and what is missing is counted.
        var encoded = ""
        var included = 0
        for name in facts.sensorNames {
            let separator = included == 0 ? "" : escape("\n")
            let candidate = encoded + separator + escape(name)
            if prefix.count + candidate.count > maximumURLLength { break }
            encoded = candidate
            included += 1
        }

        // Not even one name fits: the budget cannot describe this machine, and
        // a link with an empty sensor list would ask the user to file a report
        // saying nothing.
        guard included > 0 else { return nil }

        return Link(
            url: prefix + encoded,
            omittedSensorCount: facts.sensorNames.count - included)
    }
}
