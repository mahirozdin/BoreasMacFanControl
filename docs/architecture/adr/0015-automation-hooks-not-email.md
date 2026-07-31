# 0015 — E-posta bildirimi yerine otomasyon kancaları

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §8.4, §12.3

## Bağlam

Uzak bir Mac'i izleyen kullanıcı, eşik aşıldığında haberdar olmak ister. Klasik çözüm uygulamaya SMTP istemcisi gömmektir.

Bunun gerçek maliyeti: kimlik bilgisi saklama, Keychain yönetimi, sağlayıcıya özel uygulama şifreleri, TLS uyumluluğu, port/şifreleme otomatik keşfi, teslimat sorunları ve bunların hepsinin sürekli bakımı.

## Karar

SMTP istemcisi **yazılmaz**. Yerine iki genel mekanizma:

**① Webhook**
```json
{ "type": "webhook", "url": "https://…", "method": "POST", "template": "…" }
```

**② Kabuk komutu**
```json
{ "type": "command", "path": "~/bin/on-hot.sh", "arguments": ["${sensor}", "${celsius}"] }
```

Güvenlik önlemleri: komut kancası varsayılan **kapalı**, açılırken açık uyarı; komut **kullanıcı ayrıcalıklarıyla** çalışır, asla daemon içinde değil; zaman aşımı ve eşzamanlılık sınırı uygulanır.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Gömülü SMTP istemcisi | Devasa bakım yükü, kimlik bilgisi saklama sorumluluğu, sağlayıcıya özel kod |
| Yalnızca yerel bildirim | Uzak sunucu senaryosunu karşılamaz |
| Üçüncü taraf bildirim servisi | Bağımlılık + ağ + gizlilik yüzeyi ([0014](0014-zero-telemetry.md)'e aykırı) |

## Sonuçlar

- ✅ Çok daha az kod, çok daha az saldırı yüzeyi
- ✅ Kimlik bilgisi saklama sorumluluğu tamamen ortadan kalkar
- ✅ Kullanıcı kendi entegrasyonunu kurar — Slack, Discord, ntfy, Home Assistant, `mail` komutu
- ⚠️ E-posta isteyen kullanıcı kendi betiğini yazmalı — dokümantasyonda hazır örnek verilir
- ⚠️ Komut kancası ayrıcalık yükseltme riski taşır → varsayılan kapalı + uyarı

## Zorlama

- `make gate-daemon` → daemon'da alt süreç başlatma varsa kırmızı
- `make gate-privacy` → ağ API'si yalnızca `App/Sources/Automation/` ve `App/Sources/Updates/` altında
- Birim testi: komut kancası varsayılan olarak kapalı
