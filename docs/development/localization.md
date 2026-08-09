# Localisation

> Last updated: 2026-08-10 — P6.11
> Source: blueprint §9.7 · Decision: [ADR 0016](../architecture/adr/0016-language-scope.md)

## Scope

**Application interface — 5 languages, complete in v1.0:**

| Code | Language | Note |
|---|---|---|
| `en` | English | **Source language** — keys are written here first |
| `tr` | Türkçe | Not a translation — written thinking in Turkish |
| `ru` | Русский | Long strings, three plural forms |
| `es` | Español | |
| `zh-Hans` | 简体中文 | Simplified |

**Documentation:** `README.md` in English (authoritative) + 4 translations. `CONTRIBUTING.md`, `SECURITY.md`, `docs/**`, code, comments, commits and the project management documents (`TODO.md`, `AGENTS.md`, `BOOT.md`) → **English only**. The original Turkish carve-out for project management documents was superseded by [ADR 0021](../architecture/adr/0021-english-only-repository.md).

## Technical rules

- The **String Catalog** (`.xcstrings`) is the single source
- `String(localized:)` is mandatory — hard coded text is forbidden (Y1)
- The **`comment` field is mandatory** for every string (Y2) — a translator cannot translate correctly without context
- Russian's three plural forms (`one`/`few`/`many`) must be handled correctly
- Temperature, number and date formatting goes through `Locale` and `Measurement` — **manual formatting is forbidden**
- Sorting and search use `localizedStandardCompare`
- A missing translation falls back to the source language (`en`), **never shows blank** (Y4)

## Layout consequence

Russian strings can run **30–50% longer** than English; Chinese is markedly shorter. Therefore:

> **There is no text container with a fixed pixel width or height.** All labels grow with their content and wrap when needed. Except for the menu bar item, overflow is never solved by truncation (`…`).

CI checks this with a **pseudo-locale** (artificially lengthened strings) layout test.

## Translation maintenance

- `TRANSLATORS.md` — responsible contributors per language
- When a new string is added and translations are missing, CI **warns** (not an error — it does not block a release)
- Translation quality approval requires a **native speaker** → a manual task

## Text writing principle

Interface text is written from scratch. Plain, direct, free of jargon.

**The Turkish text does not read like a translation from English** — it is written thinking in Turkish, and the English version is written separately. Both are source quality.

Tone: it also says what it cannot do. In this category, honesty is the strongest communication.

## Gate

`make gate-i18n` enforces: no hard coded user facing text · all 5 languages present in the catalogue · no string with an empty `comment` field.


## How the catalogue is built (P6.11)

`App/Resources/Localizable.xcstrings`, and it is **generated from the
compiler's own extraction** rather than parsed out of the Swift:

```bash
make generate && xcodebuild -project Boreas.xcodeproj -scheme Boreas build
make strings          # merges the compiler's extraction into the catalogue
make strings-check    # fails if the catalogue is out of date with the source
```

The build has to happen first: `make strings` reads what the compiler
wrote, so it can only ever be as current as the last build.

Every user facing string is a `String(localized:defaultValue:comment:)`
call, sometimes spread over five lines with a multiline default. A regular
expression over that would be wrong on the day somebody formats a call
differently, and wrong quietly. The compiler already writes a
`.stringsdata` file per source file carrying the key, the comment and the
English value; `scripts/build-string-catalog.py` merges those in, keeps
existing translations, and marks a translation `needs_review` when the
English underneath it changed.

## What the gate checks

`make gate-i18n` reads the catalogue and enforces:

| Rule | Check |
|---|---|
| Y1 | No hard coded user facing text in `App/Sources` |
| Y2 | Every string carries a translator comment |
| Y4 | **Every language present covers every string** — no half translated language ships |
| Honesty rule | No diagnostic wording names a fault, **in any language** |

The completeness rule replaced a `grep` for five language codes that would
have passed with a single translated string, and that went red for the
three languages P7.06 owns. It now checks what is true rather than
asserting a future: `en` and `tr` must exist, and anything else added has
to be complete from the day it appears.

**Where user facing text may not live:** `Packages/Core`. Core has no
bundle of its own in this application and the gate does not scan it, so
strings there are invisible twice over — which is exactly what happened to
two dozen diagnostic sentences until the Turkish render exposed them. Core
returns *values* (`DiagnosticFinding`, `DiagnosticCause`); the application
supplies the words.

**Turkish is not a translation.** It is written thinking in Turkish, and
**an interpolated value never takes a suffix**: a sentence is phrased so
the placeholder ends it (`"Son: %@"`) rather than carrying a case ending
(`"%@'e kadar"`). Turkish suffixes agree with the vowels of the word before
them, and nothing can make that agree with a value formatted at runtime —
so the phrasing sidesteps the agreement instead of guessing at it.

Note for anyone editing these documents: `make gate-language` (H6) refuses
Turkish characters outside the catalogue and the files it names. Examples
in prose have to be chosen to avoid them, which is why the two above are
written the way they are.
