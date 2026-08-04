# Test Strategy

> Last updated: 2026-07-31 — P0.24
> Source: blueprint §15 · Decision: [ADR 0011](../architecture/adr/0011-hardware-abstraction.md)

## Layers

| Layer | Scope | Tool |
|---|---|---|
| **Unit** | Curve evaluation, hysteresis, rate limiting, arbitration, safety chain, configuration validation, migration | Swift Testing |
| **Property based** | Engine invariants against generated inputs | Swift Testing |
| **Golden file** | Recorded thermal scenarios → expected fan command sequence | `Tests/Fixtures/` |
| **Integration** | XPC handshake, daemon install/uninstall, watchdog timeout | Mock + real daemon |
| **Hardware smoke test** | Take over / hand back cycle on a real Mac | `scripts/smoke-test-hardware.sh` |
| **UI** | Installation, profile switching, curve editing | XCUITest |
| **Accessibility** | VoiceOver label coverage, keyboard navigation, pseudo-locale layout | Audit + automated |

## Critical scenarios

**No release ships** until these pass:

- [ ] After `kill -9`, the fans return to firmware within ≤ the watchdog timeout
- [ ] On system sleep, the fans are handed back to firmware
- [ ] With the daemon not installed, the application is a fully functional monitor and shows no error
- [ ] A corrupt configuration does not crash the application; it falls back to the last valid state
- [ ] When `T_panic` is exceeded, output goes to 100% and stays locked for the hold period
- [ ] While the thermal state is `critical`, output is 100% regardless of the user curve
- [ ] When the sensor source fails, it degrades to monitoring mode — no crash
- [ ] On a fanless model, the application behaves meaningfully
- [ ] A profile switch causes no fan speed jump
- [ ] Schema migration carries data over without loss

## Hardware coverage limits

The development hardware is a **single model**: Mac mini (M4, 2024) — single fan, battery-less desktop.

| Code path | On real hardware | How it is verified |
|---|---|---|
| M4 generation sensor discovery and grouping | ✅ | Directly |
| Single fan take over / hand back | ✅ | Directly |
| Safety chain K1–K5, watchdog | ✅ | Directly |
| Desktop (battery-less) code path | ✅ | Directly |
| Thermal pressure rise | ✅ | Via load test |
| **Fanless model behaviour** | ❌ | Mock + community reports |
| **Multi-fan arbitration, per-fan curves** | ❌ | Mock + community reports |
| **Battery / power source triggers** | ❌ | Mock + community reports |
| **Battery health diagnostics** | ❌ | Mock + community reports |
| **M1 / M2 / M3 sensor naming** | ❌ | Mock + community reports |

**Three binding consequences:**

1. **The Mock and Replay layers are built in P2** — they cannot be deferred
2. **A "Tested hardware" section in the README is mandatory** — not overstating coverage is the only source of trust
3. **A dedicated issue template exists for unverified code paths**; the user's log is replayed locally with `Replay`

## CI

`macos-latest` (arm64): lint → `xcodegen generate` → build (warnings as errors) → unit + property + golden file tests → coverage (`Core` ≥ 85% blocking) → on tagged releases, signing + notarisation + DMG.

**Tests that require hardware do not run in CI.** Thanks to the Mock layer, the entire engine is still tested.

## Evidence rule

If the verification could not be run, **`NOT RUN` + the reason** goes into the Run Log and the task is not marked `DONE`. "I wrote it, it probably works" is forbidden.
