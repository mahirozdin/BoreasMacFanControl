# CLAUDE.md

> Loaded automatically. Kept short — the binding contract is `AGENTS.md`.

## Do this first

**Open `BOOT.md` and follow the protocol.** Do not write code before running the
health snapshot.

## The project in one paragraph

**Boreas** — free, open source temperature monitoring and fan control for Apple
Silicon Macs. Swift 6.2 + SwiftUI, macOS 14.0+, arm64 only, Apache-2.0. Reading
temperatures needs no privileges; writing fan speeds goes through a privileged
helper installed with a single administrator prompt. **No SIP changes, no kernel
extension, no sensitive permissions.**

## The ten rules broken most often

1. **The repository is written in English** — documents, comments, commits,
   issues. *(AGENTS.md §2.1)*
2. **No third party commercial product name enters the repository.** Use generic
   wording. *(§2.1 H1)*
3. **`Packages/Core` never imports IOKit, SwiftUI or AppKit.** Not even
   temporarily. *(M1)*
4. **No checkbox without evidence.** If you could not run the verification,
   write `NOT RUN` and the reason in the run log. *(§5)*
5. **A gate you add must be proven by a deliberate violation.** A gate never
   shown to fail is not a gate. *(§8)*
6. **No user facing string is hard coded.** `String(localized:)` with a
   `comment`. Five languages depend on it. *(Y1, Y2)*
7. **The blueprint is frozen.** `BLUEPRINT.md` and `docs/blueprint/` are never
   edited; deviations are recorded as ADRs. *(§7)*
8. **Never swallow a hardware error with `try?`.** Throw, and let the caller
   degrade gracefully. *(§6.3)*
9. **Safety layers only ever raise fan speed.** None of them may lower it. *(G1)*
10. **Closing a session has three parts** — checkbox, status summary and run log,
    in the same change. *(§9)*

## Documents are living documents

When code changes, consult the *change type → files to update* table in
`AGENTS.md` §7. A task is not closed until the documentation is updated.

## Evidence rule

Do not claim something works — **show it**. Run the command, read the output,
record it in the run log.

## External authority

Trademark and legal matters, Apple account operations, GitHub secrets, hardware
you do not own → `TODO.md` manual tasks table.
Installing local tools, writing scripts, writing tests → **your job**, not a
manual task.

## Common commands

```bash
make next           # the next actionable task
make check          # every gate
make gate-names     # H1 — run on every task
make gate-language  # the repository is English
```
