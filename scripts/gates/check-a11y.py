#!/usr/bin/env python3
"""GATE: gate-a11y — the accessibility rules in docs/product/ui.md, over the source.

Why a source scan rather than a walk of the accessibility tree: SwiftUI builds
its accessibility nodes lazily, only when an accessibility client is attached.
P6.12 probed three ways of reading our own tree in-process (the NSAccessibility
protocol on an NSHostingView, AXUIElementCreateApplication against our own pid,
and the hosting window's children) and every one returned the container with
nothing inside it. Attaching a real client needs the Accessibility permission,
which invariant I2 forbids this project from requesting. So the rules are
enforced where they are written: in the source.

Three rules, each traceable to docs/product/ui.md:

  A1  Every SF Symbol is either named, explicitly hidden, or supplied with a
      name by the Label it sits in. There is no fourth option, because an
      unlabelled glyph reads aloud as its symbol name or as nothing at all.

  A2  Every Canvas and Chart carries an accessibility label. A picture cannot
      describe itself.

  A3  No animation is declared without consulting Reduce Motion. The interface
      currently declares none at all, which is why "honours Reduce Motion" is
      true today — this rule is what keeps it true.
"""

import re
import sys
from pathlib import Path

# How far after a declaration a modifier may sit and still count as attached.
# A chain of SwiftUI modifiers is routinely a dozen lines; a Canvas's label sits
# after the whole closure. Both limits are heuristics, and the docstring of each
# rule says so — the gate is a regression net, not a proof.
ICON_MODIFIER_WINDOW = 12
CANVAS_MODIFIER_WINDOW = 60

ICON = re.compile(r"Image\(\s*systemName:")
CANVAS = re.compile(r"\b(Canvas|Chart)\s*(\{|\()")
LABELLED = re.compile(r"\.accessibilityLabel\(")
HIDDEN = re.compile(r"\.accessibilityHidden\(\s*true\s*\)")
IGNORES_CHILDREN = re.compile(r"\.accessibilityElement\(\s*children:\s*\.ignore\s*\)")
ANIMATION = re.compile(r"\bwithAnimation\b|\.animation\(|\.transition\(|repeatForever")
REDUCE_MOTION = re.compile(r"accessibilityReduceMotion|ReduceMotion")

# `Label { … } icon: { Image(…) }` gives the glyph its name from the text
# beside it, so the icon needs nothing of its own.
ICON_SLOT = re.compile(r"icon:\s*\{")


def strip_comment(line: str) -> str:
    """Drop a trailing line comment so prose about a rule cannot satisfy it."""
    marker = line.find("//")
    return line if marker < 0 else line[:marker]


def previous_code_line(lines: list[str], number: int) -> str:
    """The nearest line above `number` that carries code.

    Comments are already stripped to whitespace, so this walks past a comment
    block of any length. Counting a fixed number of lines back does not work:
    `HelperSetupView` has three lines of reasoning between `} icon: {` and the
    glyph it introduces, which is exactly the shape that made this gate's first
    run report a false positive.
    """
    for candidate in range(number - 1, -1, -1):
        if lines[candidate].strip():
            return lines[candidate]
    return ""


def check_file(path: Path) -> list[str]:
    raw = path.read_text().splitlines()
    lines = [strip_comment(line) for line in raw]
    problems: list[str] = []

    for number, line in enumerate(lines):
        # ---- A1: every SF Symbol is named, hidden, or named by its Label ----
        if ICON.search(line):
            window = lines[number : number + ICON_MODIFIER_WINDOW]
            attached = "\n".join(window)
            preceding = previous_code_line(lines, number)
            if (
                LABELLED.search(attached)
                or HIDDEN.search(attached)
                or ICON_SLOT.search(preceding)
            ):
                continue
            problems.append(
                f"{path}:{number + 1}: A1 an SF Symbol with no name and no "
                "decision — add .accessibilityLabel(…) if it carries meaning, "
                ".accessibilityHidden(true) if it decorates"
            )

        # ---- A2: a picture cannot describe itself ----
        if CANVAS.search(line):
            window = "\n".join(lines[number : number + CANVAS_MODIFIER_WINDOW])
            if LABELLED.search(window) or IGNORES_CHILDREN.search(window):
                continue
            problems.append(
                f"{path}:{number + 1}: A2 a Canvas or Chart with no "
                ".accessibilityLabel within "
                f"{CANVAS_MODIFIER_WINDOW} lines"
            )

        # ---- A3: no motion without asking whether motion is wanted ----
        if ANIMATION.search(line):
            window = "\n".join(lines[max(0, number - 20) : number + 20])
            if REDUCE_MOTION.search(window):
                continue
            problems.append(
                f"{path}:{number + 1}: A3 an animation that never asks about "
                "Reduce Motion — read \\.accessibilityReduceMotion and skip it "
                "when set (docs/product/ui.md)"
            )

    return problems


def main() -> int:
    roots = [Path(argument) for argument in sys.argv[1:]] or [Path("App/Sources")]
    files = sorted(
        path
        for root in roots
        for path in root.rglob("*.swift")
    )
    if not files:
        print("  ✗ no Swift sources found to scan — a silent pass is forbidden")
        return 1

    problems: list[str] = []
    for path in files:
        problems.extend(check_file(path))

    icons = sum(
        len(ICON.findall(strip_comment(line)))
        for path in files
        for line in path.read_text().splitlines()
    )
    pictures = sum(
        len(CANVAS.findall(strip_comment(line)))
        for path in files
        for line in path.read_text().splitlines()
    )
    print(f"    UI files scanned: {len(files)}")

    if problems:
        for problem in problems:
            print(f"  ✗ {problem}")
        return 1

    print(f"  ✓ every SF Symbol is named or explicitly hidden ({icons} symbols)")
    print(f"  ✓ every Canvas and Chart carries a label ({pictures} pictures)")
    print("  ✓ no animation ignores Reduce Motion")
    return 0


if __name__ == "__main__":
    sys.exit(main())
