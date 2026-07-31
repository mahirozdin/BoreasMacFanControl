# 0007 — Ayrıcalıksız okuma / ayrıcalıklı yazma ayrımı

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §4.2, §6

## Bağlam

Kullanıcıların bu kategorideki araçlardan en büyük çekincesi, sistem güvenliğini zayıflatan kurulum adımları. Aynı zamanda fan yazımı gerçekten root gerektiriyor.

Kritik teknik bulgu: **Apple Silicon'da sıcaklık okumak hiçbir ayrıcalık gerektirmiyor.** Yalnızca SMC'ye yazmak gerektiriyor.

## Karar

Mimari bu bulgu üzerine kurulur:

- **Okuma yolu** — uygulama doğrudan donanıma erişir, daemon'dan geçmez
- **Yazma yolu** — yalnızca fan hedefi/modu; ayrıcalıklı daemon üzerinden
- **Daemon yüzeyi minimum:** dört XPC metodu, yapılandırma okumaz, ağ kullanmaz, alt süreç başlatmaz

Sonuç: kullanıcı daemon'u **hiç kurmasa bile** uygulama tam işlevli bir izleme aracıdır.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Her şeyi daemon üzerinden yapmak | Ayrıcalıklı yüzeyi gereksiz büyütür; okuma için root istemek savunulamaz |
| Kernel extension | SIP kapatma + Recovery Mode gerektirir — İlke 2'ye aykırı |
| Daemon'un yapılandırmayı okuması | Root tarafında kullanıcı verisi ayrıştırmak saldırı yüzeyi yaratır |

## Sonuçlar

- ✅ Yönetici şifresi yalnızca bir kez, yalnızca fan kontrolü istendiğinde
- ✅ Daemon kurulmadan tam izleme
- ✅ Ayrıcalıklı kod yüzeyi birkaç yüz satırla sınırlı
- ⚠️ İki farklı donanım erişim yolu (okuma/yazma) bakımı gerektirir

## Zorlama

- `make gate-daemon` → daemon'da `JSONDecoder`/dosya okuma varsa kırmızı (M5)
- `make gate-daemon` → daemon'da ağ API'si varsa kırmızı (M6)
- `make gate-daemon` → daemon'da alt süreç başlatma varsa kırmızı
- `make gate-privacy` → daemon entitlement'ında ağ yetkisi varsa kırmızı
