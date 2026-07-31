# Bildirimler ve Otomasyon

> Son güncelleme: 2026-07-31 — P0.27
> Kaynak: blueprint §12 · Karar: [ADR 0015](../architecture/adr/0015-automation-hooks-not-email.md)

## Bildirim tetikleyicileri

| Tetikleyici | Varsayılan |
|---|---|
| Sensör grubu eşiği aştı | Kapalı (kullanıcı eşiği belirler) |
| Termal durum `serious` veya üstü | Açık |
| Panik katmanı (K3) devreye girdi | Açık |
| Fan anomalisi tespit edildi | Açık |
| Daemon bağlantısı koptu / watchdog devreye girdi | Açık |
| Profil değişti | Kapalı |
| Pil sağlığı bozuldu | Açık |

## Gürültü kontrolü

Bu kategoride en sık yapılan hata, eşik çevresinde salınan bir sensörün kullanıcıyı bildirime boğmasıdır. Dört mekanizma:

1. **Bastırma penceresi** — aynı türden bildirim varsayılan 15 dakika içinde tekrarlanmaz (1–120 dk ayarlanabilir)
2. **Oturum başına bir kez** — donanım sağlığı bildirimleri (pil, fan anomalisi) uygulama açılışı başına yalnızca bir kez
3. **Toplama** — aynı anda birden fazla eşik aşılırsa tek bildirimde birleştirilir
4. **Sessiz saatler** — ayrı zaman aralığı tanımlanabilir; macOS Odak modlarına da saygı duyulur

## Otomasyon kancaları

E-posta/SMTP istemcisi **yazılmaz** ([ADR 0015](../architecture/adr/0015-automation-hooks-not-email.md)). Yerine iki genel mekanizma:

**① Webhook**
```json
{ "type": "webhook", "url": "https://…", "method": "POST", "template": "…" }
```
Kullanıcı kendi entegrasyonunu kurar: Slack, Discord, ntfy, Home Assistant.

**② Kabuk komutu**
```json
{ "type": "command", "path": "~/bin/on-hot.sh", "arguments": ["${sensor}", "${celsius}"] }
```

### Güvenlik önlemleri

| Önlem | Neden |
|---|---|
| Komut kancası **varsayılan kapalı** | Ayrıcalık yükseltme riski |
| Açılırken **açık uyarı** gösterilir | Kullanıcı ne kabul ettiğini bilmeli |
| Komut **kullanıcı ayrıcalıklarıyla** çalışır | **Asla daemon içinde değil** — `make gate-daemon` bunu zorlar |
| Zaman aşımı ve eşzamanlılık sınırı | Kaçak süreç birikmesini önler |
| Ağ yalnızca `App/Sources/Automation/` altında | `make gate-privacy` bunu zorlar |

## E-posta isteyen kullanıcı için

Dokümantasyonda hazır bir betik örneği verilir (sistemin `mail` komutunu kullanan). Bu, kimlik bilgisi saklama sorumluluğunu tamamen kullanıcıya bırakır ve uygulamanın saldırı yüzeyini büyütmez.
