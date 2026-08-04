# 0005 — Apache License 2.0

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §2.5, §2.6

## Context

The project will be free and open source. Hardware control is a field that can carry patent claim risk. Code arriving from contributors must also carry the same protection.

## Decision

**Apache License 2.0.**

Permitted dependency licences: MIT, BSD (2/3-clause), Apache-2.0, ISC.
**Forbidden:** GPL, LGPL, AGPL, SSPL, commercial/proprietary.

Every dependency, and every project ideas were drawn from, is recorded in the `NOTICE` file.

## Alternatives

| Candidate | Why rejected |
|---|---|
| **MIT** | The simplest and most widespread, but **no patent grant**. In the field of hardware control that gap leaves both the project and the user exposed |
| **GPL-3.0** | Forces derivative works to stay open, but blocks corporate adoption and limits spread |

## Consequences

- ✅ An explicit patent grant (§3) — protects the project and the user
- ✅ A patent grant is received from contributors too
- ✅ Open to commercial use → wider adoption
- ✅ The `NOTICE` mechanism standardises attribution management
- ⚠️ No GPL licensed code can be used — some existing open source references stay out of reach

## Enforcement

- `make gate-deps` → red if a forbidden licence text or SPDX identifier is found
- `make gate-deps` → the `NOTICE` file is mandatory once there is a dependency
- The `LICENSE` file sits at the repository root
