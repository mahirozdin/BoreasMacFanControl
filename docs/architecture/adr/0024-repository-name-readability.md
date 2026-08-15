# 0024 — The repository name is read before it is searched

<!-- gate-names:policy-doc — This file discusses naming policy and quotes the
     repository's own identifiers. See LEGAL.md §5.1 -->

- **Status:** Accepted
- **Date:** 2026-08-15
- **Amends:** [0002](0002-product-name.md) · the layer map in [`../../release/discoverability.md`](../../release/discoverability.md)

## Context

[`discoverability.md`](../../release/discoverability.md) fixed the repository
name at `boreas-mac-fan-control` and gave the reason in one line: *"Words in the
URL are a strong signal; both brand and keywords."* That is true, and it was the
right call for a repository nobody had looked at yet.

It was chosen without anyone having read it on the page. The project owner did,
after v0.1.0 shipped, and the objection is not about search: `mahirozdin /
boreas-mac-fan-control` reads as a slug rather than as a name. Hyphenated
lowercase is the convention of package identifiers, and this is the line at the
top of the product's own home page.

GitHub constrains the options more than it first appears. A repository name
cannot contain a space — one typed is converted to a hyphen — so
`Boreas Mac Fan Control`, which is what the name actually is, cannot exist as a
repository name. The choice is between hyphens, run-together words, and a single
word.

## Decision

**The repository is `BoreasMacFanControl`.**

Every keyword stays in the name. The words are separated by capitals rather than
by hyphens, which is the only separation GitHub allows other than a hyphen.

**This costs discoverability, deliberately, and the cost should not be
understated in the record.** A hyphen is an unambiguous word separator to both
GitHub's index and to search engines; a capital letter is not reliably treated
as one. The name will match the phrase *mac fan control* less well than it did.

Three things carry that weight instead, and all three are already in place:

| Layer | Value |
|---|---|
| Repository description | Carries the keywords in prose |
| Topics | `mac-fan-control`, `fan-control`, `apple-silicon` and 17 more — at GitHub's maximum of 20 |
| README `<h1>`, tagline and first paragraph | The text a search result actually shows |

The judgement is that the name is read by a human deciding whether to care, and
found by an index that has four other places to look. Where those two pull
apart, this decision favours the human.

## Consequences

- The previous name redirects. GitHub keeps `boreas-mac-fan-control` pointing
  here for the web, for `git`, and for release asset downloads, so **the v0.1.0
  and v0.1.1 assets keep resolving** and no existing clone breaks.
- **A redirect is not a guarantee.** It survives only while nobody creates a
  repository under the old name. Nothing in this project can prevent that, which
  is why every reference inside the repository is rewritten rather than left to
  the redirect.
- The Homebrew cask's `url`, `verified` and `homepage` are regenerated. The
  cask token stays `boreas`: it is the product, not the repository.
- `discoverability.md` records the change in its "As shipped" table, so the
  layer map and reality do not drift apart again.

## Enforcement

None, and that is a deliberate answer rather than an omission. A gate could
check that no file mentions the old name — but the old name legitimately
appears in this ADR, in the run log entries that record the change, and in the
frozen blueprint, so such a gate would spend its life maintaining an exception
list longer than the rule.

What is checkable is already checked elsewhere: `make docs-check` fails on a
broken link, which is how a missed reference surfaces.
