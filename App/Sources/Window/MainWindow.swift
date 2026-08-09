import Core
import SwiftUI

/// The main window (P6.04, P6.05).
///
/// Two tabs for now — Monitoring and Control. Diagnostics is P6.09 and is
/// deliberately absent rather than present-but-empty: a tab that promises
/// checks it cannot run is the kind of thing the honesty rule exists to
/// prevent.
struct MainWindow: View {
    static let windowID = "main"

    let model: MonitorModel
    let control: ControlModel
    let setup: HelperSetupModel

    var body: some View {
        TabView {
            MonitoringTab(model: model, control: control)
                .tabItem {
                    Label {
                        Text(
                            String(
                                localized: "window.tab.monitoring", defaultValue: "Monitoring",
                                comment: "Main window tab showing temperatures and fan speeds"))
                    } icon: {
                        Image(systemName: "chart.xyaxis.line")
                    }
                }

            ControlTab(model: model, control: control, setup: setup)
                .tabItem {
                    Label {
                        Text(
                            String(
                                localized: "window.tab.control", defaultValue: "Control",
                                comment: "Main window tab showing the active profile and safety chain"))
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 580, idealHeight: 680)
    }
}
