# BOOT.md — Session Start Protocol

> Last updated: 2026-08-04 — ADR 0021
> Every session starts here. Do not skip steps.

---

## 1. Where am I

```bash
pwd
git status --short
git branch --show-current
git log --oneline -3
```

**Expected markers** — if these are missing you are in the wrong directory:

```bash
ls BLUEPRINT.md AGENTS.md TODO.md ARCHITECTURE.md LEGAL.md docs/blueprint/
```

---

## 2. Load the required context

Read, in this order:

1. `AGENTS.md` — invariants and working discipline
2. `TODO.md` — status summary and next task
3. `ARCHITECTURE.md` — MUST / MUST NOT rules for the layer you will touch
4. `LEGAL.md` — **every session**
5. Whatever `docs/` file the task points at

---

## 3. Health snapshot

Run all of it. **If anything is red, fix that before taking new work.**

### 3.1 Gates

```bash
make check
make next
```

Individually, when needed:

```bash
make gate-names       # H1 — third party product names, comparative marketing
make gate-language    # H6 — the repository is written in English
make blueprint-check  # the frozen source is untouched
make docs-check       # broken links, traceability targets, ADR index
make gate-layers      # Core purity, Live/Mock coverage
make gate-deps        # zero dependencies, licence compatibility
make gate-privacy     # telemetry and network traces
make gate-i18n        # hard coded user strings
make gate-a11y        # SF Symbol names, chart labels, Reduce Motion
make gate-daemon      # privileged surface limits
make gate-coverage    # Core line coverage at or above 85 percent
```

### 3.2 Work status

```bash
# Phase table
grep -nE '^\| P[0-9]+ ' TODO.md

# Blocked work
grep -nE 'BLOCKED' TODO.md

# Open manual tasks
grep -nE '^\| M[0-9]+ .*OPEN' TODO.md
```

### 3.3 Is the remote green

```bash
make ci-status
```

**`make check` passing locally does not mean CI passed.** They are different
machines running different steps: the gates run offline, CI additionally
generates the Xcode project, builds the app and the CLI, and runs the layout
test. A green local run says nothing about any of those.

This step exists because CI was **red for 27 consecutive pushes** (2026-08-04 to
2026-08-10) while every run log in that window correctly recorded `make check`
green. Nothing was lying; nothing was asking either. A fresh clone could not
generate the project at all, and the failure was invisible from here (P7.15).

Skips cleanly when `gh` is absent or unauthenticated. It is **not** part of
`make check` — a gate must not go red because a remote is unreachable.

### 3.4 Risky tracked files

```bash
# Has a secret or signing material been committed
git ls-files | grep -iE '\.(p12|mobileprovision|provisionprofile|p8)$|^\.env$' \
  && echo "SECRET IN REPOSITORY - REMOVE IT NOW" || echo "OK: no signing material"

# Has the generated project been committed (T5)
git ls-files | grep -E '\.xcodeproj/' \
  && echo ".xcodeproj committed - T5 violation" || echo "OK: .xcodeproj clean"
```

> **Note:** invariant scans look only at source files. Documentation contains
> the text of the prohibitions themselves, and an unrestricted scan produces
> false positives.

---

## 4. Pick the next task

```bash
make next
```

The choice is **deterministic** — it is not left to judgement. Anything blocked
on a manual task is skipped automatically, across phase boundaries.

- Exit `0` → there is work, do it
- Exit `1` → nothing actionable; the output names the manual tasks being waited
  on. **Tell the project owner**
- Exit `2` → `TODO.md` formatting is broken; fix that first

Details and the format contract: `AGENTS.md` section 4.

---

## 5. Do the work

- Honour the constraints in the task description
- Produce the **evidence** the acceptance criterion asks for
- If you add an invariant, **add its gate and prove it with a deliberate
  violation**

---

## 6. Close the session

Three things, in the same change:

1. `TODO.md` checkbox `[x]`
2. `TODO.md` status summary table
3. `TODO.md` run log entry plus `Next: P<n>.<nn>`

Then commit **and push** — finished work does not sit unpushed on one machine
(project owner's standing instruction, 2026-08-05):

```bash
git add -A
git commit -m "<type>: <summary> (P<n>.<nn>)"
git push
```

---

## 7. Which file answers which question

| Question | File |
|---|---|
| What should I do? | `TODO.md` |
| What must I not do? | `AGENTS.md` sections 2 and 12 |
| Why was this decided this way? | `docs/architecture/adr/` |
| What are the legal boundaries? | `LEGAL.md` |
| What are the layer rules? | `ARCHITECTURE.md` |
| How does the control engine work? | `docs/product/control-model.md` |
| How is hardware accessed? | `docs/architecture/hardware-access.md` |
| What is the privilege model? | `docs/architecture/privilege-model.md` |
| What is the configuration schema? | `docs/architecture/configuration.md` |
| How is it tested? | `docs/development/testing.md` |
| How is it built and signed? | `docs/release/build-and-sign.md` |
| Where did a blueprint section go? | `docs/reference/blueprint-map.md` |
| Which risks are tracked? | `docs/reference/risks.md` |
| What does this term mean? | `docs/reference/glossary.md` |
| Which decisions are settled? | `docs/reference/decisions.md` |
| What was originally planned? | `docs/blueprint/` (reference only) |

---

## 8. First message of the session

```
BOOT complete.
- Directory: <pwd> - Branch: <branch> - Last commit: <hash> <summary>
- Gates: make check -> <PASS / FAIL: which one>
- CI: make ci-status -> <green / failure + run URL / SKIP + reason>
- Active phase: P<n> (<status>) - <theme>
- Next task: P<n>.<nn> - <title>
- Blocked: <manual task numbers, or "none">

Starting.
```
