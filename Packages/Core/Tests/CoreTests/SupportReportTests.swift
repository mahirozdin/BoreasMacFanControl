import Foundation
import Testing

@testable import Core

/// The support report (P7.05).
///
/// **Almost every test here is about something not being in the file.** The
/// report exists to be attached to a public issue, so the failure that matters is
/// a leak, and the three things there are to leak were each found rather than
/// imagined: the drive's serial number (which sits beside its model in the IO
/// registry), the account name inside any absolute path, and the machine's name,
/// which is usually a person's.
@Suite("Support report (an allowlist, and the leaks it has to refuse)")
struct SupportReportTests {

    private static let moment = Date(timeIntervalSince1970: 1_800_000_000)

    /// The three real values this machine would leak, used as the forbidden set.
    private static let secrets = [
        "0ba028e404b43624",  // the drive serial the P7.03 probe turned up
        "mahirtahaozdin",  // an account name, as it appears in a path
        "Mahir's Mac mini",  // a machine name, as macOS forms it
    ]

    private static func report(
        configurationJSON: String = "{\"schemaVersion\":1}",
        diagnosticLines: [String] = ["Fan response: the fans followed their targets"],
        logLines: [String] = ["control: engaged"]
    ) -> SupportReport {
        SupportReport(
            generatedAt: moment,
            system: SupportReport.System(
                modelIdentifier: "Mac16,10", macOSVersion: "26.0", appVersion: "0.1.0",
                coreCount: 10, memoryGigabytes: 16),
            hardware: SupportReport.Hardware(
                sensorCount: 40,
                sensors: [
                    SupportReport.ReportedSensor(
                        rawName: "PMU tdie5", group: .compute, celsius: 62.4),
                    SupportReport.ReportedSensor(
                        rawName: "NAND CH0 temp", group: .storage, celsius: 41.5),
                ],
                fans: [
                    SupportReport.ReportedFan(
                        id: 0, minimumRPM: 1_000, maximumRPM: 4_900, currentRPM: 1_608)
                ],
                driveModel: "APPLE SSD AP0256Z",
                driveFirmware: "2973.120"),
            configurationJSON: configurationJSON,
            diagnosticLines: diagnosticLines,
            logLines: logLines)
    }

    // MARK: - The leaks

    @Test("a clean report contains none of the three values that would identify anybody")
    func cleanReportLeaksNothing() {
        let text = Self.report().markdown()
        #expect(SupportReport.leaks(in: text, forbidden: Self.secrets).isEmpty)
    }

    @Test("the drive's serial number is never rendered, even though its model is")
    func serialIsNotIncluded() {
        // The two sit side by side in the IO registry, so including one and not
        // the other is a decision the type has to make rather than a habit the
        // caller has to remember. `Hardware` has no serial field at all.
        let text = Self.report().markdown()
        #expect(text.contains("APPLE SSD AP0256Z"), "the model is useful and should be there")
        #expect(!text.contains("0ba028e404b43624"))
        #expect(text.contains("serial number deliberately omitted"))
    }

    @Test("an account name inside a path is redacted, and the shape of the path survives")
    func accountNameIsRedacted() {
        // The path is often the useful part — that something was under Application
        // Support, say — so the name goes and the shape stays.
        let redacted = SupportReport.redacted(
            "could not write /Users/mahirtahaozdin/Library/Application Support/Boreas/config.json")
        #expect(!redacted.contains("mahirtahaozdin"))
        #expect(redacted.contains("/Users/<redacted>/Library/Application Support"))
    }

    @Test("redaction survives several paths in one line")
    func redactionHandlesRepeats() {
        let redacted = SupportReport.redacted(
            "copied /Users/alice/a.json to /Users/alice/b.json")
        #expect(!redacted.contains("alice"))
        #expect(redacted.components(separatedBy: "<redacted>").count == 3)
    }

    @Test("a leak planted in every free-text section is caught by the audit")
    func auditCatchesPlantedLeaks() {
        // The audit is what makes "built from an allowlist" a checked claim. Each
        // section that carries text the App layer supplies gets a secret planted
        // in it, and the audit has to find every one — otherwise a future section
        // could carry a leak past it silently.
        let inLog = Self.report(logLines: ["failed for \(Self.secrets[0])"]).markdown()
        #expect(SupportReport.leaks(in: inLog, forbidden: Self.secrets) == [Self.secrets[0]])

        let inDiagnostics = Self.report(
            diagnosticLines: ["sensor on \(Self.secrets[2])"]
        ).markdown()
        #expect(!SupportReport.leaks(in: inDiagnostics, forbidden: Self.secrets).isEmpty)

        let inConfiguration = Self.report(
            configurationJSON: "{\"defaultProfileName\":\"\(Self.secrets[1])\"}"
        ).markdown()
        #expect(!SupportReport.leaks(in: inConfiguration, forbidden: Self.secrets).isEmpty)
    }

    @Test("the audit does not fire on an empty forbidden value")
    func auditIgnoresEmptyCandidates() {
        // Reachable: the App layer builds the forbidden list from things like the
        // machine name, which can come back empty. An empty needle matches
        // everything, so it would report every report as leaking.
        let text = Self.report().markdown()
        #expect(SupportReport.leaks(in: text, forbidden: ["", "  "]).isEmpty == true)
    }

    // MARK: - What the report is for

    @Test("the hardware map is present, because that is what an R8 report is for")
    func hardwareMapIsIncluded() {
        // The reason this file exists at all: a machine this project cannot test
        // reporting what its sensors are called and how they were grouped.
        let text = Self.report().markdown()
        #expect(text.contains("PMU tdie5"))
        #expect(text.contains("compute"))
        #expect(text.contains("NAND CH0 temp"))
        #expect(text.contains("1000–4900 rpm"))
    }

    @Test("the report states plainly that nothing was uploaded")
    func reportSaysItIsLocal() {
        // The one sentence a user has to be able to trust before attaching it
        // anywhere, and the reason there is no automatic submission at all.
        let text = Self.report().markdown()
        #expect(text.contains("nothing here was uploaded"))
    }

    @Test("no machine name field exists to be forgotten")
    func thereIsNoMachineNameField() {
        // A structural assertion rather than a textual one: `System` has five
        // fields and none of them can hold a machine name, so no caller can
        // supply one by accident.
        let text = Self.report().markdown()
        #expect(text.contains("No machine name, no serial number and no account name"))
    }

    @Test("an empty report still renders rather than producing nothing")
    func emptyReportRenders() {
        let bare = SupportReport(
            generatedAt: Self.moment,
            system: SupportReport.System(
                modelIdentifier: "unknown", macOSVersion: "unknown", appVersion: "0.1.0",
                coreCount: 0, memoryGigabytes: 0),
            hardware: SupportReport.Hardware(
                sensorCount: 0, sensors: [], fans: [], driveModel: nil, driveFirmware: nil),
            configurationJSON: "{}",
            diagnosticLines: [],
            logLines: [])
        let text = bare.markdown()
        #expect(text.contains("No checks ran"))
        #expect(text.contains("No log lines were collected"))
        #expect(!text.isEmpty)
    }
}
