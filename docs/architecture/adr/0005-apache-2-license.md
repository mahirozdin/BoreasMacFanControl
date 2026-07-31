# 0005 — Apache License 2.0

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §2.5, §2.6

## Bağlam

Proje ücretsiz ve açık kaynak olacak. Donanım kontrolü, patent iddiası riski taşıyabilecek bir alan. Ayrıca katkıcılardan gelen kodun da aynı korumayı taşıması gerekiyor.

## Karar

**Apache License 2.0.**

İzinli bağımlılık lisansları: MIT, BSD (2/3-clause), Apache-2.0, ISC.
**Yasaklı:** GPL, LGPL, AGPL, SSPL, ticari/tescilli.

Her bağımlılık ve fikir alınan proje `NOTICE` dosyasına yazılır.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| **MIT** | En basit ve yaygın, ama **patent hibesi yok**. Donanım kontrolü alanında bu boşluk hem projeyi hem kullanıcıyı savunmasız bırakır |
| **GPL-3.0** | Türev işlerin açık kalmasını zorlar ama kurumsal benimsemeyi engeller ve yayılımı sınırlar |

## Sonuçlar

- ✅ Açık patent hibesi (§3) — projeyi ve kullanıcıyı korur
- ✅ Katkıcılardan da patent hibesi alınır
- ✅ Ticari kullanıma açık → daha geniş benimseme
- ✅ `NOTICE` mekanizması atıf yönetimini standartlaştırır
- ⚠️ GPL lisanslı hiçbir kod kullanılamaz — bazı mevcut açık kaynak referanslar dışarıda kalır

## Zorlama

- `make gate-deps` → yasaklı lisans metni veya SPDX tanımlayıcısı bulunursa kırmızı
- `make gate-deps` → bağımlılık varsa `NOTICE` dosyası zorunlu
- `LICENSE` dosyası depo kökünde
