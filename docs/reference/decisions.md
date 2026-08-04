# Decision Log — Founding Decisions

> Last updated: 2026-07-31 — P0.11
> Source: blueprint §23

The six decisions settled at the project's founding. Each is tied to an ADR.

| # | Decision | Outcome | ADR |
|---|---|---|---|
| **A1** | Product name | **Boreas** · repository `boreas-mac-fan-control` · bundle `com.bubiapps.boreas` · CLI `boreas`. The trademark search was done by the project owner; no obstacle was found (2026-08-03) | [0002](../architecture/adr/0002-product-name.md) |
| **A2** | Minimum macOS | **14.0 Sonoma** | [0003](../architecture/adr/0003-minimum-macos-14.md) |
| **A3** | Repository owner | **Personal GitHub account.** It can move to an organization later; GitHub redirects the old URL. The bundle ID does not depend on it | (no architectural impact) |
| **A4** | Developer ID | **Deferred to P8** (2026-08-03 revision). P1–P7 require no signing identity; the decision and the consequences of both paths are in ADR 0019 | [0019](../architecture/adr/0019-signing-identity-deferred.md) |
| **A5** | Test hardware | **Only a Mac mini (M4, 2024) — `Mac16,10`.** A single-fan desktop with no battery | [0011](../architecture/adr/0011-hardware-abstraction.md) |
| **A6** | Language scope | **Interface in 5 languages** (`en` `tr` `ru` `es` `zh-Hans`) · **documentation in English**. Translations are produced within the project and their origins are marked in `TRANSLATORS.md` (2026-08-03 addendum) | [0016](../architecture/adr/0016-language-scope.md) |

## Where the decisions influenced one another

- **A5 → strengthened A1.** A project tested on a single piece of hardware has to be honest; a brand and a README that do not overstate their scope are the only source of trust.
- **A5 → changed the roadmap.** The Mock/Replay infrastructure was pulled forward to P2; mandatory, not "nice to have".
- **A6 → constrained the interface design.** Five languages extended the ban on fixed-size text containers to the width axis as well.
- **A1 → moved discoverability into its own layer.** With a distinctive brand chosen, the keywords were resolved in `docs/release/discoverability.md`.
- **A4 → removed the risk.** Because the certificate is available, an alternative distribution plan was no longer needed.

## Left for the next wave

These are **not** topics awaiting a decision but topics deliberately deferred. They are tracked, with their triggers, in `ARCHITECTURE.md` §12.
