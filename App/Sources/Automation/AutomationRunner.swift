import Core
import Foundation
import OSLog

/// Fires the user's automation hooks (P7.10,
/// [ADR 0015](../../../docs/architecture/adr/0015-automation-hooks-not-email.md)).
///
/// **What decides, and what does.** Whether a hook may run at all is
/// `AutomationSettings.runnable()` in `Core`, under unit test. This type only
/// carries out what that returned, and adds the two limits ADR 0015 asks for: a
/// timeout per hook and a ceiling on how many run at once.
///
/// **Hooks fire on notifications that were actually delivered**, not on every
/// event observed. That reuses P7.01's whole noise-control chain — the
/// suppression window, coalescing, the once-per-session rule and quiet hours —
/// so there is one mental model and one place to configure it rather than a
/// second set of switches that would drift from the first. The consequence
/// worth stating: quiet hours silence a webhook too. That is acceptable because
/// **the panic survives all five mechanisms** (P7.01), so the event that means
/// "your Mac is in trouble" reaches the hook whatever else is configured.
actor AutomationRunner {

    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "automation")
    private let webhook = WebhookSender()
    private let command = CommandRunner()

    private var inFlight = 0

    /// Outcomes, newest last, for the drill and the interface. Bounded: an
    /// unbounded record of every hook that ever ran is a memory leak with a
    /// diary.
    private(set) var recent: [String] = []
    private static let recentLimit = 20

    /// Runs every hook the settings permit for one event.
    ///
    /// Returns when they have all finished or timed out, so a caller that wants
    /// to know can wait; the application's own path does not.
    func fire(_ context: AutomationContext, settings: AutomationSettings) async {
        let hooks = settings.runnable()
        guard !hooks.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for hook in hooks {
                // **Dropped rather than queued.** Queueing is exactly the
                // runaway build-up ADR 0015 names: a slow endpoint plus a busy
                // machine would grow a backlog that outlives the reason for it.
                // A dropped hook is recorded, so it is visible rather than
                // merely absent.
                guard inFlight < settings.maximumConcurrent else {
                    note("skipped: \(settings.maximumConcurrent) already running")
                    continue
                }
                inFlight += 1
                group.addTask { [weak self] in
                    await self?.perform(hook, context: context, timeout: settings.timeoutSeconds)
                }
            }
            await group.waitForAll()
        }
    }

    private func perform(_ hook: AutomationHook, context: AutomationContext, timeout: Double) async {
        defer { inFlight -= 1 }
        switch hook {
        case .webhook(let url, let method, let template):
            let body = AutomationTemplate.expand(template, with: context)
            let result = await webhook.send(
                url: url, method: method, body: body, timeout: timeout)
            note("webhook \(result)")
        case .command(let path, let arguments):
            let expanded = arguments.map { AutomationTemplate.expand($0, with: context) }
            let result = await command.run(
                path: path, arguments: expanded, timeout: timeout)
            note("command \(result)")
        }
    }

    private func note(_ line: String) {
        recent.append(line)
        if recent.count > Self.recentLimit {
            recent.removeFirst(recent.count - Self.recentLimit)
        }
    }
}
