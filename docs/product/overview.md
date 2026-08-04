# Product Definition

> Last updated: 2026-07-31 — P0.14
> Source: blueprint §1

## In one sentence

Boreas is a free, open source menu bar application that monitors the internal temperature sensors of Apple Silicon Macs in real time, drives fan speeds with user defined continuous curves, and does so without compromising system safety.

## Problem

On Apple Silicon Macs, cooling is entirely under firmware control and the user is offered no adjustment. This creates problems in both directions:

1. **When it is too quiet** — under loads like long builds, video encoding or virtualisation, the firmware spins the fans up late and conservatively; the chip is thermally throttled and performance drops.
2. **When it is too loud** — in scenarios that demand silence (audio recording, working at night), the fans spin needlessly high.

Both share the same root cause: **the decision mechanism is closed to the user.**

## Target audience

| Segment | Need |
|---|---|
| Software developers | Reduce throttling during long build/test runs |
| Video/visual production | Sustained performance during export |
| Audio production | Absolute silence while recording |
| Server/homelab | Monitoring, alerts and metrics on headless Macs |
| Curious users | See what is going on inside their machine |

## Product principles

Not open to debate. Every design decision is tested against these.

1. **Safety always beats user preference.** If the software crashes, hangs or is killed, the fans return to firmware control. → [ADR 0009](../architecture/adr/0009-watchdog-dead-man-switch.md)
2. **No sensitive permission is requested.** No SIP disabling, kernel extension, Recovery Mode, Full Disk Access or Accessibility permission. → [ADR 0007](../architecture/adr/0007-privilege-split.md)
3. **Reversible.** Deleting the application returns the system to its pre-install state.
4. **No telemetry.** → [ADR 0014](../architecture/adr/0014-zero-telemetry.md)
5. **The configuration belongs to the user.** Readable, version controllable, hand editable. → [ADR 0013](../architecture/adr/0013-json-config-zero-deps.md)
6. **Free and open.** There is no licence key, activation server or "pro" tier, and there never will be.
7. **Measurable.** The application's own cost is measured and kept under budget.

## Success criteria

| Metric | Target |
|---|---|
| Idle CPU usage | Average < 0.3% |
| Application memory footprint | < 60 MB |
| Daemon memory footprint | < 8 MB |
| Cold launch to menu bar | < 400 ms |
| From install to first fan control | One administrator password, < 30 s |
| Hand back after force kill | ≤ 10 s |

Measurement methods and gates: `ARCHITECTURE.md` §3.
