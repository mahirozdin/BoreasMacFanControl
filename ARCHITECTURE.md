# ARCHITECTURE.md

> Last updated: 2026-08-04 — ADR 0021
> Source: blueprint sections 4, 5, 6, 7 and 17.2

This file is **the code review checklist**. Narrative explanation lives under
`docs/architecture/`; only binding rules and the decision index are here.

---

## 1. Goals

| Goal | Measure |
|---|---|
| Unprivileged monitoring | Every sensor and fan speed is readable without installing the helper |
| Safe fan control | In every failure mode of the software, the fans return to firmware |
| Testable without hardware | The whole control engine is exercised in CI with no real fan |
| Minimal privileged surface | No user supplied data is parsed as root |
| Predictable acoustics | Fan speed changes are continuous and rate limited |

## 2. Non-goals

- Intel Mac support
- macOS 13 and earlier
- Mac App Store distribution — the sandbox forbids a privileged daemon
- CPU frequency or voltage manipulation
- External GPU, external drive temperatures
- An enterprise deployment tool in version 1.0

## 3. Quality targets

| Target | Measurement | Gate |
|---|---|---|
| Idle CPU below 0.3 percent | 10 minute sample with `powermetrics` | Smoke test, manual |
| Application memory below 60 MB | Activity Monitor or `footprint` | Smoke test, manual |
| Helper memory below 8 MB | `footprint` | Smoke test, manual |
| Launch to menu bar under 400 ms | `os_signpost` measurement | Performance test |
| Fan handover within 10 seconds | Measured after `kill -9` | Invariant plus smoke test |
| `Core` coverage at or above 85 percent | `swift test --enable-code-coverage` | **Blocking in CI** |

---

## 4. System context

```
User session (unprivileged)          Root                     Hardware
+----------------------+           +----------------+        +--------------+
| Boreas.app           |  NSXPC    | FanDaemon      | IOKit  | AppleSMC     |
|  UI / ControlEngine  |<--------->|  XPCListener   |<------>| HID sensors  |
|  SensorReader -------+-----------+----------------+------->| SmartBattery |
|  ConfigStore         | signature |  SafetyGovernor|        | power source |
|  DaemonClient        | verified  |  Watchdog      |        +--------------+
+----------------------+ both ways |  StateRestorer |
+----------------------+           +----------------+
| boreas (CLI)         |
+----------------------+
```

**The key point:** `SensorReader` does not go through the helper. Reading
temperatures needs no privileges, so it talks to the hardware directly. The
helper sits only on the **write** path.

---

## 5. Trust boundaries

| Boundary | Verification | Invariant |
|---|---|---|
| App to helper | `setCodeSigningRequirement` pinned to the team identifier; a mismatched peer is refused by the system | G5 |
| Helper to app | The application applies the same requirement to the helper | G5 |
| Helper to hardware | `SafetyGovernor` filters every write; out of range commands are refused and logged | K4 |
| Config to engine | Schema validation and range constraints; an invalid file falls back to the last valid state | G6 |

---

## 6. Module boundaries and dependency rules

```
App    --> Core, HardwareKit, SharedIPC
CLI    --> Core, HardwareKit, SharedIPC
Daemon --> Core, HardwareKit (write surface only), SharedIPC
Core   --> (Foundation only)
HardwareKit --> Core (model types only)
```

### MUST / MUST NOT

| # | Rule | Gate |
|---|---|---|
| **M1** | `Packages/Core` **MUST NOT** import IOKit, SwiftUI, AppKit or any hardware API | `make gate-layers` |
| **M2** | Every hardware protocol **MUST** have at least a `Live` and a `Mock` implementation | `make gate-layers` |
| **M3** | Temperature reading **MUST NOT** pass through the helper | Review |
| **M4** | The helper's XPC surface **MUST** contain only `describeFans`, `applyTargets`, `releaseToFirmware` and `heartbeat` | `make gate-daemon` |
| **M5** | The helper **MUST NOT** read or parse a configuration file | `make gate-daemon` |
| **M6** | The helper **MUST NOT** import a network API | `make gate-daemon` |
| **M7** | Code that touches hardware **MUST NOT** run on `@MainActor` | Review |
| **M8** | `Core` functions **MUST** be pure — same input, same output | Unit test |

---

## 7. The safety chain

Engine output passes through five layers before it reaches hardware. **Every
layer may only correct upwards.**

| Layer | Where | Rule | Can it be disabled? |
|---|---|---|---|
| **K1** Fan floor | Engine | Output never goes below the hardware minimum | No |
| **K2** Thermal state | Engine | `serious` raises the floor to 55 percent; `critical` forces 100 percent | No |
| **K3** Panic threshold | Engine | Any sensor above the panic temperature forces 100 percent, held for at least 30 seconds | No — it may only be lowered |
| **K4** Helper guard | Helper | A command outside the hardware's own limits is refused | No |
| **K5** Watchdog | Helper | No heartbeat means the fans go back to firmware | No |

K2 rests on `ProcessInfo.thermalState`, a fully public API, so it does not
depend on any undocumented interface.

### Invariant tests (never deleted)

```
test("no safety layer can lower the output")
test("thermalState .critical forces 100 percent regardless of the user curve")
test("the watchdog timeout cannot be set outside 10 to 60 seconds")
test("the helper releases the fans when heartbeats stop")
test("a client whose signature is not verified cannot issue commands")
test("an invalid configuration does not crash the app; the last valid state is used")
test("a monotonically increasing curve produces a monotonically increasing output")
test("output always lies within the fan's minimum and maximum")
```

---

## 8. State machine

```
MONITORING --(user enables control and the helper is ready)--> CONTROLLING
CONTROLLING --(K3 fires)--> PANIC --(conditions normalise)--> CONTROLLING
any state --(watchdog / sleep / quit / error)--> RELEASING --> MONITORING
```

`RELEASING` is **idempotent**; calling it repeatedly is safe.

---

## 9. Failure scenarios

| Scenario | Expected behaviour |
|---|---|
| The sensor source fails | Fall back to the secondary source; if that also fails, drop to monitoring only, tell the user, **never crash** |
| An unknown sensor name | Show it under `uncategorized`, **never hide it** |
| An unknown SMC data type | Skip the key and log a warning |
| The helper connection drops | Drop to monitoring, notify; the helper releases via the watchdog |
| A fan does not reach its target | Detect the deviation and correct it; if it persists, tell the user honestly that control is limited on this model |
| A corrupt configuration | Fall back to the last valid state, show the offending field, leave the fans with the firmware |
| No fan found (fanless Mac) | Hide the fan section, do not offer to install the helper, keep monitoring |
| The log disk fills | Delete the oldest files at the hard limit and tell the user |

---

## 10. Release gates

| Gate | Required for 1.0 |
|---|---|
| All invariant tests pass | Yes |
| `Core` coverage at or above 85 percent | Yes |
| `make check` fully green | Yes |
| `kill -9` smoke test passes on real hardware | Yes |
| Sleep and wake smoke test passes | Yes |
| Notarisation succeeds | Yes |
| Five languages complete, pseudo-locale layout test passes | Yes |
| The README tested hardware section is honest | Yes |

---

## 11. Decision record index

| # | Decision | Status |
|---|---|---|
| [0001](docs/architecture/adr/0001-native-swift.md) | Native Swift and SwiftUI; Flutter and Electron rejected | Accepted |
| [0002](docs/architecture/adr/0002-product-name.md) | The product is named Boreas | Accepted |
| [0003](docs/architecture/adr/0003-minimum-macos-14.md) | Minimum target macOS 14.0 Sonoma | Accepted |
| [0004](docs/architecture/adr/0004-apple-silicon-only.md) | Apple Silicon only (arm64) | Accepted |
| [0005](docs/architecture/adr/0005-apache-2-license.md) | Apache-2.0 licence | Accepted |
| [0006](docs/architecture/adr/0006-independent-development-policy.md) | **Independent development policy** | Accepted |
| [0007](docs/architecture/adr/0007-privilege-split.md) | Unprivileged reading, privileged writing | Accepted |
| [0008](docs/architecture/adr/0008-smappservice-xpc.md) | SMAppService with signature verified XPC | Accepted |
| [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Dead man's switch (watchdog) | Accepted |
| [0010](docs/architecture/adr/0010-continuous-curve-model.md) | Continuous curve control model | Accepted |
| [0011](docs/architecture/adr/0011-hardware-abstraction.md) | Hardware abstraction: Live, Mock, Replay | Accepted |
| [0012](docs/architecture/adr/0012-core-layer-purity.md) | `Core` layer purity | Accepted |
| [0013](docs/architecture/adr/0013-json-config-zero-deps.md) | JSON configuration with zero dependencies | Accepted |
| [0014](docs/architecture/adr/0014-zero-telemetry.md) | Zero telemetry | Accepted |
| [0015](docs/architecture/adr/0015-automation-hooks-not-email.md) | Automation hooks instead of email | Accepted |
| [0016](docs/architecture/adr/0016-language-scope.md) | Five interface languages, English documentation | Accepted, partly superseded |
| [0017](docs/architecture/adr/0017-distribution-channels.md) | Distribution channels; App Store excluded | Accepted |
| [0018](docs/architecture/adr/0018-undocumented-sensor-api.md) | Accepting an undocumented sensor interface | Accepted |
| [0019](docs/architecture/adr/0019-signing-identity-deferred.md) | Signing identity deferred to the release phase | Accepted |
| [0020](docs/architecture/adr/0020-compute-die-sensor-group.md) | A `compute` group for die sensors with no cluster | Accepted |
| [0021](docs/architecture/adr/0021-english-only-repository.md) | The repository is written in English | Accepted |
| [0022](docs/architecture/adr/0022-panic-threshold-ceiling.md) | The panic threshold's ceiling is its default (95 °C) | Accepted |
| [0023](docs/architecture/adr/0023-watchdog-timeout-not-user-settable.md) | The watchdog timeout is not user settable | Accepted |

---

## 12. Deferred decisions

Deliberately left open. **Expected, not forgotten.**

| Topic | Waiting on | What would trigger the decision |
|---|---|---|
| In-app updates via Sparkle | Whether Homebrew alone is enough | User feedback after 1.0 |
| Local metrics endpoint | Real demand from home lab users | At least three requests |
| Traditional Chinese | Demand | A user request |
| Moving to an organisation | Contributor count | Three or more regular contributors |
| Per-fan default sensor group | Measurement on multi-fan hardware | Access to multi-fan test hardware |
| Whether the 95th percentile aggregate is needed | Usage data, which does not exist by design | User feedback |
| Enterprise deployment tooling | Enterprise demand | Version 2 scope |
