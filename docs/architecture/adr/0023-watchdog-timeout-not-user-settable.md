# ADR 0023 — The watchdog timeout is not user settable

> Status: Accepted · 2026-08-05 · Phase P6.08

## Context

The blueprint's settings window (§9.5, Advanced tab) lists **"watchdog
duration"** among the things a user may change, and the published schema has
carried a `safety.watchdogTimeoutSeconds` field since P5.10.

Implementing that tab in P6.08 exposed a conflict that had not been noticed
before, because nothing had tried to *deliver* the value:

- **M5** — the helper **reads no configuration**. Nothing user supplied is
  parsed as root.
- **M4** — the XPC surface is **exactly four methods**. Adding a fifth
  requires its own ADR.

The helper derives its timeout in `FanControlService.init` from the shared
constants (`BoreasIPC.heartbeatIntervalSeconds` ×
`BoreasIPC.missedHeartbeatsBeforeRelease`), clamped by `WatchdogPolicy` into
the 10–60 s range that **G3** locks. There is therefore no path — not a file,
not a message — by which a number chosen in the interface could reach the
component that enforces it.

The three ways out were:

1. **Add a fifth XPC method** to set the timeout. Costs an ADR against M4,
   widens the privileged surface, and hands a user the ability to lengthen
   the exact mechanism that protects them from a hung application.
2. **Let the helper read the configuration file.** Directly against M5, and
   the reason M5 exists: nothing user supplied is parsed as root.
3. **Keep the field, stop offering it as a control.**

## Decision

**Option 3.** The watchdog timeout is fixed by the helper's own constants and
is presented in the Advanced tab **read-only, with the reason stated**.

The schema field stays. Removing it would need a version bump and a migration
for a value that is already inside the locked range, and keeping it costs
nothing: it round-trips, and if a future ADR ever opens a delivery path the
field is already there. Its schema description now says plainly that this
build cannot deliver it.

## Consequences

- The Advanced tab shows the timeout as a fact about the machine, not a
  setting. A control that silently did nothing would be worse than no
  control.
- **G3 gets stronger, not weaker.** The timeout cannot be disabled *or*
  lengthened, because it cannot be reached at all.
- A user who edits `safety.watchdogTimeoutSeconds` by hand changes nothing.
  This is documented in `docs/architecture/configuration.md` and in the
  schema description, so the file does not quietly lie.
- If a real need for a settable timeout appears, it needs a new ADR that
  argues explicitly for a fifth XPC method — which is the conversation that
  should happen, rather than the surface widening by accident.

## Enforcement

| Layer | How |
|---|---|
| Invariants | M4 (`make gate-daemon` counts the XPC surface) and M5 keep the delivery paths closed |
| Interface | The Advanced tab renders the value as text, never as a control — the render evidence shows it |
| Schema | `schema/config.schema.json` marks the field read-only for this build |
| Documentation | `docs/architecture/configuration.md` records it beside the field |

## Related

- [ADR 0007](0007-privilege-split.md) — the privilege split M5 comes from
- [ADR 0008](0008-smappservice-xpc.md) — the four method XPC surface (M4)
- [ADR 0009](0009-watchdog-dead-man-switch.md) — the watchdog itself and G3
