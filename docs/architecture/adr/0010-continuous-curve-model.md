# 0010 — Continuous curve control model

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §7

> The engineering heart of the product and the structural foundation of its originality.

## Context

There are two common ways to define fan behaviour: (a) a discrete rule list — "if the temperature passes X, set the speed to Y"; (b) a continuous transfer function — a curve that maps temperature to a duty ratio.

A discrete rule list has two problems: at the thresholds the fan speed **jumps** (the ear finds this sudden change more annoying than a constant loud noise) and it produces **oscillation** around the threshold.

## Decision

**A piecewise linear, continuous transfer function.**

```
Input: temperature (°C)  →  Output: duty ratio (0.0 – 1.0)
Control points: [(35, 0.00), (50, 0.20), (65, 0.45), (78, 0.75), (88, 1.00)]
Between points: linear interpolation
rpm = fanMin + (fanMax − fanMin) × duty
```

Constraints: sorted ascending by temperature, duty ratio non-decreasing, at least 2 and at most 16 points.

A three-stage processing chain — each stage solves a **different** problem:

| Stage | Parameter | Default | Problem it solves |
|---|---|---|---|
| Input smoothing | EWMA `α` | 0.30 | Sensor noise, momentary spikes |
| Hysteresis | `H` (°C) | 3.0 | Oscillation around the threshold |
| Output rate limit | `maxRise` / `maxFall` | 600 / 150 RPM/s | Audible sudden noise change |

**Hysteresis via a dual curve:** in the falling direction the curve is shifted left by `H`; the engine selects the curve by direction and stays locked to the selected curve.

**The rate limit is asymmetric:** rise is fast (safety), fall is slow (acoustic comfort + thermal stability). A single "transition time" parameter cannot express this asymmetry.

## Alternatives

| Option | Why not |
|---|---|
| Discrete rule list | Stepped output → acoustically annoying, oscillation at the thresholds |
| Full PID controller | Overkill for fan systems; the tuning parameters cannot be explained to the user; risk of integral windup |
| A single "ramp time" parameter | Cannot express the rise/fall asymmetry |

## Consequences

- ✅ Continuous, predictable, acoustically comfortable output
- ✅ No separate "time delay" setting is needed — hysteresis + the rate limit are enough
- ✅ The parameters exposed to the user are meaningful ("how fast should the fan react?")
- ✅ Originality is structural — not merely declared ([0006](0006-independent-development-policy.md))
- ⚠️ The curve editor requires a more complex interface than a discrete list would

## Enforcement

Invariant tests (cannot be deleted):

```
test("a monotonically increasing curve produces monotonically increasing output")
test("the output is always within the [fanMin, fanMax] range")
test("no safety layer can lower the output")
test("curve points cannot violate the monotonicity constraint")
test("the rate limit is asymmetric: rise and fall are applied independently")
```

A comparison test (keeps the ADR alive in the code):
```
test("if the discrete stepped model had been applied there would be a jump at the threshold")
```
