import SwiftUI

/// Menu bar entry point.
///
/// Boreas runs as an `LSUIElement` app: no Dock icon, no window on launch.
/// Reading temperatures needs no privileges, so the monitor starts immediately
/// whether or not the privileged helper is ever installed (invariant İ4).
@main
struct BoreasApp: App {

    @State private var model = MonitorModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model)
                .task { model.start() }
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
