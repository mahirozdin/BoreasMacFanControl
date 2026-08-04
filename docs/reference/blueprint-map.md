# Traceability Matrix — Blueprint → Document

<!-- gate-names:policy-doc — This file DESCRIBES forbidden patterns and is therefore exempt from the gate-names scan. See LEGAL.md §5.1 -->

> Last updated: 2026-07-31 — P0.10
> Source: `docs/blueprint/boreas-blueprint-v1.1.md` (frozen)

**Every section** of the blueprint maps to a target document. Missing sections are not acceptable.

**The Complete? column:** `✅ complete` (content carried over in full) · `➕ expanded` (carried over and built upon) · `🔗 summary+link` (summary carried over, detail in another file)

| § | Blueprint section | Target document(s) | Complete? |
|---|---|---|---|
| 0 | About This Document | `docs/blueprint/README.md`, `AGENTS.md` | ✅ complete |
| 1 | Product Definition | `docs/product/overview.md` | ➕ expanded |
| 2 | Legal and Ethical Framework | `LEGAL.md`, `docs/architecture/adr/0006-independent-development-policy.md`, `docs/architecture/adr/0005-apache-2-license.md` | ➕ expanded |
| 3 | Technology Choice | `docs/architecture/adr/0001-native-swift.md`, `docs/architecture/adr/0003-minimum-macos-14.md`, `docs/architecture/adr/0004-apple-silicon-only.md`, `docs/development/setup.md` | ➕ expanded |
| 4 | System Architecture | `docs/architecture/system.md`, `ARCHITECTURE.md` | ➕ expanded |
| 5 | Hardware Access Layer | `docs/architecture/hardware-access.md`, `docs/architecture/adr/0011-hardware-abstraction.md`, `docs/architecture/adr/0018-undocumented-sensor-api.md` | ➕ expanded |
| 6 | Privilege Model and Permissions | `docs/architecture/privilege-model.md`, `docs/architecture/adr/0007-privilege-split.md`, `docs/architecture/adr/0008-smappservice-xpc.md`, `docs/architecture/adr/0009-watchdog-dead-man-switch.md` | ➕ expanded |
| 7 | Control Engine | `docs/product/control-model.md`, `docs/architecture/adr/0010-continuous-curve-model.md` | ➕ expanded |
| 8 | Feature Scope | `docs/product/scope.md`, `TODO.md` | ➕ expanded |
| 9 | User Interface | `docs/product/ui.md`, `docs/development/localization.md`, `docs/architecture/adr/0016-language-scope.md` | ➕ expanded |
| 10 | Configuration | `docs/architecture/configuration.md`, `docs/architecture/adr/0013-json-config-zero-deps.md` | ➕ expanded |
| 11 | Observability | `docs/operations/observability.md` | ✅ complete |
| 12 | Notifications and Automation | `docs/operations/notifications.md`, `docs/architecture/adr/0015-automation-hooks-not-email.md` | ➕ expanded |
| 13 | Diagnostics | `docs/operations/diagnostics.md` | ✅ complete |
| 14 | Security and Privacy | `SECURITY.md`, `docs/architecture/adr/0014-zero-telemetry.md` | ➕ expanded |
| 15 | Test Strategy | `docs/development/testing.md` | ➕ expanded |
| 16 | Build, Signing and Distribution | `docs/release/build-and-sign.md`, `docs/architecture/adr/0017-distribution-channels.md` | ➕ expanded |
| 17 | Repository Structure | `docs/development/repo-structure.md`, `docs/architecture/adr/0012-core-layer-purity.md` | ➕ expanded |
| 18 | README Specification | `docs/release/readme-spec.md`, `docs/release/discoverability.md` | ➕ expanded |
| 19 | Other Repository Files | `docs/development/repo-structure.md`, `TODO.md` | 🔗 summary+link |
| 20 | Roadmap | `TODO.md` | ➕ expanded |
| 21 | Risks and Mitigations | `docs/reference/risks.md` | ➕ expanded |
| 22 | Glossary | `docs/reference/glossary.md` | ✅ complete |
| 23 | Decision Log | `docs/reference/decisions.md`, `docs/architecture/adr/README.md` | ➕ expanded |
| 24 | Putting It into Practice | `TODO.md`, `BOOT.md` | ➕ expanded |

## Coverage summary

| Metric | Value |
|---|---|
| Blueprint section count | 25 |
| Mapped sections | 25 |
| **Missing sections** | **0** |
| ADRs produced | 18 |

## Reverse direction: document → blueprint

Which blueprint section a document comes from is written in the `> Source: blueprint §X` line at the top of that file.

## How this matrix is maintained

`make docs-check` verifies that:
- Every target file named in the matrix **actually exists**
- No row is unmapped (missing = 0)

When the blueprint is deviated from (with a new ADR), this matrix is updated as well — see `AGENTS.md` §7.
