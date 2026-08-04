# Ayrıcalık Modeli ve İzinler

> Son güncelleme: 2026-07-31 — P0.20
> Kaynak: blueprint §6 · Kararlar: [ADR 0007](adr/0007-privilege-split.md), [ADR 0008](adr/0008-smappservice-xpc.md), [ADR 0009](adr/0009-watchdog-dead-man-switch.md)

## İstenen izinlerin tam listesi

| İzin | Ne zaman | Sıklık | Zorunlu |
|---|---|---|---|
| Yönetici kimlik doğrulaması | Fan daemon'u ilk kurulurken | **Tek sefer** | Hayır — atlanırsa izleme modu |
| Arka planda çalışma onayı | Daemon kaydı sırasında | Tek sefer | Fan kontrolü için evet |
| Bildirim izni | Kullanıcı bildirimleri açtığında | Tek sefer | Hayır |
| Girişte başlatma | Kullanıcı açarsa | Tek sefer | Hayır |

## İstenmeyen izinler — açık taahhüt

README'de ve uygulama içinde yayınlanır:

- ❌ SIP devre dışı bırakma
- ❌ Kernel extension / DriverKit sürücüsü
- ❌ Recovery Mode veya güvenlik politikası değişikliği
- ❌ Tam Disk Erişimi
- ❌ Erişilebilirlik izni
- ❌ Ekran kaydı izni
- ❌ Kamera / mikrofon / konum / kişiler / takvim
- ❌ NVRAM veya firmware değişikliği

## Kurulan dosyalar

> **P3'te gerçek donanımda doğrulandı (2026-08-04).** P0 taslağındaki tablo, eski nesil
> yardımcı kurulum akışının yollarını (`/Library/PrivilegedHelperTools/…`,
> `/Library/LaunchDaemons/…`) varsayıyordu — **bulunan hata:** `SMAppService` bu
> konumların hiçbirine yazmaz. Yardımcı kayıtlı ve çalışır durumdayken her iki dizinde
> de bize ait hiçbir giriş olmadığı gösterildi (Run Log, 2026-08-04 P3 kayıtları).

| Konum | İçerik | Ne zaman yazılır |
|---|---|---|
| `Boreas.app/Contents/Library/LaunchDaemons/` içindeki yardımcı ikilisi ve launchd tanımı | `com.bubiapps.boreas.fanhelper` + `.plist` (`BundleProgram` paket içini gösterir) | Uygulama derlenirken — **kurulum hiçbir şey kopyalamaz** |
| Sistemin arka plan öğeleri veritabanı | Kayıt ve onay durumu; Sistem Ayarları → Giriş Öğeleri altında görünür | `register()` çağrısında |
| `~/Library/Application Support/Boreas/` | Yapılandırma ve yerel veriler | **Henüz yazılmıyor** — ilk yazan P5 olacak |

Kurulum sistem klasörlerine dosya kopyalamadığı için kaldırma tek bir `unregister()`
çağrısıdır; geride yalnızca silinecek kayıt vardır, yetim dosya sınıfı hiç doğmaz.

## Daemon kurulumu

**`SMAppService.daemon(plistName:)`** kullanılır — eski `SMJobBless` akışı kullanılmaz.

**Akış** (uygulamadaki karşılığı: `App/Sources/Helper/` — kurulum penceresi ve modeli):

1. Kullanıcı menü çubuğu panelinden fan kontrolü kurulumunu açar. Kontrol edilebilir
   fanı olmayan modelde bu giriş hiç gösterilmez; yardımcı kurulu değilken de bu bir
   hata olarak sunulmaz (İ4)
2. **Ne olacağı, hangi dosyaların nereye yazılacağı ve nasıl geri alınacağı, kurulum
   düğmesinden önce aynı pencerede gösterilir**
3. `register()` çağrılır. macOS 13+ akışında bu çoğunlukla `requiresApproval`
   durumuna düşer — bu bir hata değil, belgelenmiş onay akışıdır
4. Uygulama bu durumu algılar, tek düğmeyle doğrudan ilgili Sistem Ayarları paneline
   götürür ve onay gelene kadar durumu düzenli aralıkla yoklar — onay gelince
   kendiliğinden ilerler, "geri dönüp yenile" adımı yoktur
5. Bağlantı uçtan uca kanıtlanır (nonce turu + fan dökümü, her iki yönde imza
   doğrulamasıyla) ve sonuç kullanıcıya bildirilir

## Kaldırma

Üç yol, üçü de aynı sonuca çıkar:

1. **Arayüz** — kurulum penceresindeki Remove düğmesi (`unregister()`)
2. **CLI** — `boreas uninstall` yardımcıyı kaldırır; `--all` ayrıca
   `~/Library/Application Support/<uygulama adı>/` dizinini siler. `SMAppService`
   kaydı çağıran sürecin paketine bağlı olduğundan CLI kaldırmayı uygulamanın bakım
   giriş noktasına devreder; kayıtlı bir şey yoksa komut hata değil başarı döner
   (idempotent). Dizin adı çalışma zamanında bulunan paketten okunur (K2)
3. **Sistem Ayarları** — Giriş Öğeleri'ndeki anahtar kapatılır

Kaldırma sonrası geride hiçbir dosya kalmadığı gerçek donanımda beş açıdan kanıtlandı:
`SMAppService` durumu, `launchctl` sorgusu, sistem klasörleri, kullanıcı veri dizini ve
süreç listesi (Run Log, 2026-08-04 P3.06). Ürün README'sindeki manuel kaldırma adımları
P8.05'te yazılacak.

> **Bilinen kenar:** kaldır → hemen yeniden kur dizisi saniye-altı aralıkla yapılırsa
> `register()` geçici olarak `Operation not permitted` verebiliyor (arka plan kaydının
> asenkron temizliği otururken). Birkaç saniye sonra aynı çağrı başarılı; arayüzdeki
> "Try Again" düğmesi bu durumu karşılar.

## Ölü adam anahtarı

Tasarımın ayırt edici güvenlik unsuru → [ADR 0009](adr/0009-watchdog-dead-man-switch.md)

- Uygulama daemon'a düzenli **kalp atışı** gönderir (varsayılan 5 sn)
- Daemon ardışık **3 kalp atışı** kaçırırsa (≈15 sn) fanları koşulsuz firmware'e iade eder
- Kapsadığı senaryolar: çökme · `kill -9` · donma · oturum kapanması · XPC kopması
- Ayrıca **anında** devreder: sistem uykusu · sistem kapanışı · daemon durdurulması
- Zaman aşımı **10–60 sn arasında kilitli**, devre dışı bırakılamaz

**Tasarım gerekçesi:** Kullanıcı alanındaki bir uygulamanın hatası hiçbir koşulda donanımı savunmasız bırakmamalı. Kontrolü elinde tutan taraf sağlık denetiminden sorumlu olmalıdır.

## Daemon güvenlik yüzeyi

XPC arayüzü kasıtlı olarak minimaldir:

```
describeFans()          // salt okunur
applyTargets([FanTarget])  // sınırlar dahilinde
releaseToFirmware()
heartbeat(nonce:)
```

Daemon: dosya yolu/komut/betik **kabul etmez** · yapılandırma **okumaz** · ağ erişimi **yoktur** · alt süreç **başlatmaz**.

`make gate-daemon` bunların hepsini zorlar.
