# 0004 — Yalnızca Apple Silicon (arm64)

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §8.4

## Bağlam

Intel ve Apple Silicon Mac'ler farklı SMC semantiği, farklı sensör topolojisi ve farklı throttling davranışına sahip. Intel desteği kod tabanını ikiye, test yüzeyini üçe katlıyor.

## Karar

**Yalnızca arm64.** Intel kod yolu yazılmaz. Universal binary üretilmez.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Universal binary (Intel + arm64) | İki ayrı SMC erişim katmanı, iki ayrı sensör haritalama stratejisi, iki ayrı throttling davranışı. Tek geliştiricili bir projede sürdürülemez |
| Önce Intel, sonra Apple Silicon | Geliştirme donanımı Apple Silicon; Intel'de doğrulanamayan kod yazmak anlamsız |

## Sonuçlar

- ✅ Tek sensör keşif stratejisi, tek SMC katmanı
- ✅ Test yüzeyi yönetilebilir
- ⚠️ Intel Mac kullanıcıları hedef kitle dışında — README'de açıkça yazılır
- ⚠️ Karar geri alınırsa `HardwareKit` içinde ikinci bir `Live` uygulaması gerekir; protokol soyutlaması bunu mümkün kılıyor ([0011](0011-hardware-abstraction.md))

## Zorlama

- `project.yml` → `ARCHS: arm64`
- README "Gereksinimler" bölümü
- CI arm64 koşucuda derler
