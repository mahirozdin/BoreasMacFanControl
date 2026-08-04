# Localisation

> Last updated: 2026-07-31 — P0.25
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
