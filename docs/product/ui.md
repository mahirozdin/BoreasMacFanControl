# User Interface

> Last updated: 2026-08-10 — P6.11, P6.14
> Source: blueprint §9

## Design language

The visual identity is designed from scratch. Binding decisions:

| Element | Decision |
|---|---|
| Base approach | macOS 26 design language; system materials, SF Pro, system accent colour |
| Colour system | **Separate scales for temperature and fans.** Temperature: cool blue → neutral → warm orange, a **continuous** transition. Fans: neutral grey fill. Red is reserved **only** for panic/error |
| Why a continuous scale | A discrete three colour band contradicts the continuous curve philosophy. Continuous data is visualised continuously |
| Iconography | SF Symbols; the only custom icon is the application icon |
| Application icon | Original, a **four blade fan** + hub; cool blue gradient. Source and rationale: [`Design/icon/`](../../Design/icon/README.md) |
| Dark/light | Both are first class |
| Animation | Only those that carry meaning; no decorative animation |

> **Decision change (2026-08-03):** This table previously said "the fan blade cliché is avoided". The project owner explicitly asked for a fan motif, and that decision was applied. The cliché risk is answered by the originality of the geometry: wide swept blades, parametrically defined, with every number justified. Details in `Design/icon/README.md`.

**Implementation (P6.01):** the colour decisions — ramp stops, anchor temperatures with their rationale, the fan fill floor — live as pure maths in [`Packages/Core/Sources/Core/Presentation/ColorScale.swift`](../../Packages/Core/Sources/Core/Presentation/ColorScale.swift), under property tests (continuity, monotone warmth, red exclusion, the banded-scale comparison that keeps the "why continuous" decision measurable). The SwiftUI realisation is [`App/Sources/Design/DesignSystem.swift`](../../App/Sources/Design/DesignSystem.swift); views take colours only from there. Visual evidence renders deterministically with the app's `--render-design <dir>` maintenance argument (both appearances, no screen recording permission).

**Text principle:** All interface text is written from scratch. The Turkish text does not read like a translation — it is written thinking in Turkish, with the English written separately. → `docs/development/localization.md`

## Menu bar

**Status item:** configurable content (primary/secondary temperature, fan RPM, mini chart) · horizontal or vertical · compact mode · active profile indicator · a visible but unobtrusive indicator while fan control is active · informing the user when space runs out (notch included).

**Implementation (P6.03):** [`App/Sources/MenuBar/MenuBarLabel.swift`](../../App/Sources/MenuBar/MenuBarLabel.swift) reads its layout from the `statusItem.*` defaults keys in [`StatusItemStyle.swift`](../../App/Sources/MenuBar/StatusItemStyle.swift) (the P6.08 Appearance tab edits the same keys). The space warning's concealment *decision* is pure maths in [`Core/Presentation/StatusItemVisibility.swift`](../../Packages/Core/Sources/Core/Presentation/StatusItemVisibility.swift) under unit tests; [`StatusItemVisibilityMonitor.swift`](../../App/Sources/MenuBar/StatusItemVisibilityMonitor.swift) feeds it window-frame measurements (`MenuBarExtra` renders its label to an image, so measurement happens at app level, not in the label). Render evidence: `--render-status <dir>`; the crowded-bar leg is proven empirically with `--crowd-menubar`.

**Drop-down panel:** profile picker (one click switch + temporary override) · fans (name, RPM, fill) · temperatures (grouped, collapsible) · main window / settings / quit.

The sampling loop does **not stop** while the panel is open.

**Implementation (P6.02):** [`App/Sources/MenuBar/MenuBarPanel.swift`](../../App/Sources/MenuBar/MenuBarPanel.swift) with its sections in [`PanelSections.swift`](../../App/Sources/MenuBar/PanelSections.swift); profile selection drives the P5 engine through `ControlModel` (arbitration + `Engine.step`, safety chain always in the path). The footer's main-window and settings entries arrive with those windows (P6.04, P6.08). Render evidence: the app's `--render-panel <dir>` maintenance argument.

## Main window

**① Monitoring** — summary cards · time series chart (Swift Charts, 5 min/1 h/6 h/24 h) · **fan RPM chart on the same time axis** (temperature and response align visually) · sensor table · reset maximums.

**② Control** — the active profile **and why it is active** (which trigger held — transparency matters) · curve editor · fan↔sensor group mapping · manual override (with a duration picker) · safety chain status.

**③ Diagnostics** — the checks in `docs/operations/diagnostics.md` · system and hardware summary · log access · **local** support report (no automatic upload).

**Implementation (P6.09):** the tab is built with the four checks whose inputs already exist, the discovered-hardware summary, and the honesty rule enforced by `Core.Diagnostic` rather than by careful writing → [`docs/operations/diagnostics.md`](../operations/diagnostics.md). Log access and the support report are **not** in it: log files arrive with P7.02 and the report generator with P7.05, and both tasks own their part of this tab. Evidence: `--render-window` (the tab in both appearances, showing all four verdicts) and `--diagnostics-drill` (a healthy fan is not accused).

**Implementation (P6.04, P6.05):** [`App/Sources/Window/`](../../App/Sources/Window/) — `MainWindow` carries three tabs; Diagnostics joined them in P6.09, once there were checks it could actually run. The charts share **one x domain computed once and handed to both**, which is what makes a temperature rise and the fan's answer readable as cause and effect. Chart history lives in [`Core/Presentation/TimeSeries.swift`](../../Packages/Core/Sources/Core/Presentation/TimeSeries.swift), which spends resolution rather than span when it fills up — a "24 hour" window that had quietly become "the last few minutes" would be a chart that lies by omission. Series identity uses `Core.SeriesPalette` (categorical hue, still no red); fans stay neutral because the y-axis already says how fast. Render evidence: `--render-window <dir>`; the manual override's "expiry returns to the engine, not the firmware" rule is proven on hardware by `--override-drill`.

## Curve editor

The product's signature interface.

- X: temperature, Y: duty cycle; draggable control points
- Double click to add, right click to delete; **the monotonicity constraint is enforced while dragging**
- **Live layers:** the current operating point · the trace of the last 60 s (a faint cloud — comparing real behaviour against the curve) · the hysteresis band shadow
- **Numeric editing:** every point can also be entered from a table (accessibility + precision)
- Ready-made templates · undo/redo
- Live parameters in the side panel (hysteresis, smoothing, rise/fall rate) reflect instantly in the chart

**Implementation (P6.06, P6.07):** the monotonicity constraint is enforced by **clamping the input**, not by validating the result — the editing operations in [`Core/Engine/CurveEditing.swift`](../../Packages/Core/Sources/Core/Engine/CurveEditing.swift) are total, so an invalid curve is unrepresentable rather than merely rejected, and 10 000 hostile edits are thrown at them in the tests. The plot ([`CurveEditor.swift`](../../App/Sources/Window/CurveEditor.swift)) contributes the gesture and nothing else. The numeric table ([`CurvePointTable.swift`](../../App/Sources/Window/CurvePointTable.swift)) edits the same curve through the same operations, so the two entry points cannot disagree about what is legal. Edits reach the running engine within one cycle (`ControlModel.updateActiveProfile`) and, since P6.08, are written to the configuration file. Proven on hardware by `--curve-drill`.

## Settings

Tabs: **General · Appearance · Sensors · Control · Notifications · Recording · Advanced**

**Implementation (P6.14):** profile triggers are editable — [`TriggerEditor.swift`](../../App/Sources/Settings/TriggerEditor.swift) and [`TriggerRow.swift`](../../App/Sources/Settings/TriggerRow.swift), one editor per kind, under the profile each belongs to. The picker gained an **Auto** choice: arbitration's first rule is that a manual choice beats everything, so without a way back to automatic every trigger would have been vetoed forever. The shipped fallback is `System`, so a fresh install still takes nothing over.

**Implementation (P6.08):** [`App/Sources/Settings/`](../../App/Sources/Settings/), with persistence in [`ConfigurationStore.swift`](../../App/Sources/Model/ConfigurationStore.swift) — see [`docs/architecture/configuration.md`](../architecture/configuration.md). Five tabs are built: **Notifications and Recording are deliberately absent rather than present and inert**, because their subsystems arrive in P7.01 and P7.02 and a tab full of switches that change nothing is what the honesty rule exists to prevent. Those two tasks own their tabs. The watchdog timeout appears in Control as a fact, not a control → [ADR 0023](../architecture/adr/0023-watchdog-timeout-not-user-settable.md). Profile *triggers* are shown but not editable: a trigger editor needs one interface per kind and is its own piece of work. Evidence: `--render-settings` for the tabs, `--config-drill` for persistence.

## Accessibility — not negotiable

- All interactive elements are keyboard reachable, with a sensible focus order
- VoiceOver descriptions for the charts and the curve editor; **the curve is also presented as a list of points**
- Honours `Increase Contrast`, `Reduce Motion`, `Reduce Transparency`
- **Colour never carries information alone** — always backed by a number or label
- Dynamic Type support; **no text container with a fixed pixel width or height**
- The menu bar item provides a meaningful accessibility label
