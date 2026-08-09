#!/usr/bin/env python3
"""String Catalog checks for gate-i18n (Y2, Y4 and the honesty rule).

WHAT CHANGED IN P6.11 AND WHY:
    The gate used to `grep` the catalogue for five language codes and pass
    if each appeared anywhere in the file. One translated string would have
    satisfied it, and the three languages P7.06 owns made it red for a
    phase that never promised them. Both are the same mistake: asserting a
    future instead of checking a fact.

    It now checks what is true. The languages this build ships must be
    present, and **every language present must be complete** — a half
    translated language shipping is the failure that matters, and adding
    one in P7.06 makes this stricter by itself rather than weaker.
"""
import json
import sys

# The languages this build ships. P7.06 adds ru, es and zh-Hans; when it
# does, the completeness rule below covers them without this list moving.
REQUIRED = ["en", "tr"]

# The honesty rule's vocabulary (docs/operations/diagnostics.md). The
# application must never tell somebody their hardware is faulty, and a
# translation can break that rule as easily as the source can — which is
# why this runs over the catalogue rather than over the Swift, where the
# test it replaced could only ever see English.
FORBIDDEN = {
    "en": ["faulty", "broken", "defective", "damaged"],
    "tr": ["arızalı", "bozuk", "kusurlu", "hasarlı"],
}

# Only the diagnostic wording is bound by it: the sentence that *explains*
# the rule necessarily contains the word it forbids.
DIAGNOSTIC_PREFIXES = ("diagnostics.finding.", "diagnostics.cause.", "diagnostics.step.")


def main(path):
    try:
        data = json.load(open(path))
    except Exception as exc:
        print(f"  ✗ the String Catalog could not be parsed: {exc}")
        return 1

    strings = data.get("strings", {})
    if not strings:
        print("  ✗ the String Catalog is empty")
        return 1

    failed = False

    # Y2 — every string carries a translator comment.
    missing_comment = [key for key, value in strings.items() if not value.get("comment")]
    if missing_comment:
        print(f"  ✗ strings with an empty comment field: {len(missing_comment)} (Y2)")
        for key in missing_comment[:10]:
            print(f"      {key}")
        failed = True
    else:
        print(f"  ✓ every string carries a comment ({len(strings)} strings)")

    present = set()
    for value in strings.values():
        present.update(value.get("localizations", {}).keys())

    for language in REQUIRED:
        if language not in present:
            print(f"  ✗ a language this build ships is missing entirely: {language}")
            failed = True

    # Y4 — no half translated language. A gap falls back to the source,
    # which is two languages mixed on one screen without saying so.
    for language in sorted(present):
        gaps = [
            key
            for key, value in strings.items()
            if language not in value.get("localizations", {})
        ]
        if gaps:
            print(f"  ✗ {language} is incomplete: {len(gaps)} untranslated")
            for key in gaps[:5]:
                print(f"      {key}")
            failed = True
        else:
            print(f"  ✓ {language} covers every string")

    # The honesty rule, in every language.
    accusations = 0
    for key, value in strings.items():
        if not key.startswith(DIAGNOSTIC_PREFIXES):
            continue
        for language, localization in value.get("localizations", {}).items():
            text = localization.get("stringUnit", {}).get("value", "").lower()
            for word in FORBIDDEN.get(language, []):
                if word in text:
                    print(f"  ✗ diagnostic wording names a fault ({language}): {key}")
                    print(f'      contains "{word}"')
                    accusations += 1
                    failed = True
    if accusations == 0:
        print("  ✓ no diagnostic wording names a fault, in any language")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
