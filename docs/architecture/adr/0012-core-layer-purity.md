# 0012 — `Core` layer purity

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §17.2

## Context

Being able to test the control engine without hardware is the precondition of [0011](0011-hardware-abstraction.md). But the intention of "testable design" collapses at the first "let me import this temporarily". Nothing temporary ever is.

## Decision

Dependency direction, enforced by the build and by a gate:

```
App    ──▶ Core, HardwareKit, SharedIPC
CLI    ──▶ Core, HardwareKit, SharedIPC
Daemon ──▶ HardwareKit (write surface only), SharedIPC
Core   ──▶ (Foundation only)
HardwareKit ──▶ Core (model types only)
```

**`Packages/Core` may not import:** IOKit, SwiftUI, AppKit, Cocoa, Carbon, ServiceManagement, UserNotifications, WidgetKit, AppIntents, Charts, Network.

Additional rules: force unwrapping (`!`) is forbidden inside `Core`; all types are `Sendable`; engine functions are pure.

## Alternatives

| Option | Why not |
|---|---|
| A single module, no layer separation | Testability is impossible; nothing can be verified in CI |
| Only documenting the layer rule | An unenforced rule gets violated over time |
| Relying on SPM target dependencies | SPM catches a wrong import, but its error message is unhelpful; the gate also states the reason |

## Consequences

- ✅ The engine is tested in CI in seconds
- ✅ New platform/hardware support affects only `HardwareKit`
- ⚠️ Some utilities may be written twice (on the `Core` and `App` sides) — an accepted cost

## Enforcement

`make gate-layers`:
- A forbidden `import` line under `Packages/Core/Sources` → red
- Force unwrapping (`!`) inside `Core` → red

Proven: when a file containing `import IOKit` was placed under `Core`, the gate turned red; when the file was removed, it turned green again.
