# 0006 — Independent development policy

<!-- gate-names:policy-doc — This file DESCRIBES forbidden patterns and is
     therefore exempt from the gate-names scan. See LEGAL.md section 5.1 -->

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint section 2

> This is the project's most important decision. Breaking it stops the project.

## Context

Other commercial products solve a functionally similar problem in this
category. Copyright protects **expression, not ideas, functions or the problem
being solved** — so "adjust fan speed based on temperature" is free to
implement, while a particular interface text, icon set or data schema is not.

The project's legal safety depends on applying that distinction with discipline.
A git repository is also a **permanent record**: a line written with no ill
intent can still be produced as evidence later.

## Decision

Seven absolute prohibitions, stated in full in `LEGAL.md` section 2:

| # | Prohibition |
|---|---|
| Y1 | Reverse engineering, disassembling or decompiling a third party commercial application |
| Y2 | Copying **or translating** text, labels, help content or error messages |
| Y3 | Imitating icons, colour palettes, window layouts or visual identity |
| Y4 | Reusing a configuration schema, key names or data format verbatim |
| Y5 | **Writing any third party commercial product name in the repository** |
| Y6 | Comparative marketing |
| Y7 | Including code under an incompatible licence |

In addition, the control engine is **deliberately built on a different model**
([ADR 0010](0010-continuous-curve-model.md)) — originality is structural here,
not merely asserted.

## Alternatives

| Option | Why not |
|---|---|
| Simply telling people not to copy | A rule that is not enforced is broken in time |
| Keeping a list of competitor names and scanning for them | **That would break the rule itself** — those names would be in the repository |
| Writing no policy at all | Recorded good faith is the strongest defence against a claim |

## Consequences

- Recorded, auditable independent development process
- Originality at the architecture level, not only in wording
- Extra discipline for contributors; a declaration is required on every pull request
- Y5 cannot be fully automated — see below

## Enforcement

`make gate-names` applies three layers:

| Layer | What it catches |
|---|---|
| Comparative marketing patterns | Generic constructions such as "alternative to", "better than", "replacement for" |
| External domain allowlist | Any URL outside the permitted list requires human review — **needs no product name** |
| Trademark symbol scan | The registered and trademark signs |
| Local name list (optional) | `scripts/gates/.forbidden-names.local`, which is in `.gitignore` |

### The missing layer, recorded explicitly

**There is no stored list of forbidden names, and there cannot be.** Keeping
such a list in a file would put those names in the repository, which is exactly
what Y5 forbids.

This is an unavoidable, deliberate limitation. The remaining gap is closed by
two layers:

1. **The pull request declaration** — three checkboxes in
   `.github/PULL_REQUEST_TEMPLATE.md`
2. **Human review** — part of the code review checklist

The domain allowlist closes most of the gap without naming anything: a reference
to a third party product almost always carries a link to that product's site.

### Policy document exemption

Files that describe these prohibitions cannot avoid containing the patterns they
forbid. They declare their own exemption with a marker comment, the gate skips
them, and it **reports how many files were skipped on every run** so the
exemption is never silent. Adding the marker is a deliberate act and is
questioned in review.
