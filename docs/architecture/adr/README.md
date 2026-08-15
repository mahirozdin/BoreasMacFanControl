# Architecture Decision Records (ADR)

> Last updated: 2026-07-31 — P0.08
> Source: blueprint §3, §5, §6, §7, §23

Format: Michael Nygard — `Context` / `Decision` / `Alternatives` / `Consequences` / **`Enforcement`**.

**The `Enforcement` section is mandatory.** If a decision cannot be enforced in code or in CI, that decision is a wish.

## Index

| # | Decision | Status | Area |
|---|---|---|---|
| [0001](0001-native-swift.md) | Native Swift + SwiftUI | Accepted | Technology |
| [0002](0002-product-name.md) | Product name: Boreas | Accepted | Identity |
| [0003](0003-minimum-macos-14.md) | Minimum macOS 14.0 Sonoma | Accepted | Technology |
| [0004](0004-apple-silicon-only.md) | Apple Silicon only (arm64) | Accepted | Scope |
| [0005](0005-apache-2-license.md) | Apache License 2.0 | Accepted | Legal |
| [0006](0006-independent-development-policy.md) | **Independent development policy** | Accepted | Legal |
| [0007](0007-privilege-split.md) | Unprivileged reading / privileged writing | Accepted | Architecture |
| [0008](0008-smappservice-xpc.md) | SMAppService + signature verified XPC | Accepted | Security |
| [0009](0009-watchdog-dead-man-switch.md) | Dead man's switch (watchdog) | Accepted | Security |
| [0010](0010-continuous-curve-model.md) | Continuous curve control model | Accepted | Product |
| [0011](0011-hardware-abstraction.md) | Hardware abstraction: Live/Mock/Replay | Accepted | Architecture |
| [0012](0012-core-layer-purity.md) | `Core` layer purity | Accepted | Architecture |
| [0013](0013-json-config-zero-deps.md) | JSON configuration + zero dependencies | Accepted | Architecture |
| [0014](0014-zero-telemetry.md) | Zero telemetry | Accepted | Privacy |
| [0015](0015-automation-hooks-not-email.md) | Automation hooks instead of email | Accepted | Scope |
| [0016](0016-language-scope.md) | 5 language interface / English documentation | Accepted | Product |
| [0017](0017-distribution-channels.md) | Distribution channels; App Store excluded | Accepted | Release |
| [0018](0018-undocumented-sensor-api.md) | Accepting the undocumented sensor API | Accepted | Risk |
| [0019](0019-signing-identity-deferred.md) | Signing identity deferred to P8 | Accepted | Release |
| [0020](0020-compute-die-sensor-group.md) | A `compute` group for core sensors that cannot be attributed to a cluster | Accepted | Hardware |
| [0021](0021-english-only-repository.md) | The repository is written in English | Accepted | Governance |
| [0022](0022-panic-threshold-ceiling.md) | The panic threshold's ceiling is its default (95 °C) | Accepted | Safety |
| [0023](0023-watchdog-timeout-not-user-settable.md) | The watchdog timeout is not user settable | Accepted | Safety |
| [0024](0024-repository-name-readability.md) | The repository name is read before it is searched | Accepted | Release |

## Writing a new ADR

1. Take the next number and create the file as `NNNN-short-slug.md`
2. Fill in all five sections — **`Enforcement` cannot be left empty**
3. Add a row to this index
4. Add a row to the `ARCHITECTURE.md` §11 table
5. Run `make docs-check` — the three way sync is checked

## When to write an ADR

- A deviation from the blueprint (**mandatory**)
- A new technology or framework choice
- A new invariant or a "never/always" rule
- Widening the privileged surface
- Any decision that would be expensive to reverse
