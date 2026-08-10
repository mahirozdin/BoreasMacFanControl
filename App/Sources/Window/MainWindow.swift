import Core
import SwiftUI

/// The main window (P6.04, P6.05).
///
/// Three tabs: Monitoring, Control and Diagnostics — the last arriving in
/// P6.09, once there were checks it could actually run. Until then it was
/// deliberately absent rather than present-but-empty.
struct MainWindow: View {
    static let windowID = "main"

    let model: MonitorModel
    let control: ControlModel
    let setup: HelperSetupModel
    var recording: RecordingModel?

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

            DiagnosticsTab(
                model: model, control: control, setup: setup,
                recording: recording
            )
            .tabItem {
                Label {
                    Text(
                        String(
                            localized: "window.tab.diagnostics", defaultValue: "Diagnostics",
                            comment: "Main window tab showing hardware checks and a summary"))
                } icon: {
                    Image(systemName: "stethoscope")
                }
            }
        }
        .frame(minWidth: 760, idealWidth: 860, minHeight: 580, idealHeight: 680)
    }
}
