# Development Environment

> Last updated: 2026-08-10 — P6.12
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
| `make gate-a11y` | SF Symbol names, chart labels, Reduce Motion |
| `make gate-daemon` | Privileged surface boundaries |
| `make gate-language` | The repository is written in English |
| `make gate-coverage` | `Core` line coverage ≥ 85% |
| `make smoke` | Hardware smoke test on a real Mac (P4.10; sleep leg attended-only) |
| `make layout` | Y3 — pseudo-locale overflow check; needs the app built (P6.13) |
| `make cli-test` | Every `boreas` command against real state; needs the CLI built (P7.04) |
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
| `--curve-drill` | An edited curve reaches the fans within a cycle (P6.06). **Its tolerance is temperature-dependent** — reliable only where the test curve saturates, and it misses by ~370 rpm on the curve's slope because the fan's own cooling moves the target underneath it. Measured in P7.01, tracked as P7.11 |
| `--config-drill` | Settings survive a restart; a broken file falls back; a hostile one is clamped (P6.08) |
| `--diagnostics-drill` | A healthy fan is not accused — the false positive risk (P6.09) |
| `--shortcut-drill` | Global shortcuts register with **no accessibility permission** (P6.10) |
| `--trigger-drill` | A trigger selects its profile, and a manual choice still overrides it (P6.14) |
| `--a11y-drill` | The drawn colours are exactly Core's, and their measured contrast clears the requirement each role carries — in four appearances (P6.12) |
| `--layout-drill` | No fixed-width text container clips its content in any shipped language, plus a 1.4× expansion budget (P6.13) |
| `--recording-drill` | Recordings land on disk, rotate, and the disk ceiling really deletes — proven against real files rather than fake sizes (P7.02) |
| `--notification-drill` | No permission is requested at launch; a panic survives every noise-control mechanism; a refused permission switches the feature back off; settings persist and a hostile file is clamped (P7.01) |
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

## The `boreas` command line tool (P7.04)

Built as its own target (`xcodebuild -scheme boreas`), and it takes no runtime
dependencies — the argument table is hand written (T4).

| Command | What it does |
|---|---|
| `status` | Temperatures, fans, power, and the helper's registration state |
| `sensors [--raw]` | Every sensor, grouped; `--raw` shows hardware names |
| `profile` | Lists profiles and marks the configured fallback |
| `profile <name>` | Activates one **now**, in the running app |
| `profile --auto` | Hands the decision back to the profile triggers |
| `install` | Installs the fan control helper, by asking the app to do it |
| `uninstall [--all]` | Removes the helper; `--all` also deletes saved settings |
| `export [file]` | Writes the configuration; to standard output when no file is given |
| `import <file>` | Replaces the configuration, **after validating it** |

Three decisions worth knowing, because each is a constraint rather than a
preference:

- **A profile chosen from the CLI is live, never written to disk.** P6.14 found
  that a *standing* manual selection vetoes every profile trigger forever, which
  is why the app deliberately starts with none. A CLI that persisted one would
  re-introduce that bug from outside, where nobody would look for it. So the
  command asks the **running app** through a distributed notification — local IPC,
  no network (P2), no permission — and says plainly when nothing is listening.
- **`install` delegates to the app.** `SMAppService` registers a helper on behalf
  of a *bundle*, so a command line tool doing it itself would either fail or
  register something the app does not know about.
- **`import` validates before it writes**, through `Core`'s own loader, and writes
  back the **loaded** model rather than the user's text — so what lands on disk is
  what the app will act on, clamped values and all. The previous configuration is
  kept as `config.backup.json`, the same name the app's own store uses.

Verified by `make cli-test` (19 checks), which runs the destructive commands
against a copy and restores the real configuration afterwards. It does **not** run
`install`/`uninstall`: those change the helper's registration and prompt for a
password.

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
