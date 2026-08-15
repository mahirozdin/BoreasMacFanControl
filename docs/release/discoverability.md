# Discoverability

<!-- gate-names:policy-doc — This file DESCRIBES forbidden patterns and is therefore exempt from the gate-names scan. See LEGAL.md §5.1 -->

> Last updated: 2026-08-12 — P8.07
> Source: blueprint §18.4 · Decision: [ADR 0002](../architecture/adr/0002-product-name.md)

## Principle

**The brand name and the search keywords do not have to be the same thing.**

The product name `Boreas` carries the brand; the keywords are carried by the layers outside the name. This separation is how a distinctive brand and high discoverability are achieved at the same time.

## Layer map

| Layer | Value | Why it matters |
|---|---|---|
| **Repository name** | `BoreasMacFanControl` | Both brand and keywords. **The separator changed in [ADR 0024](../architecture/adr/0024-repository-name-readability.md)** and the trade is recorded there: a hyphen is an unambiguous word separator to an index and a capital letter is not, so this name matches *mac fan control* less well than the hyphenated one did. The name is what a human reads at the top of the page; the four layers below are what an index reads |
| **Repository description** | *"Free, open-source Mac fan control and temperature monitoring for Apple Silicon (M1–M5). Native menu bar app — no kernel extension, no SIP changes."* | **The most critical field.** What search engines use as the meta description |
| **GitHub topics** | `mac-fan-control` `fan-control` `macos` `apple-silicon` `temperature-monitor` `thermal` `menu-bar` `swift` `swiftui` `m1` `m2` `m3` `m4` `macos-app` `system-monitor` | Topic pages are an organic traffic source in their own right |
| **README `<h1>` + tagline** | `# Boreas` → *Mac Fan Control & Temperature Monitoring for Apple Silicon* | The title shown in a search result |
| **README first paragraph** | 2–3 sentences containing the keywords naturally | The text pulled as a snippet |
| **Homebrew cask `desc`** | A single line carrying the keywords | Shown in `brew search` results |
| **Release titles** | Version + a short feature summary | Release pages are indexed in their own right |
| **README translations** | `tr` `ru` `es` `zh-Hans` | Reach for users who search in their own language |

## Target search intents

The phrases people actually type. The README content must serve them **naturally**:

- `mac fan control` · `macbook fan control` · `apple silicon fan control`
- `mac temperature monitor` · `m4 mac temperature`
- `macbook running hot` · `mac fan always on` · `mac fan noise`
- `free mac fan control app` · `open source mac fan control`
- `control mac mini fan speed`

## README FAQ section

At the end of the README goes a short question-and-answer section that hosts these phrases naturally, **because it is genuinely useful**:

- *"Why is my Mac running hot?"*
- *"Can I control fan speed on Apple Silicon Macs?"*
- *"Does this require disabling SIP or installing a kernel extension?"* → **No** (also the strongest selling point)
- *"Is it safe to lower fan speeds?"*
- *"What happens if the app crashes?"*

This section does two jobs at once: it answers the user's real question and earns search visibility.

## What not to do

| Don't | Why |
|---|---|
| Keyword stuffing | It backfires; it feels fake and erodes trust |
| Using a third party product name as a keyword | `LEGAL.md` Y5/Y6 — **an absolute ban** |
| Misleading topic labels | Penalized by the platform |
| Artificial stars / fake engagement | Risk of account termination, loss of reputation |
| Unmeasurable performance claims | An unevidenced statement |

---

## As shipped (P8.07)

Verified against the live repository rather than asserted. Every row was checked
with `gh repo view`; nothing in the layer map needed changing, because **M02
already set the description and the topics** when the repository was created.

| Layer | State |
|---|---|
| Repository name | `BoreasMacFanControl` — **changed 2026-08-15**, [ADR 0024](../architecture/adr/0024-repository-name-readability.md). Was `boreas-mac-fan-control` as specified, until the name was read on the page rather than reasoned about |
| Repository description | Matches, with `SwiftUI` and `no telemetry` added. Both are true and both are searched for |
| GitHub topics | **All 15 specified topics present**, plus `hardware-monitoring`, `cpu-temperature`, `fan-speed`, `open-source`, `swift6`. That is **20, which is GitHub's maximum** — adding one now means removing one |
| README `<h1>` + tagline | As specified |
| README first paragraph | The tagline and "Free and open source…" sit above the badges, so the keyword-bearing sentences are the first prose on the page |
| Homebrew cask `desc` | Written below; the cask itself is P8.08, blocked on M05 |
| Release titles | P8.04, blocked on M03/M04 |
| README translations | Four, shipped in P8.06 |

### The Homebrew cask description

Homebrew's own style rules apply: no leading article, no product name, no
trailing full stop, and it has to read as a phrase rather than a sentence.

```ruby
desc "Fan control and temperature monitoring for Apple Silicon Macs"
```

61 characters. It carries *fan control*, *temperature monitoring*, *Apple
Silicon* and *Mac* without repeating any of them, which is the whole job of a
line shown in `brew search` output.

### The one gap this task found, and what it was not

Checking the target search intents against the README literally showed only one
of six phrases present as written. **That is the wrong test** — this document's
own "What not to do" table forbids keyword stuffing, and four of the five
missing phrases are served in meaning by wording already there.

One was a real gap: **the README never used the word "MacBook"**, in any
language. `macbook fan control` and `macbook running hot` are both listed target
intents, and more to the point a laptop owner scanning the page could not find
their machine. The remedy is a paragraph that says something true and useful —
every measurement in the project comes from a desktop Mac, a laptop has less
thermal headroom and throttles sooner, and a MacBook sensor report would be
genuinely valuable — rather than the phrase dropped in for its own sake. It was
added to all five READMEs, so the translations did not drift on the day after
they were written.
