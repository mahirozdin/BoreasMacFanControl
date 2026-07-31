# Ürün Tanımı

> Son güncelleme: 2026-07-31 — P0.14
> Kaynak: blueprint §1

## Tek cümlede

Boreas; Apple Silicon Mac'lerde dahili sıcaklık sensörlerini gerçek zamanlı izleyen, fan hızlarını kullanıcı tanımlı sürekli eğrilerle yöneten, sistem güvenliğinden ödün vermeden çalışan, ücretsiz ve açık kaynak bir menü çubuğu uygulamasıdır.

## Problem

Apple Silicon Mac'lerde soğutma tamamen firmware kontrolündedir ve kullanıcıya hiçbir ayar sunulmaz. Bu iki yönde de sorun yaratır:

1. **Çok sessiz olduğu durumlar** — uzun derleme, video encode, sanallaştırma gibi yüklerde firmware fanları geç ve muhafazakâr açar; çip termal olarak kısılır, performans düşer.
2. **Çok gürültülü olduğu durumlar** — sessizlik gerektiren senaryolarda (ses kaydı, gece çalışma) fanlar gereksiz yüksek döner.

İkisinin de ortak sebebi aynı: **karar mekanizması kullanıcıya kapalı.**

## Hedef kitle

| Segment | İhtiyaç |
|---|---|
| Yazılım geliştiriciler | Uzun derleme/test koşularında throttling'i azaltmak |
| Video/görsel üretim | Export sırasında sürdürülebilir performans |
| Ses üretimi | Kayıt sırasında mutlak sessizlik |
| Sunucu/homelab | Headless Mac'lerde izleme, alarm, metrik |
| Meraklı kullanıcı | Makinesinin içinde ne olup bittiğini görmek |

## Ürün ilkeleri

Tartışmaya kapalı. Her tasarım kararı bunlara karşı sınanır.

1. **Güvenlik her zaman kullanıcı tercihini yener.** Yazılım çökerse, donarsa veya öldürülürse fanlar firmware kontrolüne döner. → [ADR 0009](../architecture/adr/0009-watchdog-dead-man-switch.md)
2. **Hassas izin istenmez.** SIP kapatma, kernel extension, Recovery Mode, Tam Disk Erişimi, Erişilebilirlik izni yok. → [ADR 0007](../architecture/adr/0007-privilege-split.md)
3. **Geri alınabilir.** Uygulamayı silmek sistemi kurulumdan önceki haline döndürür.
4. **Telemetri yok.** → [ADR 0014](../architecture/adr/0014-zero-telemetry.md)
5. **Yapılandırma kullanıcıya aittir.** Okunabilir, sürüm kontrolüne alınabilir, elle düzenlenebilir. → [ADR 0013](../architecture/adr/0013-json-config-zero-deps.md)
6. **Ücretsiz ve açık.** Lisans anahtarı, aktivasyon sunucusu, "pro" katmanı yoktur ve olmayacaktır.
7. **Ölçülebilir.** Uygulamanın kendi maliyeti ölçülür ve bütçenin altında tutulur.

## Başarı kriterleri

| Metrik | Hedef |
|---|---|
| Boştaki CPU kullanımı | Ortalama < %0,3 |
| Uygulama bellek ayak izi | < 60 MB |
| Daemon bellek ayak izi | < 8 MB |
| Soğuk açılıştan menü çubuğuna | < 400 ms |
| Kurulumdan ilk fan kontrolüne | Tek yönetici şifresi, < 30 sn |
| Zorla sonlandırma sonrası devir teslim | ≤ 10 sn |

Ölçüm yöntemleri ve kapılar: `ARCHITECTURE.md` §3.
