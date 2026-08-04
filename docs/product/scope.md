# Feature Scope

> Last updated: 2026-07-31 — P0.16
> Source: blueprint §8

The release-by-release breakdown and the **task list** live in `TODO.md`. This file answers the question *why*.

## What ships in v1.0

Curve based automatic control · the profile system with all triggers · manual control · main window with live charts · curve editor · menu bar · notifications · logging · diagnostics · global shortcuts · 5 languages · full accessibility · CLI · Homebrew cask · signed+notarised DMG.

## Distinguishing features

This project differs **structurally** on these points:

1. **Continuous curve + dual curve hysteresis + asymmetric rate limiting** → more stable, quieter, more predictable. [ADR 0010](../architecture/adr/0010-continuous-curve-model.md)
2. **Dead man's switch** — the layer holding control checks its own health. [ADR 0009](../architecture/adr/0009-watchdog-dead-man-switch.md)
3. **Context aware profiles** — foreground application, time of day, display connection
4. **Record/replay infrastructure** — the ability to reproduce a bug on hardware you do not own. [ADR 0011](../architecture/adr/0011-hardware-abstraction.md)
5. **Human editable, version controllable configuration**
6. **Zero telemetry, zero network by default**
7. **Showing unknown sensors instead of hiding them, and asking the community to contribute**
8. **Turkish as a first class language**

## Out of scope — with the reasons

These are not "not done yet"; they **will not be done**.

| Out of scope | Reason |
|---|---|
| Intel Mac support | Different SMC semantics, different sensor topology. Doubles the code base, triples the test surface. [ADR 0004](../architecture/adr/0004-apple-silicon-only.md) |
| macOS 13 and below | The cost of backwards compatibility exceeds the gain. [ADR 0003](../architecture/adr/0003-minimum-macos-14.md) |
| Email / SMTP notifications | Credential storage, 2FA, TLS compatibility, delivery — an enormous maintenance load. Webhook + command hook instead. [ADR 0015](../architecture/adr/0015-automation-hooks-not-email.md) |
| Licensing / activation / DRM | Free and open source |
| Telemetry, analytics, crash SDKs | [ADR 0014](../architecture/adr/0014-zero-telemetry.md) |
| Hackintosh / generic sensor mode | Incompatible with the M series target |
| External GPUs | Not supported on Apple Silicon |
| External disk temperature | macOS exposes no SMART data for most USB enclosures; an unreliable feature produces disappointment |
| CPU frequency/voltage manipulation | Not possible on Apple Silicon |
| Mac App Store distribution | The sandbox does not allow a privileged daemon — technically impossible. [ADR 0017](../architecture/adr/0017-distribution-channels.md) |
| Enterprise mass deployment tooling (v1.0) | Thanks to the configuration-file-first design, deployment via MDM is already possible |
| Windows / Linux | Irrelevant |

## Next wave

Mini chart in the menu bar · WidgetKit widget · App Intents/Shortcuts · local metrics endpoint · automation hooks · unknown sensor report · configuration sharing · Sparkle updates.

Tracked together with their triggers in `ARCHITECTURE.md` §12.
