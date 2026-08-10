#!/usr/bin/env python3
"""Writing-system half of gate-language (H6), added in P7.13.

WHAT WAS MISSING, AND FOR HOW LONG:
    `check-language.sh` looks for Turkish letters and Turkish function words,
    and nothing else. Cyrillic and CJK were never detected at all, so from
    P7.06 — the task that added `ru`, `es` and `zh-Hans` — three of the five
    languages this product ships could appear anywhere in the repository and
    H6 would stay green. Found in P7.07, when `TRANSLATORS.md` turned out to be
    listed in the gate's exclusion regex while being invisible to it either way.

WHY THIS IS PYTHON AND NOT ANOTHER `grep`:
    A bracket range like `[А-Яа-я]` handed to `grep` is matched **byte-wise**
    under the C locale, and the resulting range swallows the em dash this
    repository uses on nearly every line. The first scan written in P7.07
    reported all 276 files as violations. Unicode ranges need a Unicode-aware
    reader, so this reads with an explicit encoding and matches on characters.

THE EXEMPTION, AND WHY IT IS NOT A FILE LIST:
    Some files quote a translation as **evidence** — a comment recording the
    measured width of a Russian label, a run log entry naming the string a
    render exposed, a document showing what a plural form looks like. That is
    the repository working in English *about* another language, which is not
    what H6 forbids.

    A hard-coded list of those files would go stale, which is exactly the
    reasoning `LEGAL.md` §5.1 gives for the `gate-names:policy-doc` marker. So
    the same shape is used: a file declares its own exemption, the declaration
    is visible in review, and the gate **reports how many files were skipped
    every time it runs** so the exemption is never silent.
"""
import pathlib
import re
import sys

# This file carries the marker itself, deliberately: it **names the characters
# it looks for**, so it would otherwise be its own first violation. The shell
# half handles the same problem by excluding itself by name.
# gate-language:quotes-translations — the ranges below are the subject of the file.
MARKER = "gate-language:quotes-translations"

# The three writing systems the product ships in that Latin letters cannot
# cover. Turkish is handled by the shell half, which also knows its function
# words; Spanish shares the Latin alphabet and cannot be detected this way at
# all — a limitation stated in `docs/development/localization.md` rather than
# papered over.
SYSTEMS = {
    "Cyrillic": re.compile(r"[Ѐ-ӿ]"),
    "CJK": re.compile(r"[一-鿿　-〿＀-￯]"),
}


def offences(path):
    """(system, line number, the line) for the first hit of each system."""
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        # Not decodable as UTF-8 is not a language violation; a binary file has
        # no prose in it. Skipped rather than reported, quietly on purpose.
        return []
    if MARKER in text:
        return None
    found = []
    for system, pattern in SYSTEMS.items():
        for number, line in enumerate(text.splitlines(), start=1):
            if pattern.search(line):
                found.append((system, number, line.strip()))
                break
    return found


def main(paths):
    exempt = 0
    problems = []
    for path in paths:
        result = offences(path)
        if result is None:
            exempt += 1
            continue
        for system, number, line in result:
            problems.append(f"{path}:{number}: {system} — {line[:90]}")

    if exempt:
        # Never silent, the `gate-names` rule: an exemption nobody can see is
        # indistinguishable from a gate that does not run.
        print(f"    {exempt} file(s) exempt: they quote a translation as evidence")

    if problems:
        print("  ✗ non-English text found (Cyrillic or CJK):")
        for problem in problems[:15]:
            print(f"      {problem}")
        if len(problems) > 15:
            print(f"    and {len(problems) - 15} more")
        print(f"    if the text is evidence, add the '{MARKER}' marker and say why")
        return 1

    print("  ✓ no Cyrillic or CJK outside the files that declare it")
    return 0


if __name__ == "__main__":
    sys.exit(main([line.strip() for line in sys.stdin if line.strip()]))
