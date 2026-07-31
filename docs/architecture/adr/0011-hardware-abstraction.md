# 0011 — Donanım soyutlaması: Live / Mock / Replay

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §5.4, §15.4, §23 A5

## Bağlam

Geliştirme donanımı **tek bir modeldir**: Mac mini (M4, 2024) — tek fanlı, pilsiz masaüstü. Şu kod yolları gerçek donanımda **hiç doğrulanamaz**: fansız model davranışı, çok fanlı arbitraj, pil/güç kaynağı tetikleyicileri, pil sağlığı tanılaması, M1/M2/M3 sensör adlandırması.

Donanım kontrolü projelerinin kronik problemi budur: "test edemediğim N farklı model".

## Karar

Tüm donanım erişimi protokol arkasına alınır:

```
protocol SensorSource   { func snapshot() async throws -> [SensorReading] }
protocol FanSource      { func fans() async throws -> [FanState] }
protocol FanActuator    { func apply(_:) async throws; func releaseToFirmware() async throws }
protocol PowerSource    { func current() -> PowerContext }
```

Her protokolün **üç** uygulaması olur:

| Uygulama | Amaç |
|---|---|
| `Live` | Gerçek donanım |
| `Mock` | Deterministik, senaryo dosyasından beslenen sahte donanım |
| `Replay` | Kaydedilmiş bir log dosyasını yeniden oynatan kaynak |

**`Replay` kritiktir:** sahip olunmayan donanımdaki hatayı, kullanıcının gönderdiği log ile geliştirme makinesinde yeniden üretmenin tek yoludur.

Bu katman **M1 kilometre taşında** (P2) inşa edilir, sonraya bırakılamaz.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Doğrudan IOKit çağrısı | Motorun tamamı test edilemez hale gelir; CI'da hiçbir şey doğrulanamaz |
| Yalnızca `Live` + entegrasyon testi | Tek donanımda %20'lik bir kapsam; kalan %80 kör nokta |
| Soyutlamayı sonraya bırakmak | Sonradan geriye dönük soyutlama, en pahalı refactor türüdür |

## Sonuçlar

- ✅ Kontrol motorunun tamamı CI'da, donanımsız, saniyeler içinde test edilir
- ✅ Kullanıcı hata raporu → `Replay` → yerel yeniden üretim
- ✅ Yeni çip nesli çıktığında yalnızca `Live` güncellenir
- ✅ Tek donanım kısıtı mimariyi bozmuyor, **düzeltiyor**
- ⚠️ Her protokol için üç uygulama bakım yükü

## Zorlama

- `make gate-layers` → her protokol için `Live<Ad>` ve `Mock<Ad>` yoksa kırmızı (M2)
- `make gate-layers` → `Core` içinde IOKit import varsa kırmızı ([0012](0012-core-layer-purity.md))
- CI: `Core` kapsamı ≥ %85 bloklayıcı
