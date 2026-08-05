# User Interface

> Last updated: 2026-08-05 — P6.03
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

## Curve editor

The product's signature interface.

- X: temperature, Y: duty cycle; draggable control points
- Double click to add, right click to delete; **the monotonicity constraint is enforced while dragging**
- **Live layers:** the current operating point · the trace of the last 60 s (a faint cloud — comparing real behaviour against the curve) · the hysteresis band shadow
- **Numeric editing:** every point can also be entered from a table (accessibility + precision)
- Ready-made templates · undo/redo
- Live parameters in the side panel (hysteresis, smoothing, rise/fall rate) reflect instantly in the chart

## Settings

Tabs: **General · Appearance · Sensors · Control · Notifications · Recording · Advanced**

## Accessibility — not negotiable

- All interactive elements are keyboard reachable, with a sensible focus order
- VoiceOver descriptions for the charts and the curve editor; **the curve is also presented as a list of points**
- Honours `Increase Contrast`, `Reduce Motion`, `Reduce Transparency`
- **Colour never carries information alone** — always backed by a number or label
- Dynamic Type support; **no text container with a fixed pixel width or height**
- The menu bar item provides a meaningful accessibility label
