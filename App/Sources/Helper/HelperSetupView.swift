import SwiftUI

/// The fan control setup window.
///
/// Everything the installation will do is on screen **before** the install
/// button — which files are involved, where the system records the approval,
/// and how to take it all back. A user who closes this window without
/// clicking anything has lost nothing: monitoring keeps working (invariant I4).
struct HelperSetupView: View {

    static let windowID = "helper-setup"

    let model: HelperSetupModel

    /// When set, the view renders this phase instead of the model's.
    /// Used only by the `--render-setup` evidence command; the running app
    /// never passes it.
    var fixedPhaseForRendering: HelperSetupModel.Phase?

    private var phase: HelperSetupModel.Phase {
        fixedPhaseForRendering ?? model.phase
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                String(
                    localized: "setup.title",
                    defaultValue: "Fan Control Setup",
                    comment: "Title inside the helper setup window"
                )
            )
            .font(.title2)
            .fontWeight(.semibold)

            SetupDisclosure()

            Divider()

            actionArea

            Text(
                String(
                    localized: "setup.skip.note",
                    defaultValue: """
                        You can skip this entirely. Without the helper, Boreas remains \
                        a fully working temperature monitor.
                        """,
                    comment: "Reassurance under the setup actions; installing is optional (invariant I4)"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 460)
        .task {
            // Skipped for evidence rendering: onAppear may open an XPC
            // connection, and rendering a picture must not start a root
            // process as a side effect.
            if fixedPhaseForRendering == nil { model.onAppear() }
        }
    }

    // MARK: - Phase-dependent action area

    @ViewBuilder
    private var actionArea: some View {
        switch phase {
        case .idle:
            Button {
                model.install()
            } label: {
                Text(
                    String(
                        localized: "setup.install.button",
                        defaultValue: "Install Fan Control Helper",
                        comment: "Button that starts the helper installation"
                    )
                )
            }
            .buttonStyle(.borderedProminent)

        case .installing:
            progressRow(
                String(
                    localized: "setup.installing",
                    defaultValue: "Registering the helper…",
                    comment: "Progress text while the helper is being registered"
                )
            )

        case .awaitingApproval:
            approvalArea

        case .verifying:
            progressRow(
                String(
                    localized: "setup.verifying",
                    defaultValue: "Verifying the connection…",
                    comment: "Progress text while the app proves the helper connection end to end"
                )
            )

        case .ready(let fanCount):
            readyArea(fanCount: fanCount)

        case .removed:
            removedArea

        case .failed(let reason):
            failedArea(reason: reason)
        }
    }

    /// The System Settings hand-off (P3.05): explain the pending state, take
    /// the user straight to the right pane, and advance on our own once the
    /// approval lands — no "now go back and click refresh".
    private var approvalArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(
                    String(
                        localized: "setup.approval.explain",
                        defaultValue: """
                            macOS is waiting for your approval in System Settings. Boreas notices \
                            by itself once you allow it — leave this window open.
                            """,
                        comment: "Shown while the background item waits for approval in System Settings"
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "hourglass")
                    .foregroundStyle(Color.warningAccent)
            }
            .font(.callout)

            Button {
                model.openApprovalSettings()
            } label: {
                Text(
                    String(
                        localized: "setup.approval.open",
                        defaultValue: "Open System Settings",
                        comment: "Button that opens the Login Items pane where the approval is granted"
                    )
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func readyArea(fanCount: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label {
                Text(
                    String(
                        localized: "setup.ready",
                        defaultValue: "Helper installed and verified. It sees \(fanCount) fan(s).",
                        comment: """
                            Success line after installation; the number is how many fans \
                            the helper reports
                            """
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(.green)
            }
            .font(.callout)

            Spacer()

            Button(role: .destructive) {
                model.remove()
            } label: {
                Text(
                    String(
                        localized: "setup.remove.button",
                        defaultValue: "Remove…",
                        comment: "Button that unregisters the privileged helper"
                    )
                )
            }
        }
    }

    private var removedArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(
                    String(
                        localized: "setup.removed",
                        defaultValue: """
                            Helper removed. The background item is gone and the firmware \
                            controls the fans.
                            """,
                        comment: "Confirmation after the helper was unregistered"
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }
            .font(.callout)

            Button {
                model.install()
            } label: {
                Text(
                    String(
                        localized: "setup.reinstall.button",
                        defaultValue: "Install Again",
                        comment: "Button that reinstalls the helper after a removal"
                    )
                )
            }
        }
    }

    private func failedArea(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        String(
                            localized: "setup.failed",
                            defaultValue: "That did not work. The system said:",
                            comment: "Introduces the raw system error message after a failed step"
                        )
                    )
                    Text(verbatim: reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                // A failure is an error, and errors wear the product's one
                // red (docs/product/ui.md) — this was orange before the
                // design system drew that line.
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.panicAccent)
            }
            .font(.callout)

            Button {
                model.install()
            } label: {
                Text(
                    String(
                        localized: "setup.retry.button",
                        defaultValue: "Try Again",
                        comment: "Button that retries the helper installation after a failure"
                    )
                )
            }
        }
    }

    private func progressRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(verbatim: text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

/// The three sections shown **before** installation: what will happen, what
/// is written where, and how to undo it. Static by design — the promises made
/// here must not depend on any runtime state.
private struct SetupDisclosure: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section(
                heading: String(
                    localized: "setup.what.heading",
                    defaultValue: "What will happen",
                    comment: "Heading of the setup section explaining the effects of installing"
                ),
                bullets: [
                    (
                        "person.badge.key",
                        String(
                            localized: "setup.what.admin",
                            defaultValue: """
                                macOS asks an administrator to approve the helper — once. \
                                Boreas never sees the password.
                                """,
                            comment: "Setup bullet: single administrator approval (invariant I3)"
                        )
                    ),
                    (
                        "gearshape.2",
                        String(
                            localized: "setup.what.helper",
                            defaultValue: """
                                A helper service is registered. It runs with root privileges \
                                and is started by macOS on demand.
                                """,
                            comment: "Setup bullet: what the privileged helper is"
                        )
                    ),
                    (
                        "fan",
                        String(
                            localized: "setup.what.surface",
                            defaultValue: """
                                The helper only reads fan state and writes fan speeds within \
                                hardware limits. It accepts no files or commands and never \
                                touches the network.
                                """,
                            comment: """
                                Setup bullet: the helper's deliberately narrow surface \
                                (invariants M4-M6)
                                """
                        )
                    ),
                ]
            )

            section(
                heading: String(
                    localized: "setup.files.heading",
                    defaultValue: "What is written where",
                    comment: "Heading of the setup section listing file system effects"
                ),
                bullets: [
                    (
                        "shippingbox",
                        String(
                            localized: "setup.files.bundle",
                            defaultValue: """
                                The helper program and its launch definition already sit inside \
                                the Boreas app. Installing copies nothing into system folders.
                                """,
                            comment: "Setup bullet: SMAppService keeps the helper inside the app bundle"
                        )
                    ),
                    (
                        "checklist",
                        String(
                            localized: "setup.files.registry",
                            defaultValue: """
                                macOS records the approval in its background items database. \
                                The entry is visible in System Settings under Login Items & \
                                Extensions.
                                """,
                            comment: """
                                Setup bullet: the only system-side record is the background \
                                item registration
                                """
                        )
                    ),
                ]
            )

            section(
                heading: String(
                    localized: "setup.undo.heading",
                    defaultValue: "How to undo it",
                    comment: "Heading of the setup section explaining removal"
                ),
                bullets: [
                    (
                        "arrow.uturn.backward",
                        String(
                            localized: "setup.undo.button",
                            defaultValue: """
                                The Remove button on this screen unregisters the helper. The \
                                Terminal command “boreas uninstall --all” does the same and \
                                also deletes saved settings.
                                """,
                            comment: "Setup bullet: removal routes offered by the product"
                        )
                    ),
                    (
                        "shield",
                        String(
                            localized: "setup.undo.firmware",
                            defaultValue: """
                                You can also switch the item off in System Settings. The moment \
                                the helper is gone, the firmware controls the fans again — \
                                that is the safe state.
                                """,
                            comment: """
                                Setup bullet: System Settings route and the firmware fallback \
                                guarantee (G4)
                                """
                        )
                    ),
                ]
            )
        }
    }

    private func section(heading: String, bullets: [(symbol: String, text: String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: heading)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(bullets, id: \.text) { bullet in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    // A bullet glyph: it decorates the sentence beside
                    // it and adds nothing to it.
                    Image(systemName: bullet.symbol)
                        .frame(width: 16)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text(verbatim: bullet.text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
