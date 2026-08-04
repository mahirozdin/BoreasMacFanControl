# 0020 — A `compute` group for core sensors that cannot be attributed to a cluster

- **Status:** Accepted
- **Date:** 2026-08-04
- **Source:** a **deviation** from the blueprint §5.5 taxonomy
- **Related:** [0011](0011-hardware-abstraction.md), [0018](0018-undocumented-sensor-api.md)

## Context

Blueprint §5.5 split the sensor taxonomy into `compute.performance` and `compute.efficiency`; the assumption was that every core sensor could be attributed to a cluster.

On real hardware (Mac mini M4, the HID sensor interface) the assumption did not hold. 39 of the 40 reported sensors take this form:

```
PMU tdie1 … PMU tdie14        die temperatures on the SoC
PMU2 tdie1 … PMU2 tdie10
PMU tdev1 … PMU tdev8         device temperatures
PMU tcal, PMU2 tcal           calibration
```

These sensors are **reported by the PMU** but **measure the SoC die**. Two problems arose:

1. The `pmu → power` rule was assigning all of them to the `power` group. Had the user attached a fan curve to `compute.performance`, **no sensor on this machine would have matched** — the curve would silently remain bound to nothing.
2. Which cluster these sensors belong to is **unknown**. There is no information to say whether `tdie7` is in the performance or the efficiency cluster.

## Decision

A **`compute`** group was added to the taxonomy: *core temperatures that cannot be attributed to a specific cluster.*

| Pattern | Group | Rationale |
|---|---|---|
| `tdie*`, `tdev*`, `die temp` | **`compute`** | SoC die temperature; cluster unknown |
| `pacc`, `performance`, `p-core` | `compute.performance` | Cluster stated explicitly |
| `eacc`, `efficiency`, `e-core` | `compute.efficiency` | Cluster stated explicitly |
| `tcal` | `power` | Calibration, not meaningful for temperature control |
| `pmu`, `pmgr`, `vrm` (apart from the above) | `power` | Genuinely power circuitry |

Ordering is critical: the `tdie`/`tdev` rules are tried **before** the generic `pmu` rule.

`compute` is selectable as a fan curve input (it is in `curveInputCandidates`).

## Alternatives

| Candidate | Why rejected |
|---|---|
| `tdie*` → `compute.performance` | **False information.** Which cluster it is in is unknown; calling it the "performance cluster" would be making it up |
| Leaving it as it is (`power`) | The user's curve silently binds to nothing — the worst kind of failure, because it goes unnoticed |
| Dumping them into `uncategorized` | Technically honest but useless: the very sensors that drive cooling would become unattachable to a curve |
| Writing a per-model table | Every new chip would require a release; the approach ADR 0011 rejected |

## Consequences

- ✅ Fan curves can attach to a meaningful group on this hardware
- ✅ What is unknown stays unknown — no cluster is made up
- ✅ On hardware that reports cluster information explicitly, the distinction is preserved
- ⚠️ The taxonomy differs from the blueprint; `docs/architecture/hardware-access.md` and the glossary were updated
- ⚠️ The default profiles' input group should use a broader selection than `compute.performance` — to be handled in P5.07

## Enforcement

- Unit test: `PMU tdie7` → `.compute`, `PMU tcal` → `.power`, `pACC …` → `.computePerformance`
- Unit test: an ordering guard — the test breaks if the `tdie` rule is not tried before the `pmu` rule
- `SensorGroup.curveInputCandidates` contains `compute` and does not contain `uncategorized`
