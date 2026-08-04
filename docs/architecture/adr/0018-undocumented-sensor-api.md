# 0018 — Accepting the undocumented sensor API

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §5.1, §21 R1

## Context

On Apple Silicon, the practical way to reach the temperature sensors is the HID sensor services. This API is **not officially documented** and may change with macOS updates.

The alternative route is the SMC keys; that is undocumented too, but it is a different mechanism — so the odds of both breaking at the same time are low.

An important distinction: **use of an undocumented API is an App Store review rule.** It does not block the direct distribution + notarisation flow. Since the project will not be published on the App Store ([0017](0017-distribution-channels.md)), it poses no obstacle.

## Decision

- Primary sensor source: the HID sensor services
- **Fallback source:** reading via the SMC keys
- Both sit behind the `SensorSource` protocol ([0011](0011-hardware-abstraction.md))
- If the primary fails, the fallback takes over; **if both fail, the application drops to monitoring mode, informs the user and never crashes**
- Sensor names are **not embedded in code**; they are discovered at runtime
- An unmatched sensor is **not hidden**; it is shown in the `uncategorized` group and the user can generate a report with a single click

## Alternatives

| Candidate | Why rejected |
|---|---|
| Using only official APIs | Apple offers no temperature sensor API to third parties — the product would be impossible |
| Depending on a single source | A single macOS update could render the product completely non-functional |
| Embedding the sensor list in code | Every new chip generation would require a release |

## Consequences

- ✅ Two independent sources → low risk of a single point of failure
- ✅ Adapts to new chip generations without a release
- ✅ The community can contribute by reporting unknown sensors
- ⚠️ macOS updates carry a breakage risk (R1) — tracked in release notes
- ⚠️ App Store distribution is permanently impossible (already out of scope via [0017](0017-distribution-channels.md))

## Enforcement

- `make gate-layers` → sensor access must sit behind a protocol; `Live` + `Mock` required (M2)
- Unit test: when the primary source throws, the fallback takes over
- Unit test: when both sources fail, the application drops to monitoring mode and does not crash
- `ProcessInfo.thermalState` (an official API) is used in the K2 layer of the safety chain — it does **not** depend on the undocumented API
