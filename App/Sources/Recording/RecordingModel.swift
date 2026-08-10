import AppKit
import Core
import Foundation
import Observation

/// Drives the recorder from the monitor's cycle (P7.02).
///
/// **Recording runs on its own clock, not the monitor's.** The monitor samples
/// every two seconds because a live chart needs that; a file somebody will read
/// next week does not, and writing 43 200 lines a day when 8 640 would do is a
/// disk cost the user did not ask for. So `intervalSeconds` gates the writes and
/// defaults to ten.
@MainActor
@Observable
final class RecordingModel {

    private(set) var status = RecordingStatus()

    private let writer: RecordingWriter
    private let store: ConfigurationStore?
    private var lastWriteAt: Date?

    init(writer: RecordingWriter = RecordingWriter(), store: ConfigurationStore? = nil) {
        self.writer = writer
        self.store = store
    }

    private var settings: RecordingSettings {
        store?.configuration.recording ?? RecordingSettings()
    }

    /// One observation. Called from the monitor's cycle, and cheap when recording
    /// is off or the interval has not elapsed — which is the common case.
    func observe(monitor: MonitorModel, control: ControlModel, now: Date = Date()) {
        let settings = self.settings
        guard settings.isEnabled else { return }
        if let lastWriteAt,
            now.timeIntervalSince(lastWriteAt) < Double(settings.intervalSeconds)
        {
            return
        }
        lastWriteAt = now

        let record = RecordingRecord(
            timestamp: now,
            // `allReadings`, not the filtered list: a sensor the user hid is a
            // *display* choice (P6.08), and a recording that dropped it would be
            // missing data from the file somebody later uses to work out what
            // happened.
            sensors: Dictionary(
                monitor.allReadings.map { ($0.rawName, $0.celsius) },
                uniquingKeysWith: { first, _ in first }),
            fans: Dictionary(
                monitor.fans.map { ($0.id, $0.currentRPM) },
                uniquingKeysWith: { first, _ in first }),
            profileName: control.outcome?.profile.name ?? "System",
            safetyLayer: control.activeLayer,
            thermal: monitor.thermal)

        Task { [writer] in
            await writer.append(record, settings: settings)
            let latest = await writer.status
            await MainActor.run { self.status = latest }
        }
    }

    /// Reads the writer's status without writing anything, for the settings tab.
    func refreshStatus() {
        Task { [writer] in
            let latest = await writer.status
            let inventory = await writer.inventory()
            await MainActor.run {
                var merged = latest
                merged.fileCount = inventory.count
                merged.totalBytes = inventory.reduce(0) { $0 + $1.byteCount }
                self.status = merged
            }
        }
    }

    /// Closes the file so the last line is on disk. Called on quit, the same hook
    /// the configuration store flushes on — P6.14 found that a coalesced write
    /// followed by a quit was simply lost, and an open file handle is the same
    /// class of problem.
    func flushOnTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [writer] _ in
            // Synchronous on purpose: the process is going away, and a detached
            // task would not necessarily run before it does.
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                await writer.flush()
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 2)
        }
    }

    /// Opens the recordings directory in the Finder.
    ///
    /// The Diagnostics tab's "log access", deferred from P6.09. Revealing a
    /// directory needs no permission — it is the user's own folder and the act is
    /// theirs — so this stays inside the promise I2 makes.
    func revealInFinder() {
        Task { [writer] in
            let directory = await writer.recordingDirectory
            try? FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            await MainActor.run {
                NSWorkspace.shared.activateFileViewerSelecting([directory])
            }
        }
    }
}
