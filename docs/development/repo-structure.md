# Depo Yapısı

> Son güncelleme: 2026-07-31 — P0.23
> Kaynak: blueprint §17, §19 · Karar: [ADR 0012](../architecture/adr/0012-core-layer-purity.md)

## Hangi kod nereye

| Dizin | İçerik | Bağımlılık kuralı |
|---|---|---|
| `Packages/Core/` | Modeller, kontrol motoru, yapılandırma, telemetri biçimlendirme | **Yalnızca Foundation** |
| `Packages/HardwareKit/` | IOKit sarmalayıcıları, protokoller, `Live`/`Mock`/`Replay`, sensör keşfi | `Core` (yalnızca model tipleri) |
| `Packages/SharedIPC/` | XPC protokol tanımları (App + Daemon ortak) | — |
| `App/` | SwiftUI arayüz, menü çubuğu, eğri editörü, ayarlar, tasarım sistemi | `Core`, `HardwareKit`, `SharedIPC` |
| `Daemon/` | Ayrıcalıklı yardımcı: XPC dinleyici, SMC yazıcı, güvenlik, watchdog | `HardwareKit` (yazma yüzeyi), `SharedIPC` |
| `CLI/` | `boreas` komut satırı aracı | `Core`, `HardwareKit`, `SharedIPC` |
| `Widget/` | WidgetKit (sonraki dalga) | `Core` |
| `schema/` | `config.schema.json` | — |
| `scripts/` | Kapılar (`gates/`), bootstrap, imzalama, DMG, yeniden adlandırma | — |
| `Tests/` | Altın dosya senaryoları, UI testleri | — |
| `docs/` | Bu dokümantasyon | — |

## Bağlayıcı kurallar

**`Core` asla IOKit'e, SwiftUI'ya veya AppKit'e bağlanmaz.** Bu kural, motorun CI'da donanımsız test edilebilmesinin tek garantisidir ve `make gate-layers` ile zorlanır.

**`.xcodeproj` commit edilmez** — `project.yml`'den üretilir (T5).

## Ürün deposu dosyaları

Bunlar **iş kalemidir**, `TODO.md`'de takip edilir:

| Dosya | Faz | İçerik |
|---|---|---|
| `LICENSE` | P1 | Apache-2.0 tam metni (kanonik kaynaktan indirilir) |
| `NOTICE` | P1 | Telif bildirimi, atıflar, teşekkürler |
| `README.md` + 4 çeviri | P8 | `docs/release/readme-spec.md`'ye göre |
| `CONTRIBUTING.md` | P1 | Kurulum, stil, PR süreci, **bağımsız geliştirme beyanı** |
| `CODE_OF_CONDUCT.md` | P1 | Contributor Covenant 2.1 |
| `TRANSLATORS.md` | P7 | Dil başına sorumlu katkıcılar |
| `CHANGELOG.md` | P1 | Keep a Changelog formatı |
| `.github/PULL_REQUEST_TEMPLATE.md` | P1 | Beyan onay kutuları + test kontrol listesi |
| `.github/ISSUE_TEMPLATE/` | P1 | Hata, özellik, **bilinmeyen sensör raporu** |
| `.github/workflows/` | P1 | CI + release |

## Ürün adını değiştirme

`scripts/rename-product.sh` (P1) ürün adını, bundle kimliğini, daemon etiketini ve yerelleştirme dizelerini tek komutla günceller. Ad kod tabanına gömülmez.
