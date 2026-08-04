# 0004 — Apple Silicon only (arm64)

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §8.4

## Context

Intel and Apple Silicon Macs have different SMC semantics, different sensor topologies and different throttling behaviour. Intel support doubles the code base and triples the test surface.

## Decision

**arm64 only.** No Intel code path is written. No universal binary is produced.

## Alternatives

| Candidate | Why rejected |
|---|---|
| Universal binary (Intel + arm64) | Two separate SMC access layers, two separate sensor mapping strategies, two separate throttling behaviours. Unsustainable in a single developer project |
| Intel first, Apple Silicon later | The development hardware is Apple Silicon; writing code that cannot be verified on Intel is pointless |

## Consequences

- ✅ A single sensor discovery strategy, a single SMC layer
- ✅ A manageable test surface
- ⚠️ Intel Mac users are outside the target audience — stated explicitly in the README
- ⚠️ Reversing the decision would require a second `Live` implementation inside `HardwareKit`; the protocol abstraction makes that possible ([0011](0011-hardware-abstraction.md))

## Enforcement

- `project.yml` → `ARCHS: arm64`
- The README "Requirements" section
- CI builds on an arm64 runner
