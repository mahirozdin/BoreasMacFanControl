# System Architecture

> Last updated: 2026-07-31 — P0.18
> Source: blueprint §4 · Binding invariants: `ARCHITECTURE.md`

## Components

```
USER SPACE (unprivileged)                     ROOT SPACE (root)
┌────────────────────────────────┐  NSXPC   ┌──────────────────────┐
│ Boreas.app                     │◀────────▶│ FanDaemon            │
│  ├─ UI (SwiftUI)               │ signature│  ├─ XPCListener      │
│  ├─ ControlEngine              │ verified │  ├─ SMCWriter        │
│  ├─ SensorReader ──────────────┼──┐ both  │  ├─ SafetyGovernor   │
│  ├─ ConfigStore                │  │ ways  │  ├─ Watchdog         │
│  ├─ Telemetry (local)          │  │       │  └─ StateRestorer    │
│  └─ DaemonClient (heartbeat)   │  │       └──────────┬───────────┘
└────────────────────────────────┘  │                  │ IOKit
┌────────────────────────────────┐  │                  ▼
│ boreas (CLI)                   │  └──────────▶ ┌──────────────┐
└────────────────────────────────┘   unprivileged│  HARDWARE    │
                                      reading    └──────────────┘
```

## The key point of the architecture

**Reading temperatures requires no privilege at all. Only writing fans does.**

This finding shapes the entire architecture → [ADR 0007](adr/0007-privilege-split.md)

Its consequences:
- Even if the user **never installs** the daemon, the application is a fully functional monitoring tool
- The administrator password only once, and only when fan control is requested
- The privileged surface is limited to a few hundred lines: the daemon only knows "write this target to this fan" and "return to firmware"
- Curve evaluation, profile logic, configuration reading — **none of it is on the root side**

## Module dependencies

```
App    ──▶ Core, HardwareKit, SharedIPC
CLI    ──▶ Core, HardwareKit, SharedIPC
Daemon ──▶ HardwareKit (write surface only), SharedIPC
Core   ──▶ (Foundation only)
HardwareKit ──▶ Core (model types only)
```

`Core`'s purity is enforced by `make gate-layers` → [ADR 0012](adr/0012-core-layer-purity.md)

## Trust boundaries

| Boundary | Verification |
|---|---|
| App → Daemon | `SecCodeCheckValidity` + `SecRequirement`; refused if the Team ID and bundle ID do not match |
| Daemon → App | The application verifies the daemon's signature |
| Daemon → Hardware | `SafetyGovernor` filters all writes |
| Config → Engine | Schema validation; if invalid, fall back to the last valid state |

Details: [ADR 0008](adr/0008-smappservice-xpc.md)

## Concurrency model

- Sensor reading: a dedicated `actor SensorPoller`, fixed period
- Control engine: **pure functions** (`Sendable` input → `Sendable` output), no side effects
- UI: `@MainActor`, `@Observable` model
- XPC: its own queue; results are sent to the daemon `async`

**Rule:** No code that touches hardware runs on `@MainActor`. The interface never freezes.

## Failure scenarios

The full list: `ARCHITECTURE.md` §9.

The shared principle: **no hardware error crashes the application.** Graceful degradation is applied, the user is informed honestly, and the fans return to a safe state.
