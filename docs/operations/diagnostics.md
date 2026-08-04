# Diagnostics

> Last updated: 2026-07-31 — P0.28
> Source: blueprint §13

Hardware health is presented as an **honest view that makes no overclaims**.

## Checks

| Check | Method | Output |
|---|---|---|
| **Fan response** | Deviation between target and actual RPM is tracked over time | Tracking the command / lagging / not responding |
| **Fan balance** | RPM difference between fans on multi-fan models | Balanced / abnormal difference |
| **Sensor validity** | Sensors stuck at a value, out of range, or disappearing | Healthy / suspect reading |
| **Thermal history** | Time spent in `serious`/`critical` state during the session | Duration and peak values |
| **Battery health** | Cycle count, capacity ratio, temperature | Informational summary |
| **Storage health** | Basic NVMe SMART fields | Informational summary |

## Honesty rule

> **The application never states as certain what it cannot know for certain.**

It does **not** say "the fan is faulty". Instead:

> *"The fan is not responding to commands as expected — the cause may be dust build-up, a cable connection or a hardware fault."*

and it suggests next steps to the user.

**Rationale:** a false positive "faulty" label sends the user to an unnecessary repair. In this category, the cost of a wrong diagnosis is higher than the cost of making no diagnosis.

## Coverage limit

Battery health and multi-fan balance checks **cannot be verified** on the development hardware (R8). They are tested with Mock and marked "awaiting community verification" in the README. → `docs/development/testing.md`
