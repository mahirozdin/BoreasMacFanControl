#!/usr/bin/env python3
"""
Deterministically selects the next actionable atomic task from TODO.md.

WHY THIS SCRIPT EXISTS
    As long as the selection algorithm lives in a document as prose, it is
    left to model judgement, and a session can stall the moment a task hits a
    manual blocker. This script hands the choice to a machine: EVERY task
    blocked on a manual item is skipped and the next actionable task is
    returned — phase boundaries notwithstanding.

CONTRACT
    Atomic task line:   - [ ] **P<n>.<nn> — Title.** description
    Manual blocker:     at the end of the line  ⛔ M03  (several: ⛔ M03 M04)
    Phase dependency:   - **Depends on:** P1, P2      (inside the phase block)
    Manual task status: | M03 | ... | OPEN |   ->  anything except OPEN counts
                        as resolved

A TASK IS ACTIONABLE WHEN
    1. it is unchecked                  - [ ]
    2. every manual task it depends on is resolved (or it depends on none)
    3. every task in the phases it depends on is complete

Output: the chosen task plus the reasoning. If nothing is actionable, it says
what is being waited on.
Exit code: 0 = there is work, 1 = nothing actionable, 2 = parse error
"""
import os
import re
import sys
import pathlib

# Overridable via TODO_PATH — needed by the gate tests
TODO = pathlib.Path(
    os.environ.get("TODO_PATH")
    or pathlib.Path(__file__).resolve().parent.parent / "TODO.md"
)

TASK_RE = re.compile(r"^- \[( |x)\] \*\*(P\d+)\.(\d+)\s*—\s*(.+?)\*\*(.*)$")
PHASE_RE = re.compile(r"^## (P\d+) — (.+)$")
DEP_RE = re.compile(r"^- \*\*Depends on:\*\*\s*(.*)$")
MANUAL_RE = re.compile(r"^\|\s*(M\d+)\s*\|.*\|\s*(.+?)\s*\|\s*$")
BLOCK_RE = re.compile(r"⛔\s*((?:M\d+[\s,]*)+)")


def parse():
    if not TODO.exists():
        print(f"ERROR: {TODO} not found", file=sys.stderr)
        sys.exit(2)
    lines = TODO.read_text(encoding="utf-8").split("\n")

    manual = {}
    phases = {}          # "P1" -> {"theme":..., "deps":[...], "tasks":[...]}
    order = []
    current = None
    in_manual = False

    for raw in lines:
        line = raw.rstrip()

        if line.startswith("## ") and "Manual tasks" in line:
            in_manual = True
            current = None
            continue
        if in_manual and line.startswith("## "):
            in_manual = False

        if in_manual:
            m = MANUAL_RE.match(line)
            if m and m.group(1) != "#":
                manual[m.group(1)] = m.group(2)
            continue

        m = PHASE_RE.match(line)
        if m:
            current = m.group(1)
            if current not in phases:
                phases[current] = {"theme": m.group(2), "deps": [], "tasks": []}
                order.append(current)
            continue

        if current:
            m = DEP_RE.match(line)
            if m:
                phases[current]["deps"] = re.findall(r"P\d+", m.group(1))
                continue

            m = TASK_RE.match(line)
            if m:
                done = m.group(1) == "x"
                tid = f"{m.group(2)}.{m.group(3)}"
                blockers = []
                b = BLOCK_RE.search(m.group(5) or "")
                if b:
                    blockers = re.findall(r"M\d+", b.group(1))
                phases[current]["tasks"].append(
                    {"id": tid, "done": done, "title": m.group(4).strip(), "blockers": blockers}
                )

    return manual, phases, order


def manual_open(mid, manual):
    """Is the manual task still pending? An unknown id counts as pending, on purpose."""
    status = manual.get(mid)
    if status is None:
        return True
    s = status.upper()
    return "OPEN" in s and "DONE" not in s


def phase_complete(pid, phases):
    p = phases.get(pid)
    if not p:
        return True
    return all(t["done"] for t in p["tasks"])


def main():
    manual, phases, order = parse()
    if not phases:
        print("ERROR: no phase found in TODO.md", file=sys.stderr)
        sys.exit(2)

    skipped = []
    waiting_on_phase = []

    for pid in order:
        p = phases[pid]
        unmet = [d for d in p["deps"] if not phase_complete(d, phases)]
        if unmet:
            pending = [t for t in p["tasks"] if not t["done"]]
            if pending:
                waiting_on_phase.append((pid, unmet))
            continue

        for t in p["tasks"]:
            if t["done"]:
                continue
            open_blockers = [b for b in t["blockers"] if manual_open(b, manual)]
            if open_blockers:
                skipped.append((t["id"], t["title"], open_blockers))
                continue

            print(f"NEXT TASK: {t['id']}")
            print(f"  Phase  : {pid} — {p['theme']}")
            print(f"  Title  : {t['title']}")
            if skipped:
                print(f"  Skipped: {len(skipped)} task(s) waiting on manual work")
                for sid, stitle, sb in skipped[:5]:
                    print(f"           {sid} ⛔ {' '.join(sb)} — {stitle[:52]}")
            sys.exit(0)

    # Nothing actionable left
    print("NOTHING ACTIONABLE")
    if skipped:
        print(f"\n  {len(skipped)} task(s) waiting on manual work:")
        for sid, stitle, sb in skipped:
            print(f"    {sid} ⛔ {' '.join(sb)} — {stitle[:60]}")
        need = sorted({b for _, _, bs in skipped for b in bs})
        print(f"\n  Manual tasks that need resolving: {', '.join(need)}")
    if waiting_on_phase:
        print("\n  Waiting on phase dependencies:")
        for pid, unmet in waiting_on_phase:
            print(f"    {pid} <- {', '.join(unmet)}")
    if not skipped and not waiting_on_phase:
        print("\n  Everything appears to be complete.")
    sys.exit(1)


if __name__ == "__main__":
    main()
