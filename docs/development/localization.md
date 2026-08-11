<!-- gate-language:quotes-translations — this file names each language in its own script and shows what a plural form looks like, which is the subject of the document.
     H6 forbids working in another language, not writing in English about one. -->

# Localisation

> Last updated: 2026-08-11 — P8.10
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

**All five ship as of P7.06.** `en` and `tr` are source quality; `ru`, `es` and
`zh-Hans` are produced in-project and **unreviewed**, which
[ADR 0016's addendum](../architecture/adr/0016-language-scope.md) requires to be
stated rather than hidden — `TRANSLATORS.md` carries the origin per language.

### Plural forms, per language rather than per assumption

Russian was the first string in this project to need plural agreement, exactly as
P6.11 predicted. Each language gets the CLDR categories it actually has:

| Language | Categories | Strings using them |
|---|---|---|
| `ru` | one · few · many · other | 7 |
| `es` | one · other | 7 |
| `zh-Hans` | other only — the language makes no singular/plural distinction | 0 |
| `en`, `tr` | none needed | 0 |

Chinese having **no** plural variations is correct rather than a shortcut: 1 个风扇
and 3 个风扇 use the same noun, and adding categories would invent a distinction the
language does not make. Turkish likewise does not pluralise after a numeral.

**Where a sentence carries more than one number**, a single `variations.plural`
cannot express it — the catalogue would need per-argument `substitutions`. Those six
strings are instead **restructured so the numeral follows its noun**
("Циклов заряда пройдено: %lld"), which removes the agreement question entirely and
is the same technique the Turkish text uses to end a sentence at its placeholder.
Both are legitimate; which one each string uses is written down beside it.

### Two tooling blind spots, found by adding plurals

Neither could have been found earlier, because nothing used plural variations until
Russian needed them — which is how a latent hole stays invisible until it matters:

- **`gate-i18n`'s honesty check read only `stringUnit`.** A plural entry stores its
  text under `variations.plural.{category}.stringUnit` instead, so a forbidden word
  inside a Russian plural form would have passed straight through the gate that
  exists to refuse it. Proven by planting one and watching the old scan read an
  empty string.
- **`make strings` would have crashed.** It marked translations `needs_review` by
  assigning to `localization["stringUnit"]["state"]` — a `KeyError` on a
  localisation that has variations instead. Adding plurals and then editing that
  string's English would have broken the build.

Both now walk the whole structure rather than the two shapes known at the time. And
`FORBIDDEN` gained vocabulary for the three new languages: **a language present in
the catalogue with no forbidden words is a language the honesty rule silently does
not apply to**, so the gate now fails on that rather than passing quietly.

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

**Wrapping needs somewhere to wrap to.** An `HStack` of five chips in a 320 pt
panel has no second line to use, so SwiftUI truncates instead — which is how the
panel broke the rule while every fixed-width container passed. `FlowLayout`
(P8.10) gives the picker and the footer that second line; the panel grows
downwards, which a menu bar panel can afford and a row of labels cannot.

CI checks this with a **pseudo-locale** (artificially lengthened strings) layout test.

### Implementation (P6.13) — and the rule as it is actually enforced

`make layout` → [`scripts/layout-test.sh`](../../scripts/layout-test.sh), and in CI as its own
step after the app build. It runs in the *built application* rather than as a gate
because only SwiftUI and AppKit can say how wide a string renders in the font it
will really use.

**The rule above is stated absolutely and enforced as a measurement, and the
difference matters.** A sortable table needs its columns to line up, so the
sensor table has five fixed widths and always will. Banning them outright would
be a rule nobody could keep, so what is enforced is the thing the ban was
protecting: **no fixed-width container may clip what it has to hold**, at the
longest string any shipped language gives it, plus an expansion budget.

| Quantity | Value | Why |
|---|---|---|
| Expansion budget (fails the build) | **1.4×** | Measured German/Russian expansion clusters here. Sizing for 2× spends width in every language on one that does not exist |
| Diagnostic factor (reported only) | 2.0× | A container that clears 1.4 but not 2.0 has less headroom than another. That is not a defect, and failing on it teaches people to ignore the check |

Both live in [`Core/Presentation/PseudoLocale.swift`](../../Packages/Core/Sources/Core/Presentation/PseudoLocale.swift)
under test, with the expansion itself — which **preserves format specifiers**,
unlike the platform's `-NSDoubleLocalizedStrings` (that turns `%lld` into `lld`).
The flag is still used, for *renders a human looks at*: `LAYOUT_RENDER_DIR=<dir> make layout`
writes the doubled interface in both languages.

**The inventory of containers derives from the views' own declarations** —
`SensorColumn.allCases` with `SensorTable.width(of:)`,
`CurvePointTable.temperatureColumnWidth`, and since P8.10 the menu bar panel's
profile chips against `MenuBarPanel.contentWidth` — so a container that is
resized or renamed is re-measured without anybody remembering to update a list.

> **The inventory being derived does not make it complete, and P8.10 is the
> proof.** `make layout` was green for five phases while the panel truncated its
> profile names to `Balan…` and `Performa…`, because the picker was not in the
> inventory at all — deriving each entry from its view says nothing about the
> entries nobody added. It was found by looking at a screenshot for the README,
> not by a check. The `localizationKey`
those columns expose is derived from `rawValue` rather than written twice, and the
drill checks the derivation still resolves to what the view shows, because a
renamed key would otherwise make it measure the key text and pass.

**What the first run found.** Three real violations, one of them live: Turkish
**"Performans çekirdekleri" needed 144 pt of a 130 pt column**, so the group
column was truncating in the shipped product, not merely at risk of it. English
"Performance cores" and the Turkish "En yüksek" header cleared their columns but
not the budget. The columns were re-sized *by measurement* — the group column
took the width the sensor-name column gave up, since sensor names are raw keys,
not localised, and already truncate in the middle by design.

**A cost worth naming:** the group column is now the widest in the table, sized
for a name that per [ADR 0020](../architecture/adr/0020-compute-die-sensor-group.md)
may never appear on Apple Silicon at all. The width is reserved anyway — the
layout is static and the group *can* occur.

## Translation maintenance

- [`TRANSLATORS.md`](../../TRANSLATORS.md) — **the origin of every language**, and the reviewer once a language has one
- When a new string is added and translations are missing, CI **warns** (not an error — it does not block a release)
- Translation quality approval requires a **native speaker** → a manual task

### The origin declaration (P7.07)

Three of the five languages ship without native speaker review, and
[ADR 0016's addendum](../architecture/adr/0016-language-scope.md) made one thing
compensate for that: the origin is **stated**, per language, rather than left to
be assumed. Three words carry it:

| Origin | Meaning |
|---|---|
| `source` | Written in this language, not translated into it — `en` and `tr` |
| `project` | Produced by the project, awaiting native speaker review — `ru`, `es`, `zh-Hans` |
| `reviewed` | Read and approved by a **named** native speaker |

**The declaration is checked, not trusted**, because a file whose accuracy
nothing enforces is a promise rather than a mechanism. `make gate-i18n` fails on:
a shipped language with no row; a row for a language that no longer ships; an
origin outside those three words; and a row claiming `reviewed` while naming
nobody — an unsigned review being exactly the unbacked quality claim the whole
arrangement exists to avoid.

**The language set comes from the catalogue, never from a list written here
again.** That is deliberate and it is the third time this project has had to
learn it: P6.11 hard-coded five language codes that asserted a future, and P7.06
found `FORBIDDEN` carrying vocabulary for two of five languages, so the honesty
rule silently applied to none of the new ones. Both were a hand-written list
sitting beside a list that changes. Adding a sixth language now turns the gate
red until its origin is declared.

## Text writing principle

Interface text is written from scratch. Plain, direct, free of jargon.

**The Turkish text does not read like a translation from English** — it is written thinking in Turkish, and the English version is written separately. Both are source quality.

Tone: it also says what it cannot do. In this category, honesty is the strongest communication.

## Gates

| Gate | What it holds |
|---|---|
| `make gate-i18n` | The catalogue rules — see [What the gate checks](#what-the-gate-checks) below |
| `make layout` | Y3, the layout consequence — see [Implementation (P6.13)](#implementation-p613--and-the-rule-as-it-is-actually-enforced) above |

> **Stale claim removed (P6.13):** this section used to say `gate-i18n` requires
> "all 5 languages present in the catalogue". P6.11 replaced that rule — it would
> have passed on a single translated string, and went red for the three languages
> P7.06 owns — and the section below has described the real behaviour since. The
> two contradicted each other for two tasks.


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

**And `make format` has to happen before `make strings`, not after** (found in
P7.01). Reformatting a source file can reflow a multi-line `defaultValue`, which
changes the English the compiler extracts — so a catalogue built before the
format pass no longer matches the source, and `make strings-check` goes red on a
change that was purely cosmetic. Existing translations survive the rebuild, but
the wasted cycle is avoidable:

```bash
make format && make generate && xcodebuild -project Boreas.xcodeproj -scheme Boreas build
make strings && make strings-check
```

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
| Origin (P7.07) | `TRANSLATORS.md` declares an origin for every shipped language, and for no other — see [The origin declaration](#the-origin-declaration-p707) |

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

**Since P7.13 it refuses Cyrillic and CJK too** — and this document carries a
`gate-language:quotes-translations` marker, because naming each language in its
own script is its subject. What the gate covers, stated plainly so nobody
assumes more than is true:

| Language | Detected? | How |
|---|---|---|
| `tr` | Partly | Six Turkish-only letters and nine function words. A sentence avoiding all of them passes |
| `ru` | Yes | Cyrillic range |
| `zh-Hans` | Yes | CJK ranges |
| `es` | **No, and it cannot be** | It shares the Latin alphabet; no character check can tell Spanish prose from English |

The exemption is a per-file marker with a reason, counted and printed on every
run, following the `gate-names:policy-doc` precedent — see
[ADR 0021's P7.13 addendum](../architecture/adr/0021-english-only-repository.md)
for why quoting a translation as evidence was decided to be inside H6 rather
than an exception to it.
