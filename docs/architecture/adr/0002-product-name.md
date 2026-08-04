# 0002 — Product name: Boreas

<!-- gate-names:policy-doc — This file is exempt from the gate-names scan because it DESCRIBES the forbidden patterns. See LEGAL.md §5.1 -->

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §2.8, §23 A1

## Context

The product needs a name that is distinctive, legally safe and suited to international use. There are two separate constraints: (1) it must not be confused with existing products, (2) Apple's trademark guidelines advise against using Apple trademarks as a **prefix** in third party product names.

On top of that there is a discoverability concern: users must be able to find the product in search engines.

## Decision

The product name is **Boreas** — in Greek mythology, the god of the north wind, bringer of winter's cold air.

| Field | Value |
|---|---|
| Product name | Boreas |
| Repository | `boreas-mac-fan-control` |
| Bundle ID | `com.bubiapps.boreas` |
| Daemon | `com.bubiapps.boreas.fanhelper` |
| CLI | `boreas` |
| Homebrew cask | `boreas` |

**Brand and discoverability are separated:** the name carries the brand; keywords are carried by the repository name, the repository description, the topic tags and the first screen of the README.

## Alternatives

| Candidate | Why not chosen |
|---|---|
| A name prefixed with an Apple trademark | Contrary to Apple's trademark guidelines; could force a rename later |
| Imbat / Poyraz | Highly distinctive, but weak in international pronunciation and memorability |
| A generic name made of keywords | Cannot be protected as a brand, not distinctive |

## Consequences

- ✅ The Apple trademark rule risk is gone
- ✅ Easy international pronunciation and spelling
- ⚠️ The name carries no keywords by itself → discoverability must be solved in a separate layer ([0016](0016-language-scope.md) and `docs/release/discoverability.md`)
- ⚠️ The trademark registration search is still pending (manual task M01)

## Enforcement

- The name is never embedded in code; it appears only in `project.yml` variables and the localisation catalogue
- One command renaming via `scripts/rename-product.sh` (to be written in P1)
- `make gate-names` → scans for trademark symbols (™/®)
