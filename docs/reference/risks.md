# Risk Register

> Last updated: 2026-07-31 — P0.12
> Source: blueprint §21

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|
| **R1** | The undocumented sensor API breaks with a macOS update | Medium | High | Protocol abstraction + a second source (SMC) + graceful degradation; never a crash. [ADR 0018](../architecture/adr/0018-undocumented-sensor-api.md) | Developer |
| **R2** | A new chip generation brings different sensor naming | High | Medium | Runtime discovery; no chip list embedded in code; `uncategorized` visibility; community report template | Developer |
| **R3** | The firmware blocks or reverts fan writes | Medium | High | Closed-loop verification, deviation detection, honest notification to the user | Developer |
| **R4** | The user sets a fan too low and puts the hardware at risk | Medium | High | The K1–K3 layers cannot be switched off; the curve editor marks the risky region visually. [ADR 0010](../architecture/adr/0010-continuous-curve-model.md) | Product |
| **R5** | Daemon installation gets stuck in the macOS security flow | Medium | Medium | State detection + direct routing to System Settings + a troubleshooting document | Developer |
| **R6** | A legal claim | Low | Very high | All of `LEGAL.md`: the independent development protocol, the product name ban, the PR declaration, citation discipline, **original algorithm design**. [ADR 0006](../architecture/adr/0006-independent-development-policy.md) | Project owner |
| **R7** | Single-developer burnout | High | High | Milestones are small and each is useful on its own; a working monitoring tool by the end of P2; the out-of-scope list preserves discipline | Project owner |
| **R8** | **Untestable hardware diversity** — the development hardware is a single model (single fan, no battery) | **Certain** | **High** | Mock + Replay mandatory in P2; an honest scope statement in the README; community report templates; unverified code paths are flagged in release notes. [ADR 0011](../architecture/adr/0011-hardware-abstraction.md) | Developer |
| **R9** | Apple trademark rules force a name change | Low | Low | The "Mac" prefix was never used in the first place; the name lives in a single place; `scripts/rename-product.sh`. [ADR 0002](../architecture/adr/0002-product-name.md) | Project owner |
| **R10** | Translation staleness — 5 languages, a single developer | High | Low | A missing translation falls back to the source language, never showing blank; the CI warning does not block a release; [`TRANSLATORS.md`](../../TRANSLATORS.md) declares each language's origin and **`make gate-i18n` fails when that declaration and the shipped catalogue disagree** (P7.07); documentation is deliberately outside translation scope. [ADR 0016](../architecture/adr/0016-language-scope.md) | Community |
| **R11** | Layout breakage in the multilingual interface (long strings) | Medium | Medium | The ban on fixed-width/height text containers; a pseudo-locale layout test in CI | Developer |

## R8 — special note

This risk is marked **certain** because it is not a probability but the current state. Code paths that cannot be verified directly are listed in a table in `docs/development/testing.md` and reviewed at every release.

## How the risk register is updated

When a new risk is noticed, a row is added to this file and, where needed, a mitigation task enters `TODO.md`. A risk materializing is recorded in the Run Log.
