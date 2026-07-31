# Karar Kaydı — Açılış Kararları

> Son güncelleme: 2026-07-31 — P0.11
> Kaynak: blueprint §23

Projenin açılışında kesinleşen altı karar. Her biri bir ADR'ye bağlıdır.

| # | Karar | Sonuç | ADR |
|---|---|---|---|
| **A1** | Ürün adı | **Boreas** · depo `boreas-mac-fan-control` · bundle `com.bubiapps.boreas` · CLI `boreas` | [0002](../architecture/adr/0002-product-name.md) |
| **A2** | Minimum macOS | **14.0 Sonoma** | [0003](../architecture/adr/0003-minimum-macos-14.md) |
| **A3** | Depo sahibi | **Kişisel GitHub hesabı.** İleride organizasyona taşınabilir; GitHub eski URL'i yönlendirir. Bundle ID buna bağlı değil | (mimari etkisi yok) |
| **A4** | Developer ID | **Mevcut, aktif üyelik.** İmzalama + notarizasyon + Homebrew cask zinciri planlandığı gibi | [0017](../architecture/adr/0017-distribution-channels.md) |
| **A5** | Test donanımı | **Yalnızca Mac mini (M4, 2024) — `Mac16,10`.** Tek fanlı, pilsiz masaüstü | [0011](../architecture/adr/0011-hardware-abstraction.md) |
| **A6** | Dil kapsamı | **Arayüz 5 dil** (`en` `tr` `ru` `es` `zh-Hans`) · **dokümantasyon İngilizce** | [0016](../architecture/adr/0016-language-scope.md) |

## Kararların birbirini etkilediği noktalar

- **A5 → A1'i güçlendirdi.** Tek donanımda test edilen bir projenin dürüst olması gerekir; kapsamı abartmayan bir marka ve README güvenin tek kaynağıdır.
- **A5 → yol haritasını değiştirdi.** Mock/Replay altyapısı P2'ye çekildi; "iyi olurdu" değil zorunlu.
- **A6 → arayüz tasarımını bağladı.** Beş dil, sabit boyutlu metin kabı yasağını genişlik eksenine de taşıdı.
- **A1 → keşfedilebilirliği ayrı katmana taşıdı.** Ayırt edici marka seçilince anahtar kelimeler `docs/release/discoverability.md`'de çözüldü.
- **A4 → riski kaldırdı.** Sertifika mevcut olduğu için alternatif dağıtım planına gerek kalmadı.

## Sonraki dalgaya bırakılanlar

Karar bekleyen konular **değil**, bilinçli olarak ertelenmiş konular. Tetikleyicileriyle birlikte `ARCHITECTURE.md` §12'de izlenir.
