# 0009 — Dead man's switch (watchdog)

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §6.4, §7.6

## Context

Software that takes over fan control must not leave the hardware defenceless when it itself fails. The application can crash, be killed with `kill -9`, freeze, or the user session can end. In **all** of these scenarios the fans must return to firmware control.

The critical observation: the side holding control (the helper) must monitor the health of **the other side**, not its own. Assuming the application can send an "I am dying" message fails in exactly the scenario where it has crashed.

## Decision

- The application sends the helper a regular **heartbeat** (default 5 s)
- If the helper misses **3 heartbeats** in a row (≈15 s), it hands the fans back to firmware unconditionally
- The helper also hands back **immediately** on: system sleep, system shutdown, the helper being stopped
- The timeout is **locked to the 10–60 s range** and cannot be disabled

## Alternatives

| Candidate | Why rejected |
|---|---|
| The application cleaning up on exit | Does not cover the `kill -9`, crash and freeze scenarios |
| `atexit` / signal handlers | `SIGKILL` cannot be caught |
| Letting the user switch the watchdog off | A safety feature cannot be optional |

## Consequences

- ✅ All failure modes are closed by a single mechanism
- ✅ The user cannot put the hardware at risk through misconfiguration
- ⚠️ In the worst case the fans stay at their last setting for ~15 s — the accepted window
- ⚠️ Heartbeat traffic is continuous; its cost must be measured (target: negligible)

## Enforcement

Invariant tests (may never be deleted):

```
test("the watchdog timeout cannot be set outside 10-60 s")
test("the helper hands back to firmware when the heartbeat stops")
test("releaseToFirmware is idempotent")
```

Hardware smoke test: after `kill -9`, the fans are measured to return to firmware within ≤ the watchdog timeout (`scripts/smoke-test-hardware.sh`).
