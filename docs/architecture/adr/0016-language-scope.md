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

## Addendum — 2026-08-10 (P7.06): the deferred evaluation, answered

**Context.** The addendum above ends with a consequence marked *"to be evaluated in
P6"*: whether warning texts carrying safety or data-loss risk should be shown
**alongside the `en` fallback** until a native speaker has reviewed them. **P6
closed without evaluating it.** P7.06 is the task that ships the three unreviewed
languages, so it is the last honest moment to answer.

**Decision. No dual rendering.** The reasoning is that the premise does not hold
for this product:

1. **Safety here is enforced by code, not by comprehension.** G1 (layers only ever
   raise), G2 (K2/K3 cannot be switched off), G3 (the watchdog range is locked) and
   G4 (quit, crash, sleep and shutdown all return the fans to firmware) hold
   whatever language the interface is in and whether or not the user reads it.
   **Nothing in this product asks the user to act correctly on a warning in order
   to stay safe.** A mistranslated sentence is therefore a comprehension cost, not
   a safety failure — which is not what the original concern assumed.
2. **Data loss has one real path, and it is not a warning.** The recording disk
   ceiling deletes files; it is governed by a number the user set, shown as a
   standing state in the Recording tab, and not dependent on reading a sentence in
   time.
3. **Dual rendering would cost every language, including the reviewed ones.** Two
   languages in one label roughly doubles its width, on top of the 1.4× expansion
   budget `make layout` enforces — P7.06 had to widen four columns to satisfy that
   budget for one language at a time. Making every label bilingual would push the
   interface past what any fixed-width column can hold, degrading the two source
   quality languages to protect the three that are unreviewed.

**What we do instead** — the honesty the first addendum chose, applied without
inventing a second mechanism:

- `TRANSLATORS.md` states the origin per language (P7.07), so a user knows how much
  to trust what they are reading.
- The `setup.*` strings — the one place a user grants root privileges and therefore
  the one place informed consent genuinely matters — are deliberately the most
  detailed text in the product: what will happen, what is written where, and how to
  undo it. Detail of that kind survives translation; a short warning does not.
- `make gate-i18n` refuses an accusing word **in every language**, including inside
  plural forms since P7.06 — so the class of mistranslation that would do real harm
  (telling somebody their hardware is broken) is the one thing actually blocked
  mechanically.

**Consequences.**
- ✅ The open item from 2026-08-03 is closed rather than carried into P8
- ✅ No layout or readability cost imposed on `en` and `tr` to hedge the others
- ⚠️ An unreviewed translation can still read awkwardly or misdescribe a *feature*;
  `TRANSLATORS.md` and the fix template are the mitigation, and they are honest
  rather than complete
