# 0014 — Sıfır telemetri

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §1.4, §14.3

## Bağlam

Uygulama, kullanıcının donanım sensörlerini sürekli okuyan ve arka planda çalışan bir araç. Bu konumdaki bir yazılımın veri toplaması, kullanıcı güveni açısından en hassas nokta.

Karşı argüman: telemetri olmadan hangi özelliklerin kullanıldığı bilinemez. Bu kabul edilir — ürün kararları kullanıcı geri bildirimiyle verilir.

## Karar

- **Hiçbir kullanım verisi toplanmaz veya iletilmez**
- Analitik SDK'sı, çökme raporlama SDK'sı, reklam kimliği **yoktur**
- **Varsayılan durumda uygulama hiçbir ağ bağlantısı kurmaz**
- Ağ yalnızca şu iki durumda, yalnızca kullanıcı açtıysa: güncelleme kontrolü, kullanıcının tanımladığı webhook kancası
- Çökme raporu isteyen kullanıcı, oluşturulan **yerel** dosyayı kendisi issue'ya ekler
- Log satırları kişisel veri içermez: kullanıcı adı, dosya yolu, ağ bilgisi loglanmaz

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Anonim kullanım istatistikleri | "Anonim" iddiası doğrulanamaz; kullanıcının güvenmesi gerekir. Bu kategoride güven en değerli varlık |
| Opt-in telemetri | Kod tabanında telemetri altyapısı bulunması bile denetim yükü ve risk yaratır |
| Otomatik çökme raporlama | Çökme raporları bağlam içerir; bağlam kişisel veri sızdırabilir |

## Sonuçlar

- ✅ Gizlilik iddiası **kod düzeyinde doğrulanabilir** — pazarlama vaadi değil
- ✅ GDPR/KVKK yüzeyi yok
- ✅ Kurumsal ortamda benimseme kolaylaşır
- ⚠️ Özellik kullanım verisi yok → ürün kararları geri bildirime dayanır
- ⚠️ Çökme teşhisi kullanıcının aktif katılımını gerektirir

## Zorlama

`make gate-privacy`:
- Telemetri/analitik SDK adı veya `advertisingIdentifier` izi → kırmızı (P1)
- `App/Sources/Updates/` ve `App/Sources/Automation/` dışında ağ API'si → kırmızı (P2)
- Daemon entitlement'ında ağ yetkisi → kırmızı

Kanıtlandı: `Analytics` referansı içeren bir dosya konduğunda kapı kırmızıya döndü.
