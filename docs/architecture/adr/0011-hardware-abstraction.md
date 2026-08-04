# 0011 — Hardware abstraction: Live / Mock / Replay

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §5.4, §15.4, §23 A5

## Context

The development hardware is **a single model**: a Mac mini (M4, 2024) — a single-fan desktop with no battery. The following code paths can **never be verified** on the real hardware: fanless model behaviour, multi-fan arbitration, battery/power source triggers, battery health diagnostics, M1/M2/M3 sensor naming.

This is the chronic problem of hardware control projects: "N different models I cannot test".

## Decision

All hardware access is placed behind protocols:

```
protocol SensorSource   { func snapshot() async throws -> [SensorReading] }
protocol FanSource      { func fans() async throws -> [FanState] }
protocol FanActuator    { func apply(_:) async throws; func releaseToFirmware() async throws }
protocol PowerSource    { func current() -> PowerContext }
```

Every protocol has **three** implementations:

| Implementation | Purpose |
|---|---|
| `Live` | Real hardware |
| `Mock` | Deterministic fake hardware fed from a scenario file |
| `Replay` | A source that replays a recorded log file |

**`Replay` is critical:** it is the only way to reproduce a bug on hardware you do not own, on the development machine, from a log the user sent.

This layer is built at **milestone M1** (P2); it cannot be deferred.

## Alternatives

| Option | Why not |
|---|---|
| Direct IOKit calls | The entire engine becomes untestable; nothing can be verified in CI |
| `Live` only + integration tests | 20% coverage on a single piece of hardware; the remaining 80% is a blind spot |
| Deferring the abstraction | Retrofitting an abstraction later is the most expensive kind of refactor |

## Consequences

- ✅ The entire control engine is tested in CI, without hardware, in seconds
- ✅ User bug report → `Replay` → local reproduction
- ✅ When a new chip generation ships, only `Live` is updated
- ✅ The single-hardware constraint does not break the architecture, it **fixes** it
- ⚠️ Three implementations per protocol is a maintenance burden

## Enforcement

- `make gate-layers` → red if any protocol lacks a `Live<Name>` and a `Mock<Name>` (M2)
- `make gate-layers` → red if there is an IOKit import inside `Core` ([0012](0012-core-layer-purity.md))
- CI: `Core` coverage ≥ 85% is blocking
