# 0008 — SMAppService + imza doğrulamalı XPC

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §6.3, §14.2

## Bağlam

Ayrıcalıklı yardımcı kurmanın iki yolu var: eski `SMJobBless` (macOS 13'te kullanımdan kaldırıldı) ve modern `SMAppService.daemon`. Ayrıca ayrıcalıklı bir daemon'un **kimden komut aldığını doğrulaması** şart; aksi halde herhangi bir yerel süreç fan hızlarını değiştirebilir.

## Karar

- Kurulum **`SMAppService.daemon(plistName:)`** ile
- XPC bağlantısında **çift yönlü kod imzası doğrulaması**: daemon istemcinin Team ID + bundle ID'sini `SecCodeCheckValidity` ve `SecRequirement` ile doğrular; uygulama da daemon imzasını doğrular
- XPC yüzeyi **dört metotla** sınırlı: `describeFans`, `applyTargets`, `releaseToFirmware`, `heartbeat`
- Yeni metot eklemek **yeni bir ADR gerektirir**

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| `SMJobBless` | macOS 13'te kullanımdan kaldırıldı; yeni projede kullanmak teknik borç |
| İmza doğrulaması olmayan XPC | Herhangi bir yerel süreç root ayrıcalığıyla fan yazabilir — kabul edilemez |
| Geniş, genel amaçlı XPC arayüzü | Saldırı yüzeyi; her yeni metot yeni risk |

## Sonuçlar

- ✅ Tek yönetici kimlik doğrulaması
- ✅ Yalnızca imzalı uygulamamız komut gönderebilir
- ⚠️ Developer ID zorunlu — gerçek Team ID olmadan imza doğrulaması anlamsız
- ⚠️ macOS 13'te `SMAppService` kayıt sorunları — [0003](0003-minimum-macos-14.md) ile 14.0'a çıkılarak aşıldı

## Zorlama

- `make gate-daemon` → XPC protokolünde dört metot dışında `func` varsa kırmızı (M4)
- `make gate-daemon` → imza doğrulama API'si bulunamazsa kırmızı (G5)
- Invariant testi: imzası doğrulanmamış istemciden komut kabul edilmez
