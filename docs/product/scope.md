# Özellik Kapsamı

> Son güncelleme: 2026-07-31 — P0.16
> Kaynak: blueprint §8

Sürüm bazlı kırılım ve **iş listesi** `TODO.md`'dedir. Bu dosya *neden* sorusunu cevaplar.

## v1.0'da olacaklar

Eğri tabanlı otomatik kontrol · profil sistemi ve tüm tetikleyiciler · manuel kontrol · ana pencere ve canlı grafikler · eğri editörü · menü çubuğu · bildirimler · log · tanılama · global kısayollar · 5 dil · tam erişilebilirlik · CLI · Homebrew cask · imzalı+notarize DMG.

## Ayırt edici özellikler

Bu proje şu noktalarda **yapısal olarak** farklılaşır:

1. **Sürekli eğri + çift eğri histerezis + asimetrik hız sınırlama** → daha kararlı, daha sessiz, daha öngörülebilir. [ADR 0010](../architecture/adr/0010-continuous-curve-model.md)
2. **Ölü adam anahtarı** — kontrolü elinde tutan katman kendi sağlığını denetler. [ADR 0009](../architecture/adr/0009-watchdog-dead-man-switch.md)
3. **Bağlam farkında profiller** — ön plandaki uygulama, saat, ekran bağlantısı
4. **Kayıt/yeniden oynatma altyapısı** — sahip olunmayan donanımdaki hatayı üretebilme. [ADR 0011](../architecture/adr/0011-hardware-abstraction.md)
5. **İnsan tarafından düzenlenebilir, sürüm kontrolüne alınabilir yapılandırma**
6. **Sıfır telemetri, varsayılan sıfır ağ**
7. **Bilinmeyen sensörleri gizlemek yerine gösterip topluluktan katkı isteme**
8. **Türkçe birinci sınıf dil**

## Kapsam dışı — ve gerekçeleri

Bunlar "henüz yapılmadı" değil, **yapılmayacak**.

| Kapsam dışı | Gerekçe |
|---|---|
| Intel Mac desteği | Farklı SMC semantiği, farklı sensör topolojisi. Kod tabanını ikiye, test yüzeyini üçe katlar. [ADR 0004](../architecture/adr/0004-apple-silicon-only.md) |
| macOS 13 ve altı | Geriye uyumluluk maliyeti kazancından büyük. [ADR 0003](../architecture/adr/0003-minimum-macos-14.md) |
| E-posta / SMTP bildirimleri | Kimlik bilgisi saklama, 2FA, TLS uyumluluğu, teslimat — devasa bakım yükü. Yerine webhook + komut kancası. [ADR 0015](../architecture/adr/0015-automation-hooks-not-email.md) |
| Lisanslama / aktivasyon / DRM | Ücretsiz ve açık kaynak |
| Telemetri, analitik, çökme SDK'sı | [ADR 0014](../architecture/adr/0014-zero-telemetry.md) |
| Hackintosh / jenerik sensör modu | M serisi hedefiyle uyumsuz |
| Harici GPU | Apple Silicon'da desteklenmiyor |
| Harici disk sıcaklığı | macOS çoğu USB muhafaza için SMART sunmuyor; güvenilir olmayan özellik hayal kırıklığı üretir |
| CPU frekans/voltaj manipülasyonu | Apple Silicon'da mümkün değil |
| Mac App Store dağıtımı | Sandbox ayrıcalıklı daemon'a izin vermiyor — teknik olarak imkânsız. [ADR 0017](../architecture/adr/0017-distribution-channels.md) |
| Kurumsal toplu dağıtım aracı (v1.0) | Yapılandırma dosyası öncelikli tasarım sayesinde MDM ile dağıtım zaten mümkün |
| Windows / Linux | İlgisiz |

## Sonraki dalga

Menü çubuğunda mini grafik · WidgetKit widget'ı · App Intents/Shortcuts · yerel metrik uç noktası · otomasyon kancaları · bilinmeyen sensör raporu · yapılandırma paylaşımı · Sparkle güncelleme.

Tetikleyicileriyle birlikte `ARCHITECTURE.md` §12'de izlenir.
