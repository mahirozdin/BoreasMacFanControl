# Derleme, İmzalama ve Dağıtım

> Son güncelleme: 2026-07-31 — P0.29
> Kaynak: blueprint §16 · Karar: [ADR 0017](../architecture/adr/0017-distribution-channels.md)

## Yerel derleme

```bash
make bootstrap
make generate
make build
```

## İmzalama zinciri

1. **Developer ID Application** sertifikası ile imzalama — uygulama, daemon ve CLI **ayrı ayrı**
2. **Hardened Runtime** açık; entitlement'lar minimumda
3. `notarytool` ile notarizasyon
4. `stapler` ile bilet ekleme

**Notarizasyon başarısız olursa sürüm yayınlanmaz** — CI bu adımda kırılır.

Gizli değerler (sertifika, API anahtarı) GitHub Actions secrets üzerinden gelir. **Anahtarlar repoya asla girmez** — `.gitignore` ve `BOOT.md` sağlık snapshot'ı bunu denetler.

## Dağıtım kanalları

| Kanal | Öncelik |
|---|---|
| **Homebrew Cask** (`brew install --cask boreas`) | Birincil |
| **GitHub Releases** (imzalı, notarize DMG + SHA-256) | Birincil |
| Sparkle uygulama içi güncelleme | Ertelendi (`ARCHITECTURE.md` §12) |
| Mac App Store | ❌ Sandbox ayrıcalıklı daemon'a izin vermiyor |

## Sürümleme

- **Semantic Versioning** (`MAJOR.MINOR.PATCH`)
- `CHANGELOG.md` — Keep a Changelog formatı
- Etiketler: `v1.0.0`
- **Yapılandırma şeması ayrı sürümlenir**; şema kırılması MAJOR gerektirir

## Sürüm kapıları

`ARCHITECTURE.md` §10'daki tüm kapılar yeşil olmadan sürüm çıkmaz. Özetle: tüm invariant testleri · `Core` kapsamı ≥ %85 · `make check` yeşil · `kill -9` ve uyku duman testleri gerçek donanımda · notarizasyon · 5 dil eksiksiz + pseudo-locale testi · README "test edilen donanım" bölümü dürüst.
