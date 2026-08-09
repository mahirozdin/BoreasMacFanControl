# Development Environment

> Last updated: 2026-08-10 — P6.10
> Source: blueprint §16.1, §17.3 · Decision: [ADR 0001](../architecture/adr/0001-native-swift.md)

## Requirements

| Tool | Version | Note |
|---|---|---|
| macOS | 14.0+ | Development machine |
| Xcode | 26.0+ | For Swift 6.2 |
| XcodeGen | current | `.xcodeproj` generation |
| SwiftLint | current | Rule checking |
| swift-format | current | Formatting |

```bash
brew bundle
```

## Setup

```bash
make bootstrap
make generate
```

`make bootstrap` is idempotent, **deletes no volume**, and verifies: tool versions (compared against expected) · that every gate runs. Its output reads as ✓/!/✗.

> **Important:** It checks the tools not for *being there* but for *actually running*. A broken global installation can fail silently.

## Commands

| Command | What it does |
|---|---|
| `make help` | Lists all targets |
| `make check` | **Runs every gate** |
| `make gate-names` | Third party product names / comparative marketing |
| `make blueprint-check` | Frozen source integrity |
| `make docs-check` | Broken links, matrix, ADR sync |
| `make gate-layers` | `Core` purity, Mock coverage |
| `make gate-deps` | Zero dependencies, licence compatibility |
| `make gate-privacy` | Telemetry and network traces |
| `make gate-i18n` | Hard coded user facing text |
| `make gate-daemon` | Privileged surface boundaries |
| `make gate-language` | The repository is written in English |
| `make gate-coverage` | `Core` line coverage ≥ 85% |
| `make smoke` | Hardware smoke test on a real Mac (P4.10; sleep leg attended-only) |
| `make generate` | Generates the Xcode project from `project.yml` |
| `make build` / `make test` / `make lint` | Build / test / lint the packages |
| `make clean` | Removes build outputs |

## The application's own commands

The built application answers a set of arguments that are **instruments,
not features**: they exist so that claims in the run log can be reproduced
rather than believed. None of them shows the interface, and none needs a
permission this project has promised not to ask for.

```bash
BOREAS=~/Library/Developer/Xcode/DerivedData/Boreas-*/Build/Products/Debug/Boreas.app/Contents/MacOS/Boreas
```

| Argument | What it proves or does |
|---|---|
| `--helper-status` | The privileged helper's registration state |
| `--register-helper` / `--unregister-helper` | Installs or removes it. Repairs a stale registration after repeated rebuilds |
| `--helper-ping` | The XPC handshake, signatures verified in both directions |
| `--fan-state` | The fan's mode byte and speed, unprivileged. What the kill and freeze harnesses poll |
| `--fan-keys` | The SMC fan namespace, plus the proof that an unprivileged write is refused (M3) |
| **Drills — each exits non-zero on failure** | |
| `--takeover-drill` | Take over, converge, hand back, release again (P4) |
| `--pump-heartbeats` / `--helper-release` | The watchdog and release idempotency harnesses (P3) |
| `--control-drill` | The manual duty path end to end (P4.08) |
| `--profile-drill` | Selecting a profile drives the fan along its curve (P6.02) |
| `--override-drill` | A timed override expires back to the **engine**, not the firmware (P6.05) |
| `--curve-drill` | An edited curve reaches the fans within a cycle (P6.06) |
| `--config-drill` | Settings survive a restart; a broken file falls back; a hostile one is clamped (P6.08) |
| `--diagnostics-drill` | A healthy fan is not accused — the false positive risk (P6.09) |
| `--shortcut-drill` | Global shortcuts register with **no accessibility permission** (P6.10) |
| **Render evidence — writes PNGs into a directory** | |
| `--render-setup <dir>` | The helper setup window in every phase |
| `--render-design <dir>` | The design system swatch sheet, both appearances |
| `--render-panel <dir>` | The menu bar panel in five frozen states |
| `--render-status <dir>` | The status item's layouts and marks |
| `--render-window <dir>` | The main window's three tabs, both appearances |
| `--render-settings <dir>` | The settings tabs |
| `--crowd-menubar <seconds>` | Floods the menu bar, so the space warning can be watched firing |

The renders host the view in an offscreen window and ask AppKit to draw
itself, which needs no screen recording permission (I2) and — unlike
`ImageRenderer`, which this replaced — draws system controls as they
really appear.

## Coding standards

- `swift-format` + `SwiftLint` — both **blocking** in CI
- Documentation comments required on public APIs
- Force unwrapping (`!`) is forbidden inside `Core`
- No magic numbers — named constants or configuration fields
- **Everything in the repository is English** — code, comments, commits and every document ([ADR 0021](../architecture/adr/0021-english-only-repository.md))
- Turkish characters are never used in code identifiers

## Commit discipline

Conventional Commits: `feat:` `fix:` `docs:` `refactor:` `test:` `chore:`

One commit closes one task. Mixed commits are forbidden.

**Forbidden git operations:** `push --force` to a shared branch · `rebase` of published commits · `reset --hard` with uncommitted work · rewriting history.

## Bash compatibility — beware

The macOS `/bin/bash` version is **3.2.57**. Bash 4+ features **cannot be used** in gate scripts: `mapfile`/`readarray`, `${x,,}`, `${x^^}`, associative arrays.

Shared helpers live in `scripts/gates/_lib.sh`, and with `require_tools` they make a **silent pass impossible** when a command is missing.
