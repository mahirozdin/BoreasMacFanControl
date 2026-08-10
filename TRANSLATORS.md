# Translators

> Last updated: 2026-08-10 — P7.07
> Decision: [ADR 0016](docs/architecture/adr/0016-language-scope.md) and its
> 2026-08-03 addendum

Boreas ships in five languages. **Two of them are written by the project's
authors; three are produced by the project and have not been read by a native
speaker.** This file says which is which, per language, because not saying so is
quietly misinforming the person reading the interface.

Language names below are written in their own language — the one deliberate
exception this file holds to the English-only rule
([ADR 0021](docs/architecture/adr/0021-english-only-repository.md)).

## Origin per language

| Code | Language | Origin | Reviewed by |
|---|---|---|---|
| `en` | English | `source` | — |
| `tr` | Türkçe | `source` | — |
| `ru` | Русский | `project` | — |
| `es` | Español | `project` | — |
| `zh-Hans` | 简体中文 | `project` | — |

### What the three origins mean

| Origin | Meaning | What you can rely on |
|---|---|---|
| `source` | The text was **written** in this language, not translated into it. English and Turkish are both written from scratch, each thinking in its own language | Wording, tone and terminology are intentional |
| `project` | **Produced by the project, awaiting native speaker review.** No quality claim is made | The meaning should be right; the phrasing may be stiff, and a term may be wrong |
| `reviewed` | A native speaker has read the language through and approved it. **The reviewer is named** in the last column | Somebody who speaks the language has vouched for it |

`tr` is `source` rather than `reviewed` for a specific reason: it is not a
translation of the English at all. The two are written separately, and neither
is downstream of the other.

## Why the unreviewed languages ship anyway

Waiting for a native speaker per language would have held five-language support
behind an event nobody could schedule. The
[ADR 0016 addendum](docs/architecture/adr/0016-language-scope.md) chose the other
trade: ship them, and be explicit about what they are. **Honesty is what
compensates for the quality gap** — this file is that mechanism, and it is the
only thing standing between a user and the assumption that every language got
the same care.

What is *not* left to careful writing: `make gate-i18n` refuses an accusing word
— telling somebody their hardware is faulty — **in every language**, plural forms
included. The class of mistranslation that could do real harm is blocked
mechanically rather than trusted to review.

The reasoning for not showing English alongside an unreviewed language is
recorded in the [2026-08-10 addendum](docs/architecture/adr/0016-language-scope.md)
to the same ADR.

## Fixing a translation

Corrections are welcome, **including a single string**. That is the whole point
of the entry: it is small, and it does not require knowing the code base.

1. Open an issue with the **Translation fix** template
   ([`.github/ISSUE_TEMPLATE/translation_fix.yml`](.github/ISSUE_TEMPLATE/translation_fix.yml))
2. Give the string key, the current text, what it should say, and why
3. If it does not fit the space, say so — that is a layout defect, not only a
   wording one

Strings live in `App/Resources/Localizable.xcstrings`; the key is shown beside
each entry. `CONTRIBUTING.md` covers the pull request route.

## Becoming a language's reviewer

If you are a native speaker and want to read a language through rather than fix
one string:

1. Say so in an issue, naming the language
2. Read the strings for that language in the catalogue
3. Send the corrections as one pull request

When that lands, the language's row moves from `project` to `reviewed` and
**your name goes in the last column** — the row is not allowed to claim a review
without naming who did it.

## What is not translated

The documentation — this file, `README` aside, `CONTRIBUTING.md`, `SECURITY.md`
and everything under `docs/` — is **English only**, deliberately. A stale
translation of an instruction is worse than none, because the reader follows it.
See [ADR 0016](docs/architecture/adr/0016-language-scope.md) for the reasoning
and [`docs/development/localization.md`](docs/development/localization.md) for
how the catalogue is built and checked.

## This file is checked, not trusted

`make gate-i18n` reads the table above against the String Catalog and fails when
they disagree:

- a language the product ships with **no row here** — the gap this file exists to close
- a row for a language the product **does not ship** — a stale claim
- an origin outside the three defined above
- a row claiming `reviewed` while **naming nobody**

The language list is taken from the catalogue rather than written here a second
time, so adding a sixth language turns the gate red until its origin is
declared.
