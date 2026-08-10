import Core
import Foundation

/// The P7.01 drill: real state changes produce the right notifications, and the
/// noise control holds on the path the application actually uses.
///
/// **What this adds over `NotificationPolicyTests`.** Those tests prove the
/// policy — the suppression window, the session rule, coalescing, quiet hours —
/// against synthetic events, which is the right place for that. What they cannot
/// see is the wiring: whether the *edge detection* fires on the transitions it
/// should and stays silent on the ones it should not, and whether the model asks
/// for a permission it was told never to ask for at launch. That path runs
/// through `MonitorModel` and `ControlModel`, so it needs the application.
///
/// It drives a `RecordingNotificationSink` rather than the real one: delivering
/// to `UNUserNotificationCenter` needs a granted permission and puts banners on
/// the screen of whoever is running the drill, and neither is evidence.
@MainActor
enum NotificationDrill {

    static func run(report: (String) -> Void) {
        var passed = true
        func check(_ label: String, _ condition: Bool) {
            report("  \(condition ? "ok  " : "FAIL") \(label)")
            passed = passed && condition
        }

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("boreas-notification-drill", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        let store = ConfigurationStore(directory: directory)
        store.load()

        checkPermission(store: store, check: check)
        checkDelivery(store: store, check: check)
        checkPersistence(store: store, directory: directory, check: check)

        try? FileManager.default.removeItem(at: directory)
        report(passed ? "NOTIFICATION DRILL PASS" : "NOTIFICATION DRILL FAIL")
        exit(passed ? 0 : 1)
    }

    // MARK: - The permission

    /// Nothing is requested at launch, one request when the user asks, and a
    /// refusal turns the switch back off. This is the invariant the whole
    /// permission design rests on, and the one a future refactor is most likely
    /// to break by "helpfully" asking early.
    private static func checkPermission(
        store: ConfigurationStore, check: (String, Bool) -> Void
    ) {
        let sink = RecordingNotificationSink(authorization: .notAsked)
        let model = NotificationModel(sink: sink, store: store)
        model.refreshAuthorization()
        drainMainQueue()
        checkAsync(check, "no permission is requested at launch") {
            await sink.authorizationRequests == 0
        }

        store.update { $0.notifications.isEnabled = true }
        model.enableAndRequestPermission()
        drainMainQueue()
        checkAsync(check, "turning it on requests the permission, once") {
            await sink.authorizationRequests == 1
        }
        check("the model then reports the permission granted", model.authorization == .granted)

        // A refusal must not leave a switch reading "on" while macOS shows
        // nothing — that is the dishonesty this project is built against.
        let refusing = RecordingNotificationSink(authorization: .denied)
        let refused = NotificationModel(sink: refusing, store: store)
        store.update { $0.notifications.isEnabled = true }
        refused.enableAndRequestPermission()
        drainMainQueue()
        check(
            "a refused permission switches notifications back off",
            store.configuration.notifications.isEnabled == false)
    }

    // MARK: - Delivery on the real event path

    /// The edges, through `MonitorModel` and `ControlModel` rather than through
    /// synthetic events — which is the whole reason this exists beside
    /// `NotificationPolicyTests`.
    private static func checkDelivery(
        store: ConfigurationStore, check: (String, Bool) -> Void
    ) {
        let sink = RecordingNotificationSink(authorization: .granted)
        let model = NotificationModel(
            sink: sink, store: store, fixedAuthorizationForRendering: .granted)
        let monitor = MonitorModel(store: store)
        let control = ControlModel(monitor: monitor, store: store)

        store.update { $0.notifications.isEnabled = false }
        control.setLayerForDrill(nil)
        model.observe(monitor: monitor, control: control)
        control.setLayerForDrill(.panic)
        model.observe(monitor: monitor, control: control)
        drainMainQueue()
        checkAsync(check, "with notifications off, a panic is still delivered") {
            await sink.delivered.count == 1
        }

        // A level that stays put produces nothing more. This is the edge rule
        // the suppression window must not be relied on to cover.
        Task { await sink.reset() }
        drainMainQueue()
        for _ in 0..<10 {
            model.observe(monitor: monitor, control: control)
        }
        drainMainQueue()
        checkAsync(check, "a panic that persists is not announced ten more times") {
            await sink.delivered.isEmpty
        }

        // Quiet hours step aside for a panic and hold everything else.
        store.update {
            $0.notifications.isEnabled = true
            $0.notifications.quietHours = QuietHours(
                startMinuteOfDay: 0, endMinuteOfDay: 1_439)
            $0.notifications.enabledKinds = Set(NotificationKind.allCases)
        }
        Task { await sink.reset() }
        drainMainQueue()
        control.setLayerForDrill(nil)
        model.observe(monitor: monitor, control: control)
        control.setLayerForDrill(.panic)
        model.observe(monitor: monitor, control: control)
        drainMainQueue()
        checkAsync(check, "a panic is delivered inside quiet hours") {
            await sink.delivered.count == 1
        }
        checkAsync(check, "the panic notification carries a title and a body") {
            await sink.delivered.first.map { !$0.title.isEmpty && !$0.body.isEmpty } ?? false
        }
    }

    // MARK: - Persistence

    /// Settings survive a restart through the same store the interface uses, and
    /// a hostile file is clamped by the types — the P6.08 pattern.
    private static func checkPersistence(
        store: ConfigurationStore, directory: URL, check: (String, Bool) -> Void
    ) {
        store.update {
            $0.notifications.isEnabled = true
            $0.notifications.suppressionWindowMinutes = 42
            $0.notifications.thresholds[.compute] = 88
        }
        store.save(immediately: true)
        let reopened = ConfigurationStore(directory: directory)
        reopened.load()
        check(
            "the suppression window survived a restart",
            reopened.configuration.notifications.suppressionWindowMinutes == 42)
        check(
            "a threshold survived a restart",
            reopened.configuration.notifications.thresholds[.compute] == 88)

        let hostile = """
            {"schemaVersion":1,"notifications":{"isEnabled":true,\
            "suppressionWindowMinutes":99999,"thresholds":{"compute":900}}}
            """
        guard
            let data = try? JSONDecoder().decode(
                ConfigurationFile.self, from: Data(hostile.utf8))
        else {
            check("the hostile configuration decodes at all", false)
            return
        }
        check(
            "a 99999 minute suppression window is clamped to 120",
            data.notifications.suppressionWindowMinutes == 120)
        check(
            "a 900 °C threshold is clamped into the published range",
            (data.notifications.thresholds[.compute] ?? 0)
                <= NotificationSettings.thresholdRange.upperBound)
    }

    /// Runs the main queue until the `Task`s the model spawned have landed.
    ///
    /// The model does its permission and delivery work in detached tasks, which
    /// is right for an application and awkward for a drill: without this the
    /// checks would read the sink before anything had reached it. A short
    /// bounded spin rather than a sleep, so the drill stays quick.
    private static func drainMainQueue() {
        for _ in 0..<20 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    /// Bridges an `async` condition into the synchronous check list.
    private static func checkAsync(
        _ check: (String, Bool) -> Void,
        _ label: String,
        _ condition: @escaping @Sendable () async -> Bool
    ) {
        let semaphore = DispatchSemaphore(value: 0)
        // A box rather than a captured `var`: the value belongs to the task.
        final class Box: @unchecked Sendable { var value = false }
        let box = Box()
        Task.detached {
            box.value = await condition()
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            check("\(label) — timed out", false)
            return
        }
        check(label, box.value)
    }
}
