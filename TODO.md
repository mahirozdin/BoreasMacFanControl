# Boreas Master TODO — P0 → P8

- **Plan version:** 1.0
- **Baseline date:** 2026-07-31
- **Source blueprint:** v1.1 (frozen: `docs/blueprint/boreas-blueprint-v1.1.md`)
- **Overall status:** P0–P5 complete. **The fan write path is real and proven on this machine:** the helper takes a fan over, drives it (999→1548 rpm in 0.5 s), hands it back, and every failure path returns the hardware to firmware — `kill -9` in 1.0 s, a frozen client via watchdog in 15.8 s, both measured with the fan actually spinning. P4 is closed: the manual slider drives the hardware through the safety chain with rpm-exact tracking, the state machine logs every transition, and `make smoke` reproduces the whole hardware proof in one command (sleep leg attended-only, release blocker B5). The engine's signal path is in: a curve that cannot be non-monotone, hysteresis whose lock is a proven plateau, an asymmetric rate limiter, and the step-model comparison that keeps ADR 0010 measurable. P5 is closed: the composed engine runs against frozen golden scenarios, the published schema validates through the types, a broken file can only fall back, and migration is proven lossless. 144 tests, 10 gates. Next: P6.01.

---

## Status glossary

| Status | Meaning |
|---|---|
| `NOT_STARTED` | No sub-task has begun |
| `IN_PROGRESS` | At least one sub-task is done, not all |
| `BLOCKED` | Every remaining task waits on an external dependency (manual task) |
| `DONE` | All sub-tasks complete **and** acceptance criteria evidenced |

---

## Status summary

| Phase | Status | Theme | Next incomplete task |
|---|---|---|---|
| P0 | `DONE` | Documentation system and gates | (complete) |
| P1 | `DONE` | Repository skeleton and toolchain | (complete) |
| P2 | `DONE` | Hardware reading + Mock/Replay | (complete) |
| P3 | `DONE` | Privilege layer and daemon | (complete) |
| P4 | `DONE` | Fan control and the safety chain | (complete) |
| P5 | `DONE` | Control engine | (complete) |
| P6 | `NOT_STARTED` | User interface | P6.01 |
| P7 | `NOT_STARTED` | Maturation | P7.01 |
| P8 | `NOT_STARTED` | Release | P8.01 |

---

## The "do the next task" algorithm

1. Run the `BOOT.md` health snapshot. **If a gate is red, fix that first.**
2. Find the lowest numbered incomplete phase in the status summary above.
3. Are that phase's dependencies `DONE`? If not, move to the dependency.
4. Pick the first unchecked atomic task in the phase.
5. If the task depends on a manual task, **skip it, take the next one.** A blocker never freezes the work.
6. Do the task. **Run** the verification commands and read the output.
7. Pass the `AGENTS.md` §8 Definition of Done list.
8. Close the session: checkbox + status summary + run log — **in the same change**.

---

## P0 — Documentation system and gates

- **ID:** P0
- **Status:** `DONE`
- **Depends on:** nothing
- **Goal:** A machine enforced execution system that a coding agent can build from without asking a single question.

### Sub-tasks

- [x] **P0.01 — Initialise the repository.** `git init`, `.gitignore`.
- [x] **P0.02 — Freeze the blueprint.** Verbatim copy under `docs/blueprint/`; prove with `diff` and SHA-256.
- [x] **P0.03 — `AGENTS.md`.** Invariants (legal, identity, technology, architecture, safety, privacy, permission, localisation), selection algorithm, documentation update protocol, DoD.
- [x] **P0.04 — `BOOT.md` and `CLAUDE.md`.** Session protocol, health snapshot, the ten most broken rules.
- [x] **P0.05 — `ARCHITECTURE.md`.** MUST/MUST NOT invariants, trust boundaries, ADR index, deferred decisions.
- [x] **P0.06 — `LEGAL.md`.** Seven absolute prohibitions, permitted sources, independent development declaration, enforcement layers and **an explicit record of the missing layer**.
- [x] **P0.07 — Eight gates + `Makefile`.** Prove each with a deliberate violation.
- [x] **P0.08 — ADR library.** 18 ADRs; the Enforcement section filled in for each.
- [x] **P0.09 — `docs/README.md`.** Navigation map.
- [x] **P0.10 — Traceability matrix.** 25 sections mapped, zero missing.
- [x] **P0.11–P0.13 — `docs/reference/`.** Decision log, risk register, glossary.
- [x] **P0.14–P0.17 — `docs/product/`.** Overview, control model, scope, interface.
- [x] **P0.18–P0.21 — `docs/architecture/`.** System, hardware access, privilege model, configuration.
- [x] **P0.22–P0.25 — `docs/development/`.** Setup, repository structure, testing, localisation.
- [x] **P0.26–P0.28 — `docs/operations/`.** Observability, notifications, diagnostics.
- [x] **P0.29–P0.31 — `docs/release/`.** Build/signing, README specification, discoverability.
- [x] **P0.32 — `SECURITY.md`.** Security model and vulnerability reporting.
- [x] **P0.33 — Root `README.md`.** Development stage entry point + documentation map. The product README is written in P8.
- [x] **P0.34 — `make check` fully green.** Prove every gate passes with output and record it in the run log.

### Acceptance criteria

- All 25 blueprint sections mapped to a target document; **zero missing**
- The Enforcement section filled in for each of the 18 ADRs
- Each of the eight gates **proven with a deliberate violation**
- `make check` passes with zero errors

### Verification

```bash
make check
grep -c 'Missing sections' docs/reference/blueprint-map.md
ls docs/architecture/adr/*.md | wc -l    # should be 18
```

### Artifacts
`AGENTS.md` · `BOOT.md` · `CLAUDE.md` · `ARCHITECTURE.md` · `LEGAL.md` · `SECURITY.md` · `TODO.md` · `Makefile` · `scripts/gates/` · `docs/**`

### Risks
R6 (legal claim) — mitigated by `LEGAL.md` and ADR 0006.

---

## P1 — Repository skeleton and toolchain

- **ID:** P1
- **Status:** `DONE`
- **Depends on:** P0
- **Goal:** A repository ready for code: gates working, CI standing.

### Sub-tasks

- [x] **P1.01 — `Brewfile` and `scripts/bootstrap.sh`.** Check that tools *work* (`--version`), not merely that they exist; suggest an actionable fix when one is missing. Prove idempotency by running twice.
- [x] **P1.02 — `project.yml` (XcodeGen).** App and CLI targets (**the Daemon target moved to P3.02**: an empty daemon skeleton rightly breaks `gate-daemon`, which looks for XPC signature verification); `DEPLOYMENT_TARGET: 14.0`, `ARCHS: arm64`. The product name in **a single variable**. Prove `make generate` works.
- [x] **P1.03 — SPM package skeletons.** `Core`, `HardwareKit`, `SharedIPC` — empty but compiling. Prove `Core` depends only on Foundation via `make gate-layers`.
- [x] **P1.04 — `LICENSE`.** Download the full Apache-2.0 text **from the canonical source** (never retype it — error risk). Verify with a SHA.
- [x] **P1.05 — `NOTICE`.** Copyright notice + empty attribution section + "Acknowledgements".
- [x] **P1.06 — `CONTRIBUTING.md`.** Setup, style, commit rules, PR process, **independent development declaration** (`LEGAL.md` §4), guide for adding new sensor support. In English.
- [x] **P1.07 — `CODE_OF_CONDUCT.md`.** Contributor Covenant 2.1.
- [x] **P1.08 — `CHANGELOG.md`.** Keep a Changelog, with an `Unreleased` section.
- [x] **P1.09 — `.github/PULL_REQUEST_TEMPLATE.md`.** The three checkboxes of the `LEGAL.md` §4 declaration + test checklist.
- [x] **P1.10 — Issue templates.** `bug_report.yml`, `feature_request.yml`, **`unknown_sensor.yml`** (chip model, raw sensor names, expected group) and **`translation_fix.yml`** (single string fix — ADR 0016 addendum).
- [x] **P1.11 — `.swiftlint.yml` and `.swift-format`.** Including the force-unwrap ban for `Core`. Enable the `make lint` target.
- [x] **P1.12 — CI workflow.** lint → generate → build → test → gates. Targets that do not exist yet must be **skipped silently**, not break the build.
- [x] **P1.13 — `scripts/rename-product.sh`.** Renames the product in one command. Prove by running with a fake name and reverting.

### Acceptance criteria
- `make bootstrap` works on a clean machine and reports what is missing
- `make generate && make build` succeed
- CI green
- `make check` stays green

### Verification
```bash
make bootstrap && make generate && make build && make check
```

### Risks
R7 (burnout) — keep P1 mechanical and short.

---

## P2 — Hardware reading + Mock/Replay

- **ID:** P2
- **Status:** `DONE`
- **Depends on:** P1
- **Goal:** Unprivileged monitoring working, with **the abstraction layer in place from day one**.

> **This phase contains an investment that cannot be deferred.** The development hardware is a single model (R8); without the Mock and Replay layers most code paths can never be verified. → [ADR 0011](docs/architecture/adr/0011-hardware-abstraction.md)

### Sub-tasks

- [x] **P2.01 — Protocols.** `SensorSource`, `FanSource`, `PowerSource` (**`FanActuator` moved to P4.01** — the write path; its `Live` implementation depends on the daemon) — in `SharedIPC`/`HardwareKit`. Model types in `Core`, everything `Sendable`.
- [x] **P2.02 — `MockSensorSource` + `MockFanSource`.** Deterministic fake hardware fed from a scenario file. Prove with a test that the same scenario produces the same output.
- [x] **P2.03 — `ReplaySensorSource`.** Replays a JSONL log. Prove a recorded session is reproduced exactly.
- [x] **P2.04 — `LiveSensorSource`.** Temperature reading through the HID sensor services. Prove on real hardware that a sensor list and sane values come back.
- [x] **P2.05 — `SMCSensorSource` (fallback source).** Takes over when the primary fails. Prove by forcibly breaking the primary and falling back.
- [x] **P2.06 — `LiveFanSource`.** Fan count, current/min/max RPM. Prove it **requires no privileges**.
- [x] **P2.07 — Sensor name normalisation and grouping.** Pattern based classification; an unmatched sensor lands in `uncategorized` and is **never hidden**.
- [x] **P2.08 — Graceful degradation.** With both sources failing the app falls back to monitoring mode and **does not crash**. Prove with a test.
- [x] **P2.09 — Menu bar skeleton.** `MenuBarExtra`, one temperature + fan RPM. First visual output.
- [x] **P2.10 — `Core` coverage gate.** Make `Core` coverage ≥ 85% blocking in CI; prove the threshold is **actually enforced** with deliberately low coverage.

### Acceptance criteria
- All sensors and fan speeds readable **without** the daemon
- `make gate-layers` verifies a `Live` + `Mock` pair for every protocol
- A sensor source failure does not crash the app
- `Core` coverage ≥ 85% with the threshold blocking

### Verification
```bash
make test && make check
```

### Risks
R1 (API breakage), R2 (new chip naming), R8 (hardware coverage)

---

## P3 — Privilege layer and daemon

- **ID:** P3
- **Status:** `DONE`
- **Depends on:** P2
- **Goal:** A safe, narrow surfaced, self-policing privileged helper.

### Sub-tasks

- [x] **P3.00 — Empirical verification with a Development certificate.** **Prove** (do not assume) that `SMAppService` daemon registration and XPC signature verification really work with a free account Development certificate. If not, [ADR 0019](docs/architecture/adr/0019-signing-identity-deferred.md) is revised.
- [x] **P3.01 — XPC protocol (`SharedIPC`).** Exactly four methods. `make gate-daemon` verifies the surface.
- [x] **P3.02 — Daemon skeleton + launchd plist.** Registered via `SMAppService.daemon`.
- [x] **P3.03 — Two-way signature verification.** `SecCodeCheckValidity` + `SecRequirement`. **Prove with a test that an unsigned client is rejected.**
- [x] **P3.04 — Installation flow (UI).** What will happen, which files are written where and how to undo it are shown **before installing**.
- [x] **P3.05 — System Settings routing.** If background approval is needed, detect the state and take the user straight to the right pane.
- [x] **P3.06 — Removal flow.** UI button + `boreas uninstall --all`. Prove nothing is left behind after removal.
- [x] **P3.07 — `Watchdog`.** Heartbeat monitoring, hand back after 3 misses. **Prove with `kill -9`.**
- [x] **P3.08 — `StateRestorer`.** Immediate hand back on sleep, shutdown and daemon stop events. Prove idempotency.
- [x] **P3.09 — Watchdog invariant tests.** The timeout cannot be set outside 10–60 s; the fans are handed back when the heartbeat stops.

### Acceptance criteria
- Installation with a single administrator authentication
- After `kill -9` the fans return to firmware within the watchdog window (**measured on real hardware**)
- `make gate-daemon` green
- An unsigned client is rejected

### Verification
```bash
make test && make check && scripts/smoke-test-hardware.sh
```

### Risks
R5 (installation flow stalling)

---

## P4 — Fan control and the safety chain

- **ID:** P4
- **Status:** `DONE`
- **Depends on:** P3
- **Goal:** Taking the fans over — and handing them back — safely.

### Sub-tasks

- [x] **P4.01 — `LiveFanActuator`.** Takeover sequence: save the original state → force the mode → write the target. Closed loop verification.
- [x] **P4.02 — `releaseToFirmware`.** Hand back sequence + retry with exponential backoff. Idempotent.
- [x] **P4.03 — `SafetyGovernor` (K4).** A command outside physical limits is rejected and logged. Prove with an out-of-range command.
- [x] **P4.04 — K1 fan floor.** Output never goes below the hardware minimum.
- [x] **P4.05 — K2 thermal state.** `ProcessInfo.thermalState`; `serious` → 55% floor, `critical` → 100%. **Cannot be switched off.**
- [x] **P4.06 — K3 panic threshold.** Above `T_panic` → 100%, locked for ≥ 30 s. The threshold can only be lowered.
- [x] **P4.07 — Safety chain invariant tests.** Including "no layer may lower the output".
- [x] **P4.08 — Manual control (single slider).** All fans; the safety chain stays active.
- [x] **P4.09 — State machine.** MONITORING / CONTROLLING / PANIC / RELEASING transitions are logged.
- [x] **P4.10 — Hardware smoke test script.** `scripts/smoke-test-hardware.sh` — take over/hand back, `kill -9`, sleep/wake.

### Acceptance criteria
- The fans are taken over and handed back safely
- The K1–K5 invariant tests pass
- The `T_panic` and `critical` scenarios produce 100% regardless of user settings
- The smoke test passes on real hardware

### Verification
```bash
make test && scripts/smoke-test-hardware.sh
```

### Risks
R3 (firmware fighting back), R4 (user induced thermal risk)

---

## P5 — Control engine

- **ID:** P5
- **Status:** `DONE`
- **Depends on:** P4
- **Goal:** The continuous curve model, implemented in full and proven.

### Sub-tasks

- [x] **P5.01 — `Curve` model and interpolation.** The monotonicity constraint enforced at the type level.
- [x] **P5.02 — Property tests (curve).** "A monotone curve produces monotone output", "output always within `[fanMin, fanMax]`".
- [x] **P5.03 — EWMA smoothing.** The `α` parameter; boundary behaviour (0.0 and 1.0) tested.
- [x] **P5.04 — Dual curve hysteresis.** Including the direction lock. Prove with a test that there is no oscillation around a threshold.
- [x] **P5.05 — Asymmetric rate limiter.** `maxRise` / `maxFall` applied independently.
- [x] **P5.06 — Sensor aggregator.** `max` / `mean` / `p95`; selectable per group.
- [x] **P5.07 — Profile model and triggers.** Power source, application, time, battery, display, thermal state, manual.
- [x] **P5.08 — Arbitration.** Priority order + manual choice wins + no jumps at transitions.
- [x] **P5.09 — Comparison test.** "Had a discrete step model been used, the threshold would jump" — keeps ADR 0010 alive in code.
- [x] **P5.10 — Configuration schema + validation.** `schema/config.schema.json`; range constraints; a **broken configuration does not crash** test.
- [x] **P5.11 — Schema migration infrastructure.** Version field, migration function, pre-migration backup. Prove no data loss with a test.
- [x] **P5.12 — Golden file scenarios.** Recorded thermal scenarios → expected command sequence.

### Acceptance criteria
- All engine invariants pass
- A broken configuration does not crash the app; it falls back to the last valid state
- Golden file tests pass
- `Core` coverage ≥ 85%

### Verification
```bash
make test && make check
```

---

## P6 — User interface

- **ID:** P6
- **Status:** `NOT_STARTED`
- **Depends on:** P5
- **Goal:** The face of the product — including the curve editor.

### Sub-tasks

- [ ] **P6.01 — Design system.** **Separate continuous colour scales** for temperature and fans; red reserved for panic/error.
- [ ] **P6.02 — Menu bar panel.** Profile picker, fans, grouped temperatures.
- [ ] **P6.03 — Menu bar status item.** Configurable content, horizontal/vertical, compact mode, hidden-item warning.
- [ ] **P6.04 — Main window — Monitoring tab.** Swift Charts; **temperature and fan charts on the same time axis**.
- [ ] **P6.05 — Main window — Control tab.** The active profile **and why it is active**; safety chain status.
- [ ] **P6.06 — Curve editor.** Draggable points, monotonicity constraint, live operating point, 60 s trail, hysteresis band.
- [ ] **P6.07 — Curve editor — numeric editing.** Table view; for accessibility and precision.
- [ ] **P6.08 — Settings window.** Seven tabs.
- [ ] **P6.09 — Main window — Diagnostics tab.** Wording that honours the honesty rule.
- [ ] **P6.10 — Global shortcuts.**
- [ ] **P6.11 — Localisation infrastructure + `en`/`tr`.** String Catalog; `make gate-i18n` green.
- [ ] **P6.12 — Accessibility pass.** VoiceOver, keyboard navigation, the curve presented as a point list, colour-independent information.
- [ ] **P6.13 — Pseudo-locale layout test.** In CI; overflow checking with artificially lengthened strings.

### Acceptance criteria
- `make gate-i18n` green
- Every critical flow completable with VoiceOver
- No overflow in the pseudo-locale test
- The curve editor enforces the monotonicity constraint

---

## P7 — Maturation

- **ID:** P7
- **Status:** `NOT_STARTED`
- **Depends on:** P6
- **Goal:** A product that is dependable in daily use.

### Sub-tasks

- [ ] **P7.01 — Notification system.** Triggers + **suppression window** + once-per-session rule + coalescing.
- [ ] **P7.02 — Logging infrastructure.** JSONL/CSV, rotation, hard disk ceiling. **The active safety layer is recorded.**
- [ ] **P7.03 — Diagnostic checks.** Fan response, fan balance, sensor validity, thermal history, battery, storage.
- [ ] **P7.04 — CLI (`boreas`).** `status`, `profile`, `install`, `uninstall --all`, `export`, `import`.
- [ ] **P7.05 — Support report generator.** **A local file**, no automatic submission.
- [ ] **P7.06 — `ru` / `es` / `zh-Hans` translations.** Russian plural forms correct.
- [ ] **P7.07 — `TRANSLATORS.md`.**
- [ ] **P7.08 — Troubleshooting documentation.** Under `docs/`; summary in the README.
- [ ] **P7.09 — Unknown sensor report flow.** One click from the UI to a filled issue template.

---

## P8 — Release

- **ID:** P8
- **Status:** `NOT_STARTED`
- **Depends on:** P7
- **Goal:** A signed, notarized, discoverable v1.0.

### Sub-tasks

- [ ] **P8.01 — Signing script.** App, daemon and CLI separately; Hardened Runtime. ⛔ M03
- [ ] **P8.02 — Notarization script.** `notarytool` + `stapler`. **No release if it fails.** ⛔ M03 M04
- [ ] **P8.03 — DMG build.** SHA-256 published. ⛔ M03
- [ ] **P8.04 — CI release job.** Triggered by a tag. ⛔ M03 M04
- [ ] **P8.05 — Product `README.md` (English).** Icon source ready: `Design/icon/`. Per `docs/release/readme-spec.md`; **an honest "Tested hardware" section**.
- [ ] **P8.06 — README translations.** `tr`, `ru`, `es`, `zh-Hans` + a "may lag behind" note.
- [ ] **P8.07 — Discoverability setup.** Repository description, topics, Homebrew cask `desc`, README FAQ.
- [ ] **P8.08 — Homebrew cask.** Submission (depends on M05). ⛔ M05
- [ ] **P8.09 — Release gate checklist.** Every gate in `ARCHITECTURE.md` §10 green.

---

<a id="manual-tasks"></a>
## Manual tasks — outside the system

Work the agent cannot do; it belongs to **the project owner**. This is the canonical answer to *"what is on my plate?"*.

| # | Task | Why it is needed | Blocks | Status |
|---|---|---|---|---|
| M01 | Trademark search (`Boreas`) | No release before the name is settled | P8 | **DONE** (2026-08-03, no obstacle) |
| M02 | Create the GitHub repository `boreas-mac-fan-control`, set description and topics | No CI or distribution without it | P1.12, P8 | **DONE** (2026-08-02, private) |
| M03 | Export the Developer ID certificate, define it as a GitHub secret | Distribution only. Not needed for P1–P7 — see [ADR 0019](docs/architecture/adr/0019-signing-identity-deferred.md) | **P8 only** | OPEN (deferred) |
| M04 | Generate an App Store Connect API key (for notarytool), define it as a secret | Required for notarization | **P8 only** | OPEN (deferred) |
| M05 | Verify Homebrew cask name availability and submit | Primary distribution channel | P8.08 | OPEN |
| M06 | ~~Native speaker translation review~~ | **REMOVED** (2026-08-03). Translations are produced in-project; their origin is marked in `TRANSLATORS.md` — [ADR 0016 addendum](docs/architecture/adr/0016-language-scope.md) | — | CANCELLED |
| M07 | Collect sensor/fan reports from the community for other Mac models | R8 — unverifiable code paths | Ongoing | OPEN |
| M08 | Application icon design | Visual identity | P8.05 | **DONE** (2026-08-03, `Design/icon/`) |

**Not included:** local tool installation (`brew install …`), repairing a broken local setup, `xcodegen generate`. **Those are the agent's job.**

---

## Cross-phase release blockers

Conditions that **stop a release**, independent of checkbox order:

| # | Blocker |
|---|---|
| B1 | Any third party commercial product name anywhere in the repository (`LEGAL.md` Y5) |
| B2 | Any `make check` gate red |
| B3 | A safety chain invariant test failing |
| B4 | Notarization failing |
| B5 | The `kill -9` smoke test not passed on real hardware |
| B6 | The README "Tested hardware" section missing or overstating coverage |
| B7 | Blank interface text in any language due to a missing translation |
| B8 | Signing material or a secret present in the repository |

---

## Run Log

Append-only. History is **never rewritten**; a wrong entry is corrected by a new line.

| UTC | Session | Task | Result | Summary | Verification | Artifacts | Risk/Blocked | Handoff |
|---|---|---|---|---|---|---|---|---|
| 2026-07-31 | setup | P0.01–P0.07 | DONE | Repository initialised, blueprint frozen (SHA-256 match proven), governance layer and eight gates written. **Finding:** the gates first used `mapfile`; macOS `/bin/bash` 3.2.57 does not have it, the scan never ran and the gate still reported PASS — the classic fake gate. Made bash 3.2 compatible via `scripts/gates/_lib.sh`, and `require_tools` was added so a missing command can never pass silently. | `make gate-names` PASS · `make blueprint-check` PASS · all eight gates proven with deliberate violations (8/8 caught) | `AGENTS.md` `BOOT.md` `CLAUDE.md` `ARCHITECTURE.md` `LEGAL.md` `Makefile` `scripts/gates/*` | — | Next: P0.08 |
| 2026-07-31 | setup | P0.08–P0.32 | DONE | 18 ADRs (Enforcement sections filled), the `docs/` tree, the traceability matrix (25/25 mapped, zero missing), `SECURITY.md`. **Finding:** while writing `privilege-model.md` a third party helper path slipped into the text — a Y5 violation. Fixed before the file was committed; git history scanned and confirmed clean. The incident makes concrete why ADR 0006's "the automated layer cannot keep a name list" limitation requires a human review layer. **Second finding:** the `... \| grep \| head` command I wrote for the history scan always returned 0 (`head`'s exit code) — the check command itself was a fake gate; switched to a count based check. | Forbidden term scan: 0 in history, 0 in the working tree | 18 ADRs · `docs/**` (44 files) · `SECURITY.md` | R6 mitigated | Next: P0.33 |
| 2026-07-31 | setup | P0.33–P0.34 | DONE | Root README (development entry point) written and `make check` brought to full green. **Finding 1:** gate-names was catching the files that DESCRIBE the rule (readme-spec, ADR 0002 and so on). Instead of a fixed exception list, the `gate-names:policy-doc` marker convention was established; a file declares its own exemption and the gate reports the exempt file count on every run. After adding the exemption the gate was **proven again** (a violation without the marker is caught, with the marker it is exempt). **Finding 2:** docs-check caught me referencing a gate that does not exist (a `gate-repo` target) in `AGENTS.md`; the reference was fixed to the `gate-layers` target and the `format`/`release` targets were added to the Makefile. The frozen blueprint was excluded from this check (it describes planned targets, not current state). **Finding 3:** during probe cleanup `git checkout` twice restored the staged broken version — after probes, repair content directly instead of `git checkout`. | `make check` exit=0, 8/8 gates PASS · docs-check proven with 3 separate violations (broken link, nonexistent target in the matrix, ADR missing from the index) | `README.md` `TODO.md` `LEGAL.md` `Makefile` `scripts/gates/check-docs.sh` | — | Next: P1.01 |
| 2026-07-31 | setup | P0.34 (fix) | DONE | The previous entry was committed while `make check` was red, unnoticed — a discipline violation, closed with a corrective commit. The cause was recursive: docs-check caught the **run log itself** referencing a nonexistent target in `make <target>` form. The text was reworded to name targets without the `make` prefix. **Lesson:** documentation text is inside gate scope too; the syntax used while describing a finding can trip a gate. | `make check` exit=0, 8/8 PASS | `TODO.md` | — | Next: P1.01 |
| 2026-08-02 | setup | M02, P1.04, P1.05 | DONE | GitHub repository `mahirozdin/boreas-mac-fan-control` created and pushed; description and 16 topic labels set per §18.4; wiki and projects disabled. **The repository was deliberately opened PRIVATE:** there was no `LICENSE` at that moment, and a repository published without a licence defaults to "all rights reserved" — the opposite of open source intent. P1.04 and P1.05 were then done; nothing blocks flipping to public any more, the decision rests with the project owner. The LICENSE text came from the GitHub Licenses API (no new external source needed, gh was already authorised); 202 lines, the patent grant clause verified. Because of the apache.org link inside LICENSE, `apache.org` was added to the gate-names allowlist. | `make check` exit=0, 8/8 PASS · LICENSE integrity checks PASS (header, version, patent clause, 202 lines) | `LICENSE` `NOTICE` `TODO.md` `scripts/gates/check-names.sh` | M02 closed | Next: P1.01 |
| 2026-08-03 | setup | M01, M06, M08 + ADR 0019 | DONE | **M01** closed (the project owner ran the trademark search, no obstacle). **M06 cancelled** — translations will be produced in-project; an addendum was written to ADR 0016: origin is explicitly marked in `TRANSLATORS.md`, the `translation_fix.yml` template added. Where we cannot guarantee quality, we are at least honest about it. **M08 complete** — the four blade fan icon was produced with hand written SVG geometry (no generative image AI: the copyright provenance would be unclear, and LEGAL.md does not absorb that). Ten variants were eliminated. **Rasterisation caught a real geometry bug:** blade roots at r=110, hub at r=88 — a 22px gap, invisible at preview size, a broken joint at full resolution; the roots were pulled inside the hub. The first five variants (thin blades) read as 'spider/X'; switched to wide blade geometry. **ADR 0019** written: the signing identity is a P8 precondition, P1–P7 are not blocked; it is recorded in advance that choosing Path B (unsigned) would leave the privileged daemon nonfunctional and split the product in two. | `make check` exit=0 · docs-check 19 ADR sync PASS · icon visually verified at 1024/512/256/128/64/32 | `Design/icon/*` · `docs/architecture/adr/0019-*` · ADR 0016 addendum · `ARCHITECTURE.md` `decisions.md` `ui.md` `TODO.md` | M03/M04 deferred to P8 | Next: P1.01 |
| 2026-08-03 | setup | Selection mechanism + P1 (11 tasks) | DONE | **Structural change:** next task selection was handed to a machine via `scripts/next-task.py`. Every task depending on a manual task is skipped, phase boundaries are ignored. ⛔ markers were placed on the P8 tasks; proven with three scenarios (an unblocked task is chosen · with only blocked tasks left, exit=1 plus which manual task is needed · resolving the manual task unlocks the work). `AGENTS.md` §4 and `BOOT.md` §4 were bound to it. **P1:** toolchain set up (xcodegen/swiftlint/xcbeautify); `swift format` turned out to be built into Swift 6.2 and the separate package dependency was dropped. Three SPM packages (Core/HardwareKit/SharedIPC) compile, 4 tests pass. `project.yml` written, App and CLI compile, the CLI was run. Lint, LICENSE, NOTICE, CONTRIBUTING, CODE_OF_CONDUCT, CHANGELOG, PR and 4 issue templates, CI. **Four real bugs caught and fixed:** (1) `bootstrap.sh` passed commands as a single string; zsh does no word splitting, so a healthy Xcode looked broken — switched to argument arrays. (2) In a SwiftLint custom rule `^` anchors to the start of the file, not the line; fixed with `\b` + `match_kinds: [identifier]`. (3) `rename-product.sh` used the `\b` word boundary, which BSD sed does not support, and the name silently never changed — fixed with `[[:<:]]` `[[:>:]]`. (4) `docs-check` mistook the English prose verb in 'make participation' for a Makefile target — narrowed to count only backtick or code block contexts. **Scope fix:** the Daemon target was moved out of P1.02 into P3.02; an empty daemon skeleton rightly breaks `gate-daemon`. | `make check` 8/8 PASS · `make build` PASS · `make test` 4/4 PASS · `make lint` PASS · Xcode App and CLI builds PASS · CLI run · next-task 3 scenarios · lint custom rules 4 cases · rename script on real files · docs-check 3 cases | `scripts/next-task.py` `scripts/bootstrap.sh` `scripts/rename-product.sh` `Brewfile` `project.yml` `Packages/**` `App/**` `CLI/**` `.swiftlint.yml` `.swift-format` `.github/**` `CONTRIBUTING.md` `CODE_OF_CONDUCT.md` `CHANGELOG.md` | — | Next: P2.01 |
| 2026-08-03 | setup | P1.12 verification | DONE | CI was run remotely and **caught a real mismatch**: the runner's default Xcode offered Swift 6.1 while the packages require `swift-tools-version: 6.2` → 'Could not resolve package dependencies'. Invisible locally. A step was added to the workflow that selects the newest `Xcode*.app` and **fails loudly instead of passing silently** when Swift < 6.2. The runner picked Xcode 26.6.0 / Swift 6.3. All three jobs green. | GitHub Actions: Gates ✓ · Lint ✓ · Build and test ✓ · 4/4 tests · App and CLI builds ✓ | `.github/workflows/ci.yml` | — | Next: P2.01 |
| 2026-08-03 | setup | P2.07 + Core model types | DONE | Five model types (`SensorGroup`, `SensorReading`, `FanState`, `Duty`, `PowerContext`) and `SensorClassifier` written into Core; 21 tests pass. **Design decision — `Duty` is a type, not a `Double`:** if every call site had to remember to clamp, whoever forgot would produce a fan command the hardware rejects. A type that cannot hold an invalid value eliminates that bug class instead of testing for it. **A test caught a real gap:** `Duty(.infinity)` collapsed to zero — the wrong direction. In fan control the two errors are not symmetric: too much air is noise, too little is heat. Ambiguous input now resolves UP (`+inf`→1, `NaN`→1, the reasoning written in code). This is the type level counterpart of the safety chain's "no layer may lower the output" rule. **Classification order is critical:** unless the `efficiency` rule is tried BEFORE generic `cpu`, every efficiency cluster is filed as performance — a test protects the order. An unmatched sensor falls into `uncategorized` and is not hidden; it is the only signal that hardware support is incomplete. | `swift test` 21/21 PASS · `make check` 8/8 · `make lint` PASS | `Packages/Core/Sources/Core/Models/*` `Sensors/SensorClassifier.swift` + tests | — | Next: P2.01 |
| 2026-08-03 | setup | P2.01–P2.03, P2.05–P2.07 | DONE | Hardware layer: 3 protocols, 3 Mocks, Replay, 3 Live implementations (SMC sensors, SMC fans, IOKit power). 48 tests pass. **Verified on real hardware:** a Mac mini M4 reads 174 sensors and 1 fan (1000 rpm, 1000–4900). **The most valuable finding — a bug no mock could catch:** I had defined `SMCKeyData_t` as a Swift struct; field sizes looked right but the C alignment padding did not match and every call returned `kIOReturnBadArgument`. Unit tests could never catch this — a mock cannot disagree about struct padding. Switched to writing into an 80 byte buffer at explicit offsets, the offset table written in code. **Second finding:** SMC keys are opaque codes like `TCMz`, not readable names — 174 of 174 sensors fell into `uncategorized`. The prefix distribution on real hardware was studied and SMC key heuristics added (Tp/Te/Tg/Ts/TH…); now only 5 remain unclassified. The HID source (P2.04) is still needed for readable names. **Third:** Swift 6 strict concurrency rejects `NSLock` in async contexts — stateful mocks became `actor`s. **Tool conflict:** `swift-format` adds trailing commas, SwiftLint banned them; every `make format` broke `make lint`. The boundary was drawn: formatting belongs to swift-format, meaning to SwiftLint. **Gate bug:** because of `grep -i`, the uppercase requirement in the `instead of [A-Z]` pattern was meaningless and even 'instead of returning' matched — case sensitive patterns were split out. Also the gates' `**/*.swift` glob missed subdirectories; switched to directory paths. **Scope:** `FanActuator` moved to P4.01 (the write path; its `Live` implementation depends on the daemon). | `swift test` 48/48 PASS · `make check` 8/8 · `make lint` PASS · `boreas status` and `boreas sensors` run on real hardware | `Packages/Core/Sources/Core/{Models,Sensors}` `Packages/HardwareKit/Sources/HardwareKit/{Protocols,Mock,Replay,Live,SMC}` `CLI/Sources/main.swift` + tests | — | Next: P2.04 |
| 2026-08-04 | setup | P2.04, P2.08–P2.10 + ADR 0020 | DONE | **The HID sensor source** written — an undocumented interface resolved via `dlsym`; every symbol optional, falling back to SMC when unresolvable. On real hardware it returns **40 named sensors** (`PMU tdie1`, `NAND CH0 temp`) instead of the SMC path's 174 opaque keys. **Real hardware exposed a classification bug:** 39 of the 40 sensors have the form `PMU tdie<n>` and the `pmu → power` rule filed them all under power. Had a user bound a curve to `compute.performance`, **no sensor would match** on this machine — a curve silently bound to nothing, the worst failure mode because nobody notices. The blueprint taxonomy had no place for these sensors; **ADR 0020** added the `compute` group (die temperatures not attributable to a cluster). The `tdie`/`tdev` rules are tried before generic `pmu` and a test protects the order. 37 sensors now sit in `compute`. **Graceful degradation** was split into `FallbackSensorSource` so it can be tested with mocks — wiring two real backends together and hoping is not a test. A single failure does not demote (3 consecutive required), recovery is immediate. 8 tests. **The menu bar app** runs on live data: launched on real hardware, CPU 0.0%, no Dock icon, no error log. Memory 73.4 MB — target is 60 MB, but this is a Debug build; measure Release in P6. **The coverage gate** added and proven to actually enforce its threshold (red at 99%, green at 50%). The gate exposed a gap: `PowerContext` lived in Core but its test in HardwareKit, so its coverage read 0% — Core tests added, coverage 95.8% → 99.4%. | `swift test` 69/69 PASS · `make check` 9/9 · `make lint` PASS · CLI and app run on real hardware · coverage gate proven with two thresholds | `HIDSensorSource` `FallbackSensorSource` `LiveSensorSource` `SMCSensorSource` `App/Sources/**` `scripts/gates/check-coverage.sh` ADR 0020 | Memory target must be verified in Release | Next: P3.00 |
| 2026-08-04 | setup | P3.01–P3.03 | DONE | The privileged helper written: four method XPC surface, K4 safety filter, watchdog, IOKit power notifications. Embedded in the app bundle, both signed with the development team. **Certificate finding (half of P3.00):** the value in parentheses in `security find-identity` output is **not the Team ID** — the label value and the certificate's real team identifier turn out to differ. My first attempt was rejected because of this. This machine also already has a **Developer ID Application** certificate; ADR 0019's "Path A closed" premise does not actually hold. **It turned into a better design:** instead of embedding the team identifier at build time, the helper reads it from its own signature (`SecCodeCopySelf`). Nothing to configure, no drift against signing settings, the same binary correct under both Development and Developer ID signatures. **Manual signature verification was abandoned:** `connection.auditToken` is not exposed to Swift; `setCodeSigningRequirement`, supported since macOS 13, exists. Rewriting a security decision Apple got right means owning a brand new bug surface. The gate was updated to accept this API as well. **A gate gap was closed:** gate-daemon checked the protocol surface only when daemon sources existed, and would have missed a `public func` form method. It now extracts methods from the protocol body and runs independently of the daemon; proven with three scenarios (new func, hidden public func, removed method). **A second fake gate found:** `swift format ... || echo ✓` inside `make lint` presented real formatting violations as success. Existing directories are now collected explicitly and the exit code is no longer swallowed; proven with a violation. **An untestable safety layer fixed:** the K4 filter lived in the Daemon target, which has no test bundle. The pure logic moved to `Core.FanTargetGuard`, 8 tests written; the daemon is a thin adapter. | `swift test` 77/77 PASS · `make check` 9/9 · `make lint` PASS (after the fake gate fix) · app+helper built signed, bundle layout verified | `Daemon/**` `Packages/SharedIPC/**` `Core/FanTargetGuard` `project.yml` `Makefile` | **Root daemon registration awaiting approval** | Next: P3.00 (registration attempt) |
| 2026-08-04 | setup | P3.00 + P3.03 verification | DONE | **The privileged helper was actually installed and ran.** Registration succeeded with the Development certificate; ADR 0019's assumption confirmed, no revision needed. `register()` returned `Operation not permitted` but the status went `notFound` → `requiresApproval` — not an error, the documented macOS 13+ approval flow. After the project owner approved in System Settings the status became `enabled` and the daemon started on demand (`runs = 1`). **G5 proven with three scenarios:** correct team+identifier accepted (nonce echoed correctly, fan read over the privileged path: 1001 rpm, 1000–4900); a valid Apple client signed with **a different team** was rejected by the daemon; a client signed with **the right team but the wrong bundle identifier** was rejected too. Both team and identifier are enforced. **My test run found a real deadlock:** `HelperCommands` runs in a `@MainActor` context, `Task {}` inherits that isolation, and I was blocking the main thread with a semaphore — the task could never run. The symptom looked like 'the daemon is not answering'; `runs = 0` and zero logs showed the problem was the caller, not the daemon. Fixed with `Task.detached`. **I committed once while lint was red** — a discipline violation, closed with a corrective commit. The four element tuple became the `FanSnapshot` type: four unlabelled numbers crossing a privilege boundary are exactly the thing that gets transposed in a refactor. | Registration: `enabled`, `runs=1`, `pid` assigned · ping: nonce matched · describeFans: 1 fan · rejection: 2/2 scenarios · `make check` 9/9 · 77 tests | `App/Sources/Helper/**` `BoreasApp.swift` | The helper stays installed on this machine | Next: P3.04 |
| 2026-08-04 | setup | P3.04–P3.06 | CLAIMED | Installation life cycle chunk claimed: installation flow UI, System Settings routing, removal flow. | — | — | — | — |
| 2026-08-04 | setup | P3.04, P3.05 | DONE | **The setup window:** what will happen, which files are written where and how to undo it are shown in three sections **before the install button**; an entry added to the menu bar panel (never shown on fanless models, and when not installed it is a quiet offer, not an error — I4). The approval-pending state is detected, one button takes the user to System Settings, the status is polled every 2 s and verification starts by itself once approval lands. **Finding 1 (documentation error):** the P0 placeholder table in `privilege-model.md` assumed the legacy install paths (`/Library/PrivilegedHelperTools`, `/Library/LaunchDaemons`); `SMAppService` writes **nothing** to those locations — with the helper registered and running it was shown that neither directory contains an entry of ours, and the table was replaced with the empirically verified footprint (marked as a "found error"). No new ADR needed since the decision did not change (ADR 0008 already chose SMAppService). **Visual evidence was produced not with screenshots but with a `--render-setup` command added to the app:** the Screen Recording permission is against the spirit of I2 and cannot be approved in a headless session; `ImageRenderer` produces PNGs of all six phases deterministically and permission-free, all six visually verified. **P3.05 evidence limit (honest record):** `requiresApproval` could not be triggered live this session because BTM remembers the earlier approval and re-registration goes straight to `enabled`; the state leg was observed on real hardware in P3.00 with the same wrapper, the approval UI verified via render, and the routing API (`openSystemSettingsLoginItems`) executed without error (System Settings was already open, so who opened the window cannot be proven on its own — opening that pane is the API's sole function). Automated testing of the install flow is planned at the XCUITest layer in the test strategy; this phase's evidence is real hardware integration. | `xcodebuild` App PASS · `make lint` PASS · `make test` 77/77 PASS · `make check` 9/9 PASS · 6 phase PNG renders + visual verification · app run live, no error log, clean quit · `--helper-ping`: signatures matched, 1 fan | `App/Sources/Helper/HelperSetupModel.swift` `HelperSetupView.swift` `BoreasApp.swift` `MenuBarPanel.swift` `docs/architecture/privilege-model.md` | The `requiresApproval` leg should be exercised live on a clean machine (via M07 community reports) | Next: P3.06 |
| 2026-08-04 | setup | P3.06 | DONE | **The removal flow, three ways:** the Remove button in the setup window, `boreas uninstall [--all]`, the System Settings toggle. Because the `SMAppService` registration is bound to the calling process's bundle, the CLI delegates removal to the maintenance entry point of the app it locates via LaunchServices; running it with nothing registered is not an error (idempotency proven with two consecutive runs, both exit 0). The user data directory name is read from the located bundle at runtime — the product name is not embedded in code (K2). **"Nothing left behind" proven from five angles:** `SMAppService` status `not registered` · `launchctl print` "Could not find service" · 0 entries of ours in the system folders · `~/Library/Application Support/Boreas` deleted (a representative fixture file had been placed there deliberately; `--all` really removed it) · no daemon process. The CLI `status` command's stale "lands in P3" line was replaced with the real helper state (by asking the app; measured overhead ~70 ms). **Finding 2 (timing):** a remove → sub-second reinstall sequence produces a transient `Operation not permitted` + `notRegistered` from `register()`; ~8 s later the same call cleanly returns `enabled`. Recorded in `privilege-model.md` as a "known edge"; the Try Again button in the UI covers it. **Finding 3:** BTM remembers the approval across removal — re-registration went straight to `enabled` without a System Settings prompt. The helper was reinstalled and the machine returned to baseline: ping green, signatures match, 1 fan visible. | `boreas uninstall --all` exit 0 + five evidence commands · idempotent rerun exit 0 · reinstall `enabled` · `--helper-ping` PASS · `make lint` PASS · `make test` 77/77 · `make check` 9/9 | `CLI/Sources/Uninstall.swift` `CLI/Sources/main.swift` `docs/architecture/privilege-model.md` | The fast remove-reinstall edge is only reachable by hand; automatic retry deliberately not added (visible error + Try Again preferred) | Next: P3.07 |
| 2026-08-04 | migration | ADR 0021 | CLAIMED | English migration claimed: translate the remaining 77 files, rename the dotted-I permission invariant ids to ASCII (I1–I4), update the TODO parser contract, turn gate-language green. | — | — | — | — |

| 2026-08-04 | migration | ADR 0021 (completion) | DONE | **The English migration is complete and gate-language is green.** 77 files translated: 20 ADRs + the ADR index, the whole docs/ tree, TODO.md (including the run log — content preserving, following the owner's precedent of scrubbing account identifiers), all gate scripts, Makefile, bootstrap/rename scripts, CI workflow, project.yml, package manifests, plists, lint config, icon docs. Five parallel translation agents handled prose; the coupled executable set (parser, gates, TODO) was done by hand. **The parser contract migrated with it:** phase dependency key is now `Depends on:`, the manual section heading `Manual tasks`, and `next-task.py` is English — re-proven with the same three scenarios as its introduction (picks P3.07 · skips a ⛔-blocked task · exit 1 naming the manual tasks when everything is blocked). The dotted-I permission invariant ids became ASCII I1–I4 repo-wide (docs, AGENTS.md, code comments). **Finding 1 (a fragile gate):** gate-language matched single BYTES, not characters — under the C locale (headless shells, CI) grep degrades a multibyte class into a byte class, and emoji/typography sharing continuation bytes (0x9E/0x9F/0xB0/0xB1) false-positived 11 files that contain no Turkish at all; on a terminal with a UTF-8 $LANG the same gate looked correct. The locale is now pinned inside the gate and it was proven three ways: green on the migrated repo, red on a planted Turkish probe, green on an emoji/degree/± probe. **Finding 2 (a real H1 violation predating the migration):** the Turkish source of ADR 0015 and notifications.md named third party commercial chat products as integration examples — invisible to gate-names, which by design keeps no name list. Genericized during translation ("a chat service webhook"); open source integration targets (ntfy, Home Assistant) kept, matching how the repo already names Homebrew and GitHub. The frozen blueprint retains the originals as a historical record, as ADR 0021 intends. **Finding 3:** the Makefile header still said a pre-rename product name candidate ("Zephyr") — visible in `make help` output; rename-product.sh only rewrites the current name, so the leftover survived every rename. Now Boreas. **Smaller repairs while passing through:** stale pre-0021 policy sentences in localization.md/setup.md now point at ADR 0021 · setup.md command table gained the missing gate-language/gate-coverage rows · bootstrap.sh no longer hardcodes the gate count · dead Turkish Y6 patterns dropped from gate-names (gate-language guards that path first) · docs-check matrix markers moved to the English "Missing sections"/none/MISSING forms in lockstep with the matrix translation · an innocent geometry comparison in the icon README was reworded because its English form collided with a Y6 pattern · run log table row continuity fixed (stray blank lines between rows). | gate-language proven 3 ways (repo green · Turkish probe red · emoji probe green) · `make check` 10/10 PASS · `make test` 77/77 PASS · `make lint` PASS · App and CLI builds PASS · next-task 3 scenarios PASS · residual sweep for Turkish function words outside excluded paths: 0 | 77 files across the repository (docs/**, scripts/**, TODO.md, AGENTS.md contract row, Makefile, CI, manifests, App comments) | `Türkçe` remains only as the native language name in the localization table (outside the scanned character set, parallel to the other native names) | Next: P3.07 |

| 2026-08-04 | setup | P3.07–P3.09 | CLAIMED | Safety chain chunk claimed: watchdog with a `kill -9` proof, StateRestorer, watchdog invariant tests. | — | — | — | — |

| 2026-08-04 | setup | P3.07–P3.09 | DONE | **The dead man's switch is real and measured, and P3 closes.** The watchdog's decision half moved to `Core.WatchdogPolicy` (the same split that made K4 testable): the 10–60 s clamp and the expiry rule are pure functions, and the ADR 0009 invariant tests now run against them — 6 new tests including "the watchdog timeout cannot be set outside 10 to 60 seconds", "the helper releases the fans when heartbeats stop" and a clock-skew case (a heartbeat from the future never triggers a release; expiry means proven silence, not clock confusion). The daemon timeout is derived from the shared cadence (5 s × 3 misses), not typed as a number. The app gained the heartbeat pump (`HelperClient.beginHeartbeats`), an `applyTargets` wrapper, and two maintenance commands: `--pump-heartbeats` (the drill) and `--helper-release` (idempotency). **Finding 1 (the drill design was wrong before it was right):** `kill -9` does not exercise the watchdog at all — the dying client's XPC connection invalidates within milliseconds and the invalidation handler releases immediately; the watchdog's real scenario is a client that is alive but silent, which `SIGSTOP` simulates. Both paths were measured on real hardware: **`kill -9` → release + exit in 0.03 s** (invalidation), **`SIGSTOP` freeze → release + exit in 14.06 s** (watchdog expiry, inside the 15 s window), on-demand daemon spawn 0.02 s. **Finding 2 (root logs are unreadable here):** user-level `log show`/`log stream` on this machine returns zero lines for ANY system process (`smd` included) and passwordless sudo does not exist, so the daemon's own log lines cannot be evidence. **The fix became a design improvement:** the launchd plist had promised "starts on demand, stops when idle" since P3.02, but the helper never exited — that gap is now closed. The helper exits after every release with no client left (last connection gone, watchdog expiry, SIGTERM), always releasing first; a resident root process nobody talks to is attack surface with no purpose, and the exit makes every release path observable from user space as a process lifecycle — which is exactly how the drills measured it. **P3.08:** power notifications (sleep/shutdown) moved from loose globals in main.swift into a named `StateRestorer`, with the instance carried through IOKit's refcon instead of a global (Swift 6 isolates top-level lets to the main actor, which a C callback cannot touch). SIGTERM/SIGINT handled via dispatch sources: unregister with a live client → daemon released and exited in **0.04 s**, before launchd's kill escalation. Release idempotency proven over the real privileged path: three consecutive `releaseToFirmware` calls, all ok. **Sleep leg NOT RUN:** `pmset sleepnow` on an unattended machine freezes this session with nobody to wake it; the code path is reviewed, registration failure is guarded and logged, and the empirical sleep/wake pass belongs to P4.10's smoke test (release blocker B5). **Known quirk carried to P4.01:** `applyTargets` arms control state and the watchdog while replying with the documented "fan writing is not implemented yet" stub — the drill leans on it knowingly; P4.01 makes the reply true. P3 phase acceptance is met: single admin authentication (P3.00), `kill -9` return-to-firmware measured within the window, gate-daemon green, unsigned client rejected (P3.03). | Core tests 54/54 (6 new invariant tests) · full suite 83/83 · `make lint` PASS · App build PASS · drill A `kill -9` 0.03 s · drill B `SIGSTOP` 14.06 s (envelope 10–16.5 s) · SIGTERM leg 0.04 s with daemon pid verified up beforehand · `--helper-release` 3/3 ok · `make check` 10/10 · helper re-registered, ping green, 1 fan | `Packages/Core/Sources/Core/Models/WatchdogPolicy.swift` + tests · `Daemon/Sources/{Watchdog,StateRestorer,FanControlService,main}.swift` · `App/Sources/Helper/HelperClient.swift` `BoreasApp.swift` · `docs/architecture/privilege-model.md` | Sleep/wake empirical pass deferred to P4.10 (B5); baseline restored: helper `enabled` | Next: P4.01 |

| 2026-08-05 | setup | P4.01–P4.02 | CLAIMED | Fan write path claimed as a pair: takeover (LiveFanActuator) and handback (releaseToFirmware) are one closed loop — a write path without a proven release path must not be left overnight. Read-only SMC key recon comes first; nothing is written before the mode/target keys and their types are confirmed on this machine. | — | — | — | — |

| 2026-08-05 | setup | P4.01–P4.03 | DONE | **The fan write path is real: taken over, driven, handed back, on this machine.** Read-only recon came first (`--fan-keys`): the M4 exposes `F0Md` (ui8) and `F0Tg` (flt, little endian — 1000.0 reads `00 00 7a 44`), and an unprivileged write attempt is refused by the kernel with `kIOReturnNotPrivileged` — invariant M3 is now a measured boundary, not a design intention. The write primitive lives beside the read primitive in `SMCConnection` (the 80-byte layout exists once); `FanActuator` protocol + `LiveFanActuator` (sync core so exit paths can finish the hand-back before `exit()`) + `MockFanActuator` satisfy M2; the actuator's bookkeeping is unit tested through an injected `SMCPort` seam (save-once, restore-verbatim target-then-mode, backoff schedule, idempotency, type refusal). The daemon's stub reply is gone: `applyTargets` drives hardware and replies truthfully. **Finding 1 — this SMC generation applies writes asynchronously (~100 ms):** the kernel accepts the write, an immediate readback still sees the old value, and R3 "firmware fighting back" turned out to be "firmware applying lazily". Worse, an impatient retry that rewrites first restarts the apply pipeline and defeats itself forever. Every verification now waits (three reads over 300 ms) before judging. **Finding 2 — the watchdog expiry path deadlocked on its own queue:** `tick()` → `performRelease()` → `watchdog.stop()` → `queue.sync` on the queue `tick()` already holds. P3's freeze drill "passed" because with no hardware writes a crash-exit at expiry was indistinguishable from a clean release-exit — the P3.07 run log's 14.06 s measurement proved the timer, not the release. The real write path unmasked it: the fan stayed forced at 1400 rpm with the helper dead. Fixed with a queue-specific-key reentrant guard. **Finding 3 — release must trust the hardware, not its memory:** the saved original state dies with the helper process, and the next helper reported "nothing to release" while the fan stayed forced (reproduced live, twice). Release now also scans every fan the SMC reports and returns any forced mode to automatic — automatic is always the safe direction. The amnesia guard was validated against a genuinely orphaned fan. **Measured on real hardware (final build):** K4 refuses 9900 rpm with the reason string over the real path (P4.03's demanded proof; the daemon-side log line exists but root logs are unreadable from user space — the XPC reply is the observable); take-over 999→1499+ rpm, closed loop converged in 0.5 s; release: mode back to 0, firmware back in charge in 0.5 s; second release free. **Failure paths with the fan actually spinning:** `kill -9` the driving client → hardware back with firmware in 1.0 s (invalidation); SIGSTOP freeze → watchdog handed the hardware back in 15.8 s (15 s window + restore patience); helper exits after both, exit code carries the release outcome (0 ok / 3 failed) since `launchctl` shows the last exit status unprivileged. **Operational note:** full SMC namespace enumeration stalled once mid-scan (a hung key read); the drills touch only known fan keys — worth remembering when P7.03 builds diagnostics. | recon + M3 refusal measured · `--takeover-drill` PASS (K4 refusal, converge 0.5 s, release 0.5 s, idempotent) · handback harness PASS (kill 1.0 s, freeze 15.8 s, fan state witnessed unprivileged via `--fan-state`) · amnesia guard live-validated on a stuck fan · `make test` 91/91 (37 HardwareKit incl. 8 new actuator tests) · `make lint` PASS · `make check` 10/10 · App build PASS | `Packages/HardwareKit/Sources/HardwareKit/{SMC/SMCConnection,SMC/SMCPort,Protocols/FanActuator,Live/LiveFanActuator,Mock/MockFanActuator}.swift` + tests · `Core/Models/FanTarget.swift` · `Daemon/Sources/{FanControlService,Watchdog,main}.swift` · `App/Sources/Helper/HardwareDrills.swift` `BoreasApp.swift` `HelperClient.swift` · `docs/architecture/hardware-access.md` | Fans idle at ~1000 rpm under firmware control; helper `enabled`, daemon idle. Multi-fan behaviour unverifiable on this one-fan machine (R8, M07) | Next: P4.04 |

| 2026-08-05 | setup | P4.04–P4.07 | CLAIMED | Engine-side safety layers claimed as one chunk: K1 fan floor, K2 thermal state, K3 panic threshold, and the invariant tests that guard them (G1/G2). Pure Core logic. | — | — | — | — |

| 2026-08-05 | setup | P4.04–P4.07 | DONE | **The engine-side safety layers exist as one pure function under undeletable tests.** `Core.SafetyChain.govern(requested:thermal:hottestCelsius:threshold:lock:now:)` applies K2 and K3 and returns the duty, the layer that determined it (for the P6.05 display and P7.02 logs — the user is always told why the fans are loud), and the next panic-lock state; time is injected, so the 30 s hold is tested without waiting. **G1 is structural:** every layer is a `max` against a floor — no code path can lower the request — and the grid test sweeps duty × thermal state × temperature × lock combinations asserting output ≥ input everywhere. **K1 is carried by the types:** `Duty` cannot hold a value below zero and `Duty.rpm(for:)` maps zero to the hardware minimum; the invariant test feeds adversarial raw values (−∞, NaN, 2.0) and the rpm never leaves `[min, max]`. **K2:** `ThermalPressure` mirrors the official `ProcessInfo.ThermalState`; `serious` floors at 55% without touching a higher request, `critical` forces 100% and is reported as the active layer even when the curve already sat there; an `@unknown` future thermal state reads as `critical` — the safe reading of "unknown" is the worst case. **K3:** strictly-above-threshold triggers, the hold re-arms on every evaluation that stays hot (expiry is 30 s after the *last* excursion, not the first), recovery inside the hold does not release, and a missing sensor never panics by itself — panic acts on measured heat; sensor loss is monitoring's problem and K2 still covers the machine. **Finding — the frozen blueprint contradicts itself on the panic range:** §7.6 says the threshold may never be raised above the 95 °C default (G2) while the schema section allows `[70, 105]`. The safety invariant wins: ADR 0022 records the deviation, `PanicThreshold` clamps to `[70, 95]` at the type level (a raised threshold is unrepresentable), configuration.md now documents the narrowed range for P5.10, and NaN resolves DOWN to the floor — for a trigger threshold, panicking sooner is the safe direction, the mirror image of an ambiguous `Duty` resolving up. There is deliberately no flag to switch K2 or K3 off; the only tunable moves down. | `swift test` Core 65/65 (11 new safety chain tests incl. the two named undeletable invariants) · full suite 102/102 · `make lint` PASS · `make check` 10/10 (docs-check verified the ADR 0022 three-way sync) | `Core/Models/SafetyChain.swift` + `SafetyChainTests.swift` · `docs/architecture/adr/0022-panic-threshold-ceiling.md` · `ARCHITECTURE.md` · `docs/architecture/adr/README.md` · `docs/architecture/configuration.md` | K2/K3 behaviour under a real `serious`/`critical` thermal state is unverifiable without heat-soaking the machine; the official API is trusted and P4.10's smoke test exercises what load testing can reach | Next: P4.08 |

| 2026-08-05 | setup | P4.08–P4.10 | CLAIMED | The rest of P4 claimed as the closing chunk: manual control slider, the MONITORING/CONTROLLING/PANIC/RELEASING state machine, and the hardware smoke test script. | — | — | — | — |

| 2026-08-05 | setup | P4.08–P4.10 | DONE | **P4 closes: the product now drives fans on purpose, not only in drills.** `Core.ControlStateMachine` is a total transition table — every (state, event) pair answers the next state or `nil`, and `nil` is a refusal, not an error to bend around; release is legal from every active state including panic, releasing twice is state-level idempotent, and the seven illegal jumps are pinned by tests. The app-side `ControlModel` owns the cycle the P5 engine will inherit: govern through the safety chain → transition → apply → heartbeat, every taken transition logged (P4.09) and every refusal logged as an error. The panel gained the P4.08 scaffold: one slider for all fans, enabled only when the helper is installed, with a caption that always says which safety layer is overriding the slider — the chain never acts invisibly. **Finding — the describeFans handshake is a protocol precondition, not a convenience:** the daemon builds its K4 limits in `describeFans`, and `ControlModel` skipped it — the first apply was refused with "call describeFans before applying targets". The drill caught it; the handshake is now explicit in `run()` with the reason in a comment. **Measured end to end (`--control-drill`, the real ControlModel headless with the run loop pumped by hand):** engage at 10% → mode 1, 1389–1390 rpm against an expected 1390; slider to 30% → 2170–2173 against 2170; disengage → monitoring, mode 0, back at 1000. The state machine walked monitoring→controlling→releasing→monitoring with transitions in the log. **P4.10:** `scripts/smoke-test-hardware.sh` (+ `make smoke`, setup.md row) reproduces the whole hardware proof in one command: takeover drill, control drill, kill -9 leg (handed back in 1.0 s), freeze leg (watchdog handed back in 15.9 s) — full run PASS on this machine. The sleep/wake leg runs only attended (`--with-sleep`): `pmset sleepnow` on an unattended machine parks the session with nobody to wake it; the script says so out loud and release blocker B5 requires that leg before v1.0. **Phase acceptance:** safe takeover/handback proven (P4.01–03), K1–K5 invariant tests pass (P4.04–07 + P3.09), `T_panic`/`critical` force 100% regardless of settings (tests), smoke test passes on real hardware for every unattended leg — sleep/wake recorded as NOT RUN with the reason, gated by B5 at release. | `--control-drill` PASS (rpm-exact tracking) · `make smoke` full run PASS (kill 1.0 s, freeze 15.9 s) · `make test` 106/106 (4 new state machine tests) · `make lint` PASS · `make check` 10/10 · App build PASS | `Core/Models/ControlStateMachine.swift` + tests · `App/Sources/Model/ControlModel.swift` · `MenuBarPanel.swift` `BoreasApp.swift` `HardwareDrills.swift` · `scripts/smoke-test-hardware.sh` `Makefile` `docs/development/setup.md` | Sleep/wake leg NOT RUN (attended only — B5 before release); rate limiting arrives with P5.05, so slider jumps step instantly for now | Next: P5.01 |

| 2026-08-05 | setup | P5.01–P5.06 + P5.09 | CLAIMED | The engine's signal path claimed as one chunk: the curve type with type-level monotonicity, its property tests, EWMA smoothing, dual-curve hysteresis with the direction lock, the asymmetric rate limiter, the sensor aggregator, and the discrete-model comparison test that keeps ADR 0010 alive in code. Pure Core throughout. | — | — | — | — |

| 2026-08-05 | setup | P5.01–P5.06, P5.09 | DONE | **The engine's signal path exists, pure and proven.** `Core/Engine/` gains five components. **Curve (P5.01):** the monotonicity constraints live in the only initialiser — strictly increasing temperatures, non-decreasing duties, 2–16 finite points — so an invalid curve is unrepresentable rather than checked at call sites; interpolation is linear, ends clamp, and a NaN temperature reads as the hot end because the safe reading of an unreadable temperature is the hot one. **Property tests (P5.02):** the two undeletable ARCHITECTURE §7 properties pass over dense sweeps — a monotone curve produces monotone output (−10…120 °C at 0.25° steps) and every output rpm stays inside the fan's limits. **EWMA (P5.03):** boundaries pinned exactly as stated (α=1 passes samples through, α=0 freezes), NaN samples cannot poison the stream in either direction, ambiguous α resolves to unsmoothed truth. **Hysteresis (P5.04):** the direction lock is implemented as a plateau — the output holds at the branch extreme until the temperature moves a full band against it, and the handoff lands on the shifted curve exactly where the base curve left off, so switching branches never steps the output. The no-oscillation proof wobbles 2 °C around a steep knee for seven samples and the output does not move once; continuity at both handoffs is asserted within 0.002 duty. **Rate limiter (P5.05):** rise and fall independent (600/150 defaults), steps scale with elapsed time, never overshoot, first evaluation passes through; deliberately shapes only the engine's output — the safety chain runs after it unlimited, acoustics never delay a panic. **Aggregator (P5.06):** max is the safety default, p95 is nearest-rank (a 105 °C outlier over twenty readings does not decide, the hot cluster at 78 does), empty and all-poisoned inputs answer nil — no data is not a temperature. **P5.09:** the comparison test builds the rejected three-band step model inside the test and measures it: crossing a band edge by 0.1 °C jumps the step model by ≥35 duty-points while the continuous curve moves under 1 — ADR 0010 stays a measurement, not a memory. One test bug caught in review of its own failure: the expected mean was miscomputed (70.55 vs the true 70.8); the arithmetic is now written next to the assertion. | `swift test` Core 87/87 (18 new engine tests) · full suite 124/124 · `make lint` PASS · `make check` 10/10 (coverage gate re-measured with the engine in) | `Packages/Core/Sources/Core/Engine/{Curve,Hysteresis,EWMA,RateLimit,SensorAggregate}.swift` · `CoreTests/{CurveTests,SignalPathTests}.swift` | Engine components are not yet wired into a running loop — P5.07/P5.08 (profiles, arbitration) and the golden files (P5.12) close that | Next: P5.07 |

| 2026-08-05 | setup | P5.07–P5.08 | DONE | **The engine's decision layer: profiles, triggers, arbitration — with the reason always attached.** `ProfileTrigger` covers the six automatic conditions (power source, running/foreground application, daily time window, battery level, external display, thermal-state-at-least) evaluated against an injected `Environment` value, so every trigger is a pure function the tests feed directly. Manual selection is deliberately **not** a trigger — it is an arbitration input that beats every trigger, and modelling it as a condition would let it lose. The midnight-wrapping window (the blueprint's own 23:00–08:00 example) is pinned by tests: evening OR morning, end exclusive, empty window never holds. A battery trigger never holds on a desktop — no battery is not "at 0%". `Profile` carries per-fan binding overrides (own curve + own sensor group per fan), a priority, and `enginePaused` for the `System` profile — modelled as data, not a special case in the loop. **Built-ins:** Quiet/Balanced/Performance/System; Balanced is the blueprint's worked example, Quiet engages later and shallower, Performance earlier and steeper — the concrete points are this project's product decision (the blueprint is qualitative) with the rationale in code, and two promises are test-pinned: every built-in reaches full duty by 88 °C (no profile is a way of never cooling hard) and Quiet ≤ Balanced ≤ Performance across the range where they differ. **Arbitration (P5.08):** live manual wins (time-limited supported); an expired or dangling manual selection falls through rather than being honoured blindly; highest priority among holding triggers, ties to the earlier profile in the list; nothing holding → the default. The outcome carries `ActivationReason` (manual/trigger/fallback) end to end — the P6.05 control tab's "why is this active" transparency starts here. Rule 5 (no jumps) stays where it belongs: every emitted target passes the rate limiter, whoever won. **Codable groundwork for P5.10:** `Curve`, `Duty` and `EWMA` now decode through their validating/clamping initialisers — a downhill curve in a configuration file is a thrown `DecodingError`, not a decoded-but-invalid value (G6 groundwork, test-pinned); `Duty` rides the wire as a bare number. | `swift test` Core 96/96 (9 new suites' worth: trigger semantics, midnight wrap, manual/priority/order/fallback, per-fan overrides, built-in promises, decode-validation) · full suite 133/133 · `make lint` PASS · `make check` 10/10 | `Core/Engine/{ProfileTrigger,Profile,Arbitration}.swift` · Codable extensions in `Curve.swift`, `EWMA.swift`, `Models/Duty.swift` · `CoreTests/ProfileTests.swift` | The engine loop that composes signal path + arbitration into running control arrives with the config phase (P5.10–P5.12) and replaces the P4.08 manual source | Next: P5.10 |

| 2026-08-05 | setup | P5.10–P5.12 | CLAIMED | The configuration chunk that closes P5: the published JSON schema with range constraints, the G6 no-crash fallback loader, versioned migration with a data-loss proof, and golden thermal scenarios over the composed engine step. The engine model first aligns to the blueprint's wire contract (trigger lists, profile-level smoothing/slew). | — | — | — | — |

| 2026-08-05 | setup | P5.10–P5.12 | DONE | **P5 closes: the engine is composed, configured, and frozen under golden scenarios.** **P5.10:** `schema/config.schema.json` is published (draft-07) and describes the implemented wire format truthfully — trigger objects carry a type discriminator, per-fan overrides are string-keyed objects (Swift would otherwise encode Int-keyed dictionaries as flat arrays), curve points live in `[0,120]` °C (range validation added to `Curve` itself; a curve too close to 0 °C keeps its base branch rather than shifting out of range). The wire model decodes through the clamping/validating types end to end: a downhill curve is a refused `DecodingError` whose problem names the field path, an out-of-range panic threshold decodes to 95, a 300 s watchdog to 60, a 500 s sampling interval to 60 — all test-pinned. The G6 loader is a pure function: garbage bytes, a downhill curve, a newer schema version, or no file at all always answer with a configuration (the last valid one) plus the problem to show; nothing throws past it. Missing sections mean their defaults — a minimal file is valid — and a foreign version is reported as exactly that instead of being half-read. **P5.11:** `ConfigurationMigrator` upgrades v0 (the pre-release draft: no version field, pre-ADR-0022 panic ceiling) to v1; the lossless proof feeds a v0 document with a custom profile and asserts every user value survives — name, priority, trigger, smoothing, hysteresis, slew, curve points, aggregate — with the one deliberate change (panic 105 → 95) called out; the loader hands the original bytes back for the pre-migration backup file, and a current document passes through untouched. **P5.12:** `Engine.step` is the composed pipeline (aggregate → smooth → hysteresis/curve → safety chain → slew) — the golden scenarios run against exactly the function the app loop will call, so there is no second pipeline to drift. Three frozen scenarios with hand-reviewed waypoints: the ramp rises strictly monotonically and ±1 °C input wobble never reverses the output once (smoothing+hysteresis turn chatter into a monotone approach; the literal constant plateau is the unit-level proof in HysteresisTests); the 97 °C spike jumps straight to 4900 with **no slew** (safety is never rate limited) and the hold spans exactly 15 samples = 30 s though the input recovers immediately, then releases at exactly −300 rpm/step; Quiet's fall limit binds at exactly −200/step. Re-recording is a deliberate act (`GOLDEN_RECORD=1`) whose fixture diff becomes part of review. The `System` profile resets per-fan memory and emits no targets — data, not a special case. | `swift test` Core 107/107 (11 new: G6 fallback ×6, migration ×2, golden ×3) · full suite 144/144 · `make lint` PASS · `make check` 10/10 · App build PASS | `Core/Engine/{Configuration,Engine}.swift` · Codable range work in `Curve.swift` · `schema/config.schema.json` · `CoreTests/{ConfigurationTests,GoldenTests}.swift` + `Fixtures/*.golden.json` · `Packages/Core/Package.swift` (test resources) · `docs/architecture/configuration.md` | The app loop still drives the P4.08 manual slider; swapping in `Engine.step` with profile selection is P6's control tab work. File IO for config (~/Library/Application Support) lands with the settings UI | Next: P6.01 |

| 2026-08-05 | setup | gate repair | DONE | **Session opened on a red gate and the red exposed a scan-scope hole in every gate.** `make check` failed in gate-names: `json-schema.org`, introduced by `schema/config.schema.json` in the previous session's commit. The previous session's 10/10 PASS was honest at the time — the root cause is that `tracked()` used plain `git ls-files`, so **a brand-new file is invisible to every gate until after it is committed**; a violation enters permanent history first and turns the gate red one session too late, exactly backwards for the legal gates (and it would equally hide a new Core file importing IOKit from gate-layers). Fixed in `_lib.sh`: the scan set is now `git ls-files --cached --others --exclude-standard` (tracked + untracked-but-not-ignored; build artifacts stay excluded), with the incident recorded in the comment. **Proven with a deliberate violation in the honest order:** off-allowlist probe file untracked → old scope PASSes it (bug visible) → fixed scope turns it red naming the file → probe removed → green. The domain itself passed human review and joined the allowlist: the draft-07 `$schema` value is a spec-mandated identifier (never fetched), a standards-body domain parallel to the already-allowed w3.org/spdx.org — same reasoning that admitted apache.org (M02). Stale check-names COUNT=0 diagnosis reworded (untracked files can no longer be the cause). **TODO.md self-consistency repaired in passing:** the P3/P4/P5 phase-block `Status:` fields still said IN_PROGRESS/NOT_STARTED while the summary table said DONE (sessions updated the table, never the blocks — `next-task.py` reads neither, so selection was unaffected), and the overall-status head still said "P4 in progress"; all now state the truth. First occurrence of this inconsistency class in a session — per protocol, a second occurrence stops hand-fixing and gets an audit script. | `make gate-names` red→green on allowlist fix · probe sequence: old scope PASS (miss) → new scope FAIL (caught, file named) → cleanup PASS · full `make check` exit=0, 10/10 PASS | `scripts/gates/_lib.sh` `scripts/gates/check-names.sh` `TODO.md` | None — scan scope is strictly wider, so no formerly-caught case is lost | Next: P6.01 |

### Run log entry template

```
| YYYY-MM-DD | <session> | P<n>.<nn> | DONE/BLOCKED | <what was done and WHY it was done that way; unexpected findings> | <commands + PASS/FAIL/NOT RUN+reason> | <files> | <risk> | Next: P<n>.<nn> |
```

**Rules:**
- Never hesitate to write `NOT RUN` — "I wrote it, it probably works" makes the system a liar
- Record the unexpected finding **with its evidence**, so the next session does not fall into the same trap
- `Handoff` must be a single, definite task
