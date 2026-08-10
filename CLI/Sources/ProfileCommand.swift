import Core
import Foundation
import SharedIPC

/// `boreas profile` (P7.04).
///
/// **A selection made here is live, never persisted — and that is a lesson, not
/// a limitation.** P6.14 found that a *standing* manual profile selection vetoes
/// every trigger forever, because arbitration's first rule is that a manual
/// choice beats everything; the application deliberately starts with none. A CLI
/// that wrote a selection into the configuration would re-introduce exactly that
/// bug, from outside, where nobody would think to look for it.
///
/// So changing the active profile asks the **running application** to do it,
/// through a distributed notification — local IPC between the user's own
/// processes, no network (P2) and no permission. When nothing is listening the
/// command says so plainly instead of silently persisting an override.
enum ProfileCommand {

    /// The notification the running application observes. Named after the bundle
    /// so it cannot collide with anything else on the machine.
    static let selectionNotification = Notification.Name(
        "\(BoreasIPC.clientBundleIdentifier).selectProfile")

    /// The key carrying the profile name; absent means "hand the decision back
    /// to the triggers".
    static let profileNameKey = "profileName"

    static func run(arguments: [String]) -> Int32 {
        let named = arguments.first { !$0.hasPrefix("-") }

        if arguments.contains("--auto") {
            post(profileName: nil)
            write(
                """
                asked the running app to hand the decision back to the triggers.
                nothing is written to disk — a selection made here lasts until the
                app decides otherwise or is restarted.

                """)
            return 0
        }

        guard let named else {
            return list()
        }

        // Checked against the configuration first, so a typo is refused here
        // rather than posted into the void.
        let configured = configuredProfiles()
        guard configured.isEmpty || configured.contains(where: { $0.name == named }) else {
            writeError(
                "no profile named '\(named)'. run 'boreas profile' to see them.\n")
            return 1
        }

        // Refused rather than attempted: driving fans needs the helper, and I4
        // says the application is a working monitor without it. A selection that
        // silently did nothing would leave the user with no way to tell why.
        if let profile = configured.first(where: { $0.name == named }), !profile.enginePaused,
            !helperIsInstalled()
        {
            writeError(
                """
                '\(named)' drives the fans, and the fan control helper is not installed.
                Set it up from the app first — Boreas works as a monitor without it.

                """)
            return 1
        }

        post(profileName: named)
        write(
            """
            asked the running app to activate '\(named)'.
            nothing is written to disk: a selection made here is live only, because a
            stored one would override every trigger for good.

            """)
        return 0
    }

    // MARK: - Listing

    private static func list() -> Int32 {
        let profiles = configuredProfiles()
        guard !profiles.isEmpty else {
            writeError(
                """
                no configuration found, so the built-in profiles are what would run.
                start the app once to write one.

                """)
            return 1
        }

        let fallback = configuredFallbackName()
        var output = "\n"
        for profile in profiles {
            let marker = profile.name == fallback ? "*" : " "
            let kind =
                profile.enginePaused
                ? "hands the fans to the firmware"
                : "\(profile.binding.input.group.rawValue), \(profile.binding.curve.points.count) points"
            // Padded by hand: `%-14@` does not pad an `NSString` on this
            // platform, which the first run of this command showed plainly.
            let padded = profile.name.padding(
                toLength: max(14, profile.name.count), withPad: " ", startingAt: 0)
            output += "  \(marker) \(padded) \(kind)\n"
        }
        output += "\n  * the fallback: what runs when no trigger and no choice apply\n"
        output += "  boreas profile <name>   activate one now (needs the app running)\n"
        output += "  boreas profile --auto   hand the decision back to the triggers\n\n"
        write(output)
        return 0
    }

    // MARK: - The configuration

    /// Reads the configuration through **`Core`'s own validating loader**, not by
    /// parsing JSON here. A CLI that accepted a document the application would
    /// refuse is a CLI that breaks the application.
    static func loadedConfiguration() -> ConfigurationFile? {
        guard let url = configurationURL(),
            let data = try? Data(contentsOf: url)
        else { return nil }
        let outcome = ConfigurationLoader.load(candidate: data)
        return outcome.problem == nil ? outcome.configuration : nil
    }

    static func configurationURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Boreas/config.json")
    }

    private static func configuredProfiles() -> [Profile] {
        loadedConfiguration()?.profiles ?? []
    }

    private static func configuredFallbackName() -> String? {
        loadedConfiguration()?.defaultProfileName
    }

    private static func helperIsInstalled() -> Bool {
        guard let app = AppBundle.locate(),
            let answer = app.run(argument: "--helper-status")
        else { return false }
        return answer.contains("enabled")
    }

    private static func post(profileName: String?) {
        var info: [AnyHashable: Any] = [:]
        if let profileName { info[profileNameKey] = profileName }
        // `deliverImmediately` because the user is waiting at a prompt: the
        // default coalescing would let the notification sit until the app next
        // becomes idle.
        DistributedNotificationCenter.default().postNotificationName(
            selectionNotification, object: nil, userInfo: info, deliverImmediately: true)
    }

    // MARK: - Output

    private static func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    private static func writeError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }
}
