import AppKit
import Core
import OSLog
import Observation
import SwiftUI

/// Watches whether the status item can actually be seen (P6.03).
///
/// The *decision* — off the bar, behind the notch, visible — is
/// `Core.StatusItemVisibility`, pure and unit tested. This model only feeds
/// it measurements and reacts to transitions: a log line always, stdout when
/// the drill asks for it, and the warning window once per run.
///
/// Measurement route: `MenuBarExtra` renders its label to an image, so a
/// view planted inside the label never joins a window and can measure
/// nothing (verified empirically — `viewDidMoveToWindow` never fires). The
/// status item's window still belongs to this process, so the model finds
/// it in `NSApp.windows` by class name and reads its frame — public API,
/// polled gently.
@MainActor
@Observable
final class StatusItemVisibilityModel {

    private(set) var concealment: StatusItemVisibility.Concealment = .visible

    /// The warning is worth one interruption per run, not a nag loop —
    /// crowding fluctuates as other apps come and go.
    private(set) var warnedThisRun = false

    /// Drill mode: `BOREAS_CONCEALMENT_STDOUT=1` prints measurements for the
    /// crowd drill and suppresses the warning window, which would block a
    /// headless run.
    private let reportsToStdout =
        ProcessInfo.processInfo.environment["BOREAS_CONCEALMENT_STDOUT"] != nil

    /// Launch grace: before the status window has ever been seen, "not
    /// found" means "not created yet", not "crowded out". Only after a
    /// sighting does a missing window count as concealment.
    private var hasSeenStatusWindow = false

    private var pollTimer: Timer?
    private var confirmTask: Task<Void, Never>?
    private var warningWindow: NSWindow?
    private let logger = Logger(subsystem: "com.bubiapps.boreas", category: "statusitem")

    /// How often the bar is re-measured. Crowding by other applications
    /// rearranges the bar without any notification this process receives,
    /// so polling is the mechanism, not a fallback. Three seconds is far
    /// below how fast a user reacts to a missing icon, and the work is a
    /// frame read.
    private static let pollInterval: TimeInterval = 3

    func beginMonitoring() {
        guard pollTimer == nil else { return }
        measure()
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.measure() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.measure() }
        }
    }

    /// Reads the status item's window frame and hands the numbers to Core.
    private func measure() {
        guard let window = Self.statusWindow() else {
            if hasSeenStatusWindow {
                update(item: nil, bar: StatusItemVisibility.Span(start: 0, width: 0), notch: nil)
            } else if reportsToStdout {
                FileHandle.standardOutput.write(
                    Data("measure: status window not created yet (launch grace)\n".utf8))
            }
            return
        }
        hasSeenStatusWindow = true
        guard let screen = window.screen ?? NSScreen.main else {
            update(item: nil, bar: StatusItemVisibility.Span(start: 0, width: 0), notch: nil)
            return
        }

        let frame = window.frame
        let screenFrame = screen.frame
        let item = StatusItemVisibility.Span(
            start: frame.minX - screenFrame.minX, width: frame.width)
        let bar = StatusItemVisibility.Span(start: 0, width: screenFrame.width)

        // The notch's dead span is the gap between the two auxiliary areas
        // macOS defines beside it; a screen without a notch has no such
        // areas and reports nil.
        var notch: StatusItemVisibility.Span?
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notch = StatusItemVisibility.Span(
                start: left.maxX - screenFrame.minX, width: right.minX - left.maxX)
        }

        update(item: item, bar: bar, notch: notch)
    }

    /// This process's own status bar window. The class is not public API,
    /// but the window is ours and its name is stable; if it is ever renamed
    /// the monitor degrades to silence, never to a false warning.
    private static func statusWindow() -> NSWindow? {
        NSApp.windows.first { String(describing: type(of: $0)).contains("StatusBarWindow") }
    }

    func update(
        item: StatusItemVisibility.Span?,
        bar: StatusItemVisibility.Span,
        notch: StatusItemVisibility.Span?
    ) {
        let verdict = StatusItemVisibility.assess(item: item, bar: bar, notch: notch)
        if reportsToStdout {
            // Drill mode traces every measurement, not only transitions —
            // raw numbers are what make a wrong reading diagnosable.
            let itemText = item.map { "[\(Int($0.start)),w\(Int($0.width))]" } ?? "nil"
            FileHandle.standardOutput.write(
                Data("measure: item=\(itemText) bar=w\(Int(bar.width)) -> \(verdict)\n".utf8))
        }
        guard verdict != concealment else { return }
        concealment = verdict

        let name: String
        switch verdict {
        case .visible: name = "visible"
        case .offBar: name = "offBar"
        case .behindNotch: name = "behindNotch"
        }
        logger.notice("status item concealment: \(name, privacy: .public)")
        if reportsToStdout {
            FileHandle.standardOutput.write(Data("concealment: \(name)\n".utf8))
        }

        if verdict == .visible {
            confirmTask?.cancel()
            confirmTask = nil
        } else {
            scheduleWarning()
        }
    }

    /// Marks the warning as delivered — the window calls this from either
    /// button, and a dismissed warning does not come back this run.
    func warningDelivered() {
        warnedThisRun = true
        warningWindow?.close()
        warningWindow = nil
    }

    /// A two-second confirmation: menu bar layout jitters while items come
    /// and go, and a warning for a concealment that lasted 200 ms would
    /// train the user to ignore it.
    private func scheduleWarning() {
        guard !warnedThisRun, !reportsToStdout, confirmTask == nil else { return }
        confirmTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            if self.concealment != .visible, !self.warnedThisRun {
                self.presentWarning()
            }
            self.confirmTask = nil
        }
    }

    /// A plain titled window, deliberately not a modal alert: a modal run
    /// loop would pause sampling and the heartbeat pump, and no warning is
    /// worth stalling the safety path.
    private func presentWarning() {
        guard warningWindow == nil else { return }
        let hosting = NSHostingController(
            rootView: StatusItemSpaceWarningView(visibility: self))
        let window = NSWindow(contentViewController: hosting)
        window.title = String(
            localized: "statusitem.window.title",
            defaultValue: "Menu Bar Space",
            comment: "Title of the window warning that the status item has no room"
        )
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        warningWindow = window
    }
}

/// The space-runs-out warning (blueprint §9.2): informs, offers compact
/// mode, and leaves.
struct StatusItemSpaceWarningView: View {
    let visibility: StatusItemVisibilityModel

    @AppStorage(StatusItemStyle.Keys.compact) private var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(
                    String(
                        localized: "statusitem.warning.title",
                        defaultValue: "The menu bar is out of room",
                        comment: "Title of the warning shown when the status item is pushed out"
                    )
                )
                .font(.headline)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.warningAccent)
            }

            Text(
                String(
                    localized: "statusitem.warning.body",
                    defaultValue: """
                        The Boreas status item does not fit in the visible part of \
                        the menu bar right now, so its numbers cannot be seen. \
                        Compact mode makes the item narrower.
                        """,
                    comment: "Body of the warning shown when the status item is pushed out"
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button {
                    visibility.warningDelivered()
                } label: {
                    Text(
                        String(
                            localized: "statusitem.warning.later",
                            defaultValue: "Not Now",
                            comment: "Dismisses the out-of-room warning without changes"
                        )
                    )
                }
                Button {
                    compact = true
                    visibility.warningDelivered()
                } label: {
                    Text(
                        String(
                            localized: "statusitem.warning.compact",
                            defaultValue: "Use Compact Mode",
                            comment: "Switches the status item to compact mode from the warning"
                        )
                    )
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
