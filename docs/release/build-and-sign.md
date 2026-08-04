# Build, Signing and Distribution

> Last updated: 2026-07-31 — P0.29
> Source: blueprint §16 · Decision: [ADR 0017](../architecture/adr/0017-distribution-channels.md)

## Local build

```bash
make bootstrap
make generate
make build
```

## Signing chain

1. Signing with the **Developer ID Application** certificate — the application, the daemon and the CLI **each separately**
2. **Hardened Runtime** on; entitlements kept to the minimum
3. Notarization with `notarytool`
4. Ticket stapling with `stapler`

**If notarization fails, the release is not published** — CI breaks at this step.

Secret values (the certificate, the API key) come in through GitHub Actions secrets. **Keys never enter the repository** — `.gitignore` and the `BOOT.md` health snapshot check for this.

## Distribution channels

| Channel | Priority |
|---|---|
| **Homebrew Cask** (`brew install --cask boreas`) | Primary |
| **GitHub Releases** (signed, notarized DMG + SHA-256) | Primary |
| Sparkle in-app updates | Deferred (`ARCHITECTURE.md` §12) |
| Mac App Store | ❌ The sandbox does not allow a privileged daemon |

## Versioning

- **Semantic Versioning** (`MAJOR.MINOR.PATCH`)
- `CHANGELOG.md` — Keep a Changelog format
- Tags: `v1.0.0`
- **The configuration schema is versioned separately**; a schema break requires MAJOR

## Release gates

No release ships until every gate in `ARCHITECTURE.md` §10 is green. In short: all invariant tests · `Core` coverage ≥ 85% · `make check` green · the `kill -9` and sleep smoke tests on real hardware · notarization · 5 languages complete + the pseudo-locale test · an honest README "tested hardware" section.
