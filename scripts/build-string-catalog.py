#!/usr/bin/env python3
"""Merges the compiler's extracted strings into the String Catalog (P6.11).

WHY NOT PARSE THE SWIFT:
    Every user facing string is a `String(localized:defaultValue:comment:)`
    call, sometimes spread over five lines with a multiline default value
    and a line continuation. A regular expression over that would be wrong
    on the day somebody formats a call differently, and wrong quietly.

    The compiler already does this extraction: with SWIFT_EMIT_LOC_STRINGS
    it writes a `.stringsdata` file per source file, carrying the key, the
    comment and the English value. This script merges those into the
    catalogue, so what ships is what the compiler saw — not what a pattern
    guessed.

WHAT IT PRESERVES:
    Existing translations. A key whose English text has not changed keeps
    every language it already had; a key whose English text *has* changed
    has its translations marked `needs_review`, because a translation of a
    sentence that no longer exists is worse than an obvious gap.

Usage:  scripts/build-string-catalog.py [--check]
        --check reports what would change and exits non-zero, for CI.
"""
import glob
import json
import os
import sys

CATALOG = "App/Resources/Localizable.xcstrings"
SOURCE_LANGUAGE = "en"


def stringsdata_files():
    """The compiler's extraction output for the application target."""
    pattern = os.path.expanduser(
        "~/Library/Developer/Xcode/DerivedData/Boreas-*/Build/Intermediates.noindex/"
        "Boreas.build/*/Boreas.build/Objects-normal/*/*.stringsdata"
    )
    return sorted(glob.glob(pattern))


def extracted():
    """Every key the compiler saw, with its English value and comment."""
    found = {}
    for path in stringsdata_files():
        try:
            data = json.load(open(path))
        except (OSError, ValueError):
            continue
        for entry in data.get("tables", {}).get("Localizable", []):
            key = entry.get("key")
            if not key:
                continue
            # A key used from two places must say the same thing in both.
            # Disagreement is a real defect: two call sites with one key and
            # different text means one of them silently loses.
            previous = found.get(key)
            if previous and previous["value"] != entry.get("value", ""):
                print(f"  ! key used with two different texts: {key}")
            found[key] = {
                "value": entry.get("value", ""),
                "comment": entry.get("comment", ""),
            }
    return found


def load_catalog():
    try:
        return json.load(open(CATALOG))
    except (OSError, ValueError):
        return {"sourceLanguage": SOURCE_LANGUAGE, "strings": {}, "version": "1.0"}


def merge(catalog, found):
    strings = catalog.setdefault("strings", {})
    added, changed, removed = [], [], []

    for key, entry in found.items():
        existing = strings.get(key)
        if existing is None:
            strings[key] = {
                "comment": entry["comment"],
                "extractionState": "manual",
                "localizations": {
                    SOURCE_LANGUAGE: {
                        "stringUnit": {"state": "translated", "value": entry["value"]}
                    }
                },
            }
            added.append(key)
            continue

        existing["comment"] = entry["comment"]
        localizations = existing.setdefault("localizations", {})
        source = localizations.setdefault(
            SOURCE_LANGUAGE, {"stringUnit": {"state": "translated", "value": ""}}
        )
        if source["stringUnit"].get("value") != entry["value"]:
            source["stringUnit"] = {"state": "translated", "value": entry["value"]}
            # The English changed underneath every translation of it.
            for language, localization in localizations.items():
                if language == SOURCE_LANGUAGE:
                    continue
                mark_needs_review(localization)
            changed.append(key)

    for key in list(strings):
        if key not in found:
            del strings[key]
            removed.append(key)

    catalog["strings"] = dict(sorted(strings.items()))
    return added, changed, removed


def mark_needs_review(localization):
    """Marks every translated unit in one localisation as needing review.

    **Found in P7.06, and it would have crashed.** This used to do
    `localization["stringUnit"]["state"] = "needs_review"` — which is a `KeyError`
    on a localisation that has no `stringUnit` because it holds plural
    `variations` instead. Russian is the first language in this project to need
    plural forms, so it is the first thing that could have hit it: adding them and
    then editing that string's English would have broken `make strings` outright.

    The same shape of blind spot the honesty gate had, from the same cause — the
    catalogue tooling was written when every string was a single unit.
    """
    units = []

    def collect(node):
        if isinstance(node, dict):
            unit = node.get("stringUnit")
            if isinstance(unit, dict):
                units.append(unit)
            for key, child in node.items():
                if key != "stringUnit":
                    collect(child)
        elif isinstance(node, list):
            for child in node:
                collect(child)

    collect(localization)
    for unit in units:
        unit["state"] = "needs_review"


def main():
    check_only = "--check" in sys.argv
    found = extracted()
    if not found:
        print("  ✗ no extracted strings found — build the app first (make build-app)")
        return 1

    catalog = load_catalog()
    before = json.dumps(catalog, sort_keys=True)
    added, changed, removed = merge(catalog, found)
    after = json.dumps(catalog, sort_keys=True)

    print(f"  keys in source: {len(found)}")
    for label, keys in (("added", added), ("English changed", changed), ("removed", removed)):
        if keys:
            print(f"  {label}: {len(keys)}")
            for key in keys[:10]:
                print(f"      {key}")

    if before == after:
        print("  ✓ the catalogue already matches the source")
        return 0

    if check_only:
        print("  ✗ the catalogue is out of date — run: make strings")
        return 1

    with open(CATALOG, "w") as handle:
        json.dump(catalog, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(f"  ✓ wrote {CATALOG}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
