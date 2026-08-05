# Development Environment

> Last updated: 2026-07-31 — P0.22
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
