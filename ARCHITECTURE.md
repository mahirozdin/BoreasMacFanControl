# ARCHITECTURE.md

> Son güncelleme: 2026-07-31 — P0.05
> Kaynak: blueprint §4, §5, §6, §7, §17.2

Bu dosya **kod incelemesinin kontrol listesidir**. Ayrıntılı anlatım `docs/architecture/` altındadır; burada yalnızca bağlayıcı kurallar ve karar indeksi bulunur.

---

## 1. Hedefler

| Hedef | Ölçüt |
|---|---|
| Ayrıcalıksız izleme | Daemon kurulmadan tüm sensörler ve fan hızları okunabilir |
| Güvenli fan kontrolü | Yazılımın her başarısızlık modunda fanlar firmware'e döner |
| Donanımsız test edilebilirlik | Kontrol motorunun tamamı CI'da, gerçek Mac fanı olmadan test edilir |
| Minimum ayrıcalıklı yüzey | Root tarafında ayrıştırılan kullanıcı verisi yok |
| Öngörülebilir akustik | Fan hızı değişimleri sürekli ve hız-sınırlı |

## 2. Hedef olmayanlar

- Intel Mac desteği
- macOS 13 ve altı
- Mac App Store dağıtımı (sandbox ayrıcalıklı daemon'a izin vermiyor)
- CPU frekans/voltaj manipülasyonu
- Harici GPU, harici disk sıcaklığı
- Kurumsal toplu dağıtım aracı (v1.0)

## 3. Kalite hedefleri

| Hedef | Ölçüm | Kapı |
|---|---|---|
| Boştaki CPU < %0,3 | 10 dk örnekleme, `powermetrics` | Duman testi (elle) |
| Uygulama belleği < 60 MB | Activity Monitor / `footprint` | Duman testi (elle) |
| Daemon belleği < 8 MB | `footprint` | Duman testi (elle) |
| Açılıştan menü çubuğuna < 400 ms | `os_signpost` ölçümü | Performans testi |
| Fan devir teslimi ≤ 10 sn | `kill -9` sonrası ölçüm | Invariant + duman testi |
| `Core` kapsamı ≥ %85 | `swift test --enable-code-coverage` | CI bloklayıcı |

---

## 4. Sistem bağlamı

```
Kullanıcı alanı (yetkisiz)          Kök alanı (root)          Donanım
┌──────────────────────┐           ┌────────────────┐        ┌──────────────┐
│ Boreas.app           │  NSXPC    │ FanDaemon      │ IOKit  │ AppleSMC     │
│  UI / ControlEngine  │◀────────▶│  XPCListener   │◀──────▶│ AppleSensors │
│  SensorReader ───────┼───────────┼────────────────┼───────▶│ SmartBattery │
│  ConfigStore         │  imza     │  SafetyGovernor│        │ IOPS         │
│  DaemonClient        │  doğrulama│  Watchdog      │        └──────────────┘
└──────────────────────┘  (çift    │  StateRestorer │
┌──────────────────────┐   yönlü)  └────────────────┘
│ boreas (CLI)         │
└──────────────────────┘
```

**Kilit nokta:** `SensorReader` daemon'dan geçmez. Sıcaklık okuma ayrıcalık gerektirmediği için doğrudan donanıma gider. Daemon yalnızca **yazma** yolundadır.

---

## 5. Güven sınırları

| Sınır | Doğrulama | Değişmez |
|---|---|---|
| App → Daemon | `SecCodeCheckValidity` + `SecRequirement`; Team ID ve bundle ID eşleşmezse bağlantı reddedilir | G5 |
| Daemon → App | App, daemon imzasını doğrular; sahte daemon'a komut göndermez | G5 |
| Daemon → Donanım | `SafetyGovernor` tüm yazmaları süzer; sınır dışı komut reddedilir ve loglanır | K4 |
| Config → Motor | Şema doğrulaması + aralık kısıtları; geçersizse son geçerli hale dönülür | G6 |

---

## 6. Modül sınırları ve bağımlılık kuralları

```
App    ──▶ Core, HardwareKit, SharedIPC
CLI    ──▶ Core, HardwareKit, SharedIPC
Daemon ──▶ HardwareKit (yalnızca yazma yüzeyi), SharedIPC
Core   ──▶ (yalnızca Foundation)
HardwareKit ──▶ Core (yalnızca model tipleri)
```

### MUST / MUST NOT

| # | Kural | Kapı |
|---|---|---|
| **M1** | `Packages/Core` **MUST NOT** import IOKit, SwiftUI, AppKit veya herhangi bir donanım API'si | `make gate-layers` |
| **M2** | Her donanım protokolü **MUST** en az `Live` + `Mock` uygulamasına sahip olsun | `make gate-layers` |
| **M3** | Sıcaklık okuma **MUST NOT** daemon üzerinden geçsin | İnceleme |
| **M4** | Daemon XPC yüzeyi **MUST** yalnızca `describeFans` / `applyTargets` / `releaseToFirmware` / `heartbeat` içersin | `make gate-daemon` |
| **M5** | Daemon **MUST NOT** yapılandırma dosyası okusun veya ayrıştırsın | `make gate-daemon` |
| **M6** | Daemon **MUST NOT** ağ API'si import etsin | `make gate-daemon` |
| **M7** | Donanım erişen kod **MUST NOT** `@MainActor` üzerinde çalışsın | İnceleme |
| **M8** | `Core` fonksiyonları **MUST** saf olsun (aynı girdi → aynı çıktı) | Birim testi |

---

## 7. Güvenlik zinciri

Motor çıktısı donanıma ulaşmadan beş katmandan geçer. **Her katman yalnızca yukarı düzeltebilir.**

| Katman | Nerede | Kural | Kapatılabilir mi |
|---|---|---|---|
| **K1** Fan tabanı | Motor | Çıktı fanın donanım minimumunun altına inmez | ✗ |
| **K2** Termal durum | Motor | `serious` → taban %55; `critical` → %100 | ✗ |
| **K3** Panik eşiği | Motor | Sensör > `T_panic` → %100, ≥30 sn kilitli | ✗ (yalnızca düşürülebilir) |
| **K4** Daemon guard | Daemon | Fizikî sınır dışı komut reddedilir | ✗ |
| **K5** Watchdog | Daemon | Kalp atışı yoksa firmware'e devret | ✗ |

### Invariant testleri (silinemez)

```
test("hiçbir güvenlik katmanı çıktıyı düşüremez")
test("thermalState .critical iken çıktı kullanıcı eğrisinden bağımsız %100")
test("watchdog zaman aşımı 10-60 sn dışına ayarlanamaz")
test("kalp atışı kesildiğinde daemon firmware'e devreder")
test("XPC istemcisi imzası doğrulanmadan komut kabul edilmez")
test("geçersiz yapılandırma uygulamayı çökertmez, son geçerli hale döner")
test("monoton artan eğri monoton artan çıktı üretir")
test("çıktı her zaman [fanMin, fanMax] aralığındadır")
```

---

## 8. Durum makinesi

```
MONITORING ──(kullanıcı kontrolü açar + daemon hazır)──▶ CONTROLLING
CONTROLLING ──(K3 tetiklendi)──▶ PANIC ──(normale döner)──▶ CONTROLLING
* ──(watchdog / uyku / çıkış / hata)──▶ RELEASING ──▶ MONITORING
```

`RELEASING` **idempotenttir**; kaç kez çağrılırsa çağrılsın güvenlidir.

---

## 9. Hata senaryoları

| Senaryo | Beklenen davranış |
|---|---|
| Sensör kaynağı hata verdi | Yedek kaynağa geç; o da başarısızsa izleme moduna düş, kullanıcıyı bilgilendir, **çökme yok** |
| Bilinmeyen sensör adı | `uncategorized` grubunda göster, **gizleme** |
| Bilinmeyen SMC veri tipi | Sensörü atla, uyarı logla |
| Daemon bağlantısı koptu | İzleme moduna düş, bildirim göster; daemon watchdog ile devreder |
| Fan hedefe ulaşmıyor | Sapmayı tespit et, düzelt; ısrar ederse kullanıcıya dürüst bildir ("bu modelde kontrol sınırlı") |
| Yapılandırma bozuk | Son geçerli hale dön, hatalı alanı göster, fanlar firmware'de |
| Fan bulunamadı (fansız model) | Fan bölümünü gizle, daemon kurulumu önerme, izleme sun |
| Disk dolu (log) | Sert üst sınırda en eskiyi sil, kullanıcıyı bilgilendir |

---

## 10. Sürüm kapıları

| Kapı | v1.0 için zorunlu |
|---|---|
| Tüm invariant testleri geçiyor | ✅ |
| `Core` kapsamı ≥ %85 | ✅ |
| `make check` tüm kapılar yeşil | ✅ |
| `kill -9` duman testi geçti (gerçek donanım) | ✅ |
| Uyku/uyanma duman testi geçti | ✅ |
| Notarizasyon başarılı | ✅ |
| 5 dil eksiksiz, pseudo-locale düzen testi geçti | ✅ |
| README "test edilen donanım" bölümü dürüst | ✅ |

---

## 11. ADR indeksi

| # | Karar | Durum |
|---|---|---|
| [0001](docs/architecture/adr/0001-native-swift.md) | Native Swift + SwiftUI; Flutter/Electron reddedildi | Kabul |
| [0002](docs/architecture/adr/0002-product-name.md) | Ürün adı Boreas | Kabul |
| [0003](docs/architecture/adr/0003-minimum-macos-14.md) | Minimum macOS 14.0 Sonoma | Kabul |
| [0004](docs/architecture/adr/0004-apple-silicon-only.md) | Yalnızca Apple Silicon (arm64) | Kabul |
| [0005](docs/architecture/adr/0005-apache-2-license.md) | Apache-2.0 lisansı | Kabul |
| [0006](docs/architecture/adr/0006-independent-development-policy.md) | **Bağımsız geliştirme politikası** | Kabul |
| [0007](docs/architecture/adr/0007-privilege-split.md) | Ayrıcalıksız okuma / ayrıcalıklı yazma ayrımı | Kabul |
| [0008](docs/architecture/adr/0008-smappservice-xpc.md) | SMAppService + imza doğrulamalı XPC | Kabul |
| [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Ölü adam anahtarı (watchdog) | Kabul |
| [0010](docs/architecture/adr/0010-continuous-curve-model.md) | Sürekli eğri kontrol modeli | Kabul |
| [0011](docs/architecture/adr/0011-hardware-abstraction.md) | Donanım soyutlaması: Live / Mock / Replay | Kabul |
| [0012](docs/architecture/adr/0012-core-layer-purity.md) | `Core` katman saflığı | Kabul |
| [0013](docs/architecture/adr/0013-json-config-zero-deps.md) | JSON yapılandırma + sıfır bağımlılık | Kabul |
| [0014](docs/architecture/adr/0014-zero-telemetry.md) | Sıfır telemetri | Kabul |
| [0015](docs/architecture/adr/0015-automation-hooks-not-email.md) | E-posta yerine otomasyon kancaları | Kabul |
| [0016](docs/architecture/adr/0016-language-scope.md) | 5 dil arayüz / İngilizce dokümantasyon | Kabul |
| [0017](docs/architecture/adr/0017-distribution-channels.md) | Dağıtım kanalları; App Store dışlandı | Kabul |
| [0018](docs/architecture/adr/0018-undocumented-sensor-api.md) | Dokümante edilmemiş sensör API'si kabulü | Kabul |
| [0019](docs/architecture/adr/0019-signing-identity-deferred.md) | İmzalama kimliği P8'e ertelendi | Kabul |

---

## 12. Ertelenmiş kararlar

Bilinçli olarak açık bırakıldı. **Unutulan değil, beklenen.**

| Konu | Neyi bekliyor | Kararı tetikleyecek olay |
|---|---|---|
| Sparkle ile uygulama içi güncelleme | Homebrew'un yeterli olup olmadığı | v1.0 sonrası kullanıcı geri bildirimi |
| Yerel metrik uç noktası (Prometheus) | Gerçek homelab talebi | En az 3 kullanıcı isteği |
| Geleneksel Çince (`zh-Hant`) | Talep | Kullanıcı isteği |
| Organizasyona taşıma | Katkıcı sayısı | Düzenli katkıcı ≥ 3 |
| Fan başına farklı sensör grubu varsayılanı | Çok fanlı donanımda ölçüm | Çok fanlı test cihazına erişim |
| `p95` toplayıcının gerçekten gerekli olup olmadığı | Kullanım verisi (yok — telemetri yok) | Kullanıcı geri bildirimi |
| Kurumsal toplu dağıtım aracı | Kurumsal talep | v2 kapsamı |
