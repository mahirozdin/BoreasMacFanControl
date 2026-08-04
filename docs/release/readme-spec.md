# README Specification

<!-- gate-names:policy-doc — This file DESCRIBES forbidden patterns and is therefore exempt from the gate-names scan. See LEGAL.md §5.1 -->

> Last updated: 2026-07-31 — P0.30
> Source: blueprint §18

The product `README.md` is written in **English** (the authoritative version) and translated into 4 languages → [ADR 0016](../architecture/adr/0016-language-scope.md)

## Required sections — in this order

| # | Section | Content |
|---|---|---|
| 1 | Title + one-sentence definition | Product name, logo, what it does |
| 2 | Badges | Build status, version, licence, supported macOS, architecture |
| 3 | Screenshot / short GIF | Menu bar panel + curve editor; dark and light |
| 4 | Why this project exists | The problem statement. **No third party product name appears** |
| 5 | Feature highlights | 6–10 items, one line each, benefit-focused |
| 6 | **Requirements and tested hardware** | Apple Silicon (M1+), macOS 14.0+. **States explicitly which model it was actually tested on** (R8) |
| 7 | Installation | Homebrew (primary) + DMG. First launch and Gatekeeper steps |
| 8 | Quick start | 3 steps: open → pick a profile → (optionally) enable fan control |
| 9 | **Permissions and why they are needed** | The permissions requested + **the list of those not requested**. The section where user trust is earned — keep it near the top |
| 10 | How it works | 6–8 sentences + a layer diagram |
| 11 | Safety | Dead man's switch, safety chain, narrow daemon surface |
| 12 | Privacy | The zero telemetry commitment, plain and clear |
| 13 | Configuration | File location, a sample fragment, a link to the schema |
| 14 | CLI usage | Command list and examples |
| 15 | Troubleshooting | The 8–10 most common problems; detail in `docs/` |
| 16 | Uninstall | Complete steps + the guarantee that nothing is left behind |
| 17 | Roadmap | Short |
| 18 | Contributing | `CONTRIBUTING.md` + **a call for unknown sensor reports** |
| 19 | FAQ | → `discoverability.md` |
| 20 | Disclaimer | `LEGAL.md` §8 |
| 21 | Licence | Apache-2.0 + `NOTICE` |

## What must not appear

| Must not appear | Why |
|---|---|
| Any third party product name | `LEGAL.md` Y5 |
| "An alternative to X" / "like X but free" | Y6 — comparative marketing risk |
| A comparison table (us vs. them) | Same reasoning |
| Exaggerated performance claims ("40% cooler") | Unprovable; not written without a measurement methodology |
| Donation/sponsorship pressure | Distracts from focus in the first release |
| A long personal story | The README is a technical document |

## Tone

Plain, honest, unexaggerated. **It also says what it cannot do** (e.g. when the hardware turns the fans off, control is not possible).

> Honesty is the strongest marketing in this category.
