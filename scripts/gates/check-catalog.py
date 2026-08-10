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

# Every language the product ships. P6.11 required only `en` and `tr` and let the
# "every language present must be complete" rule do the rest, deliberately — the
# three P7.06 owns did not exist yet and asserting a future is what that task
# removed. They exist now, so a build that dropped one would be a regression the
# gate has to catch rather than shrug at.
REQUIRED = ["en", "tr", "ru", "es", "zh-Hans"]

# The honesty rule's vocabulary (docs/operations/diagnostics.md). The
# application must never tell somebody their hardware is faulty, and a
# translation can break that rule as easily as the source can — which is
# why this runs over the catalogue rather than over the Swift, where the
# test it replaced could only ever see English.
# Adding a language without adding its forbidden vocabulary would make this check
# **pass trivially** for that language — the rule would look enforced and would
# not be. Found while adding three languages in P7.06, which is the first time the
# omission could have mattered.
FORBIDDEN = {
    "en": ["faulty", "broken", "defective", "damaged"],
    "tr": ["arızalı", "bozuk", "kusurlu", "hasarlı"],
    "ru": ["неисправ", "сломан", "дефект", "поврежд", "вышел из строя"],
    "es": ["defectuoso", "averiado", "roto", "dañado", "estropeado"],
    # Chinese needs no word boundaries and the characters are the whole word:
    # 故障 fault, 损坏 damaged, 坏了 broken, 失效 failed.
    "zh-Hans": ["故障", "损坏", "坏了", "失效", "报废"],
}

# Every language the honesty rule can actually police. A language present in the
# catalogue but absent here is one the rule silently does not apply to, so the
# gate says so rather than letting it pass unnoticed.
def unpoliced(languages):
    return sorted(language for language in languages if language not in FORBIDDEN)

# Which keys the rule binds. Not every string: the sentence that *explains* the
# rule necessarily contains the word it forbids, and so does a settings label
# describing what a check does.
#
# `notify.` joined the list in P7.01, and it should have been obvious sooner: a
# notification makes exactly the same claim about somebody's hardware that a
# diagnostic finding does, and it makes it *unprompted*, on top of whatever they
# were doing. If any wording in this product needs holding to the honesty rule,
# an interruption does. Proven by planting the Turkish word for "faulty" in a
# notification body and watching this turn red.
DIAGNOSTIC_PREFIXES = (
    "diagnostics.finding.",
    "diagnostics.cause.",
    "diagnostics.step.",
    "notify.",
)


def translated_values(localization):
    """Every piece of translated text in one localisation, plural forms included.

    **Found in P7.06, and it was a real blind spot.** A plural entry does not
    store its text at `stringUnit` — it stores one per category under
    `variations.plural.{one,few,many,other}.stringUnit`. The honesty check used to
    read only the former, so a forbidden word inside a Russian plural form would
    have passed straight through the gate that exists to refuse it. No string used
    variations until Russian needed them, which is exactly how a latent hole stays
    invisible until the moment it matters.

    Written to walk the whole structure rather than the two shapes known today, so
    a device variation or a nested case is covered without anybody remembering to
    come back here.
    """
    found = []

    def walk(node):
        if isinstance(node, dict):
            unit = node.get("stringUnit")
            if isinstance(unit, dict) and isinstance(unit.get("value"), str):
                found.append(unit["value"])
            for key, child in node.items():
                if key != "stringUnit":
                    walk(child)
        elif isinstance(node, list):
            for child in node:
                walk(child)

    walk(localization)
    return found


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
            for text in translated_values(localization):
                for word in FORBIDDEN.get(language, []):
                    if word in text.lower():
                        print(f"  ✗ diagnostic wording names a fault ({language}): {key}")
                        print(f'      contains "{word}"')
                        accusations += 1
                        failed = True
    # A language with no forbidden vocabulary is a language this check cannot
    # police. Saying so is the difference between a rule and the appearance of one.
    blind = unpoliced(present)
    if blind:
        print(f"  ✗ no honesty vocabulary for: {', '.join(blind)}")
        print("      the rule cannot apply to a language it has no words for")
        failed = True

    if accusations == 0 and not blind:
        print("  ✓ no diagnostic wording names a fault, in any language")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
