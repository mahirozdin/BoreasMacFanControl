# Configuration

> Last updated: 2026-08-10 — P7.01
> Source: blueprint §10 · Decision: [ADR 0013](adr/0013-json-config-zero-deps.md)

## Format and location

| Topic | Value |
|---|---|
| Format | **JSON** — Codable-native, zero dependencies, schema verifiable |
| Location | `~/Library/Application Support/Boreas/config.json` |
| Schema | `schema/config.schema.json` — published and versioned in the repository |
| Versioning | The `schemaVersion` field; automatic migration + a pre-migration backup |
| Backup | `config.backup.json` before every successful write |

## Structure

```
{
  "schemaVersion": 1,
  "general":           { samplingIntervalSeconds, … },
  "safety":            { panicTemperatureCelsius, watchdogTimeoutSeconds },
  "defaultProfileName": "Balanced",
  "profiles":          [ { name, binding, perFan, triggers[], priority,
                           smoothing, hysteresis, slew, enginePaused } ],
  "sensorOverrides":   { "<raw sensor name>": { displayName, group, hidden } },
  "shortcuts":         { "<action>": { keyCode, modifiers } },
  "notifications":     { isEnabled, suppressionWindowMinutes, enabledKinds[],
                         quietHours: { startMinuteOfDay, endMinuteOfDay },
                         thresholds: { "<sensor group>": celsius } },
  "recording":         { isEnabled, format, retentionDays, diskCeilingBytes,
                         maximumFileBytes, intervalSeconds },
  "automation":        { isEnabled, commandHooksAllowed, timeoutSeconds,
                         maximumConcurrent, hooks[] }
}
```

> **`safety.watchdogTimeoutSeconds` is read-only in this build.** The helper
> reads no configuration (M5) and the XPC surface is exactly four methods
> (M4), so there is no path by which a different value could reach the
> component that enforces it; the helper derives its own timeout from the
> shared heartbeat constants. Editing the field by hand changes nothing. The
> settings window shows it as a fact rather than a control.
> → [ADR 0023](adr/0023-watchdog-timeout-not-user-settable.md)

> **`sensorOverrides.hidden` is a display choice, never a safety one.** A
> hidden sensor is still read, still counted by its group's aggregate, and
> still able to trigger the panic layer. `defaultProfileName` and
> `sensorOverrides` are both optional: a file without them is valid, which
> is why adding them in P6.08 needed no version bump.

> **`notifications` is optional and additive** (P7.01): a file without it is
> valid and means the defaults, which leave notifications **off**. `isEnabled`
> being false is not a placeholder — macOS requires a permission to deliver a
> notification, and this application does not request one until the user turns
> the switch on. → [`docs/operations/notifications.md`](../operations/notifications.md)
>
> `notifications.thresholds` is **empty by default and deliberately so**: what
> counts as hot depends on the machine and on what its owner is doing with it, so
> there is no honest default to ship. A group name this build does not recognise
> is **refused**, taking the section down to its defaults, rather than dropped —
> the P6.10 rule for shortcuts, and for the same reason: a configuration that
> says one thing and does another is what the loader exists to prevent.

> **`recording` is optional and additive** (P7.02), and its defaults leave
> recording **off**. `diskCeilingBytes` is a **hard** limit that overrides
> `retentionDays`: when the total exceeds it, the oldest files are deleted even
> when they are newer than the retention period, because retention is a
> preference and the ceiling is a promise not to fill the disk. The file being
> written is never deleted. → [`docs/operations/observability.md`](../operations/observability.md)

> **`shortcuts` is an object keyed by action name — corrected in P7.10.** It
> used to be an alternating array, `["boost", {…}]`, because Swift encodes a
> dictionary with an enum key that way; nobody noticed in P6.10 because all four
> shortcuts ship unset, so it had never reached a real file. It round-tripped
> correctly and was unpleasant to edit by hand, which matters for a file this
> project expects people to edit. The fix is the hand-written `encode(to:)`
> `notifications.thresholds` already used.
>
> **The old shape is still accepted on read.** A file written by an earlier
> build does not stop being valid because the writer improved, and only a
> genuine type mismatch falls through to it — so a *malformed object* still
> fails as an object rather than being retried as an array and reported
> confusingly. An unrecognised action name is refused rather than dropped,
> taking the section to its defaults: the P6.10 rule, unchanged.

> **`automation` is optional and additive** (P7.10), and every switch inside it
> defaults to off, so a file that has never heard of the section behaves exactly
> as it did. `isEnabled` and `commandHooksAllowed` are **separate and both
> required** before a hook that executes code will run. `timeoutSeconds` and
> `maximumConcurrent` are clamped into range rather than refused, like every
> other limit here. → [`docs/operations/notifications.md`](../operations/notifications.md)

**Who reads and writes it:** `App/Sources/Model/ConfigurationStore.swift`
does the disk work — atomic writes, coalesced so a slider drag writes once,
and `config.backup.json` refreshed before every write. What a document
*means* stays in `Core.ConfigurationLoader`, so a broken file behaves the
same in the application as it does in the tests. Proven end to end by the
application's `--config-drill`.

Sections for later phases (`sensorOverrides`, `notifications`, `logging`) are
added by the phase that implements them; unknown fields are already tolerated
today. The field descriptions and ranges live in `schema/config.schema.json`
(written in P5.10). **No copy of the schema is kept in this file** — it would
become a source of drift.

## Validation rules

| Field | Constraint |
|---|---|
| Curve points | Sorted ascending by temperature, duty ratio non-decreasing |
| `duty` | `[0.0, 1.0]` |
| Temperature | `[0, 120]` °C |
| `panicTemperatureCelsius` | `[70, 95]` — the blueprint's `[70, 105]` allowed raising the threshold, which G2 forbids; see [ADR 0022](adr/0022-panic-threshold-ceiling.md) |
| `watchdogTimeoutSeconds` | `[10, 60]` — **locked** |
| `samplingIntervalSeconds` | `[1, 60]` |
| Profile `id` | Unique |
| Unknown field | **A warning, not an error** (forward compatibility), logged |

## Invalid configuration behaviour

**The application does not refuse to start.** It falls back to the last valid configuration and shows the user a clear error message and which field is at fault. **Throughout this, the fans are under firmware control.**

This behaviour is protected by an invariant test (G6).

## Migration

When the schema version increases, a migration function is written and **a test proves it migrates without data loss**. A pre-migration backup is taken automatically.

A schema break requires a **MAJOR** version.
