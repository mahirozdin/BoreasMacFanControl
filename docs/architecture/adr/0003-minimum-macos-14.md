# 0003 — Minimum target macOS 14.0 Sonoma

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §3.2, §23 A2

## Context

Registering the privileged helper requires `SMAppService` (macOS 13.0+). Modern SwiftUI calls for `@Observable` (14.0+) and a stable `MenuBarExtra`. A lower target means wider reach, but brings version branching and maintenance burden.

## Decision

**Minimum macOS 14.0 Sonoma.**

## Alternatives

| Candidate | Why rejected |
|---|---|
| **macOS 13.0 Ventura** | No `@Observable` → `ObservableObject` + Combine (more code, more error surface). `SMAppService`'s registration problems on 13.0 would need workarounds. A testing burden across two versions. Estimated gain: ~3% reach; the cost is permanent |
| **macOS 15.0 Sequoia** | Cleaner code, but needlessly leaves out part of the M1/M2 user base; slows open source adoption |

## Consequences

- ✅ The mature `SMAppService`, `@Observable`, a stable `MenuBarExtra`, mature Swift Charts, full String Catalog support
- ✅ A single code path — no version branching
- ⚠️ Users still on macOS 13 are left out (an estimated ~5% of the Apple Silicon base)

## Enforcement

- `project.yml` → `DEPLOYMENT_TARGET: 14.0`
- The build catches any assumption of an older version's API
- CI builds on `macos-latest`
