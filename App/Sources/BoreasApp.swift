import Core
import SwiftUI

/// Menu bar entry point.
///
/// Boreas runs as an `LSUIElement` app: no Dock icon, no window on launch.
/// The real menu bar panel, the main window and the curve editor land in P6;
/// this scaffold exists so the target builds and the toolchain is proven.
@main
struct BoreasApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            Image(systemName: "fan")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Placeholder contents of the menu bar panel.
struct MenuBarContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "menubar.placeholder.title",
                    defaultValue: "Boreas",
                    comment: "Product name shown while the menu bar panel is still a scaffold"
                )
            )
            .font(.headline)

            Text(
                String(
                    localized: "menubar.placeholder.schema",
                    defaultValue: "Configuration schema v\(Boreas.configSchemaVersion)",
                    comment: "Diagnostic line proving the Core package is linked; removed in P6"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minWidth: 200, alignment: .leading)
    }
}
