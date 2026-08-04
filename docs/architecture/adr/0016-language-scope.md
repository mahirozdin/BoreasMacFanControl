# 0016 — Language scope: 5-language interface, English documentation

- **Status:** Accepted (partly superseded by [0021](0021-english-only-repository.md))
- **Date:** 2026-07-31
- **Source:** blueprint §9.7, §23 A6

## Context

The project will be open to an international audience. It is also a single developer project — every translation is a maintenance burden. A stale translation is more harmful than no translation: the user follows the wrong instructions.

## Decision

**The application interface — 5 languages, complete at v1.0:**

| Code | Language | Note |
|---|---|---|
| `en` | English | **Source language** — keys are written here first |
| `tr` | Turkish | Not a translation; written thinking in Turkish |
| `ru` | Russian | Long strings — layout flexibility is critical |
| `es` | Spanish | |
| `zh-Hans` | Simplified Chinese | Simplified; Traditional in a later wave |

**Documentation — a different rule:**

| File | Languages |
|---|---|
| `README.md` | **English (authoritative)** |
| `README.{tr,ru,es,zh-Hans}.md` | Translations + a "may lag behind" note |
| `CONTRIBUTING.md`, `SECURITY.md`, `docs/**` | English only |
| Code, comments, commit messages | English only |
| Project management documents (`TODO.md`, `AGENTS.md`, `BOOT.md`) | Turkish |

**Mandatory technical rules:** String Catalog (`.xcstrings`); `String(localized:)` is required; the `comment` field is filled for every string; Russian's three plural forms are handled correctly; a missing translation falls back to the source language and never shows blank.

**Layout consequence:** Russian strings can run 30–50% longer than English, Chinese is noticeably shorter. Hence **no text container has a fixed pixel width or height**.

## Alternatives

| Option | Why not |
|---|---|
| Keeping the documentation in 5 languages as well | `docs/` changes constantly; with a single developer it cannot be kept in sync. A stale translation is harmful |
| An English-only interface | A Turkish interface is rare in this category — a real differentiator |
| Deferring translation to v1.1 | If the localisation infrastructure is added later, every string is rewritten |

## Consequences

- ✅ Broad international reach
- ✅ Turkish is a first class language
- ⚠️ Every new string requires 5 translations → CI **warns** (not an error, does not block a release)
- ⚠️ Translation quality approval needs a native speaker → a manual task
- ⚠️ Layout design has to be multilingual

## Enforcement

`make gate-i18n`:
- Hard coded user facing text under `App/Sources` → red (Y1)
- Any of the 5 languages missing from the String Catalog → red
- Any string with an empty `comment` field → red (Y2)

A pseudo-locale layout test in CI: overflow checking with artificially lengthened strings (activated in P6).

---

## Addendum — 2026-08-03: translations ship without native speaker approval

**Context.** The original decision required translations to be reviewed by a native speaker (manual task M06). The project owner removed that requirement: translations will be produced within the project and shipped without waiting for review.

**Decision.** M06 is removed. Translations are produced by the project. But **their origin is not hidden** — honesty is what compensates for the quality gap:

1. `TRANSLATORS.md` states the origin for every language explicitly: `produced by the project, awaiting native speaker review`.
2. When a native speaker reviews and approves a language, the line is updated and the contributor is named.
3. The repository carries a standing **call for translation fixes**; an issue template (`translation_fix.yml`) makes fixing a single string easy.
4. `en` and `tr` are source quality (the languages of the project owner and the author); no quality claim is made for `ru`, `es`, `zh-Hans`.

**Why we mark the origin.** Not saying that a translation is unreviewed is quietly misinforming the user. In an application that performs thermal control, a mistranslated safety warning is expensive. Marking lets the user know how much to trust each language, and opens a concrete contribution door to the community.

**Consequences.**
- ✅ Five languages can ship at v1.0; the blocker is gone
- ✅ A clear, small entry point for contribution now exists
- ⚠️ `ru`/`es`/`zh-Hans` quality is initially uncertain — and declared openly
- ⚠️ Warning texts that carry safety or data loss risk may deserve to be shown **alongside the `en` fallback** until the translation is reviewed; to be evaluated in P6

**Enforcement.** `make gate-i18n` already checks that all five languages are present and that `comment` fields are filled. In addition, P7 will add a check that `TRANSLATORS.md` contains an origin line for every language.
