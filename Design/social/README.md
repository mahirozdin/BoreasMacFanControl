# Boreas — Social Preview

> Last updated: 2026-08-15 — P9.02
> Source: `scripts/make-social-card.sh` · Related: [`discoverability.md`](../../docs/release/discoverability.md)

## What this is

`social-card.png` — 1280×640 — is the picture GitHub attaches to the
repository's link. It is what a reader sees before they see the repository:
in a chat client, a forum post, a search result preview, a shared message.

Until P9.02 there was none. `openGraphImageUrl` was `null`, and every share of
this project rendered GitHub's generic card.

## Uploading it

**By hand, and there is no way around that.** GitHub's REST API has no endpoint
for the social preview. It is set in one place:

> Repository → **Settings** → **General** → **Social preview** → *Upload an image*

Tracked as manual task **M10** in [`TODO.md`](../../TODO.md). Re-upload after any
change to the file — GitHub stores a copy, so editing the file in the repository
does not update the card.

## What is on it, and why

| Element | Reason |
|---|---|
| Icon and the name | The two things that survive when the card is rendered small |
| One line of what it is | The same words as the repository description, so the card and the search snippet agree |
| Three chips | *No kernel extension · No SIP changes · No telemetry*. Phrased as what is **not** asked for, because that is the first question about a tool that writes to hardware |
| The interface, bleeding off two edges | A card showing only a logo says a project exists. One showing the product says what it is |
| Licence and platform | Answers "can I use this" without a click |

The panel picture runs off the right **and** the bottom on purpose. The first
version cleared the right edge and stopped a few pixels short of the bottom,
which read as a picture cut by accident — the word "Quit" sliced in half — not
as a window continuing past the card.

## Regenerating

```bash
make social-card
```

Needs `imagemagick`, which is a development tool and not a build dependency: the
output is committed, so nothing in a build or on a CI runner needs it.
