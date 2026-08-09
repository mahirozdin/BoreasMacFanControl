# Configuration

> Last updated: 2026-08-05 — P6.08
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
  "sensorOverrides":   { "<raw sensor name>": { displayName, group, hidden } }
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
