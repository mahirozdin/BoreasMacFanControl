# 0017 — Dağıtım kanalları; Mac App Store dışlandı

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §16.3, §16.4

## Bağlam

macOS uygulaması dağıtmanın üç yolu var: Mac App Store, doğrudan dağıtım (imzalı + notarize), paket yöneticisi.

Kritik kısıt: **App Store sandbox'ı ayrıcalıklı LaunchDaemon kurulumuna izin vermiyor.** Bu teknik bir imkânsızlık, tercih değil.

## Karar

| Kanal | Durum |
|---|---|
| **Homebrew Cask** (`brew install --cask boreas`) | **Birincil** — kurulum ve güncellemenin en kolay yolu |
| **GitHub Releases** (imzalı, notarize DMG + SHA-256) | **Birincil** |
| Sparkle ile uygulama içi güncelleme | Ertelendi (v1.1) — Homebrew'un yeterliliği ölçülecek |
| **Mac App Store** | ❌ **Teknik olarak imkânsız** |

İmzalama zinciri: Developer ID Application sertifikası ile uygulama + daemon + CLI **ayrı ayrı** imzalanır → Hardened Runtime → `notarytool` → `stapler`. Notarizasyon başarısız olursa **sürüm yayınlanmaz**; CI bu adımda kırılır.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| App Store | Sandbox ayrıcalıklı daemon'a izin vermiyor — imkânsız |
| Yalnızca "kaynaktan derle" | Hedef kitleyi geliştiricilerle sınırlar; Developer ID mevcut olduğu için gereksiz |
| İmzasız DMG | Gatekeeper uyarısı, güvenilmez daemon kaydı, zayıf XPC imza doğrulaması |

## Sonuçlar

- ✅ Tek komutla kurulum ve güncelleme
- ✅ Gatekeeper uyarısı yok
- ✅ XPC imza doğrulaması gerçek Team ID ile çalışır
- ⚠️ App Store keşfedilebilirliği yok → [0002](0002-product-name.md) ve `docs/release/discoverability.md` bunu telafi eder
- ⚠️ Apple Developer Program üyeliği yıllık maliyet

## Zorlama

- CI release job'ı: notarizasyon başarısızsa sürüm üretilmez
- `.gitignore` → `*.p12`, `*.p8`, `*.provisionprofile` asla commit edilmez
- `BOOT.md` sağlık snapshot'ı → depoda imzalama materyali varsa uyarı
