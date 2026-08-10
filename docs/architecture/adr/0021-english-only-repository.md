# 0021 — The repository is written in English

- **Status:** Accepted
- **Date:** 2026-08-04
- **Supersedes:** part of [0016](0016-language-scope.md)

## Context

[ADR 0016](0016-language-scope.md) set the interface to five languages and the
documentation to English, but carved out an exception: the project management
documents — `TODO.md`, `AGENTS.md`, `BOOT.md`, the `docs/` tree and the gate
scripts — were written in Turkish, the working language of the author.

That exception was reasonable while the repository was private and had one
reader. It stops being reasonable the moment the repository is public.

A contributor who cannot read `AGENTS.md` cannot follow the invariants. One who
cannot read `TODO.md` cannot find a task. One who cannot read a gate script
cannot understand why their pull request is red. The barrier is not politeness,
it is functional: **the working language of a project decides who can work on
it.**

## Decision

**Everything in the repository is written in English**, with three deliberate
exceptions:

| Exception | Why |
|---|---|
| `docs/blueprint/**` and `BLUEPRINT.md` | A frozen historical record. It is never edited, so translating it would falsify what was actually written at the start |
| `README.{tr,ru,es,zh-Hans}.md` | Translations exist on purpose, for reach ([ADR 0016](0016-language-scope.md)) |
| `TRANSLATORS.md` | Names translators in their own languages |

This covers governance documents, the `docs/` tree, architecture decision
records, gate scripts, build files, issue templates, commit messages and code
comments.

The user interface language scope from [ADR 0016](0016-language-scope.md) is
unchanged: five languages, Turkish among them. **What the software speaks and
what the repository speaks are separate questions.** A Turkish speaking user is
served by a Turkish interface; a Turkish speaking contributor is not served by
Turkish documentation that nobody else can review.

## Alternatives

| Option | Why not |
|---|---|
| Keep governance documents in Turkish | Excludes almost every potential contributor from the files they must read first |
| Maintain both languages | Two copies of a document that changes every session will drift within days, and a stale invariant is worse than none |
| Translate only when a contributor appears | The barrier is invisible from inside. Someone who cannot read the repository does not file an issue saying so; they leave |

## Consequences

- ✅ Any English reading developer can pick up a task without a translation step
- ✅ Gate failures explain themselves to the person who triggered them
- ✅ Issues, pull requests and commit history are reviewable by anyone
- ⚠️ The author writes governance documents in a second language
- ⚠️ One large rewrite: 84 files at the time of this decision

## Enforcement

`make gate-language` scans every tracked file for characters that appear in
Turkish and in no English word — g-breve, dotless i, s-cedilla and their
capitals — plus a short list of Turkish function words that survive when
diacritics are dropped. The characters themselves are spelled out only in the
gate script, which is excepted; printing them here would trip the gate this
decision created.

The excepted paths are listed in the script with the reason for each.

Proven by writing this decision: the gate went red against the repository as it
stood, and turning it green is what the rewrite is measured against.

---

## Addendum — 2026-08-10 (P7.13): the gate could only see one of the languages

**Context.** The Enforcement section above describes a scan for Turkish
characters and Turkish function words, and that is all it ever was. When
[ADR 0016](0016-language-scope.md)'s remaining three languages shipped in P7.06,
**Cyrillic and CJK were not detected at all** — so `ru` and `zh-Hans` could
appear anywhere in the repository and H6 stayed green. `es` shares the Latin
alphabet and was never detectable this way.

The gap surfaced in P7.07, when `TRANSLATORS.md` was found listed in the gate's
exclusion regex while being invisible to it either way: the exemption granted by
the Decision above was **inert**, because nothing in that file was of a kind the
gate could see.

**The question this addendum has to answer.** Adding the missing detection turns
the gate red on files that are not violations. Six of them quote a translation as
**evidence**: three Swift comments recording the measured widths that
`make layout` found, `TODO.md`'s Run Log naming the strings a render exposed, the
localisation document showing what a plural form looks like, and the P7.14 tests
whose whole subject is that a translated status line changes nothing about a
parsed token. Is that permitted?

**Decision. Yes, and it is not an exception to H6 — it is what H6 already
meant.** The invariant forbids *working in* another language. A comment in
English that names the Russian string which overflowed a column is working in
English **about** Russian, and deleting the string would delete the evidence.
A defect recorded without the text that showed it is not a record.

**How, and why not a file list.** A file **declares its own exemption** with a
`gate-language:quotes-translations` marker and a reason, and the gate reports how
many files were skipped **every time it runs**. This is deliberately the same
shape as the `gate-names:policy-doc` marker, for the reason `LEGAL.md` §5.1 gives:
a hard-coded list goes stale, while a declaration is visible in review. Adding the
marker is a deliberate act and is questioned in review; it cannot be used to hide
a passage somebody simply wrote in another language.

**Consequences.**
- ✅ H6 now covers four of the five shipped languages instead of one
- ✅ The evidence this project depends on stays in the record
- ⚠️ **Spanish remains undetectable** by any character check, and no claim is made
  that it is covered. Stated here rather than left to be discovered a third time
- ⚠️ A marker exempts a whole file, not a passage — the same coarseness
  `gate-names:policy-doc` accepts, and the same mitigation: it is counted, visible
  and reviewed

**Enforcement.** The writing-system half is
[`scripts/gates/check-language.py`](../../../scripts/gates/check-language.py),
in Python because a `grep` bracket range is matched **byte-wise** under the C
locale and swallows the em dash this repository uses on nearly every line — the
first attempt at this scan, in P7.07, reported all 276 files as violations.
Proven three ways: Russian prose in a source file is caught, Chinese prose is
caught, and the same Chinese text with the marker passes while the exempt count
rises by one.
