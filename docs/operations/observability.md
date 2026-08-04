# Observability

> Last updated: 2026-07-31 — P0.26
> Source: blueprint §11 · Decision: [ADR 0014](../architecture/adr/0014-zero-telemetry.md)

## In-app logging

`OSLog` / `Logger` is used.

**Categories:** `sensor` · `fan` · `engine` · `daemon` · `xpc` · `ui` · `config`
**Levels:** `debug` (off by default) · `info` · `notice` · `error` · `fault`

> **No log line contains personal data.** No user name, file path or network information is logged (P3).

## Measurement recording — at the user's request

| Format | Use |
|---|---|
| **JSONL** | Default. One sample per line; easy to process with tools, resilient to schema evolution |
| **CSV** | Direct export to spreadsheet applications |

**Rotation:** daily or size based; default retention 14 days. A **hard upper limit** against filling the disk (default 500 MB) — when exceeded, the oldest files are deleted and the user is informed.

**Recorded fields:** timestamp · sensors · fans · active profile · engaged safety layer.

Recording the active safety layer is critical: it is the answer to the question "why is the fan at 100%?"

## Metric export — next wave

- Local HTTP endpoint in Prometheus text format
- **`127.0.0.1` only**, configurable port, **off by default**
- When enabled, a **persistent indicator** appears in the interface — the user always knows the network is being listened on
- A sample Grafana dashboard is provided in the repo

This feature is tracked as a deferred decision in `ARCHITECTURE.md` §12.

## Support report

If the user asks, a **local** diagnostics file is generated. **There is no automatic upload** — the user inspects the file and attaches it to an issue if they choose.

Contents: anonymous system summary · application log · configuration (contains no secret values) · sensor and fan snapshot · discovered hardware map.
