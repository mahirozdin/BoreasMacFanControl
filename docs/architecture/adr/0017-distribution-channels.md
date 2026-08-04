# 0017 — Distribution channels; Mac App Store excluded

- **Status:** Accepted
- **Date:** 2026-07-31
- **Source:** blueprint §16.3, §16.4

## Context

There are three ways to distribute a macOS application: the Mac App Store, direct distribution (signed + notarized), and a package manager.

The critical constraint: **the App Store sandbox does not allow installing a privileged LaunchDaemon.** This is a technical impossibility, not a preference.

## Decision

| Channel | Status |
|---|---|
| **Homebrew Cask** (`brew install --cask boreas`) | **Primary** — the easiest way to install and update |
| **GitHub Releases** (signed, notarized DMG + SHA-256) | **Primary** |
| In-app updates via Sparkle | Deferred (v1.1) — whether Homebrew suffices will be measured |
| **Mac App Store** | ❌ **Technically impossible** |

The signing chain: with the Developer ID Application certificate, the app + the daemon + the CLI are signed **separately** → Hardened Runtime → `notarytool` → `stapler`. If notarization fails, **no release is published**; CI breaks at this step.

## Alternatives

| Option | Why not |
|---|---|
| App Store | The sandbox does not allow a privileged daemon — impossible |
| "Build from source" only | Limits the audience to developers; unnecessary since a Developer ID is available |
| An unsigned DMG | Gatekeeper warnings, untrusted daemon registration, weak XPC signature verification |

## Consequences

- ✅ Install and update with a single command
- ✅ No Gatekeeper warning
- ✅ XPC signature verification works with the real Team ID
- ⚠️ No App Store discoverability → [0002](0002-product-name.md) and `docs/release/discoverability.md` compensate
- ⚠️ Apple Developer Program membership is a yearly cost

## Enforcement

- The CI release job: if notarization fails, no release is produced
- `.gitignore` → `*.p12`, `*.p8`, `*.provisionprofile` are never committed
- The `BOOT.md` health snapshot → warns if signing material is present in the repository
