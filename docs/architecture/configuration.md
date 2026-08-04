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
  "general":   { samplingIntervalSeconds, temperatureUnit, launchAtLogin, language },
  "safety":    { panicTemperatureCelsius, panicHoldSeconds, watchdogTimeoutSeconds },
  "profiles":  [ { id, name, priority, triggers[], smoothing, slew, fanCurves[] } ],
  "sensorOverrides": [ { match, displayName, group } ],
  "notifications":   { enabled, suppressionWindowMinutes, rules[] },
  "logging":         { enabled, format, path, rotation, fields[] }
}
```

The full example and the field descriptions live in `schema/config.schema.json` (to be written in P4). **No copy of the schema is kept in this file** — it would become a source of drift.

## Validation rules

| Field | Constraint |
|---|---|
| Curve points | Sorted ascending by temperature, duty ratio non-decreasing |
| `duty` | `[0.0, 1.0]` |
| Temperature | `[0, 120]` °C |
| `panicTemperatureCelsius` | `[70, 105]` |
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
