<!-- gate-names:policy-doc — quotes the forbidden-pattern policy. See LEGAL.md 5.1 -->

# Contributing to Boreas

Thanks for considering a contribution. This document covers everything you need
to get from a clean checkout to a merged pull request.

## Requirements

- Apple Silicon Mac (M1 or newer) — Intel is out of scope by design
- macOS 14.0 or newer
- Xcode 26 or newer

## Getting started

```bash
git clone https://github.com/mahirozdin/boreas-mac-fan-control.git
cd boreas-mac-fan-control
brew bundle          # xcodegen, swiftlint, xcbeautify
make bootstrap       # verifies the tools actually run, not just that they exist
make generate        # produces Boreas.xcodeproj from project.yml
```

`make bootstrap` ends by telling you which task is next.

## Commands

| Command | What it does |
|---|---|
| `make next` | Prints the next actionable task from `TODO.md` |
| `make check` | Runs all gates — must be green before you push |
| `make build` | Builds the Swift packages |
| `make test` | Runs the test suites |
| `make lint` | SwiftLint and swift format, check only |
| `make format` | Applies formatting in place |

## How work is organised

This repository uses a document driven workflow. Read these in order:

1. `BOOT.md` — session start protocol
2. `AGENTS.md` — the binding contract: invariants, definition of done
3. `TODO.md` — phases, atomic tasks, run log
4. `ARCHITECTURE.md` — MUST / MUST NOT rules for the layer you touch

Pick work with `make next`. It skips anything blocked on a manual task, so it
never hands you something you cannot finish.

## Rules that are enforced by machine

Every invariant has a gate. A rule without a gate is a wish, so please do not
add one without the other.

- `Packages/Core` may not import IOKit, SwiftUI or AppKit. It stays pure so the
  control engine is testable in CI without real hardware.
- The project takes **zero runtime dependencies**. Only Apple frameworks.
- No user facing string may be hard coded. Use `String(localized:comment:)`.
- The privileged daemon has a four method XPC surface. Widening it needs an ADR.
- No telemetry, no analytics, no crash reporting SDK.
- The generated `.xcodeproj` is never committed.

## Independent development

Boreas is an independent product. Other software solves a similar problem;
that is normal and lawful. Copyright protects expression, not ideas, and this
project stays strictly on the right side of that line.

When you open a pull request you confirm three things:

- [ ] The code and text are your own, or derived from compatibly licensed work
      that is credited in `NOTICE`.
- [ ] You did not reverse engineer, disassemble or decompile any commercial
      software while preparing this contribution.
- [ ] No third party commercial product name appears anywhere in the change.

The third point is checked by `make gate-names`. Please use generic wording
such as "commercial equivalents" or "other tools in this category" when you
need to refer to the wider landscape. Full policy: `LEGAL.md`.

## Commits

Conventional Commits: `feat:` `fix:` `docs:` `refactor:` `test:` `chore:`

One commit closes one task. Code, comments and commit messages are in English.

## Definition of done

Before you mark a task complete:

- [ ] Acceptance criteria met, with evidence — command output, a test, a screenshot
- [ ] `make check` passes
- [ ] Tests written for new behaviour; invariant tests if an invariant is involved
- [ ] Documentation updated per the table in `AGENTS.md` section 7
- [ ] If you added a gate, you proved it catches a deliberate violation

Claiming something works is not the same as showing it. If you could not run a
verification, write `NOT RUN` and the reason in the run log rather than assuming.

## Adding support for new hardware

Sensor names differ between chip generations. If Boreas shows sensors under
"uncategorized" on your Mac, that is useful data — please open an issue with the
**Unknown sensor** template. Nothing is hidden from you; unmapped sensors are
displayed precisely so they can be reported.

## Translations

The interface ships in English, Turkish, Russian, Spanish and Simplified
Chinese. Translations beyond English and Turkish are produced by the project and
have not been reviewed by native speakers — `TRANSLATORS.md` states this for
each language. Corrections are very welcome; the **Translation fix** issue
template exists to make a one string fix easy.

## Reporting a security issue

Please do not open a public issue. See `SECURITY.md`.
