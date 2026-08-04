# Discoverability

<!-- gate-names:policy-doc — This file DESCRIBES forbidden patterns and is therefore exempt from the gate-names scan. See LEGAL.md §5.1 -->

> Last updated: 2026-07-31 — P0.31
> Source: blueprint §18.4 · Decision: [ADR 0002](../architecture/adr/0002-product-name.md)

## Principle

**The brand name and the search keywords do not have to be the same thing.**

The product name `Boreas` carries the brand; the keywords are carried by the layers outside the name. This separation is how a distinctive brand and high discoverability are achieved at the same time.

## Layer map

| Layer | Value | Why it matters |
|---|---|---|
| **Repository name** | `boreas-mac-fan-control` | Words in the URL are a strong signal; both brand and keywords |
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
