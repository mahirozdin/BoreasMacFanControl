import Core
import Foundation

/// The application's side of `boreas profile` (P7.04).
///
/// Its own file because `ControlModel.swift` reached its length budget — and the
/// seam is real: everything else in that type is the control path, while this is
/// one door into it from another process.
extension ControlModel {

    /// Listens for `boreas profile` (P7.04).
    ///
    /// The selection arrives as a distributed notification — local IPC between
    /// the user's own processes, no network (P2) and no permission — and is
    /// applied through **the same `select` and `selectAutomatic` the menu bar
    /// uses**. Anything else would let the two disagree about which profile is
    /// active, and the CLI would be lying about a machine the app is driving.
    ///
    /// Nothing is persisted, deliberately: P6.14 found that a standing manual
    /// selection vetoes every trigger for good, so a choice made from a terminal
    /// lasts exactly as long as one made from the menu.
    public func observeCommandLineSelections() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.bubiapps.boreas.selectProfile"),
            object: nil, queue: .main
        ) { [weak self] notification in
            // The `String?` is read out here, before the main-actor hop:
            // `Notification` is not `Sendable` and strict concurrency (T1) is
            // right to refuse it crossing. A `String` is.
            let requested = notification.userInfo?["profileName"] as? String
            guard let self else { return }
            MainActor.assumeIsolated {
                guard let requested else {
                    self.selectAutomatic()
                    return
                }
                self.select(profileName: requested)
            }
        }
    }
}
