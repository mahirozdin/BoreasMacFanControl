import Core
import SwiftUI

/// What sits in the menu bar itself.
///
/// Kept to one temperature and one fan speed: the menu bar is shared with every
/// other application on the system, and a status item that sprawls is one the
/// user ends up hiding.
struct MenuBarLabel: View {
    let model: MonitorModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "fan")
            if let hottest = model.hottest {
                Text(verbatim: "\(Int(hottest.celsius.rounded()))°")
                    .monospacedDigit()
            }
            if let fan = model.fans.first, !fan.isPoweredOff {
                Text(verbatim: "\(fan.currentRPM)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
