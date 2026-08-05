# 0022 — The panic threshold's ceiling is its default

- **Status:** Accepted
- **Date:** 2026-08-05
- **Source:** blueprint §7.6, §8; invariant G2

## Context

The blueprint states two things about the K3 panic threshold that do not
agree with each other:

- §7.6: the default is 95 °C, and the user **may lower it, never raise it**
  (the G2 safety invariant).
- The configuration schema section: `panicTemperatureCelsius ∈ [70, 105]`.

A schema that accepts 105 permits exactly what the invariant forbids. One of
the two had to give, and the blueprint is frozen — the contradiction is
resolved here instead of edited away.

## Decision

**The safety invariant wins.** The effective range of the panic threshold is
`[70, 95]`:

- The ceiling is the default (95 °C). `Core.PanicThreshold` clamps any higher
  request down to it — a raised threshold is unrepresentable, not merely
  rejected.
- The floor stays at the blueprint's 70 °C: below that, a panic threshold
  degenerates into a permanently-on switch.
- An ambiguous value (NaN) resolves **down** to the floor: for a trigger
  threshold, panicking sooner is the safe direction — the mirror image of an
  ambiguous `Duty` resolving up.

The configuration schema (P5.10) must encode `[70, 95]`, and the type clamps
regardless of what a configuration file claims.

## Alternatives

| Option | Why not |
|---|---|
| Honour the schema range `[70, 105]` | Permits raising the threshold, which G2 forbids; safety invariants take precedence over the schema section |
| Treat 105 as the ceiling and 95 as a soft default | "May not be raised" would become advisory; a safety rule that is advisory is a preference |
| Edit the blueprint's schema section | The blueprint is frozen; deviations are recorded, not painted over |

## Consequences

- ✅ G2 is enforced at the type level; no call site can hold a raised threshold
- ✅ The contradiction is recorded instead of silently resolved
- ⚠️ A future decision to allow a higher ceiling needs a new ADR, not a config change

## Enforcement

`Core.PanicThreshold` clamps in its initialiser. Invariant tests (may never
be deleted): "the panic threshold cannot be raised above the default" and
"the panic threshold has a floor, and ambiguity resolves down" in
`SafetyChainTests`.
