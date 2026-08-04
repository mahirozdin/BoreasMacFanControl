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
