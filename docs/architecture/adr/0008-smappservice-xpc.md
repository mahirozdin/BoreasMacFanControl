# 0008 — SMAppService + signature verified XPC

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §6.3, §14.2

## Context

There are two ways to install a privileged helper: the legacy `SMJobBless` (deprecated in macOS 13) and the modern `SMAppService.daemon`. A privileged helper must also **verify who its commands come from**; otherwise any local process could change fan speeds.

## Decision

- Installation via **`SMAppService.daemon(plistName:)`**
- **Code signature verification in both directions** on the XPC connection: the helper verifies the client's Team ID + bundle ID with `SecCodeCheckValidity` and `SecRequirement`; the application verifies the helper's signature in turn
- The XPC surface is limited to **four methods**: `describeFans`, `applyTargets`, `releaseToFirmware`, `heartbeat`
- Adding a new method **requires a new ADR**

## Alternatives

| Candidate | Why rejected |
|---|---|
| `SMJobBless` | Deprecated in macOS 13; using it in a new project is technical debt |
| XPC without signature verification | Any local process could write fan speeds with root privileges — unacceptable |
| A broad, general purpose XPC interface | Attack surface; every new method is new risk |

## Consequences

- ✅ A single administrator authentication
- ✅ Only our signed application can send commands
- ⚠️ Developer ID is mandatory — without a real Team ID, signature verification is meaningless
- ⚠️ `SMAppService` registration problems on macOS 13 — overcome by raising the target to 14.0 with [0003](0003-minimum-macos-14.md)

## Enforcement

- `make gate-daemon` → red if the XPC protocol contains a `func` outside the four methods (M4)
- `make gate-daemon` → red if the signature verification API cannot be found (G5)
- Invariant test: no command is accepted from a client whose signature has not been verified
