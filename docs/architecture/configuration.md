# Configuration

> Last updated: 2026-07-31 — P0.21
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
  "general":   { samplingIntervalSeconds, … },
  "safety":    { panicTemperatureCelsius, watchdogTimeoutSeconds },
  "profiles":  [ { name, binding, perFan, triggers[], priority,
                   smoothing, hysteresis, slew, enginePaused } ]
}
```

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
