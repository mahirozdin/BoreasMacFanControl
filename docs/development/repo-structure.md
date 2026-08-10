# Repository Structure

> Last updated: 2026-07-31 — P0.23
> Source: blueprint §17, §19 · Decision: [ADR 0012](../architecture/adr/0012-core-layer-purity.md)

## Which code goes where

| Directory | Contents | Dependency rule |
|---|---|---|
| `Packages/Core/` | Models, control engine, configuration, telemetry formatting | **Foundation only** |
| `Packages/HardwareKit/` | IOKit wrappers, protocols, `Live`/`Mock`/`Replay`, sensor discovery | `Core` (model types only) |
| `Packages/SharedIPC/` | XPC protocol definitions (shared by App + Daemon) | — |
| `App/` | SwiftUI interface, menu bar, curve editor, settings, design system | `Core`, `HardwareKit`, `SharedIPC` |
| `Daemon/` | Privileged helper: XPC listener, SMC writer, safety, watchdog | `HardwareKit` (write surface), `SharedIPC` |
| `CLI/` | The `boreas` command line tool | `Core`, `HardwareKit`, `SharedIPC` |
| `Widget/` | WidgetKit (next wave) | `Core` |
| `schema/` | `config.schema.json` | — |
| `scripts/` | Gates (`gates/`), bootstrap, signing, DMG, renaming | — |
| `Tests/` | Golden file scenarios, UI tests | — |
| `docs/` | This documentation | — |

## Binding rules

**`Core` never links against IOKit, SwiftUI or AppKit.** This rule is the sole guarantee that the engine can be tested without hardware in CI, and it is enforced by `make gate-layers`.

**`.xcodeproj` is never committed** — it is generated from `project.yml` (T5).

## Product repository files

These are **work items**, tracked in `TODO.md`:

| File | Phase | Contents |
|---|---|---|
| `LICENSE` | P1 | Full Apache-2.0 text (downloaded from the canonical source) |
| `NOTICE` | P1 | Copyright notice, attributions, acknowledgements |
| `README.md` + 4 translations | P8 | Per `docs/release/readme-spec.md` |
| `CONTRIBUTING.md` | P1 | Setup, style, PR process, **independent development declaration** |
| `CODE_OF_CONDUCT.md` | P1 | Contributor Covenant 2.1 |
| `TRANSLATORS.md` | P7.07 | **The origin of every language** (`source` / `project` / `reviewed`) and the reviewer once there is one. Checked by `make gate-i18n` |
| `CHANGELOG.md` | P1 | Keep a Changelog format |
| `.github/PULL_REQUEST_TEMPLATE.md` | P1 | Declaration checkboxes + test checklist |
| `.github/ISSUE_TEMPLATE/` | P1 | Bug, feature, **unknown sensor report** |
| `.github/workflows/` | P1 | CI + release |

## Renaming the product

`scripts/rename-product.sh` (P1) updates the product name, bundle identifier, daemon label and localisation strings with a single command. The name is never embedded in the code base.
