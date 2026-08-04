# Hardware Access Layer

> Last updated: 2026-07-31 — P0.19
> Source: blueprint §5 · Decisions: [ADR 0011](adr/0011-hardware-abstraction.md), [ADR 0018](adr/0018-undocumented-sensor-api.md)

## Temperature reading — unprivileged

On Apple Silicon, temperature sensors are exposed as HID sensor services:

1. A HID event system client is created
2. Services in the temperature sensor class are filtered with a matching dictionary
3. The product property is read from each service to obtain the sensor's hardware name
4. The temperature event is pulled from each service and the float value is read

**Characteristics:** requires no root · sensor names vary by chip and **are not embedded in code but discovered at runtime** · raw names are not user friendly; a mapping layer is required.

⚠️ **Risk (R1):** This API is not officially documented. Mitigation: the `SensorSource` protocol + a second source via SMC + graceful degradation. Details in [ADR 0018](adr/0018-undocumented-sensor-api.md).

📌 **Notarisation:** Use of an undocumented API is an **App Store review** rule; it does not block the direct distribution + notarisation flow.

## Fan reading and writing — SMC

Via the `AppleSMC` IOService, with four character keys:

| Need | Direction | Privilege |
|---|---|---|
| Fan count, current speed, min, max | Read | None |
| Target speed, control mode | **Write** | **Root** |

**Take-over sequence (inside the daemon):**
1. The current mode and target are read, and **the original state is saved**
2. The mode is switched to "forced"
3. The target speed is written
4. On the next cycle the actual speed is read and any deviation is corrected (**closed loop verification**)

**Hand-back sequence:**
1. The target is written back to its original value
2. The mode is switched to "automatic"
3. A verification read; on failure, up to 5 attempts with exponential backoff

**Data types:** SMC keys return typed data. The type information is read together with the key; **the type is never assumed**. Unknown type → the sensor is skipped, a warning is logged.

## Other data sources

| Source | Privilege | What it provides |
|---|---|---|
| `ProcessInfo.thermalState` | None | **A fully official API** — the foundation of safety chain layer K2 |
| The power source API | None | Adapter/battery, charge percentage |
| The battery IORegistry node | None | Cycle count, capacity, temperature, state |
| Internal SSD SMART | None | Disk temperature, lifetime used |
| CPU load | None | "Why did it heat up?" context |
| The frontmost application | None | Application triggered profiles |
| Display connection | None | The external display trigger |

## Abstraction and testability

```
protocol SensorSource   { func snapshot() async throws -> [SensorReading] }
protocol FanSource      { func fans() async throws -> [FanState] }
protocol FanActuator    { func apply(_:) async throws; func releaseToFirmware() async throws }
protocol PowerSource    { func current() -> PowerContext }
```

Each has **three** implementations: `Live` (real) · `Mock` (deterministic) · `Replay` (replays from a log).

**This is the project's most valuable engineering investment** — [ADR 0011](adr/0011-hardware-abstraction.md). Enforced by `make gate-layers`.

## Sensor naming and grouping

Raw names pass through two layers: **normalisation** (prefix/suffix cleanup, abbreviation expansion) → **classification** (pattern based group assignment).

Group taxonomy: **`compute`** · `compute.performance` · `compute.efficiency` · `graphics` · `memory` · `storage` · `power` · `battery` · `chassis` · `airflow` · `wireless` · `uncategorized`

> **`compute`** was added to the blueprint taxonomy later. Most Apple Silicon die sensors (`PMU tdie<n>`) do not say which cluster they are in; rather than make a cluster up, die temperatures that cannot be attributed are collected in this group. Rationale and alternatives: [ADR 0020](adr/0020-compute-die-sensor-group.md).

**Rule:** An unmatched sensor is **never hidden.** It is shown under `uncategorized` and the user can generate a report with a single click. This speeds up adaptation to new chip generations through the community (the R2 mitigation).

**User override:** Any sensor can be assigned a custom name and group from the configuration.
