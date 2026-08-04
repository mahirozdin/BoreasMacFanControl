# Control Model — The Core Abstraction

> Last updated: 2026-07-31 — P0.15
> Source: blueprint §7 · Decision: [ADR 0010](../architecture/adr/0010-continuous-curve-model.md)

> **This is the product's core abstraction.** The rest of the system takes its shape from it.

## Base model

Fan behaviour is defined by a **piecewise linear, continuous transfer function**:

```
Input: temperature (°C)  →  Output: duty cycle (duty, 0.0 – 1.0)
```

The curve consists of ordered control points, with **linear interpolation** between points:

```
[(35, 0.00), (50, 0.20), (65, 0.45), (78, 0.75), (88, 1.00)]
```

**Constraints:** strictly increasing in temperature, non-decreasing in duty, 2–16 points. Below the first point the output is the first point's value; above the last point, the last point's value.

**RPM conversion:**
```
rpm = fanMin + (fanMax − fanMin) × duty
```

`duty = 0` does **not stop** the fan; it lowers it to the hardware minimum.

## Processing chain

Three stages, each solving a different problem:

| # | Stage | Parameter | Default | Problem |
|---|---|---|---|---|
| 1 | Input smoothing | EWMA `α` | 0.30 | Sensor noise, momentary spikes |
| 2 | Hysteresis | `H` (°C) | 3.0 | Oscillation around a threshold |
| 3 | Output rate limit | `maxRise`/`maxFall` | 600/150 RPM/s | Audible sudden changes in sound |

**Hysteresis — dual curve:** in the falling direction the curve is shifted left by `H`. The engine picks a curve based on the direction of the temperature and **stays locked** to the chosen curve until there is enough reverse movement to cross the other one.

**The rate limit is asymmetric**, and this is deliberate: rising must be fast (safety), falling slow (acoustic comfort + thermal stability). A single "transition time" parameter cannot express this.

## Input selection

Each curve is bound to a **sensor aggregator**:

```
input: { group: "compute.performance", aggregate: "max", smoothing: 0.30 }
```

`max` is the default (biased towards safety). `mean` for smoother behaviour, `p95` to reduce the influence of an outlier sensor.

## Profiles and arbitration

A **profile** = name + per-fan curve set + smoothing parameters + trigger + priority.

Built-in profiles: `Quiet`, `Balanced` (default), `Performance`, `System` (engine disabled).

**Trigger types:** power source · running/foreground application · time window · battery level · external display · thermal state · manual selection.

**Arbitration rules:**
1. Manual selection beats everything (may be time-limited)
2. Otherwise, among the profiles whose condition holds, the **highest priority** wins
3. On a tie, the one earlier in the list
4. If none holds, the default profile
5. Transitions pass through the rate limiter — no jumps

A profile may define **a separate curve and a separate sensor group for each fan**.

## Safety chain

Engine output passes through five layers before reaching the hardware. **Each layer can only correct upward.**

| Layer | Where | Rule | Can be disabled |
|---|---|---|---|
| K1 Fan floor | Engine | Never below the hardware minimum | No |
| K2 Thermal state | Engine | `serious` → floor 55%; `critical` → 100% | No |
| K3 Panic threshold | Engine | Sensor > `T_panic` → 100%, locked ≥30 s | No (can only be lowered) |
| K4 Daemon guard | Daemon | Out-of-bounds commands are rejected | No |
| K5 Watchdog | Daemon | No heartbeat → hand back to firmware | No |

K2 rests on the official `ProcessInfo.thermalState` API — it does **not** depend on an undocumented API.

## State machine

```
MONITORING ──(control turned on + daemon ready)──▶ CONTROLLING
CONTROLLING ──(K3)──▶ PANIC ──(returns to normal)──▶ CONTROLLING
* ──(watchdog / sleep / quit / error)──▶ RELEASING ──▶ MONITORING
```

`RELEASING` is **idempotent**.

## Invariants

The undeletable tests protecting the correctness of this model are listed in `ARCHITECTURE.md` §7.
