# 0013 — JSON configuration + zero runtime dependencies

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §10, §3.3

## Context

Configuration must be human editable, usable under version control and processable by tools. TOML/YAML are more readable but **require a dependency**. In an open source project every dependency is an installation step for the contributor and a security/licence surface for the project.

## Decision

- **Format: JSON.** Codable-native, zero dependencies, schema verifiable, tool friendly
- **Location:** `~/Library/Application Support/Boreas/config.json`
- **Schema:** `schema/config.schema.json` — published and versioned in the repository
- **Versioning:** a `schemaVersion` field; old versions are migrated automatically, with a backup taken before migration
- **Runtime dependencies: zero.** Apple frameworks only

Validation is **strict**: out-of-range values are rejected. **An invalid configuration does not crash the application** — it falls back to the last valid state, the offending field is shown to the user, and the fans stay with the firmware.

Unknown fields are **a warning, not an error** (forward compatibility).

## Alternatives

| Option | Why not |
|---|---|
| TOML | More readable but requires a dependency; costs contributor experience and licence surface |
| YAML | The same problem + parsing ambiguities (the Norway problem, etc.) |
| `UserDefaults` / plist | Hard for a human to edit, unsuited to version control, cannot travel in dotfiles |

## Consequences

- ✅ Users can carry the configuration in their dotfiles
- ✅ Deployment via MDM is already possible (no need to write an enterprise tool)
- ✅ Zero dependencies → zero supply chain risk
- ⚠️ JSON has no comments — the schema file and the documentation compensate

## Enforcement

- `make gate-deps` → red if `Package.swift` contains `.package(url:` (T4)
- Unit test: invalid configuration → falls back to the last valid state, no crash (G6)
- Migration test: an old schema version is migrated without data loss
