<!-- gate-names:policy-doc — This file DESCRIBES forbidden patterns and is
     therefore exempt from the gate-names scan. See section 5.1 below. -->

# LEGAL.md — Independent Development and Legal Boundaries

> Last updated: 2026-08-04 — ADR 0021
> Source: blueprint section 2
> **Read every session.** Breaking this stops the project.
> **This is not legal advice.** Consult a lawyer before a public release.

---

## 1. The position

This project is **independent work**. Other software solves the same problem;
that is normal and lawful.

Copyright protects **expression**, not ideas, functions or the problem being
solved:

| Category | Example | Protected? |
|---|---|---|
| **Idea** | "Adjust fan speed based on temperature" | No — free to implement |
| **Function** | "Show temperatures in the menu bar" | No — free to implement |
| **Expression** | Specific interface text, icon set, help content, source code, data tables | Yes — cannot be copied |

The project's safety comes from applying that distinction **with discipline**.

---

## 2. Absolute prohibitions

Breaking one of these means the contribution is rejected, and history is
rewritten if necessary.

| # | Prohibition | Why |
|---|---|---|
| **Y1** | Reverse engineering, disassembling or decompiling any third party commercial application | The heaviest class of claim, and usually a licence breach as well |
| **Y2** | Copying **or translating** text, labels, help content, error messages, marketing copy or documentation from another product | A translation is a derivative work |
| **Y3** | Imitating another product's icons, colour palette, window layout or visual identity | Trade dress exposure |
| **Y4** | Reusing another product's configuration schema, key names or data format verbatim | Reads as structural copying |
| **Y5** | **Writing any third party commercial product name** in the repository, commit messages, issues, code, comments or documentation | See below |
| **Y6** | Comparative marketing of the "an alternative to X" or "better than X" kind | Trademark and unfair competition exposure |
| **Y7** | Including code under an incompatible licence (GPL, LGPL, AGPL) | Incompatible with Apache-2.0; contaminates the whole project |

### Why Y5 is this strict

A commit, issue or comment naming a competitor — **however innocent** — becomes
evidence for the claim that "the developer knew that product and worked from
it". Intent does not matter; the record is permanent and git history is not
erased.

**Use these instead:**

- *"commercial equivalents"*
- *"closed source alternatives"*
- *"other tools in this category"*
- *"existing solutions"*

If a specific behaviour needs describing, describe the **behaviour, not its
source**. Never "product X uses a ten second ramp"; instead, "a gradual ramp is
a common approach, and it is preferred here because ...".

---

## 3. What is permitted

| Source | Scope |
|---|---|
| Apple's official documentation | IOKit, ServiceManagement, HIDDriverKit, Human Interface Guidelines |
| Apple SDK public headers | Public headers |
| Compatibly licensed open source | MIT, BSD, Apache-2.0 — **attribution required** in `NOTICE` |
| Public technical knowledge | SMC key naming conventions, IOKit service names |
| Our own measurements | Sensor discovery, log analysis and thermal tests on our own hardware |
| Academic and engineering literature | Control theory, hysteresis, PID, thermal modelling |

---

## 4. Independent development declaration

Confirmed on every pull request, embedded in
`.github/PULL_REQUEST_TEMPLATE.md`:

```
[ ] The code and text in this contribution are my own, or derived from
    compatibly licensed work credited in NOTICE.
[ ] I did not reverse engineer, disassemble or decompile any commercial
    software while preparing this contribution.
[ ] No third party commercial product name appears in this contribution.
```

---

## 5. How this is enforced

Why Y5 and Y6 **cannot** be fully automated, and what covers the gap.

### 5.1 The automated layer — `make gate-names`

| Check | What it catches |
|---|---|
| **Comparative marketing patterns** | Generic constructions such as "alternative to", "better than", "replacement for" |
| **External domain allowlist** | Every URL in the repository is checked against a permitted list; anything else requires human review |
| **Trademark symbols** | The registered and trademark signs, which mark a third party reference |
| **Local name list** (optional) | `scripts/gates/.forbidden-names.local` if present — **this file is in `.gitignore`** |

#### Policy document exemption

Files that **describe** the forbidden patterns — this one, the README
specification, the relevant decision records — inevitably produce false
positives. They declare their own exemption with a marker comment, which is
visible at the top of this file.

The gate skips files carrying that marker and **reports how many were skipped
every time it runs**, so the exemption is never silent.

A marker is preferred over a hard coded file list because the file declares its
own exemption, that declaration is visible in review, and a hard coded list goes
stale.

**Adding the marker is a deliberate act and is questioned in review.** It cannot
be used to hide a real violation.

### 5.2 Why no name list is stored

Keeping a list of forbidden product names in a file would **break the rule
itself** — those names would then be in the repository. This is an unavoidable
consequence of Y5.

Instead:

- The automated layer uses **generic patterns** and a **domain allowlist**,
  neither of which needs a name
- A developer may keep a local, git ignored list, which works locally and is
  absent in CI
- The remaining gap is covered by **human review** and the **pull request
  declaration**

### 5.3 The licence layer — `make gate-deps`

When a dependency is added its licence is checked. GPL, LGPL, AGPL or SSPL turns
the gate red.

---

## 6. Licensing

| Topic | Decision |
|---|---|
| Project licence | **Apache-2.0** — explicit patent grant, patent grant from contributors, open to commercial use |
| Permitted dependency licences | MIT, BSD (2 and 3 clause), Apache-2.0, ISC |
| Forbidden dependency licences | GPL, LGPL, AGPL, SSPL, proprietary |
| Attribution file | `NOTICE` — project name, version, licence, URL, and what it is used for |
| Projects that informed the design | Listed under Acknowledgements in `NOTICE`. **Transparency is the strongest evidence of good faith** |

Details: [ADR 0005](docs/architecture/adr/0005-apache-2-license.md)

---

## 7. Trademarks

| Topic | Position |
|---|---|
| Product name | **Boreas** — the Greek god of the north wind |
| Use of Apple trademarks | Only as a qualifier. "Boreas for Mac" is acceptable; using an Apple mark as a prefix is not |
| Relationship to Apple | Stated in the README and in the application: not affiliated with, authorised by or endorsed by Apple Inc. |

---

## 8. Disclaimer

Present in the README and on first launch, **written in our own words**:

- The software is provided as is, without warranty
- Lowering fan speeds increases thermal risk, and the responsibility is the
  user's
- The project is not affiliated with or endorsed by Apple Inc.
- Any effect on hardware warranty is the user's responsibility

---

## 9. When in doubt

If you are unsure whether a contribution stays inside these boundaries:

1. **Do not proceed.** Stop.
2. Describe the doubt in an issue, without naming any product.
3. Wait for the project owner's decision.

Reverting a questionable contribution costs far more than never taking it.
