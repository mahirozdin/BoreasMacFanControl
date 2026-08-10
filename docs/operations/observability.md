# Observability

> Last updated: 2026-08-10 — P7.02
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

**Implementation (P7.02).** Recording is **off until asked** — the heading above
says "at the user's request", and writing files to somebody's disk unasked is not
that. Files live in `Application Support/Boreas/Recordings`, one per day plus a
sequence number, and nothing ever leaves the machine.

| Decision | Where | Why there |
|---|---|---|
| Rotation, retention, the disk ceiling | [`Core/Recording/RecordingPolicy.swift`](../../Packages/Core/Sources/Core/Recording/RecordingPolicy.swift) | A pure function over `(day, sequence, byteCount)`, so the 14-day rule is testable without waiting 14 days and the 500 MB ceiling without writing 500 MB |
| The record and both formats | [`Core/Recording/RecordingRecord.swift`](../../Packages/Core/Sources/Core/Recording/RecordingRecord.swift) | Silent corruption is the failure that matters, and it is a property of the format alone |
| The file system work | [`App/Sources/Recording/RecordingWriter.swift`](../../App/Sources/Recording/RecordingWriter.swift) | What is left once the decisions are elsewhere — kept small because it is the part no test can reach |

Evidence: `--recording-drill` (16 checks, including a **real** 4 MB × 4 pruning
against a 10 MB ceiling) and `--render-settings`.

### The ceiling is a promise; retention is a preference

They are separate settings and they run in that order, which matters when they
disagree:

1. **Retention** deletes what the user said they no longer want.
2. **The ceiling** then deletes whatever it must, *including files retention would
   have kept*, until the total fits.

Running the ceiling first would delete files the user wanted while files they had
already asked to expire sat there taking up the room. Two rules are absolute:
**today's file never expires** whatever retention says, and **the file being
written is never deleted** whatever the ceiling says — deleting it would lose the
sample in flight and leave the writer holding a handle to nothing.

When the ceiling has to act, the Recording tab **says so and keeps saying so**.
That is deliberately not a notification: a ceiling doing its configured job is a
standing condition, not an event, and it stays true until the user raises the
limit or shortens retention. An interrupt would fire once and be gone.

### What each format costs

- **JSONL** survives schema evolution and a power loss: a reader ignores a field
  it does not know, and a truncated file is readable up to its last complete line.
- **CSV** needs a fixed column order, and the set of sensors is only known at
  runtime — so the header is written once per file and **a sensor that first
  appears later that day is not in it**. Reopening an existing CSV reads its
  header back rather than trusting this run's sensor order, because writing new
  columns under an old header produces a file that looks correct and is not.
- A sensor missing from a record is an **empty field, never a zero**. Zero is a
  temperature; absence is not, and a spreadsheet averaging zeros into a column of
  real readings would quietly lie.
- Timestamps are ISO 8601 in **UTC**: a recording is read later, possibly on
  another machine, and a local time with no offset is ambiguous twice a year.

### Access

The Diagnostics tab and the Recording tab both **reveal the folder** rather than
showing contents inline (the log access deferred from P6.09). A viewer inside the
application would have to decide what to redact, and the user already has tools
for reading a file — so building another one here would add a judgement call and
no capability.

## Metric export — next wave

- Local HTTP endpoint in Prometheus text format
- **`127.0.0.1` only**, configurable port, **off by default**
- When enabled, a **persistent indicator** appears in the interface — the user always knows the network is being listened on
- A sample Grafana dashboard is provided in the repo

This feature is tracked as a deferred decision in `ARCHITECTURE.md` §12.

## Support report

If the user asks, a **local** diagnostics file is generated. **There is no automatic upload** — the user inspects the file and attaches it to an issue if they choose.

Contents: anonymous system summary · application log · configuration (contains no secret values) · sensor and fan snapshot · discovered hardware map.
