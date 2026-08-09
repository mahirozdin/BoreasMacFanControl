import Core
import SwiftUI

/// The uppercase section heading every panel section shares.
struct PanelSectionTitle: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

/// The profile picker (P6.02): one click switches, the context menu is the
/// temporary override, and the caption always says what is driving the fans
/// and why — neither the engine nor the safety chain acts invisibly.
struct ProfilePickerSection: View {
    let control: ControlModel
    let setup: HelperSetupModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelSectionTitle(
                text: String(
                    localized: "panel.section.profile",
                    defaultValue: "Profile",
                    comment: "Heading above the profile picker in the menu bar panel"
                )
            )

            HStack(spacing: 6) {
                // "Automatic" first, because it is the state that lets the
                // triggers decide — and without it a manual choice would
                // be a permanent veto on every one of them (P6.14).
                automaticChip
                ForEach(control.profiles, id: \.name) { profile in
                    profileChip(profile)
                }
            }

            if let caption = controlCaption {
                Text(verbatim: caption)
                    .font(.caption)
                    .foregroundStyle(captionColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let ending = overrideEnding {
                Text(verbatim: ending)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var automaticChip: some View {
        let isActive = control.manualSelection == nil
        return Button {
            control.selectAutomatic()
        } label: {
            HStack(spacing: 3) {
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(
                    String(
                        localized: "panel.profile.automatic", defaultValue: "Auto",
                        comment: "Profile picker choice that lets the triggers decide")
                )
                .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isActive ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.05),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(isActive ? Color.accentColor : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(
            String(
                localized: "panel.profile.automatic.help",
                defaultValue: "Let the profile triggers decide",
                comment: "Tooltip of the automatic choice in the profile picker"))
    }

    /// Selection is marked with a checkmark as well as colour — colour never
    /// carries information alone.
    private func profileChip(_ profile: Profile) -> some View {
        let isActive = control.outcome?.profile.name == profile.name
        return Button {
            choose(profile)
        } label: {
            HStack(spacing: 3) {
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(verbatim: profile.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isActive ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.05),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach([30, 60, 180], id: \.self) { minutes in
                Button {
                    choose(profile, minutes: minutes)
                } label: {
                    Text(
                        String(
                            localized: "panel.profile.override",
                            defaultValue: "For \(minutes) minutes",
                            comment: """
                                Context menu entry that activates a profile temporarily \
                                for the given number of minutes
                                """
                        )
                    )
                }
            }
        }
    }

    /// A driving profile is only selectable once the helper exists; until
    /// then the tap opens the setup window — a quiet offer, not an error
    /// (invariant I4). `System` never needs the helper.
    private func choose(_ profile: Profile, minutes: Int? = nil) {
        if !profile.enginePaused, setup.installerState != .enabled {
            openWindow(id: HelperSetupView.windowID)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        control.select(
            profileName: profile.name,
            until: minutes.map { Date().addingTimeInterval(Double($0) * 60) }
        )
    }

    private var controlCaption: String? {
        if let problem = control.lastProblem {
            return problem
        }
        switch control.activeLayer {
        case .panic:
            return String(
                localized: "panel.manual.layer.panic",
                defaultValue: "Panic: a sensor crossed the panic threshold — full speed is locked",
                comment: "Caption when the K3 panic layer is overriding the engine"
            )
        case .thermalCritical:
            return String(
                localized: "panel.manual.layer.critical",
                defaultValue: "Thermal state critical — full speed is forced",
                comment: "Caption when the K2 critical thermal state is overriding the engine"
            )
        case .thermalSerious:
            return String(
                localized: "panel.manual.layer.serious",
                defaultValue: "Thermal state serious — the floor is raised to 55%",
                comment: "Caption when the K2 serious thermal state raises the floor"
            )
        case nil:
            if control.isEngaged, let active = control.outcome?.profile {
                return String(
                    localized: "panel.profile.driving",
                    defaultValue: "Driving the fans on the \(active.displayName) curve",
                    comment: "Caption while the engine follows the named profile's curve"
                )
            }
            if control.outcome?.profile.enginePaused == true {
                return control.manualSelection == nil
                    ? String(
                        localized: "panel.profile.firmware.automatic",
                        defaultValue:
                            "No trigger holds, so the fans stay with the firmware",
                        comment:
                            "Caption in automatic mode when nothing has selected a driving profile")
                    : String(
                        localized: "panel.profile.firmware",
                        defaultValue: "The firmware is controlling the fans",
                        comment:
                            "Caption while the System profile leaves the fans with the firmware")
            }
            return nil
        }
    }

    /// Mirrors `controlCaption`'s precedence: whatever text is shown decides
    /// the colour. Errors and panic are the two states allowed to wear red
    /// (`docs/product/ui.md`); other safety overrides are warnings.
    private var captionColor: Color {
        if control.lastProblem != nil { return .panicAccent }
        switch control.activeLayer {
        case .panic: return .panicAccent
        case .thermalCritical, .thermalSerious: return .warningAccent
        case nil: return .secondary
        }
    }

    /// The second caption line, only while a timed override is running.
    private var overrideEnding: String? {
        guard case .manual(let until) = control.outcome?.reason, let until else {
            return nil
        }
        let time = until.formatted(date: .omitted, time: .shortened)
        return String(
            localized: "panel.profile.until",
            defaultValue: "Temporary override until \(time)",
            comment: "Shown while a profile override with an end time is active"
        )
    }
}

/// The fan rows (P6.02): name, the design-system fill, and the number beside
/// it — the gauge alone never carries the value.
struct FanListSection: View {
    let fans: [FanState]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelSectionTitle(
                text: String(
                    localized: "panel.section.fans",
                    defaultValue: "Fans",
                    comment: "Heading above the list of fans"
                )
            )
            ForEach(fans) { fan in
                HStack(spacing: 8) {
                    Text(verbatim: fan.name)
                        .font(.callout)
                    fanGauge(fan)
                    Spacer(minLength: 0)
                    if fan.isPoweredOff {
                        Text(
                            String(
                                localized: "panel.fan.parked",
                                defaultValue: "parked",
                                comment: "Shown when the firmware has switched a fan off entirely"
                            )
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: "\(fan.currentRPM) rpm")
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func fanGauge(_ fan: FanState) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                if !fan.isPoweredOff {
                    Capsule()
                        .fill(Color.fanFill(fan.currentDuty))
                        .frame(width: max(6, geometry.size.width * fan.currentDuty.value))
                }
            }
        }
        .frame(width: 90, height: 8)
    }
}

/// The grouped, collapsible temperature list (P6.02).
struct SensorGroupList: View {
    let model: MonitorModel

    @State private var expandedGroups: Set<SensorGroup>

    init(model: MonitorModel, initiallyExpanded: Set<SensorGroup> = []) {
        self.model = model
        _expandedGroups = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelSectionTitle(
                text: String(
                    localized: "panel.section.temperatures",
                    defaultValue: "Temperatures",
                    comment: "Heading above the grouped temperature list"
                )
            )
            // The scroll cap engages by row count, not by measured pixels: a
            // measured height needs a second layout pass, which the
            // single-pass render evidence never gets. Collapsed groups are a
            // dozen rows at most; only an expanded group (37 sensors on this
            // machine's compute group) can outgrow the panel.
            if expandedSensorRows > 12 {
                ScrollView {
                    list
                }
                .frame(height: 250)
            } else {
                list
            }
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(model.grouped, id: \.group) { entry in
                groupRows(entry.group, readings: entry.readings)
            }
        }
    }

    /// Sensor rows currently visible below the group headers — the measure
    /// that decides whether the list needs to scroll.
    private var expandedSensorRows: Int {
        model.grouped
            .filter { expandedGroups.contains($0.group) }
            .reduce(0) { $0 + $1.readings.count }
    }

    /// A hand-rolled disclosure row: `DisclosureGroup` draws nothing under
    /// `ImageRenderer`, which would blind the render evidence — and plain
    /// primitives also keep the compact look this panel wants.
    private func groupRows(_ group: SensorGroup, readings: [SensorReading]) -> some View {
        let isExpanded = expandedGroups.contains(group)
        return VStack(alignment: .leading, spacing: 3) {
            Button {
                if isExpanded {
                    expandedGroups.remove(group)
                } else {
                    expandedGroups.insert(group)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)
                    if let hottest = readings.first {
                        Circle()
                            .fill(Color.temperature(hottest.celsius))
                            .frame(width: 8, height: 8)
                        Text(verbatim: group.displayName)
                            .font(.callout)
                        Spacer()
                        Text(verbatim: String(format: "%.1f °C", hottest.celsius))
                            .font(.callout)
                            .monospacedDigit()
                        Text(verbatim: "(\(readings.count))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(readings, id: \.id) { reading in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.temperature(reading.celsius))
                            .frame(width: 7, height: 7)
                        Text(verbatim: reading.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .truncationMode(.middle)
                            .lineLimit(1)
                        Spacer()
                        Text(verbatim: String(format: "%.1f", reading.celsius))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding(.leading, 24)
                }
            }
        }
    }
}
