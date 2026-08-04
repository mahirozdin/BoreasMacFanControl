# AGENTS.md — Binding Working Contract

> Last updated: 2026-08-04 — ADR 0021
> Source: blueprint §0, §2, §14, §17.2, §17.3

This file is **binding on every agent and every developer** working in this
repository. Where it conflicts with anything else, the precedence order in §3
applies.

---

## 1. Required reading order

Every session, before writing code, in this order:

| # | File | Why |
|---|---|---|
| 1 | `BOOT.md` | Session start protocol and health snapshot |
| 2 | `AGENTS.md` (this file) | Invariants and working discipline |
| 3 | `TODO.md` | Next task, acceptance criteria, verification command |
| 4 | `ARCHITECTURE.md` | MUST / MUST NOT rules for the layer you are touching |
| 5 | `LEGAL.md` | **Every session.** Breaking it stops the project |
| 6 | The relevant `docs/` file | Whatever the task in `TODO.md` points at |

The blueprint (`docs/blueprint/`) is **reference, not instruction**. The current
truth lives under `docs/`.

---

## 2. Invariants

Breaking these is not acceptable. Each is tied to an ADR and to a gate.

### 2.1 Legal invariants — highest priority

| # | Rule | ADR | Gate |
|---|---|---|---|
| **H1** | **No third party commercial product name** appears anywhere: code, comments, commit messages, issues, documentation | [0006](docs/architecture/adr/0006-independent-development-policy.md) | `make gate-names` |
| **H2** | No commercial software is reverse engineered, disassembled or decompiled | [0006](docs/architecture/adr/0006-independent-development-policy.md) | Review + pull request declaration |
| **H3** | No text, label, icon, layout, schema or data format is copied from another product | [0006](docs/architecture/adr/0006-independent-development-policy.md) | Review + pull request declaration |
| **H4** | No comparative marketing ("an alternative to X", "better than X") | [0006](docs/architecture/adr/0006-independent-development-policy.md) | `make gate-names` |
| **H5** | Only Apache-2.0 compatible licences (MIT / BSD / Apache-2.0 / ISC). GPL, LGPL and AGPL are **forbidden** | [0005](docs/architecture/adr/0005-apache-2-license.md) | `make gate-deps` |
| **H6** | **The repository is written in English** — documents, comments, commits, issues | [0021](docs/architecture/adr/0021-english-only-repository.md) | `make gate-language` |

> Why H1 is this strict: a commit that mentions a competitor, however
> innocently, becomes evidence for a claim of deliberate copying. Intent does
> not matter; the record is permanent and git history is not erased. Use
> generic wording instead: *"commercial equivalents"*, *"closed source
> alternatives"*, *"other tools in this category"*.

### 2.2 Identity invariants

| # | Rule | ADR |
|---|---|---|
| **K1** | The product is **Boreas**. Bundle `com.bubiapps.boreas`, helper `com.bubiapps.boreas.fanhelper`, CLI `boreas` | [0002](docs/architecture/adr/0002-product-name.md) |
| **K2** | The product name is never embedded in code; it appears only in `project.yml` variables and the localisation catalogue | [0002](docs/architecture/adr/0002-product-name.md) |
| **K3** | An Apple trademark is never used as a prefix in the product name | [0002](docs/architecture/adr/0002-product-name.md) |

### 2.3 Technology invariants

| # | Rule | ADR | Gate |
|---|---|---|---|
| **T1** | **Swift 6.2**, strict concurrency on. Objective-C only where a bridge is unavoidable | [0001](docs/architecture/adr/0001-native-swift.md) | Build |
| **T2** | Minimum target **macOS 14.0**. Never assume an older API | [0003](docs/architecture/adr/0003-minimum-macos-14.md) | Build |
| **T3** | **arm64 only**. No Intel code path | [0004](docs/architecture/adr/0004-apple-silicon-only.md) | Build |
| **T4** | **Zero runtime dependencies.** Apple frameworks only | [0013](docs/architecture/adr/0013-json-config-zero-deps.md) | `make gate-deps` |
| **T5** | The Xcode project is generated from `project.yml`; `.xcodeproj` is never committed | [0001](docs/architecture/adr/0001-native-swift.md) | `.gitignore` + `make gate-layers` |

### 2.4 Architecture invariants

| # | Rule | ADR | Gate |
|---|---|---|---|
| **M1** | `Packages/Core` **never imports IOKit, SwiftUI, AppKit or any hardware API.** Foundation only | [0012](docs/architecture/adr/0012-core-layer-purity.md) | `make gate-layers` |
| **M2** | All hardware access sits behind a protocol; every protocol has a `Live` and a `Mock` implementation | [0011](docs/architecture/adr/0011-hardware-abstraction.md) | `make gate-layers` |
| **M3** | Reading temperatures **requires no privileges**. The helper exists only to write fan speeds | [0007](docs/architecture/adr/0007-privilege-split.md) | Review |
| **M4** | The helper accepts no file path, command, script or arbitrary data. The XPC surface is exactly four methods | [0008](docs/architecture/adr/0008-smappservice-xpc.md) | `make gate-daemon` |
| **M5** | The helper **reads no configuration**. Nothing user supplied is parsed as root | [0007](docs/architecture/adr/0007-privilege-split.md) | `make gate-daemon` |
| **M6** | The helper has **no network access** | [0007](docs/architecture/adr/0007-privilege-split.md) | `make gate-daemon` |

### 2.5 Safety invariants

| # | Rule | ADR | Gate |
|---|---|---|---|
| **G1** | Safety chain layers **only raise**. No layer may lower a fan speed | [0010](docs/architecture/adr/0010-continuous-curve-model.md) | Invariant test |
| **G2** | K2 (thermal state) and K3 (panic threshold) **cannot be switched off**. The panic threshold may be lowered, never raised | [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Invariant test |
| **G3** | The watchdog timeout is **locked to 10–60 seconds** and cannot be disabled | [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Invariant test |
| **G4** | On quit, crash, sleep or shutdown the fans are handed back to firmware **unconditionally** | [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Invariant + smoke test |
| **G5** | The XPC connection verifies code signatures in **both directions** | [0008](docs/architecture/adr/0008-smappservice-xpc.md) | Invariant test |
| **G6** | No configuration error crashes the application; it falls back to the last valid state and the fans stay with the firmware | [0013](docs/architecture/adr/0013-json-config-zero-deps.md) | Unit test |

### 2.6 Privacy invariants

| # | Rule | ADR | Gate |
|---|---|---|---|
| **P1** | **Zero telemetry.** No analytics SDK, no crash reporting SDK, no advertising identifier | [0014](docs/architecture/adr/0014-zero-telemetry.md) | `make gate-privacy` |
| **P2** | By default the application makes **no network connection at all** | [0014](docs/architecture/adr/0014-zero-telemetry.md) | `make gate-privacy` |
| **P3** | Log lines contain no personal data: no user name, no file path, no network information | [0014](docs/architecture/adr/0014-zero-telemetry.md) | Review + unit test |

### 2.7 Permission invariants

| # | Rule |
|---|---|
| **I1** | Never ask for SIP to be disabled, a kernel extension, a DriverKit driver or a Recovery Mode step |
| **I2** | Never ask for Full Disk Access, Accessibility, Screen Recording, camera, microphone or location |
| **I3** | Administrator authentication is requested **once**, and only to install the helper |
| **I4** | Without the helper the application is a **fully working monitor** and shows no error |

### 2.8 Localisation invariants

| # | Rule | Gate |
|---|---|---|
| **Y1** | No user facing string is hard coded; `String(localized:)` is required | `make gate-i18n` |
| **Y2** | Every string carries a `comment` — a translator cannot work without context | `make gate-i18n` |
| **Y3** | No text container has a fixed pixel width or height | Pseudo-locale test |
| **Y4** | A missing translation falls back to the source language, never to blank | Unit test |

---

## 3. Source precedence

When sources conflict, from the top:

1. **The user's explicit instruction in this session**
2. **Legal invariants (§2.1)** — not overridden even by a user request; if there
   is a conflict, stop and ask
3. **Safety invariants (§2.5)**
4. **ADRs** (`docs/architecture/adr/`)
5. **`TODO.md`** — the current task and its acceptance criteria
6. **This file**
7. The `docs/` tree
8. `docs/blueprint/` — historical reference only

---

## 4. Choosing the next task

**The choice is not left to judgement — it is asked of a machine:**

```bash
make next
```

This parses `TODO.md` and returns the next actionable task, **skipping anything
blocked on a manual task**. It ignores phase boundaries: if the rest of a phase
is blocked it moves to the next phase's unblocked work.

| Exit code | Meaning | What to do |
|---|---|---|
| `0` | There is work | Do it |
| `1` | Nothing actionable | The output names the manual tasks being waited on. **Stop and tell the project owner** |
| `2` | Parse error | `TODO.md` formatting is broken; fix that first |

### The contract

`make next` only works while `TODO.md` keeps this shape:

| Element | Format |
|---|---|
| Atomic task | `- [ ] **P<n>.<nn> — Title.** description` |
| Manual blocker | `⛔ M03` at the end of the line (several: `⛔ M03 M04`) |
| Phase dependency | `- **Depends on:** P1, P2` inside the phase block |
| Manual task status | Last column of the manual tasks table; anything other than `OPEN` counts as resolved |

**Follow this shape when adding work.** If a task depends on something manual,
mark it with `⛔` — without that marker an agent will start it and stall.

### Afterwards

1. Do the task, honouring the constraints in its description.
2. **Run** the verification commands and read the output.
3. Pass the Definition of Done in §8.
4. Close the session (§9): checkbox, status summary and run log, **in the same
   change**.

**More than one task per session is fine**, but each gets its own run log entry,
and `make next` is run again after each.

---

## 5. Status and run log discipline

### Phase status

| Status | Meaning |
|---|---|
| `NOT_STARTED` | No sub-task has begun |
| `IN_PROGRESS` | At least one sub-task is done, not all |
| `BLOCKED` | Every remaining task waits on something external |
| `DONE` | All sub-tasks complete **and** acceptance criteria evidenced |

### Run log rule

| Value | When |
|---|---|
| `PASS` | The command ran and succeeded |
| `FAIL` | The command ran and failed — the task cannot be `DONE` |
| `NOT RUN` | **The command could not be run, plus the reason.** The task cannot be `DONE` |

> "I wrote it, it probably works" is forbidden. Unverified work is unfinished
> work.

---

## 6. Code rules

### 6.1 General

- Formatting by `swift-format`, rules by `SwiftLint` — both blocking in CI
- Documentation comments required on all public API
- **Code, comments, commit messages and documentation are English** (H6)
- No magic numbers — named constants or configuration fields

### 6.2 `Packages/Core`

- **`import IOKit`, `import SwiftUI`, `import AppKit` are forbidden** (M1)
- Force unwrapping (`!`) is forbidden — enforced by lint
- All types are `Sendable`
- Engine functions are **pure**: same input, same output, no side effects
- Every public function has a unit test

### 6.3 `Packages/HardwareKit`

- Every protocol has at least a `Live` and a `Mock` implementation (M2)
- `Live` implementations are **never** used directly; they are injected
- Hardware errors are **thrown, not swallowed**; the caller degrades gracefully
- An unknown sensor or key is skipped with a warning — **never a crash**

### 6.4 `Daemon`

- The XPC surface is the four methods in §2.4 M4 — **adding one requires an ADR**
- Every incoming command passes through the safety filter
- Nothing received is interpreted as a file path or a command
- No network API is imported (M6)

### 6.5 `App`

- Code that touches hardware **never** runs on `@MainActor`
- All user text goes through `String(localized:)` (Y1)
- Colour alone never carries meaning — always paired with a number or label
- No fixed size text container (Y3)

---

## 7. Documentation update protocol

When you change something, **which files to update is written down**:

| Change type | Files to update |
|---|---|
| New architecture or technology decision | New ADR + `ARCHITECTURE.md` table + `docs/architecture/adr/README.md` index |
| Deviation from the blueprint | **ADR required** + the relevant `docs/` file + `docs/reference/blueprint-map.md` |
| New invariant | `AGENTS.md` §2 + ADR + **a gate script** + `BOOT.md` snapshot |
| New gate | `Makefile` + `scripts/gates/` + `BOOT.md` + the ADR's Enforcement section |
| New phase or task | `TODO.md` phase block + status summary |
| New risk | `docs/reference/risks.md` |
| New manual task | `TODO.md` manual tasks table |
| Control engine behaviour | `docs/product/control-model.md` + invariant test |
| Configuration schema | `docs/architecture/configuration.md` + `schema/config.schema.json` + migration test |
| New command or script | `Makefile` + `docs/development/setup.md` + `README.md` command table |
| New user facing string | Localisation catalogue (five languages) + `comment` field |

**Rule:** the same fact is never written in two files. The second place links to
the first.

**Rule:** once code exists, documentation points at the source rather than
copying it.

---

## 8. Definition of Done

A task is `DONE` only when **all** of these hold:

- [ ] Everything the task description asks for is done
- [ ] The acceptance criterion is met **with evidence** — test output, command
      output, a screenshot
- [ ] `make check` passes (or `NOT RUN` plus the reason is in the run log)
- [ ] Tests cover the new behaviour; an invariant test if an invariant is involved
- [ ] Documentation updated per §7
- [ ] If a gate was added, **a deliberate violation was shown to trip it**
- [ ] `make gate-names` passes (H1 — every task)
- [ ] Checkbox, status summary and run log updated **in the same change**

---

## 9. Closing a session

Three things, in the same change:

1. `TODO.md` checkbox `[x]`
2. `TODO.md` status summary table (phase status and next task)
3. `TODO.md` run log entry plus `Next: P<n>.<nn>`

If any of the three is missing, the system lies to the next session.

---

## 10. External authority

### Not yours to do — record in the `TODO.md` manual tasks table

- Trademark searches and legal approval
- Apple Developer account operations, certificate generation, App Store Connect keys
- Creating the GitHub repository, defining secrets
- Homebrew cask submission
- Testing on hardware you do not have
- Translation quality approval that needs a native speaker

### Yours to do — **not** manual tasks

- Installing local tools (`brew install xcodegen swiftlint xcbeautify`)
- Repairing a broken local installation
- Running `xcodegen generate`
- Writing scripts, gates and tests
- Updating documentation

The distinguishing question: *does the project owner need to sign into a console
or make a decision?*

## 10.1 The project owner's working preferences

These are standing preferences, not one-off instructions.

| Preference | How it applies |
|---|---|
| **Ask about decisions one at a time** | When several decisions are open, do not batch them into one question. Ask in sequence, weighing each answer against the previous one |
| A recommendation is required | Every set of options comes with a recommendation and its reasoning |
| Push back when a constraint costs more than it returns | If a request breaks the cost/benefit balance, say so with reasons before implementing it |

---

## 11. Repository hygiene

- Prefer `rg` (ripgrep) for searching; `grep -r` is slow and noisy
- **Forbidden git operations:** `push --force` to a shared branch, `rebase` of
  published commits, `reset --hard` with uncommitted work, rewriting history
- Commit messages follow **Conventional Commits**: `feat:` `fix:` `docs:`
  `refactor:` `test:` `chore:`
- One commit closes one task; mixed commits are not acceptable
- `.xcodeproj` is never committed (T5)

---

## 12. Forbidden shortcuts

| Anti-pattern | Why it is forbidden |
|---|---|
| Ticking a checkbox without running the verification | The system lies to the next session |
| Adding a gate without proving it with a violation | A gate never shown to fail is not a gate |
| "Fixing" the blueprint | It is frozen; deviations are recorded as ADRs |
| Changing an invariant without an ADR | The reasoning behind the decision is lost |
| Importing IOKit into `Core` "just for now" | Testability collapses, and nothing temporary ever is |
| Swallowing a hardware error with `try?` | Silent failure, undiagnosable bug reports |
| Hard coding a user facing string | Five languages break |
| Writing a competitor's name "just as a note" | **H1 violation — absolutely forbidden** |
| Stopping work because something is blocked | Skip the blocked task, take the next independent one |
| Writing code without updating documentation | Drift starts |
| Writing anything in the repository in another language | **H6 violation** — see [ADR 0021](docs/architecture/adr/0021-english-only-repository.md) |
