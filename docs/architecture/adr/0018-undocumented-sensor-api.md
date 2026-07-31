# 0018 — Dokümante edilmemiş sensör API'sinin kabulü

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §5.1, §21 R1

## Bağlam

Apple Silicon'da sıcaklık sensörlerine erişmenin pratik yolu, HID sensör servisleridir. Bu API **resmî olarak dokümante edilmemiştir** ve macOS güncellemeleriyle değişebilir.

Alternatif yol SMC anahtarlarıdır; o da dokümante edilmemiştir ama farklı bir mekanizmadır — yani ikisinin aynı anda bozulma olasılığı düşüktür.

Önemli ayrım: **dokümante edilmemiş API kullanımı App Store inceleme kuralıdır.** Doğrudan dağıtım + notarizasyon akışını engellemez. Proje App Store'da yayınlanmayacağı için ([0017](0017-distribution-channels.md)) engel oluşturmaz.

## Karar

- Birincil sensör kaynağı: HID sensör servisleri
- **Yedek kaynak:** SMC anahtarları üzerinden okuma
- Her ikisi de `SensorSource` protokolü arkasında ([0011](0011-hardware-abstraction.md))
- Birincil başarısızsa yedeğe geçilir; **ikisi de başarısızsa uygulama izleme moduna düşer, kullanıcıyı bilgilendirir ve asla çökmez**
- Sensör adları **koda gömülmez**, çalışma zamanında keşfedilir
- Eşleşmeyen sensör **gizlenmez**, `uncategorized` grubunda gösterilir ve kullanıcı tek tıkla rapor oluşturabilir

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Yalnızca resmî API kullanmak | Apple, üçüncü taraflara sıcaklık sensörü API'si sunmuyor — ürün mümkün olmazdı |
| Tek kaynağa bağlanmak | Tek bir macOS güncellemesi ürünü tamamen çalışmaz hale getirebilir |
| Sensör listesini koda gömmek | Her yeni çip nesli sürüm çıkmasını gerektirir |

## Sonuçlar

- ✅ İki bağımsız kaynak → tek noktadan bozulma riski düşük
- ✅ Yeni çip nesillerine sürüm çıkmadan uyum
- ✅ Topluluk, bilinmeyen sensörleri raporlayarak katkı verebilir
- ⚠️ macOS güncellemeleri kırılma riski taşır (R1) — sürüm notlarında izlenir
- ⚠️ App Store dağıtımı kalıcı olarak imkânsız (zaten [0017](0017-distribution-channels.md) ile kapsam dışı)

## Zorlama

- `make gate-layers` → sensör erişimi protokol arkasında olmalı; `Live` + `Mock` zorunlu (M2)
- Birim testi: birincil kaynak hata fırlattığında yedeğe geçilir
- Birim testi: her iki kaynak da başarısızken uygulama izleme moduna düşer, çökmez
- `ProcessInfo.thermalState` (resmî API) güvenlik zincirinin K2 katmanında kullanılır — dokümante edilmemiş API'ye bağımlı **değildir**
