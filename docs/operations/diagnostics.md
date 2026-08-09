# Diagnostics

> Last updated: 2026-08-10 — P6.09
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

**Implementation (P6.09): the rule is enforced by the type, not by the wording.** [`Core/Presentation/Diagnostics.swift`](../../Packages/Core/Sources/Core/Presentation/Diagnostics.swift) has **no case for "faulty"** — the strongest verdict is `needsAttention` — and one cannot be constructed without at least one possible cause, because an accusation with no explanation beside it is exactly what the rule forbids; a caller who tries gets `indeterminate`. A test asserts that no finding on any code path contains the words *faulty, broken, defective, failed, damaged, dead*, so a future branch cannot reintroduce them by accident. The presentation is [`App/Sources/Window/DiagnosticsTab.swift`](../../App/Sources/Window/DiagnosticsTab.swift); the discovered-hardware summary is [`SystemSummary.swift`](../../App/Sources/Window/SystemSummary.swift).

**What this build checks:** fan response, fan balance, sensor validity, thermal history — the four whose inputs the application already collects. **Battery and storage health are not checked**, and the tab says so by name rather than leaving their absence to be inferred; they need hardware readings this build does not take, and neither can be verified on the development hardware (R8). They belong to P7.03.

**False positives are the risk that was tested.** A tolerance set too tight would tell every healthy owner their fan is not following commands. The application's `--diagnostics-drill` drives a known-good fan and insists the check comes back healthy: measured on the development machine, the fan followed its targets to within **69 rpm** on average against a 400 rpm tolerance.

## Coverage limit

Battery health and multi-fan balance checks **cannot be verified** on the development hardware (R8). They are tested with Mock and marked "awaiting community verification" in the README. → `docs/development/testing.md`
