# Boreas — Teknik Blueprint

> **Belge sürümü:** 1.1
> **Tarih:** 31 Temmuz 2026
> **Durum:** Kararlar kesinleşti — uygulamaya geçilebilir
> **Kapsam:** Apple Silicon (M serisi) Mac'ler için açık kaynak, ücretsiz termal izleme ve fan kontrol uygulaması

| Kimlik | Değer |
|---|---|
| Ürün adı | **Boreas** |
| Depo adı | `boreas-mac-fan-control` |
| Bundle ID | `com.bubiapps.boreas` |
| Daemon etiketi | `com.bubiapps.boreas.fanhelper` |
| CLI komutu | `boreas` |
| Homebrew cask | `boreas` |
| Minimum macOS | 14.0 Sonoma |
| Mimari | arm64 (Apple Silicon) |
| Lisans | Apache-2.0 |

---

## 0. Bu Belge Hakkında

Bu blueprint, projenin **tek referans kaynağıdır**. Ürün tanımından hukuki çerçeveye, mimariden dosya ağacına, kontrol algoritmasından README içeriğine kadar her şeyi tanımlar.

**Nasıl kullanılır:**

| Rolündeysen | Şu bölümleri oku |
|---|---|
| Projeye ilk kez bakıyorsan | §1, §2, §3, §8 |
| Kod yazacaksan | §4, §5, §6, §7, §10, §15, §17 |
| Arayüz tasarlayacaksan | §9, §12 |
| Katkı vereceksen | §2, §17, §18, §19 |
| Yayına hazırlıyorsan | §14, §16, §18, §19, §20 |

**Değişiklik politikası:** Bu belgedeki bir kararı değiştirmek isteyen, önce buradaki ilgili bölümü günceller, sonra kodu yazar. Kod ile blueprint çeliştiğinde blueprint kazanır; kod düzeltilir veya blueprint bilinçli olarak revize edilir.

---

## 1. Ürün Tanımı

### 1.1 Tek cümlelik tanım

Boreas; Apple Silicon Mac'lerde dahili sıcaklık sensörlerini gerçek zamanlı izleyen, fan hızlarını kullanıcı tanımlı sürekli eğrilerle yöneten, sistem güvenliğinden ödün vermeden çalışan, ücretsiz ve açık kaynak bir menü çubuğu uygulamasıdır.

### 1.2 Neden var — problem tanımı

Apple Silicon Mac'lerde soğutma tamamen firmware kontrolündedir ve kullanıcıya hiçbir ayar sunulmaz. Bu, iki yönde de sorun yaratır:

1. **Çok sessiz olduğu durumlar:** Uzun süreli derleme, video encode, sanallaştırma gibi yüklerde firmware fanları geç ve muhafazakâr açar. Çip termal olarak kısılır (throttling), performans düşer. Kullanıcı biraz fan sesine razı olsa daha hızlı bitecek işler yavaşlar.
2. **Çok gürültülü olduğu durumlar:** Sessizlik gerektiren senaryolarda (ses kaydı, gece çalışma, toplantı) fanlar gereksiz yüksek dönebilir.

İkisinin de ortak sebebi aynı: **karar mekanizması kullanıcıya kapalı.** Bu proje o kararı kullanıcıya açar.

### 1.3 Hedef kitle

| Segment | İhtiyaç |
|---|---|
| Yazılım geliştiriciler | Uzun derleme/test koşularında throttling'i azaltmak |
| Video/görsel üretim | Export sırasında sürdürülebilir performans |
| Ses üretimi | Kayıt sırasında mutlak sessizlik |
| Sunucu/homelab kullanıcıları | Headless Mac mini'lerde sıcaklık izleme, alarm, metrik dışa aktarımı |
| Meraklı kullanıcı | Makinesinin içinde ne olup bittiğini görmek |

### 1.4 Ürün ilkeleri

Bunlar tartışmaya kapalıdır; her tasarım kararı bunlara karşı sınanır.

1. **Güvenlik her zaman kullanıcı tercihini yener.** Yanlış yapılandırma donanıma zarar vermemeli. Yazılım çökerse, donarsa veya öldürülürse fanlar firmware kontrolüne döner.
2. **Hassas izin istenmez.** SIP devre dışı bırakma yok, kernel extension yok, Recovery Mode adımı yok, Tam Disk Erişimi yok, Erişilebilirlik izni yok, ekran kaydı izni yok.
3. **Geri alınabilir.** Uygulamayı silmek, sistemi kurulumdan önceki haline döndürür. Kalıcı firmware/NVRAM değişikliği yapılmaz.
4. **Telemetri yok.** Hiçbir kullanım verisi, çökme raporu veya analitik dışarı gönderilmez. Ağ bağlantısı yalnızca kullanıcının açıkça istediği işlemler için kurulur.
5. **Yapılandırma kullanıcıya aittir.** Tüm ayarlar okunabilir, sürüm kontrolüne alınabilir, elle düzenlenebilir bir dosyada durur.
6. **Ücretsiz ve açık.** Lisans anahtarı, aktivasyon sunucusu, kullanım kısıtı, "pro" katmanı yoktur ve olmayacaktır.
7. **Ölçülebilir.** Uygulamanın kendi CPU/enerji maliyeti ölçülür ve bir bütçenin altında tutulur.

### 1.5 Başarı kriterleri

| Metrik | Hedef |
|---|---|
| Boştaki CPU kullanımı | Ortalama < %0,3 (2 sn örnekleme, tek çekirdek üzerinden) |
| Bellek yerleşik boyutu | < 60 MB (uygulama), < 8 MB (daemon) |
| Enerji etkisi (Activity Monitor) | "Düşük" bandında |
| Soğuk açılıştan menü çubuğuna | < 400 ms |
| Kurulumdan ilk fan kontrolüne | Tek yönetici şifresi, < 30 saniye |
| Uygulama zorla sonlandırıldığında | Fanlar ≤ 10 sn içinde firmware kontrolüne döner |

---

## 2. Hukuki ve Etik Çerçeve

> **Bu bölüm projenin en kritik kısmıdır. Kod yazmadan önce ekipteki herkes okumalıdır.**
> **Not:** Buradaki içerik hukuki tavsiye değildir. Ticari yayın öncesi bir avukatla görüşülmelidir.

### 2.1 Temel duruş

Bu proje **bağımsız bir üründür.** İşlevsel olarak aynı problemi çözen başka yazılımlar mevcuttur; bu normaldir ve yasaldır. Telif hakkı **fikirleri, işlevleri veya çözülen problemi değil, ifadeyi** korur. Dolayısıyla:

- "Fan hızını sıcaklığa göre ayarlamak" bir **fikirdir** — korunmaz, serbestçe uygulanabilir.
- Belirli bir arayüz metni, ikon seti, yardım dokümanı, kaynak kodu, veri tablosu ise **ifadedir** — korunur, kopyalanamaz.

Projenin güvenliği bu ayrımı disiplinli biçimde uygulamaktan gelir.

### 2.2 Mutlak yasaklar

Aşağıdakiler, ihlali durumunda katkının reddedileceği ve gerekirse geçmişin yeniden yazılacağı kurallardır:

| # | Yasak |
|---|---|
| Y1 | Herhangi bir üçüncü taraf ticari uygulamayı tersine mühendislikle çözmek, disassemble/decompile etmek veya ikili dosyasını incelemek |
| Y2 | Başka bir üründen metin, etiket, yardım içeriği, hata mesajı, pazarlama kopyası veya dokümantasyon kopyalamak/çevirmek |
| Y3 | Başka bir ürünün ikonlarını, renk paletini, pencere düzenini veya görsel kimliğini taklit etmek |
| Y4 | Başka bir ürünün ayar dosyası şemasını, anahtar adlarını veya veri formatını birebir kullanmak |
| Y5 | Repoda, commit mesajlarında, issue'larda, kodda, yorumlarda veya dokümantasyonda herhangi bir rakip ürünün **adını geçirmek** |
| Y6 | "X'in alternatifi", "X gibi ama ücretsiz", "X'ten daha iyi" tarzı karşılaştırmalı pazarlama yapmak |
| Y7 | Lisansı uyumsuz üçüncü taraf kodu (ör. GPL) projeye dahil etmek |

**Y5 özellikle önemlidir.** Rakip ürün adı geçen bir commit veya issue, iyi niyetle yazılmış olsa bile "bilerek kopyalama" iddiasına delil oluşturabilir. İhtiyaç halinde jenerik ifadeler kullanılır: *"kapalı kaynak alternatifler"*, *"ticari muadiller"*, *"bu kategorideki diğer araçlar"*.

### 2.3 İzin verilenler

| İzinli | Açıklama |
|---|---|
| Apple'ın resmî dokümantasyonu | IOKit, ServiceManagement, HIDDriverKit, Human Interface Guidelines |
| Apple'ın açık başlık dosyaları | SDK içindeki public header'lar |
| Uyumlu lisanslı açık kaynak projeler | MIT / BSD / Apache-2.0 — **atıf zorunlu**, §2.6'ya bak |
| Genel donanım bilgisi | SMC anahtar adlandırma kuralları, IOKit servis isimleri gibi kamusal teknik bilgi |
| Kendi ölçümlerimiz | Kendi Mac'lerimizde yaptığımız sensör keşfi, log analizi, termal testler |
| Akademik/mühendislik literatürü | Kontrol teorisi, histerezis, PID, termal modelleme |

### 2.4 Bağımsız geliştirme protokolü

Her katkıcı, PR açarken aşağıdaki beyanı onaylar (PR şablonuna gömülecek):

```
[ ] Bu katkıdaki kod ve metinler tamamen benim tarafımdan yazıldı veya
    uyumlu lisanslı, kaynağı NOTICE dosyasında belirtilmiş koddan türetildi.
[ ] Bu katkıyı hazırlarken hiçbir ticari yazılımı tersine mühendislikle
    incelemedim, ikili dosyasını analiz etmedim.
[ ] Bu katkıda hiçbir üçüncü taraf ürün adı geçmiyor.
```

### 2.5 Lisans seçimi

**Karar: Apache License 2.0**

| Aday | Artı | Eksi | Karar |
|---|---|---|---|
| MIT | En basit, en yaygın | Patent koruması yok | ❌ |
| **Apache-2.0** | **Açık patent hibesi; katkıcılardan da patent hibesi alır; ticari kullanıma açık; NOTICE mekanizması atıf yönetimini kolaylaştırır** | Biraz daha uzun metin | ✅ |
| GPL-3.0 | Türev işlerin açık kalmasını zorlar | Kurumsal benimsemeyi engeller; ilke 6'ya aykırı değil ama yayılımı sınırlar | ❌ |

Apache-2.0'ın patent hibesi maddesi (§3), donanım kontrolü gibi patent riski taşıyabilecek bir alanda hem projeyi hem kullanıcıyı korur. Bu, seçimin ana gerekçesidir.

### 2.6 Üçüncü taraf bağımlılık politikası

- **Varsayılan: sıfır çalışma zamanı bağımlılığı.** Yalnızca Apple çatıları kullanılır.
- Bir bağımlılık eklenecekse lisansı MIT / BSD / Apache-2.0 olmalıdır. GPL/LGPL/AGPL **kabul edilmez**.
- Her bağımlılık kök dizindeki `NOTICE` dosyasına eklenir: proje adı, sürüm, lisans, URL, ne için kullanıldığı.
- Bir açık kaynak projeden **fikir** alındıysa (kod değil), bu da `NOTICE` içindeki "Acknowledgements" bölümünde belirtilir. Şeffaflık, iyi niyetin en güçlü kanıtıdır.

### 2.7 Sorumluluk reddi

README ve uygulama içi ilk çalıştırma ekranında, kendi sözlerimizle yazılmış şu içerikte bir uyarı bulunacak:

- Yazılım "olduğu gibi" sunulur, garanti verilmez.
- Fan hızlarını düşürmek termal riski artırır; sorumluluk kullanıcıdadır.
- Proje Apple Inc. ile ilişkili değildir, onaylanmamıştır.
- Donanım garantisi üzerindeki etkisi kullanıcının sorumluluğundadır.

### 2.8 Marka ve isim

**Karar: ürün adı Boreas.** Yunan mitolojisinde kuzey rüzgârını, yani kışın soğuk havasını getiren tanrının adı. Uluslararası kitle için telaffuzu ve yazımı kolay, tematik olarak yerinde, macOS yazılım alanında bilinen bir çakışması yok.

**Neden "Mac" öneki taşıyan bir ad tercih edilmedi:** Apple'ın marka kuralları, üçüncü taraf ürün adlarında Apple markalarının **önek olarak** kullanılmasını önermiyor. Apple markası yalnızca **niteleyici** konumda kabul görüyor — *"Boreas for Mac"* uygundur, *"MacBoreas"* değildir. Bu bir telif değil marka meselesidir ve herhangi bir rakiple ilgisi yoktur; ancak ileride ad değişikliği zorunluluğu doğurabileceği için baştan kaçınıldı.

**Marka ile keşfedilebilirlik ayrımı:** Ürün adının arama anahtar kelimelerini taşıması gerekmez. Keşfedilebilirlik, adın kendisinden değil; depo adından, depo açıklamasından, konu etiketlerinden ve README'nin ilk ekranından gelir. Bu ayrımın nasıl uygulanacağı §18.4'te tanımlanmıştır.

**Kalan doğrulama adımları** (yayın öncesi, proje sahibi):
- [ ] TÜRKPATENT marka araması (9. ve 42. sınıflar)
- [ ] EUIPO / USPTO marka araması
- [ ] `boreas` Homebrew cask adının müsaitliği
- [ ] Varsa alan adı temini

**Ada karşı dayanıklılık:** Ürün adı kod tabanına gömülmez. Yalnızca `project.yml` içindeki değişkenlerde ve yerelleştirme kataloğunda geçer. Ad değişimi gerekirse `scripts/rename-product.sh` ile tek komutluk iştir (§17.4).

---

## 3. Teknoloji Seçimi

### 3.1 Karar: Swift + SwiftUI (AppKit destekli), tamamen native

**Gerekçe matrisi:**

| Kriter | Swift/SwiftUI | Flutter | Electron | Rust + native UI |
|---|---|---|---|---|
| IOKit / SMC erişimi | ✅ Doğrudan, C interop yerleşik | ❌ Native plugin şart — Swift zaten yazılacak | ❌ Native modül şart | ⚠️ FFI ile mümkün ama zahmetli |
| Ayrıcalıklı daemon (ServiceManagement) | ✅ Birinci sınıf | ❌ Mümkün değil, native gerekir | ❌ | ⚠️ Zor |
| XPC IPC | ✅ Yerleşik | ❌ | ❌ | ⚠️ |
| Menü çubuğu öğesi (NSStatusItem) | ✅ Yerleşik | ❌ Desteklenmiyor | ⚠️ Kısıtlı | ⚠️ |
| İkili boyut | ✅ ~8–15 MB | ❌ ~40–60 MB | ❌ ~120 MB+ | ✅ |
| Boştaki bellek | ✅ ~40 MB | ❌ ~90 MB+ | ❌ ~200 MB+ | ✅ |
| Boştaki CPU / enerji | ✅ Neredeyse sıfır | ⚠️ Render döngüsü maliyeti | ❌ | ✅ |
| Native görünüm/his | ✅ Kusursuz | ❌ Yabancı durur | ❌ | ⚠️ |
| Erişilebilirlik (VoiceOver) | ✅ Ücretsiz gelir | ⚠️ Kısmi | ⚠️ | ❌ |
| Widget / App Intents / Shortcuts | ✅ Yerleşik | ❌ | ❌ | ❌ |
| Notarizasyon & imzalama | ✅ Standart akış | ⚠️ Ek adımlar | ⚠️ | ⚠️ |
| Katkıcı bulma kolaylığı (macOS alanı) | ✅ | ⚠️ | ⚠️ | ⚠️ |

**Sonuç:** Flutter'ın tek avantajı çapraz platformdur; bu proje **tanımı gereği tek platformdur.** Üstelik Flutter kullanılsa bile SMC erişimi, daemon, XPC ve menü çubuğu için Swift yazmak zorunda kalınırdı — yani Flutter, işin en zor %70'ini çözmeden üstüne bir Dart runtime maliyeti eklerdi. **Flutter bu proje için yanlış araçtır.**

### 3.2 Sürüm ve hedef kararları

| Öğe | Karar | Gerekçe |
|---|---|---|
| Dil | **Swift 6.2**, strict concurrency açık | Derleme zamanı veri yarışı güvenliği; donanım okuma çok iş parçacıklı |
| UI | **SwiftUI**, gerektiğinde `NSViewRepresentable` ile AppKit | Menü çubuğu ve eğri editörü için AppKit köprüsü kaçınılmaz |
| Minimum macOS | **macOS 14.0 Sonoma** | `SMAppService` olgunlaştı, `@Observable` mevcut, `MenuBarExtra` kararlı. macOS 13'e inmek `@Observable` → `ObservableObject` dönüşümü gerektirir; kazanç düşük |
| Mimari | **arm64 tek mimari** | Proje kapsamı Apple Silicon; Intel desteği yok (§8.4) |
| Desteklenen çipler | M1 ve sonrası tüm varyantlar | Sensör keşfi çalışma zamanında yapılır, çip listesi koda gömülmez |
| Proje dosyası | **XcodeGen** (`project.yml`) | `.xcodeproj` merge conflict üretmez; katkıcı deneyimi belirgin iyileşir |
| Paket yönetimi | **Swift Package Manager**, yerel paketler | Çekirdek mantık donanımdan bağımsız test edilebilir olmalı |
| Test | **Swift Testing** (`@Test`), XCTest yalnızca UI testlerinde | Modern, ifade gücü yüksek |
| Minimum Xcode | 26.0 | Swift 6.2 için gerekli |

### 3.3 Bağımlılıklar

**Çalışma zamanı bağımlılığı: yok.** Yalnızca Apple çatıları:

`Foundation` · `SwiftUI` · `AppKit` · `IOKit` · `ServiceManagement` · `UserNotifications` · `Charts` · `OSLog` · `Combine` (sınırlı) · `AppIntents` · `WidgetKit` · `Security`

**Geliştirme zamanı araçları:** `XcodeGen`, `swift-format`, `SwiftLint`, `xcbeautify` — hepsi Brewfile ile kurulur, CI'da sabitlenir.

---

## 4. Sistem Mimarisi

### 4.1 Bileşenler

```
┌─────────────────────────────────────────────────────────────────┐
│  KULLANICI ALANI (yetkisiz)                                     │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Boreas.app                                                │ │
│  │  ├─ UI katmanı (SwiftUI): menü çubuğu, ana pencere, ayarlar│ │
│  │  ├─ ControlEngine: eğri değerlendirme, profil arbitrajı    │ │
│  │  ├─ SensorReader: sıcaklık okuma (izin GEREKTİRMEZ)        │ │
│  │  ├─ ConfigStore: yapılandırma yükleme/kaydetme/doğrulama   │ │
│  │  ├─ Telemetry: yerel log, CSV/JSONL, metrik dışa aktarım   │ │
│  │  └─ DaemonClient: XPC istemcisi + kalp atışı üreticisi     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  boreas (CLI)  — aynı Core'u kullanır, UI'sız              │ │
│  └────────────────────────────────────────────────────────────┘ │
└───────────────────────────────┬─────────────────────────────────┘
                                │ NSXPCConnection
                                │ (çift yönlü kod imzası doğrulaması)
┌───────────────────────────────┴─────────────────────────────────┐
│  KÖK ALANI (root LaunchDaemon)                                   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  FanDaemon                                                  │ │
│  │  ├─ XPCListener: yalnızca imzası doğrulanmış istemci kabul │ │
│  │  ├─ SMCWriter: fan hedef hızı ve modu yazma                │ │
│  │  ├─ SafetyGovernor: mutlak sınırlar, panik eşiği           │ │
│  │  ├─ Watchdog: kalp atışı denetimi → düşerse otomatik geri  │ │
│  │  └─ StateRestorer: çıkış/uyku/kapanışta firmware'e devret  │ │
│  └────────────────────────────────────────────────────────────┘ │
└───────────────────────────────┬─────────────────────────────────┘
                                │ IOKit
┌───────────────────────────────┴─────────────────────────────────┐
│  DONANIM                                                         │
│  AppleSMC  ·  AppleSensors (HID)  ·  AppleSmartBattery  ·  IOPS  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 Tasarımın kilit noktası

**Sıcaklık okumak hiçbir ayrıcalık gerektirmez. Yalnızca fan yazmak gerektirir.**

Bu, mimarinin en önemli sonucudur ve doğrudan İlke 2'ye hizmet eder:

- Kullanıcı daemon'u **hiç kurmasa bile** uygulama tam işlevli bir izleme aracıdır: tüm sensörler, tüm fan hızları, grafikler, log, bildirimler, tanılama.
- Yönetici şifresi **yalnızca** kullanıcı fan kontrolünü etkinleştirmek istediğinde, **tek seferlik** istenir.
- Ayrıcalıklı yüzey mümkün olan en küçük parçaya indirgenmiştir: daemon yalnızca "şu fana şu hedefi yaz" ve "firmware kontrolüne dön" komutlarını bilir. Eğri değerlendirmesi, profil mantığı, yapılandırma okuma — hiçbiri root tarafında değildir.

### 4.3 Güven sınırları

| Sınır | Doğrulama |
|---|---|
| App → Daemon | Daemon, `SecCodeCheckValidity` + `SecRequirement` ile istemcinin Team ID ve bundle ID'sini doğrular. Uyuşmazsa bağlantı reddedilir |
| Daemon → App | App, daemon'un imzasını doğrular; sahte bir daemon'a komut göndermez |
| Daemon → Donanım | `SafetyGovernor` tüm yazmaları süzer; motor bozuk değer gönderse bile donanıma geçmez |
| Config dosyası → Motor | Şema doğrulaması + aralık kısıtları; geçersiz yapılandırma reddedilir, son geçerli hali korunur |

### 4.4 Eşzamanlılık modeli

- Sensör okuma: özel bir `actor SensorPoller`, arka planda sabit periyotla çalışır.
- Kontrol motoru: saf fonksiyonlar (`Sendable` girdi → `Sendable` çıktı), yan etkisiz, kolay test edilir.
- UI güncellemesi: `@MainActor`, `@Observable` model üzerinden.
- XPC: kendi kuyruğu; motor sonucu daemon'a `async` gönderilir.
- **Kural:** Donanım erişen hiçbir kod `@MainActor` üzerinde çalışmaz. Arayüz asla donmaz.

---

## 5. Donanım Erişim Katmanı

### 5.1 Sıcaklık okuma — ayrıcalıksız

Apple Silicon'da sıcaklık sensörleri HID sensör servisleri olarak sunulur. Erişim yolu:

1. `IOHIDEventSystemClient` istemcisi oluşturulur.
2. Eşleştirme sözlüğü ile sıcaklık sensörü sınıfındaki servisler filtrelenir (`PrimaryUsagePage` / `PrimaryUsage`).
3. Her servisten `Product` özelliği okunarak sensörün donanım adı alınır.
4. Her servisten sıcaklık olayı çekilir ve float değer okunur.

**Karakteristikleri:**
- Root **gerektirmez**.
- Sensör adları çipe göre değişir; koda gömülmez, **çalışma zamanında keşfedilir**.
- Ham adlar kullanıcı dostu değildir; §5.5'teki eşleme katmanı gerekir.

⚠️ **Risk kaydı:** Bu API resmî olarak dokümante edilmemiştir. macOS güncellemeleriyle değişebilir.
**Azaltım:** Erişim, `SensorSource` protokolünün arkasına alınır. Birincil kaynak başarısız olursa `SMCSensorSource` (SMC anahtarları üzerinden) yedeğe geçer. İkisi de başarısız olursa uygulama izleme moduna düşer ve kullanıcıyı bilgilendirir; asla çökmez.

📌 **Notarizasyon notu:** Dokümante edilmemiş API kullanımı **App Store inceleme** kuralıdır; **doğrudan dağıtım + notarizasyon** akışını engellemez. Bu proje App Store'da yayınlanmayacağı için (§16.4) engel oluşturmaz. Bu bilinçli bir karardır.

### 5.2 Fan okuma ve yazma — SMC

`AppleSMC` IOService üzerinden dört karakterlik anahtarlarla erişilir.

| İhtiyaç | Anahtar deseni | Yön | Ayrıcalık |
|---|---|---|---|
| Fan sayısı | Fan sayacı anahtarı | Oku | Yok |
| Anlık hız (RPM) | Fan başına "actual" anahtarı | Oku | Yok |
| Minimum hız | Fan başına "min" anahtarı | Oku | Yok |
| Maksimum hız | Fan başına "max" anahtarı | Oku | Yok |
| Hedef hız | Fan başına "target" anahtarı | **Yaz** | **Root** |
| Kontrol modu | Fan başına "mode" anahtarı | **Yaz** | **Root** |

**Fan devralma dizisi (daemon içinde):**
1. Mevcut mod ve hedef okunur, **orijinal durum saklanır** (geri dönüş için).
2. Mod "zorlamalı"ya alınır.
3. Hedef hız yazılır.
4. Bir sonraki döngüde gerçek hız okunur ve hedefle karşılaştırılır; sapma varsa düzeltilir (kapalı çevrim doğrulama).

**Firmware'e geri devretme dizisi:**
1. Hedef, saklanan orijinal değere geri yazılır.
2. Mod "otomatik"e alınır.
3. Doğrulama okuması yapılır; başarısızsa yeniden denenir (üstel geri çekilme, en fazla 5 deneme).

**Veri tipleri:** SMC anahtarları tipli veri döndürür (float, sabit noktalı, işaretsiz tamsayı vb.). Tip bilgisi anahtarla birlikte okunur; **tip varsayılmaz**, çalışma zamanında çözülür. Bilinmeyen tip → sensör atlanır, uyarı loglanır.

### 5.3 Diğer veri kaynakları

| Kaynak | API | Ayrıcalık | Ne verir |
|---|---|---|---|
| Termal baskı | `ProcessInfo.thermalState` | Yok | `nominal` / `fair` / `serious` / `critical` — **tamamen resmî API**, güvenlik zincirinin temeli |
| Güç kaynağı | `IOPSCopyPowerSourcesInfo` | Yok | Adaptör/pil, şarj yüzdesi |
| Pil sağlığı | `AppleSmartBattery` IORegistry | Yok | Döngü sayısı, tasarım/gerçek kapasite, sıcaklık, durum |
| Dahili SSD | NVMe SMART arayüzü | Yok | Disk sıcaklığı, yazılan bayt, kullanım ömrü |
| CPU yükü | `host_processor_info` | Yok | Bağlamlandırma ve "neden ısındı?" analizi için |
| Ön plandaki uygulama | `NSWorkspace` | Yok | Uygulama tetikleyicili profiller için (§7.4) |
| Ekran bağlantısı | `NSScreen` bildirimleri | Yok | Harici ekran tetikleyicisi |

**Not:** Harici disk sıcaklığı ve harici GPU **kapsam dışıdır** (§8.4).

### 5.4 Donanım soyutlaması ve test edilebilirlik

Tüm donanım erişimi protokoller arkasına alınır:

```
protocol SensorSource   { func snapshot() async throws -> [SensorReading] }
protocol FanSource      { func fans() async throws -> [FanState] }
protocol FanActuator    { func apply(_ commands: [FanCommand]) async throws
                          func releaseToFirmware() async throws }
protocol PowerSource    { func current() -> PowerContext }
```

Her biri için üç uygulama bulunur:

1. **Live** — gerçek donanım.
2. **Mock** — birim testler için deterministik, senaryo dosyasından beslenen sahte donanım.
3. **Replay** — kaydedilmiş bir log dosyasını yeniden oynatan kaynak. Kullanıcıdan gelen hata raporlarını **o donanıma sahip olmadan** yeniden üretmeyi sağlar.

Bu, projenin en değerli mühendislik yatırımıdır: kontrol motorunun tamamı Mac fanı döndürmeden, CI'da, saniyeler içinde test edilebilir.

### 5.5 Sensör adlandırma ve gruplama

Ham donanım sensör adları anlaşılır değildir. İki katmanlı çözüm:

1. **Normalleştirme:** Ham ad, kurallı bir dönüştürücüden geçer (önek/sonek temizliği, kısaltma açma, büyük/küçük harf düzeni).
2. **Sınıflandırma:** Normalleştirilmiş ad, desen tabanlı bir kural setiyle bir **gruba** atanır.

Grup taksonomisi (kendi tanımımız):

| Grup | İçerik |
|---|---|
| `compute.performance` | Yüksek performanslı çekirdek kümeleri |
| `compute.efficiency` | Verimlilik çekirdek kümeleri |
| `graphics` | GPU kümeleri |
| `memory` | Bellek yakını sensörler |
| `storage` | Dahili SSD |
| `power` | Güç dağıtımı, şarj devresi |
| `battery` | Pil hücreleri ve yönetim birimi |
| `chassis` | Kasa, alt kapak, klavye çevresi, trackpad |
| `airflow` | Hava giriş/çıkış yolları, soğutucu blok |
| `wireless` | Kablosuz radyo bölgesi |
| `uncategorized` | Eşleşmeyen — arayüzde yine gösterilir |

**Kural:** Eşleşmeyen sensör **asla gizlenmez**. `uncategorized` altında gösterilir ve kullanıcı isterse tek tıkla "bilinmeyen sensör raporu" oluşturup issue açabilir. Bu, yeni çip nesillerine adaptasyonu topluluk eliyle hızlandırır.

**Kullanıcı geçersiz kılması:** Kullanıcı, yapılandırma dosyasından herhangi bir sensöre kendi görünen adını ve grubunu atayabilir.

---

## 6. Ayrıcalık Modeli ve İzinler

### 6.1 İstenen izinlerin tam listesi

| İzin | Ne zaman | Sıklık | Zorunlu mu |
|---|---|---|---|
| Yönetici kimlik doğrulaması | Fan kontrol daemon'u ilk kurulurken | **Tek sefer** | Hayır — atlanırsa izleme modu |
| Arka planda çalışma onayı | Daemon kaydı sırasında | Tek sefer (Sistem Ayarları) | Fan kontrolü için evet |
| Bildirim izni | Kullanıcı bildirimleri açtığında | Tek sefer | Hayır |
| Girişte başlatma | Kullanıcı açarsa | Tek sefer | Hayır |

### 6.2 İstenmeyen izinler — açık taahhüt

Bu liste README'de ve uygulama içinde yayınlanır:

- ❌ SIP (System Integrity Protection) devre dışı bırakma
- ❌ Kernel extension / DriverKit sürücüsü
- ❌ Recovery Mode veya güvenlik politikası değişikliği
- ❌ Tam Disk Erişimi
- ❌ Erişilebilirlik izni
- ❌ Ekran kaydı izni
- ❌ Kamera / mikrofon / konum / kişiler / takvim
- ❌ NVRAM veya firmware değişikliği

### 6.3 Daemon kurulumu

Modern `ServiceManagement` API'si (`SMAppService.daemon`) kullanılır — eski `SMJobBless` akışı **kullanılmaz**.

**Akış:**
1. Kullanıcı arayüzden "Fan kontrolünü etkinleştir" der.
2. Ne olacağı, hangi dosyaların nereye yazılacağı ve nasıl geri alınacağı **açıkça gösterilir**.
3. Daemon kaydedilir; sistem yönetici kimlik doğrulaması ister.
4. macOS, kullanıcıyı Sistem Ayarları'nda onaylamaya yönlendirebilir; uygulama bu durumu algılar ve doğrudan ilgili panele götüren bir yönlendirme gösterir.
5. Bağlantı doğrulanır, sonuç kullanıcıya bildirilir.

**Kaldırma:** Arayüzde tek düğme. `SMAppService.unregister()` çağrılır, fanlar firmware'e devredilir, sonuç doğrulanır. Ayrıca CLI'da `boreas uninstall --all` komutu ve README'de manuel adımlar bulunur.

### 6.4 Ölü adam anahtarı (watchdog) — özgün güvenlik özelliği

Bu, tasarımın ayırt edici güvenlik unsurudur.

- Uygulama, daemon'a düzenli aralıklarla **kalp atışı** gönderir (varsayılan 5 sn).
- Daemon, ardışık **3 kalp atışını** kaçırırsa (≈15 sn) fanları koşulsuz olarak firmware kontrolüne iade eder.
- Bu, şu senaryoların **hepsini** kapsar: uygulama çöktü, `kill -9` ile öldürüldü, donup yanıt vermiyor, kullanıcı oturumu kapandı, XPC bağlantısı koptu.
- Daemon ayrıca şu olaylarda **anında** devreder: sistem uykuya geçiyor, sistem kapanıyor, daemon durduruluyor.
- Zaman aşımı süresi yapılandırılabilir ancak **10–60 sn aralığında kilitlidir**; devre dışı bırakılamaz.

**Tasarım gerekçesi:** Kullanıcı alanındaki bir uygulamanın hatası hiçbir koşulda donanımı savunmasız bırakmamalıdır. Kontrolü elinde tutan taraf (daemon) sağlık denetiminden sorumlu olmalıdır.

---

## 7. Kontrol Motoru

> Bu bölüm ürünün mühendislik kalbidir ve **tamamen özgün bir tasarımdır.** Ayrık "kural listesi" yaklaşımı yerine sürekli transfer fonksiyonu modeli benimsenmiştir.

### 7.1 Temel model: sürekli eğri

Fan davranışı, **parçalı doğrusal bir transfer fonksiyonu** ile tanımlanır:

```
Girdi:  sıcaklık (°C)   →   Çıktı: görev oranı (duty, 0.0 – 1.0)
```

Eğri, sıralı kontrol noktalarından oluşur:

```
[(35, 0.00), (50, 0.20), (65, 0.45), (78, 0.75), (88, 1.00)]
```

- Noktalar arası **doğrusal enterpolasyon** yapılır → çıktı süreklidir, basamak yoktur.
- İlk noktanın altında çıktı ilk noktanın değeridir; son noktanın üstünde son noktanın değeri.
- Sıcaklığa göre **artan sıralı** ve görev oranı **azalmayan** olmak zorundadır; editör bunu zorlar.
- En az 2, en fazla 16 nokta.

**Görev oranı → RPM dönüşümü:**

```
rpm = fanMin + (fanMax − fanMin) × duty
```

Yani `duty = 0` fanı durdurmaz; o fanın donanım minimumuna indirir. `duty = 1` donanım maksimumudur.

**Neden basamak yerine eğri:** Basamaklı bir sistemde fan hızı eşiklerde sıçrar; kulak bu ani değişimi sabit yüksek sesten daha rahatsız edici bulur. Sürekli eğri, hem akustik olarak daha konforlu hem de termal olarak daha kararlıdır.

### 7.2 Histerezis

Eşik çevresinde salınımı (chattering) önlemek için **çift eğri** yöntemi kullanılır:

- **Yükselen eğri:** Tanımlanan eğrinin kendisi.
- **Düşen eğri:** Aynı eğri, sıcaklık ekseninde `H` kadar sola kaydırılmış hali (varsayılan `H = 3 °C`, aralık 0–10 °C).
- Motor, sıcaklığın yönüne göre eğri seçer ve seçilen eğride **kilitli kalır** — ta ki diğer eğriyi kesecek kadar ters yönde hareket olana dek.

Bu, klasik termostat histerezisinin sürekli fonksiyonlara uyarlanmış halidir ve ayrı bir "zaman gecikmesi" ayarına ihtiyaç bırakmaz.

### 7.3 Yumuşatma ve hız sınırlama

Üç aşamalı zincir — her aşama farklı bir problemi çözer:

| Aşama | Ayar | Varsayılan | Çözdüğü problem |
|---|---|---|---|
| **1. Girdi yumuşatma** | EWMA katsayısı `α` | 0.30 | Sensör gürültüsü ve anlık tepe değerler |
| **2. Histerezis** | `H` (°C) | 3.0 | Eşik çevresi salınım |
| **3. Çıktı hız sınırı** | `maxRise` / `maxFall` (RPM/sn) | 600 / 150 | Duyulabilir ani ses değişimleri |

**Asimetrik hız sınırı kritik bir tasarım kararıdır:** Fanın **yükselmesi hızlı** (güvenlik), **düşmesi yavaş** (akustik konfor ve termal kararlılık) olmalıdır. Tek bir "geçiş süresi" ayarı bu asimetriyi ifade edemez.

### 7.4 Profiller ve tetikleyiciler

**Profil** = bir isim + fan başına eğri seti + yumuşatma parametreleri + tetikleyici koşulu + öncelik.

**Yerleşik profiller** (kullanıcı düzenleyebilir veya silebilir):

| Profil | Karakter |
|---|---|
| `Sessiz` | Geç ve yumuşak devreye girer; akustik öncelikli |
| `Dengeli` | Varsayılan; firmware'e yakın ama daha erken tepki |
| `Performans` | Erken ve agresif; throttling'i geciktirmeye odaklı |
| `Sistem` | Motor devre dışı; kontrol tamamen firmware'de |

**Tetikleyici türleri** (birden fazlası `VE` ile birleştirilebilir):

| Tetikleyici | Örnek kullanım |
|---|---|
| Güç kaynağı | Pildeyken `Sessiz`, adaptördeyken `Dengeli` |
| Uygulama çalışıyor / ön planda | Derleme aracı çalışırken `Performans` |
| Zaman aralığı | 23:00–08:00 arası `Sessiz` |
| Pil seviyesi | %20'nin altında `Sessiz` |
| Harici ekran bağlı | Dock'a takılıyken `Performans` |
| Termal durum | `serious` ve üstünde `Performans` |
| Elle seçim | Menü çubuğundan geçici geçersiz kılma |

**Arbitraj kuralları:**
1. Elle seçim varsa her şeyi yener (kullanıcı isterse süreli — "1 saat sonra otomatiğe dön").
2. Aksi halde koşulu sağlanan profiller arasından **en yüksek öncelikli** olan seçilir.
3. Eşitlikte listede önce gelen kazanır.
4. Hiçbiri sağlanmazsa `Dengeli` (yapılandırılabilir varsayılan) kullanılır.
5. Profil geçişlerinde çıktı, hız sınırlayıcıdan geçtiği için ani sıçrama olmaz.

**Fan başına farklı eğri:** Bir profil, her fan için ayrı eğri ve ayrı girdi sensör grubu tanımlayabilir. Birden fazla fanı olan modellerde (ör. 16" dizüstüler, masaüstü modeller) sol/sağ fanları farklı bölgelere bağlamak mümkündür.

### 7.5 Girdi seçimi

Her eğri, bir **sensör toplayıcıya** bağlanır:

```
input:
  group: compute.performance      # veya belirli sensör adları listesi
  aggregate: max                  # max | mean | p95
  smoothing: 0.30
```

`max` varsayılandır (güvenlik yanlı). `mean` daha yumuşak davranış için, `p95` tek bir sapkın sensörün etkisini azaltmak için kullanılır.

### 7.6 Güvenlik zinciri

Motorun çıktısı, donanıma ulaşmadan önce beş katmandan geçer. **Her katman yalnızca yukarı doğru düzeltme yapabilir** — hiçbir katman fanı daha da yavaşlatamaz.

| Katman | Nerede | Kural |
|---|---|---|
| **K1 — Fan tabanı** | Motor | Çıktı hiçbir zaman fanın donanım minimumunun altına inmez |
| **K2 — Termal durum** | Motor | `serious` → taban %55; `critical` → %100 (resmî API, güvenilir) |
| **K3 — Panik eşiği** | Motor | Herhangi bir sensör `T_panic` (varsayılan 95 °C) üstündeyse → %100, en az 30 sn kilitli |
| **K4 — Daemon guard** | Daemon | Gelen komut fizikî sınırların dışındaysa reddedilir ve loglanır |
| **K5 — Watchdog** | Daemon | Kalp atışı yoksa firmware'e devret (§6.4) |

**K2 ve K3 kapatılamaz.** Kullanıcı `T_panic` değerini düşürebilir, yükseltemez.

### 7.7 Durum makinesi

```
                    ┌──────────────┐
      başlangıç ───▶│  MONITORING  │  daemon yok veya kontrol kapalı
                    └──────┬───────┘
                           │ kullanıcı kontrolü açar + daemon hazır
                           ▼
                    ┌──────────────┐
              ┌────▶│  CONTROLLING │◀────┐
              │     └──────┬───────┘     │
              │            │             │ koşullar normale döner
   profil     │            │ K3 tetiklendi
   değişimi   │            ▼             │
              │     ┌──────────────┐     │
              └─────│   PANIC      │─────┘
                    └──────────────┘
                           │ watchdog / uyku / çıkış / hata
                           ▼
                    ┌──────────────┐
                    │  RELEASING   │ → firmware'e devret → MONITORING
                    └──────────────┘
```

Her geçiş loglanır. `RELEASING` durumu idempotenttir; kaç kez çağrılırsa çağrılsın güvenlidir.

---

## 8. Özellik Kapsamı

### 8.1 v0.1 — MVP (ilk çalışan sürüm)

**Amaç:** Tek bir Mac'te, tek bir kişinin gerçekten kullanabileceği en küçük ürün.

- [ ] Sensör keşfi ve okuma (ayrıcalıksız)
- [ ] Fan durumu okuma (sayı, anlık/min/maks RPM)
- [ ] Menü çubuğu öğesi: bir sıcaklık + fan RPM
- [ ] Açılır panel: sensör listesi (gruplu) + fan durumu + profil seçici
- [ ] Daemon kurulumu / kaldırılması, watchdog dahil
- [ ] Manuel fan kontrolü (tek kaydırıcı, tüm fanlar)
- [ ] `Sistem` moduna dönüş
- [ ] Yapılandırma dosyası okuma/yazma
- [ ] Güvenlik zinciri K1–K5 tam olarak
- [ ] Mock donanım katmanı + çekirdek motor birim testleri

### 8.2 v1.0 — Yayınlanabilir sürüm

- [ ] Eğri tabanlı otomatik kontrol (§7.1–7.3), grafik eğri editörü
- [ ] Profil sistemi ve tüm tetikleyiciler (§7.4)
- [ ] Ana pencere: canlı grafikler (Swift Charts), sensör geçmişi, fan geçmişi
- [ ] Ayarlar penceresi (tam)
- [ ] Bildirimler + tekrar bastırma (§12)
- [ ] Log: CSV ve JSONL, döndürme politikası
- [ ] Tanılama paneli (§13)
- [ ] Global kısayollar
- [ ] Yerelleştirme: Türkçe + İngilizce
- [ ] Tam VoiceOver ve klavye erişilebilirliği
- [ ] CLI (`boreas`) — durum, profil değiştirme, kurulum/kaldırma
- [ ] Homebrew cask ile dağıtım
- [ ] İmzalı + notarize edilmiş DMG

### 8.3 v1.1+ — Sonraki dalga

- [ ] Menü çubuğunda mini grafik (sparkline)
- [ ] WidgetKit bildirim merkezi widget'ı
- [ ] App Intents / Shortcuts entegrasyonu (profil değiştir, sıcaklık sorgula)
- [ ] Yerel metrik uç noktası (Prometheus formatı, `127.0.0.1` ile sınırlı, varsayılan kapalı)
- [ ] Otomasyon kancaları: eşik aşımında kullanıcı betiği/webhook çalıştırma
- [ ] Bilinmeyen sensör raporu oluşturucu (topluluk katkısı için)
- [ ] Yapılandırma profillerini içe/dışa aktarma ve paylaşma
- [ ] `Replay` kaynağıyla hata ayıklama modu
- [ ] Sparkle ile uygulama içi güncelleme (Homebrew'a ek olarak)

### 8.4 Kapsam dışı — ve gerekçeleri

Bu liste **bilinçli olarak yapılmayacaklardır**. "Henüz yapılmadı" değil, "yapılmayacak" anlamına gelir.

| Kapsam dışı | Gerekçe |
|---|---|
| **Intel Mac desteği** | Farklı SMC semantiği, farklı sensör topolojisi, farklı throttling davranışı. Kod tabanını ikiye katlar, test yüzeyini üçe. Proje tanımı Apple Silicon |
| **macOS 13 ve altı** | `SMAppService` olgunluğu ve modern SwiftUI için 14.0 eşiği. Geriye uyumluluk maliyeti kazancından büyük |
| **E-posta / SMTP bildirimleri** | Kimlik bilgisi saklama, Keychain yönetimi, 2FA uygulama şifreleri, TLS uyumluluğu, teslimat sorunları — devasa bakım yükü. **Yerine:** webhook + kullanıcı betiği kancası. Kullanıcı isterse `mail` komutunu kendisi çağırır. Daha basit, daha esnek, daha güvenli |
| **Lisanslama / aktivasyon / DRM** | Ücretsiz ve açık kaynak. Yok |
| **Telemetri, analitik, çökme raporlama SDK'sı** | İlke 4. Çökme raporu isteyen kullanıcı, oluşturulan yerel dosyayı **kendisi** issue'ya ekler |
| **Hackintosh / jenerik sensör modu** | M serisi hedefiyle uyumsuz |
| **Harici GPU** | Apple Silicon'da eGPU desteklenmiyor |
| **Harici disk sıcaklığı** | macOS çoğu USB muhafaza için SMART verisi sunmuyor; üçüncü taraf sürücü gerektiriyor. Güvenilir olmayan özellik, kullanıcı hayal kırıklığı üretir |
| **Optik sürücü / Northbridge / PCI sensörleri** | M serisi donanımında karşılığı yok |
| **CPU frekans/voltaj manipülasyonu (undervolt)** | Apple Silicon'da mümkün değil; olsa bile kapsam dışı ve riskli |
| **Kurumsal toplu dağıtım aracı (v1.0'da)** | Ancak yapılandırma dosyası öncelikli tasarım sayesinde MDM ile dağıtım **zaten mümkün** olacak. Ayrı bir araç v2 konusudur |
| **App Store dağıtımı** | Sandbox, ayrıcalıklı daemon'a izin vermiyor. Teknik olarak imkânsız |
| **Windows / Linux** | İlgisiz |

### 8.5 Ayırt edici özellikler

Bu proje, kategorideki araçlardan şu noktalarda **yapısal olarak farklılaşır**:

1. **Sürekli eğri + çift eğri histerezis + asimetrik hız sınırlama.** Ayrık kural listelerine göre daha kararlı, daha sessiz, daha öngörülebilir.
2. **Ölü adam anahtarı.** Kontrolü elinde tutan katman, kendi sağlığını denetler.
3. **Bağlam farkında profiller.** Ön plandaki uygulama, saat, ekran bağlantısı gibi tetikleyiciler.
4. **Kayıt/yeniden oynatma altyapısı.** Sahip olmadığımız donanımdaki hataları yeniden üretebilme.
5. **İnsan tarafından düzenlenebilir, sürüm kontrolüne alınabilir yapılandırma.** Dotfiles ile taşınabilir.
6. **Sıfır telemetri, sıfır ağ (varsayılan).**
7. **Bilinmeyen sensörleri gizlemek yerine gösterip topluluktan katkı isteme.**
8. **Türkçe birinci sınıf dil.** Bu kategoride nadir.

---

## 9. Kullanıcı Arayüzü

### 9.1 Tasarım dili — özgün kimlik

Görsel kimlik sıfırdan tasarlanır. Bağlayıcı kararlar:

| Öğe | Karar |
|---|---|
| Temel yaklaşım | macOS 26 tasarım dili; sistem malzemeleri, sistem tipografisi (SF Pro), sistem vurgusu |
| Renk sistemi | **Sıcaklık için ayrı, fan için ayrı bir skala kullanılır.** Sıcaklık: soğuk mavi → nötr → sıcak turuncu geçişli sürekli bir skala. Fan: nötr gri tonlarında doluluk. Kırmızı **yalnızca** panik/hata durumları için ayrılmıştır |
| Neden sürekli skala | Ayrık üç renkli bant, sürekli eğri felsefesiyle çelişir. Sürekli veri sürekli görselleştirilir |
| İkonografi | SF Symbols temelli; özel ikon yalnızca uygulama simgesi |
| Uygulama simgesi | Özgün tasarım; hava akışı / rüzgâr temalı soyut form. Fan pervanesi klişesinden **kaçınılır** |
| Yoğunluk | Bilgi yoğun ama nefes alan; menü çubuğu paneli tek bakışta okunabilir |
| Karanlık/aydınlık | İkisi de birinci sınıf, sistem tercihini izler |
| Animasyon | Yalnızca anlam taşıyanlar; değer değişimlerinde yumuşak geçiş, dekoratif animasyon yok |

**Metin ilkesi:** Tüm arayüz metinleri sıfırdan yazılır. Sade, doğrudan, jargonsuz. Türkçe metinler İngilizceden çeviri gibi durmaz — **Türkçe düşünülerek yazılır**, İngilizce sürüm ayrıca yazılır.

### 9.2 Menü çubuğu

**Durum öğesi:**
- Yapılandırılabilir içerik: birincil sıcaklık, ikincil sıcaklık, fan RPM, mini grafik — istenen kombinasyon
- Yatay veya dikey yerleşim
- Kompakt mod (yalnızca sayılar, birimsiz)
- Aktif profil göstergesi; elle geçersiz kılma varsa ayırt edici işaret
- Fan kontrolü aktifken belirgin ama rahatsız etmeyen bir gösterge
- Menü çubuğunda yer kalmadığında (çentik dahil) kullanıcıyı bilgilendiren ve kompakt moda geçmeyi öneren bir uyarı

**Açılır panel (SwiftUI, `MenuBarExtra` window stili):**

```
┌────────────────────────────────────┐
│  Profil:  [Dengeli ▾]  [Geçici ▾] │   ← tek tıkla profil değiştirme
├────────────────────────────────────┤
│  FANLAR                            │
│  Sol      2 340 RPM  ▓▓▓▓▓░░░░ 42%│
│  Sağ      2 280 RPM  ▓▓▓▓░░░░░ 40%│
├────────────────────────────────────┤
│  SICAKLIKLAR                       │
│  Performans çekirdekler     68 °C  │   ← grup başlıkları katlanabilir
│  Verimlilik çekirdekler     54 °C  │
│  Grafik işlemci             61 °C  │
│  Depolama                   47 °C  │
│  ⌄ Tümünü göster                   │
├────────────────────────────────────┤
│  Ana pencere            ⌥⇧⌘M       │
│  Ayarlar…                 ⌘,       │
│  Çıkış                    ⌘Q       │
└────────────────────────────────────┘
```

Panel açıkken de veriler canlı güncellenir; ölçüm döngüsü **durmaz**.

### 9.3 Ana pencere

Üç sekme:

**① İzleme**
- Üst şerit: özet kartlar (en yüksek sıcaklık, ortalama, aktif profil, termal durum, fan ortalaması)
- Zaman serisi grafiği (Swift Charts): seçilebilir sensörler, 5 dk / 1 sa / 6 sa / 24 sa pencereleri
- Fan RPM grafiği aynı zaman ekseninde — sıcaklık ve fan tepkisi görsel olarak hizalanır
- Sensör tablosu: ad, grup, anlık, en yüksek (oturum), ortalama; sıralanabilir, filtrelenebilir
- "En yüksekleri sıfırla" eylemi

**② Kontrol**
- Aktif profil ve neden aktif olduğu (hangi tetikleyici sağlandı) — **şeffaflık önemli**
- Eğri editörü (§9.4)
- Fan başına eşleme: hangi fan, hangi sensör grubuna bağlı
- Manuel geçersiz kılma: kaydırıcı + süre seçici ("30 dk sonra otomatiğe dön")
- Güvenlik zinciri durumu: hangi katman şu an aktif müdahale ediyor

**③ Tanılama**
- §13'teki kontroller
- Sistem bilgisi ve keşfedilen donanım özeti
- Log dosyasını açma / Finder'da gösterme
- Destek raporu oluşturma (yerel dosya; **otomatik gönderim yok**)

### 9.4 Eğri editörü

Ürünün imza arayüzü.

- X ekseni sıcaklık, Y ekseni fan görev oranı
- Kontrol noktaları sürüklenebilir; çift tıkla ekleme, sağ tıkla silme
- Monotonluk kısıtı sürükleme sırasında zorlanır (nokta geçersiz konuma gitmez)
- **Canlı katmanlar:**
  - Anlık çalışma noktası, eğri üzerinde hareketli bir işaretle
  - Son 60 saniyenin izi, soluk bir bulut olarak — gerçek davranışı eğriyle karşılaştırma imkânı
  - Histerezis bandı gölgeli alan olarak
- Sayısal düzenleme: her nokta tablo üzerinden de girilebilir (erişilebilirlik ve hassasiyet)
- Hazır şablonlar: `Sessiz`, `Dengeli`, `Performans` başlangıç noktası olarak
- Geri al / yinele
- Yan panelde canlı parametreler: histerezis, yumuşatma, yükselme/düşme hızı — hepsi grafikte anında yansır

### 9.5 Ayarlar

Sekmeler: **Genel · Görünüm · Sensörler · Kontrol · Bildirimler · Kayıt · Gelişmiş**

| Sekme | İçerik |
|---|---|
| **Genel** | Girişte başlat, arka planda çalış, güncelleme kontrolü, dil, ölçüm aralığı |
| **Görünüm** | Menü çubuğu içeriği ve yerleşimi, birim (°C/°F), renk skalası, kompakt mod |
| **Sensörler** | Sensör listesi, özel adlandırma, grup atama, gizleme, `uncategorized` raporu |
| **Kontrol** | Profil yönetimi, tetikleyiciler, öncelik sırası, varsayılan profil, panik eşiği |
| **Bildirimler** | Tetikleyiciler, eşikler, bastırma penceresi, ses |
| **Kayıt** | Log açık/kapalı, format, konum, döndürme, hangi alanlar |
| **Gelişmiş** | Daemon durumu ve kur/kaldır, watchdog süresi, ayrıntılı log, yapılandırmayı dışa/içe aktar, fabrika ayarlarına dön |

### 9.6 Erişilebilirlik — pazarlık konusu değil

- Tüm etkileşimli öğeler klavyeyle erişilebilir; mantıklı odak sırası
- Grafikler ve eğri editörü için VoiceOver açıklamaları; eğri, nokta listesi olarak da sunulur
- `Increase Contrast`, `Reduce Motion`, `Reduce Transparency` sistem ayarlarına uyum
- Renk **tek başına** bilgi taşımaz — daima sayı veya etiketle desteklenir
- Dinamik tip desteği; sabit piksel yükseklikli metin kutusu yok
- Menü çubuğu öğesi anlamlı bir erişilebilirlik etiketi sunar

### 9.7 Yerelleştirme

#### Uygulama arayüzü — 5 dil, v1.0'da eksiksiz

| Kod | Dil | Not |
|---|---|---|
| `en` | English | **Kaynak dil.** Tüm anahtarlar önce burada yazılır |
| `tr` | Türkçe | Çeviri değil, Türkçe düşünülerek yazılır |
| `ru` | Русский | Uzun dizeler — düzen esnekliği kritik |
| `es` | Español | |
| `zh-Hans` | 简体中文 | Basitleştirilmiş Çince. Geleneksel (`zh-Hant`) sonraki dalga |

#### Teknik kurallar

- **String Catalog** (`.xcstrings`) tek kaynak; her dil aynı katalogda
- Metinler kodda sabit yazılmaz; `String(localized:)` zorunlu, **lint kuralı ile denetlenir**
- Her dize için `comment` alanı zorunlu — çevirmen bağlam olmadan doğru çeviremez
- Çoğul kuralları `AttributedString` / `.stringsdict` semantiğiyle; Rusça'nın üç çoğul biçimi (`one`/`few`/`many`) doğru ele alınmalı
- Sıcaklık birimi, sayı ve tarih biçimleri `Locale` ve `Measurement` üzerinden — elle biçimlendirme yasak
- Sıralama ve arama `localizedStandardCompare` ile

#### Düzen sonucu — 5 dil UI'yi bağlar

Rusça ve Almanca dizeler İngilizcenin **%30–50 fazlası** uzunlukta olabilir; Çince ise belirgin biçimde kısadır. Bu, §9.6'daki kuralı genişletir:

> Sabit piksel **genişlikli** veya **yükseklikli** metin kabı yoktur. Tüm etiketler içeriğe göre büyür, gerekirse sarar. Menü çubuğu öğesi hariç hiçbir yerde kısaltma (`…`) ile taşma çözülmez.

Bu kural CI'da pseudo-locale (yapay uzatılmış dize) testiyle denetlenir.

#### Çeviri bakımı

- `TRANSLATORS.md` — her dil için sorumlu katkıcılar
- Yeni bir dize eklendiğinde çeviriler eksikse CI **uyarı** verir (hata değil — sürümü engellemez)
- Eksik çeviri çalışma zamanında kaynak dile (`en`) düşer, asla boş görünmez
- Ek dil katkısı topluluğa açık; süreç `CONTRIBUTING.md` içinde

#### Dokümantasyon — farklı kural

Arayüz 5 dilde, **dokümantasyon değil.** Gerekçe: README dışındaki dokümanlar sık değişir ve 5 dilde senkron tutulamaz; bayat çeviri, çevirisizlikten daha zararlıdır.

| Dosya | Diller |
|---|---|
| `README.md` | **İngilizce (yetkili sürüm)** |
| `README.tr.md` · `README.ru.md` · `README.es.md` · `README.zh-Hans.md` | Çeviri; her birinin başında "bu çeviri geride kalmış olabilir, yetkili sürüm İngilizcedir" notu |
| `CONTRIBUTING.md` · `SECURITY.md` · `docs/**` | Yalnızca İngilizce |
| Issue/PR şablonları | Yalnızca İngilizce |
| Kod, yorum, commit mesajı | Yalnızca İngilizce |

README çevirileri yüksek değerlidir (keşfedilebilirlik — §18.4) ve v1.0 sonrası seyrek değişir, bu yüzden bakımı sürdürülebilir. CI, `README.md` değiştiğinde çeviriler güncellenmediyse bir uyarı etiketi düşer.

---

## 10. Yapılandırma

### 10.1 Format ve konum

- **Format:** JSON (Codable-native, sıfır bağımlılık, şema doğrulanabilir, araç dostu)
- **Konum:** `~/Library/Application Support/<ürün>/config.json`
- **Şema:** Repoda `schema/config.schema.json` olarak yayınlanır ve sürümlenir
- **Sürümleme:** Dosyada `schemaVersion` alanı; eski sürümler otomatik göç ettirilir, göç öncesi yedek alınır
- **Yedekleme:** Her başarılı yazımdan önce `config.backup.json`

### 10.2 Örnek yapılandırma

```json
{
  "schemaVersion": 1,
  "general": {
    "samplingIntervalSeconds": 2,
    "temperatureUnit": "celsius",
    "launchAtLogin": true,
    "language": "auto"
  },
  "safety": {
    "panicTemperatureCelsius": 95,
    "panicHoldSeconds": 30,
    "watchdogTimeoutSeconds": 15
  },
  "profiles": [
    {
      "id": "balanced",
      "name": "Dengeli",
      "priority": 100,
      "triggers": [],
      "smoothing": { "alpha": 0.30, "hysteresisCelsius": 3.0 },
      "slew": { "maxRiseRpmPerSecond": 600, "maxFallRpmPerSecond": 150 },
      "fanCurves": [
        {
          "fanSelector": "all",
          "input": { "group": "compute.performance", "aggregate": "max" },
          "points": [
            { "temperatureCelsius": 40, "duty": 0.00 },
            { "temperatureCelsius": 55, "duty": 0.20 },
            { "temperatureCelsius": 68, "duty": 0.45 },
            { "temperatureCelsius": 80, "duty": 0.75 },
            { "temperatureCelsius": 90, "duty": 1.00 }
          ]
        }
      ]
    },
    {
      "id": "quiet-night",
      "name": "Gece Sessizliği",
      "priority": 200,
      "triggers": [
        { "type": "timeRange", "from": "23:00", "to": "08:00" },
        { "type": "powerSource", "value": "battery" }
      ],
      "smoothing": { "alpha": 0.20, "hysteresisCelsius": 5.0 },
      "slew": { "maxRiseRpmPerSecond": 300, "maxFallRpmPerSecond": 100 },
      "fanCurves": [ "..." ]
    }
  ],
  "sensorOverrides": [
    { "match": "…", "displayName": "Ana çekirdek kümesi", "group": "compute.performance" }
  ],
  "notifications": {
    "enabled": true,
    "suppressionWindowMinutes": 15,
    "rules": [
      { "type": "temperatureAbove", "group": "compute.performance", "celsius": 92 },
      { "type": "thermalStateAtLeast", "value": "serious" },
      { "type": "fanAnomaly" }
    ]
  },
  "logging": {
    "enabled": false,
    "format": "jsonl",
    "path": "~/Library/Logs/<ürün>/",
    "rotation": { "mode": "daily", "keepDays": 14 },
    "fields": ["timestamp", "sensors", "fans", "profile", "safetyLayer"]
  }
}
```

### 10.3 Doğrulama kuralları

Yapılandırma yüklenirken **sıkı** doğrulanır:

- Eğri noktaları sıcaklığa göre artan sıralı ve görev oranı azalmayan olmalı
- Görev oranı `[0.0, 1.0]`, sıcaklık `[0, 120]` aralığında
- `panicTemperatureCelsius` ∈ `[70, 105]`
- `watchdogTimeoutSeconds` ∈ `[10, 60]`
- `samplingIntervalSeconds` ∈ `[1, 60]`
- Profil `id` değerleri benzersiz
- Bilinmeyen alanlar **hata değil uyarıdır** (ileri uyumluluk), loglanır

**Geçersiz yapılandırma davranışı:** Uygulama başlamayı reddetmez. Son geçerli yapılandırmaya döner, kullanıcıya net bir hata mesajı ve hangi satırın sorunlu olduğunu gösterir. Fanlar bu süreçte firmware kontrolündedir.

---

## 11. Gözlemlenebilirlik

### 11.1 Uygulama içi log

- `OSLog` / `Logger` kullanılır; kategoriler: `sensor`, `fan`, `engine`, `daemon`, `xpc`, `ui`, `config`
- Seviyeler: `debug` (varsayılan kapalı), `info`, `notice`, `error`, `fault`
- **Hiçbir log satırı kişisel veri içermez.** Kullanıcı adı, dosya yolları, ağ bilgisi loglanmaz

### 11.2 Ölçüm kaydı (kullanıcı isteğine bağlı)

| Format | Kullanım |
|---|---|
| **JSONL** | Varsayılan. Satır başına bir örnekleme; araçlarla işlemesi kolay, şema evrimine dayanıklı |
| **CSV** | Tablo uygulamalarına doğrudan aktarım isteyenler için |

**Döndürme:** günlük veya boyut tabanlı; varsayılan 14 gün saklama. Disk dolmasına karşı sert üst sınır (varsayılan 500 MB) — aşılırsa en eski dosyalar silinir ve kullanıcı bilgilendirilir.

### 11.3 Metrik dışa aktarımı (v1.1)

- Prometheus metin formatında yerel HTTP uç noktası
- **Yalnızca `127.0.0.1`**, yapılandırılabilir port, **varsayılan kapalı**
- Açıldığında arayüzde kalıcı bir gösterge belirir — kullanıcı ağ dinlendiğini her zaman bilir
- Homelab kullanıcıları için Grafana panosu örneği repoda sunulur

---

## 12. Bildirimler ve Otomasyon

### 12.1 Bildirim tetikleyicileri

| Tetikleyici | Varsayılan |
|---|---|
| Sensör grubu eşiği aştı | Kapalı (kullanıcı eşiği belirler) |
| Termal durum `serious` veya üstü | Açık |
| Panik katmanı devreye girdi | Açık |
| Fan anomalisi tespit edildi | Açık |
| Daemon bağlantısı koptu / watchdog devreye girdi | Açık |
| Profil değişti | Kapalı |
| Pil sağlığı bozuldu | Açık |

### 12.2 Gürültü kontrolü

- **Bastırma penceresi:** Aynı türden bildirim, varsayılan 15 dakika içinde tekrarlanmaz (yapılandırılabilir, 1–120 dk)
- **Oturum başına bir kez:** Donanım sağlığı bildirimleri (pil, fan anomalisi) uygulama açılışı başına yalnızca bir kez
- **Toplama:** Aynı anda birden fazla sensör eşiği aşarsa tek bildirimde birleştirilir
- **Sessiz saatler:** Bildirimler için ayrı zaman aralığı tanımlanabilir; macOS Odak modlarına da saygı duyulur

### 12.3 Otomasyon kancaları (v1.1) — e-postanın yerine geçen tasarım

E-posta yerine iki genel mekanizma:

**① Webhook**
```json
{ "type": "webhook", "url": "https://…", "method": "POST", "template": "…" }
```
Kullanıcı kendi Slack/Discord/ntfy/Home Assistant entegrasyonunu kurar.

**② Kabuk komutu**
```json
{ "type": "command", "path": "~/bin/on-hot.sh", "arguments": ["${sensor}", "${celsius}"] }
```

**Güvenlik önlemleri:** Komut kancası varsayılan **kapalı**; açılırken açık uyarı gösterilir. Komut kullanıcı ayrıcalıklarıyla çalışır, **asla daemon içinde değil**. Zaman aşımı ve eşzamanlılık sınırı uygulanır.

**Gerekçe:** Bu yaklaşım, SMTP istemcisi yazmaktan çok daha az kod, çok daha az saldırı yüzeyi ve çok daha fazla esneklik sunar. Kimlik bilgisi saklama sorumluluğu tamamen ortadan kalkar.

---

## 13. Tanılama

Donanım sağlığı hakkında **iddialı olmayan, dürüst** bir görünüm sunulur.

| Kontrol | Yöntem | Çıktı |
|---|---|---|
| **Fan tepkisi** | Hedef ve gerçek RPM arasındaki sapma zaman içinde izlenir | Fan komutu izliyor / gecikmeli / yanıt vermiyor |
| **Fan dengesi** | Çok fanlı modellerde fanlar arası RPM farkı | Dengeli / anormal fark var |
| **Sensör geçerliliği** | Sabit takılan, aralık dışı veya kaybolan sensörler | Sağlıklı / şüpheli okuma |
| **Termal geçmiş** | Oturum boyunca `serious`/`critical` durumda geçen süre | Süre ve tepe değerler |
| **Pil sağlığı** | Döngü sayısı, kapasite oranı, sıcaklık | Bilgilendirici özet |
| **Depolama sağlığı** | NVMe SMART temel alanları | Bilgilendirici özet |

**Dürüstlük kuralı:** Uygulama, kesin olarak bilemeyeceği bir şeyi kesinmiş gibi söylemez. "Fan arızalı" demez; **"Fan komuta beklenen şekilde yanıt vermiyor — sebebi toz birikmesi, kablo bağlantısı veya donanım arızası olabilir"** der ve kullanıcıya sonraki adımları önerir. Yanlış pozitif bir "arızalı" etiketi, kullanıcıyı gereksiz servise gönderir.

---

## 14. Güvenlik ve Gizlilik

### 14.1 Uygulama sertleştirme

| Önlem | Durum |
|---|---|
| Hardened Runtime | Zorunlu |
| Kütüphane doğrulaması | Açık |
| Apple notarizasyonu | Her sürümde zorunlu |
| Code signing (Developer ID) | Zorunlu |
| XPC istemci/sunucu imza doğrulaması | Çift yönlü, zorunlu |
| Yazılabilir bellekte kod çalıştırma | Devre dışı |
| Ağ istemcisi yetkisi | Yalnızca güncelleme kontrolü için; varsayılan kapalı olabiliyorsa kapalı |

### 14.2 Daemon güvenlik yüzeyi

Daemon'un tüm XPC arayüzü kasıtlı olarak minimaldir:

```
protocol FanControlProtocol {
    func describeFans()                        // salt okunur
    func applyTargets(_ targets: [FanTarget])  // sınırlar dahilinde
    func releaseToFirmware()
    func heartbeat(nonce:)
}
```

- Dosya yolu, komut, betik veya rastgele veri **kabul etmez**
- Yapılandırma **okumaz** — root tarafında ayrıştırılacak hiçbir kullanıcı verisi yoktur
- Ağ erişimi **yoktur**
- Gelen her `FanTarget` fizikî sınırlara karşı doğrulanır; aralık dışıysa reddedilir ve loglanır

### 14.3 Gizlilik taahhüdü

README'de ve uygulama içinde yayınlanır:

- Hiçbir kullanım verisi toplanmaz veya iletilmez
- Analitik SDK'sı, çökme raporlama SDK'sı, reklam kimliği yoktur
- Varsayılan durumda uygulama **hiçbir ağ bağlantısı kurmaz**
- Güncelleme kontrolü açıksa yalnızca sürüm bilgisi indirilir; kullanıcı hakkında veri gönderilmez
- Tüm veriler kullanıcının makinesinde, kullanıcının erişebildiği dosyalarda kalır

### 14.4 Güvenlik açığı bildirimi

`SECURITY.md`: sorumlu açıklama süreci, iletişim adresi, hedef yanıt süresi (72 saat), kapsam tanımı.

---

## 15. Test Stratejisi

### 15.1 Katmanlar

| Katman | Kapsam | Araç |
|---|---|---|
| **Birim** | Eğri değerlendirme, histerezis, hız sınırlama, arbitraj, güvenlik zinciri, yapılandırma doğrulama, göç | Swift Testing |
| **Özellik (property-based)** | Motor değişmezleri: "çıktı asla `[min, max]` dışına çıkmaz", "K2/K3 çıktıyı asla düşürmez", "monoton eğri monoton çıktı üretir" | Swift Testing + üretilmiş girdiler |
| **Altın dosya (golden)** | Kaydedilmiş termal senaryolar → beklenen fan komut dizisi | Repoda `Tests/Fixtures/` |
| **Entegrasyon** | XPC el sıkışması, daemon kur/kaldır, watchdog zaman aşımı | Sahte daemon + gerçek daemon |
| **Donanım duman testi** | Gerçek Mac'te devral/geri ver döngüsü | Elle çalıştırılan betik |
| **UI** | Kritik akışlar: kurulum, profil değiştirme, eğri düzenleme | XCUITest |
| **Erişilebilirlik** | VoiceOver etiket kapsamı, klavye gezinme | Denetim listesi + otomatik kontrol |

### 15.2 Kritik test senaryoları

Bunlar geçmeden hiçbir sürüm yayınlanmaz:

- [ ] Uygulama `kill -9` ile öldürüldüğünde fanlar ≤ watchdog süresi içinde firmware'e döner
- [ ] Sistem uykuya girdiğinde fanlar firmware'e devredilir
- [ ] Daemon kurulu değilken uygulama tam işlevli izleme yapar, hiçbir hata göstermez
- [ ] Bozuk yapılandırma dosyası uygulamayı çökertmez; son geçerli hale döner
- [ ] `T_panic` aşıldığında çıktı %100 olur ve tutma süresi boyunca kilitli kalır
- [ ] Termal durum `critical` olduğunda kullanıcı eğrisi ne olursa olsun çıktı %100 olur
- [ ] Sensör kaynağı hata verdiğinde uygulama izleme moduna düşer, çökmez
- [ ] Fanı olmayan bir modelde (varsa) uygulama anlamlı davranır
- [ ] Profil geçişinde fan hızı sıçraması olmaz (hız sınırlayıcı devrede)
- [ ] Şema göçü, eski yapılandırmayı veri kaybı olmadan taşır

### 15.3 CI

GitHub Actions, `macos-latest` (arm64) koşucu:

1. `swift-format --lint` + `SwiftLint`
2. `xcodegen generate`
3. Derleme (uyarılar hata sayılır)
4. Birim + özellik + altın dosya testleri
5. Kod kapsamı raporu (çekirdek motor için hedef ≥ %85)
6. Etiketli sürümlerde: imzalama, notarizasyon, DMG üretimi, release'e ekleme

**Donanım gerektiren testler CI'da çalışmaz** — Mock katmanı sayesinde motorun tamamı yine de test edilir. Bu, §5.4'teki yatırımın karşılığıdır.

### 15.4 Donanım kapsama sınırları

Geliştirme donanımı tek bir modeldir: **Mac mini (M4, 2024) — `Mac16,10`**, tek fanlı masaüstü. Bu, kapsamı doğrudan belirler ve dürüstçe yönetilmesi gerekir.

| Kod yolu | Gerçek donanımda | Nasıl doğrulanacak |
|---|---|---|
| M4 nesli sensör keşfi ve gruplama | ✅ | Doğrudan |
| Tek fan devral / geri ver döngüsü | ✅ | Doğrudan |
| Güvenlik zinciri K1–K5, watchdog | ✅ | Doğrudan |
| Masaüstü (pilsiz) kod yolu | ✅ | Doğrudan |
| Termal baskı yükselmesi | ✅ | Yük testiyle |
| **Fansız model davranışı** | ❌ | Mock + topluluk raporu |
| **Çok fanlı arbitraj, fan başına eğri** | ❌ | Mock + topluluk raporu |
| **Pil / güç kaynağı tetikleyicileri** | ❌ | Mock + topluluk raporu |
| **Pil sağlığı tanılaması** | ❌ | Mock + topluluk raporu |
| **M1 / M2 / M3 sensör adlandırması** | ❌ | Mock + topluluk raporu |

**Bunun üç sonucu var ve üçü de bağlayıcıdır:**

1. **Mock ve Replay katmanları M1 kilometre taşında inşa edilir**, sonraya bırakılamaz. Doğrulanamayan her kod yolu yalnızca bu katman sayesinde test edilebilir hale gelir. Bu, projenin sürdürülebilirlik şartıdır.
2. **README'de "Test edilen donanım" bölümü zorunludur** (§18.1). Test edilmemiş model sınıfları açıkça listelenir. Bu kategoride güveni kazandıran şey, kapsamı abartmamaktır.
3. **Doğrulanmamış kod yolları için özel issue şablonu** bulunur (`unknown_sensor.yml` ve benzeri). Kullanıcıdan gelen log, `Replay` kaynağıyla geliştirme makinesinde yeniden oynatılabilir — sahip olunmayan donanımdaki hatayı üretmenin tek yolu budur.

---

## 16. Derleme, İmzalama ve Dağıtım

### 16.1 Yerel geliştirme

```bash
brew bundle          # xcodegen, swiftlint, swift-format, xcbeautify
xcodegen generate
open <ürün>.xcodeproj
```

Makefile hedefleri: `make bootstrap`, `make build`, `make test`, `make lint`, `make format`, `make release`, `make clean`.

### 16.2 İmzalama ve notarizasyon

- Developer ID Application sertifikası ile imzalama (uygulama + daemon + CLI, hepsi ayrı ayrı)
- Hardened Runtime açık, gerekli entitlement'lar minimumda
- `notarytool` ile notarizasyon, ardından `stapler` ile bilet ekleme
- CI'da sırlar GitHub Actions secrets üzerinden; **anahtarlar repoya asla girmez**
- Notarizasyon başarısız olursa sürüm yayınlanmaz — CI bu adımda kırılır

### 16.3 Dağıtım kanalları

| Kanal | Öncelik | Not |
|---|---|---|
| **GitHub Releases** (imzalı, notarize DMG) | Birincil | SHA-256 sağlaması yayınlanır |
| **Homebrew Cask** | Birincil | `brew install --cask <ürün>` — kurulum ve güncellemenin en kolay yolu |
| Sparkle ile uygulama içi güncelleme | v1.1 | EdDSA imzalı appcast |
| Mac App Store | ❌ | Sandbox ayrıcalıklı daemon'a izin vermiyor — teknik olarak imkânsız |

### 16.4 Sürümleme

- **Semantic Versioning** (`MAJOR.MINOR.PATCH`)
- `CHANGELOG.md` — [Keep a Changelog](https://keepachangelog.com) biçimi
- Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- Etiketler: `v1.0.0`
- Yapılandırma şeması ayrı sürümlenir; şema kırılması MAJOR gerektirir

---

## 17. Depo Yapısı

### 17.1 Dizin ağacı

```
boreas-mac-fan-control/
├── README.md                     # İngilizce, yetkili sürüm — §18'e göre
├── README.tr.md                  # Türkçe çeviri
├── README.ru.md                  # Rusça çeviri
├── README.es.md                  # İspanyolca çeviri
├── README.zh-Hans.md             # Basitleştirilmiş Çince çeviri
├── BLUEPRINT.md                  # bu belge
├── LICENSE                       # Apache-2.0
├── NOTICE                        # atıflar ve teşekkürler
├── TRANSLATORS.md                # dil başına sorumlu katkıcılar
├── CHANGELOG.md
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── Makefile
├── Brewfile
├── project.yml                   # XcodeGen
├── .swiftlint.yml
├── .swift-format
├── .editorconfig
├── .gitignore
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   └── release.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── feature_request.yml
│   │   └── unknown_sensor.yml   # yeni donanım raporu
│   └── PULL_REQUEST_TEMPLATE.md # §2.4 beyanını içerir
│
├── Packages/
│   ├── Core/                     # saf mantık — IOKit YOK, test edilebilir
│   │   ├── Sources/Core/
│   │   │   ├── Models/           # SensorReading, FanState, Profile, Curve…
│   │   │   ├── Engine/           # CurveEvaluator, Hysteresis, SlewLimiter,
│   │   │   │                     # ProfileArbiter, SafetyChain
│   │   │   ├── Config/           # şema, kodlama, doğrulama, göç
│   │   │   └── Telemetry/        # log biçimlendirme, toplama
│   │   └── Tests/CoreTests/
│   │
│   ├── HardwareKit/              # IOKit sarmalayıcıları + protokoller
│   │   ├── Sources/HardwareKit/
│   │   │   ├── Protocols/        # SensorSource, FanSource, FanActuator…
│   │   │   ├── Live/             # gerçek donanım uygulamaları
│   │   │   ├── Mock/             # deterministik sahte donanım
│   │   │   ├── Replay/           # log tabanlı yeniden oynatma
│   │   │   └── Discovery/        # sensör keşfi, normalleştirme, gruplama
│   │   └── Tests/HardwareKitTests/
│   │
│   └── SharedIPC/                # XPC protokol tanımları (app + daemon ortak)
│       └── Sources/SharedIPC/
│
├── App/                          # SwiftUI uygulaması
│   ├── Sources/
│   │   ├── AppEntry.swift
│   │   ├── MenuBar/
│   │   ├── MainWindow/
│   │   ├── CurveEditor/
│   │   ├── Settings/
│   │   ├── Notifications/
│   │   ├── DaemonClient/
│   │   └── DesignSystem/         # renk skalaları, tipografi, bileşenler
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   └── Localizable.xcstrings # en, tr, ru, es, zh-Hans
│   └── Info.plist
│
├── Daemon/                       # ayrıcalıklı yardımcı
│   ├── Sources/
│   │   ├── main.swift
│   │   ├── XPCListener.swift
│   │   ├── SMCWriter.swift
│   │   ├── SafetyGovernor.swift
│   │   ├── Watchdog.swift
│   │   └── StateRestorer.swift
│   ├── Launchd.plist
│   └── Info.plist
│
├── CLI/                          # boreas komut satırı aracı
│   └── Sources/
│
├── Widget/                       # WidgetKit (v1.1)
│
├── schema/
│   └── config.schema.json
│
├── docs/
│   ├── architecture.md
│   ├── control-engine.md         # motorun matematiği
│   ├── hardware-access.md        # SMC/HID erişim notları
│   ├── security-model.md
│   ├── configuration.md
│   ├── troubleshooting.md
│   ├── contributing-sensors.md   # yeni donanım desteği ekleme rehberi
│   └── images/
│
├── Tests/
│   ├── Fixtures/                 # altın dosya senaryoları
│   └── UITests/
│
└── scripts/
    ├── bootstrap.sh
    ├── sign-and-notarize.sh
    ├── make-dmg.sh
    ├── smoke-test-hardware.sh
    └── rename-product.sh         # §17.4
```

### 17.2 Katman kuralları

Derleme zamanında zorlanan bağımlılık yönü:

```
App  ──▶ Core, HardwareKit, SharedIPC
CLI  ──▶ Core, HardwareKit, SharedIPC
Daemon ──▶ HardwareKit (yalnızca yazma yüzeyi), SharedIPC
Core ──▶ (hiçbir şey — Foundation dışında)
HardwareKit ──▶ Core (yalnızca model tipleri)
```

**`Core` asla IOKit'e, SwiftUI'ya veya AppKit'e bağlanmaz.** Bu kural, motorun CI'da donanımsız test edilebilmesinin tek garantisidir ve ihlali CI'da yakalanır.

### 17.3 Kodlama standartları

- `swift-format` ile biçimlendirme, `SwiftLint` ile kural denetimi — ikisi de CI'da zorunlu
- Genel API'ler için dokümantasyon yorumu zorunlu
- `Core` içinde zorla açma (`!`) yasak; lint kuralı ile denetlenir
- Tüm kullanıcıya görünen metinler yerelleştirme kataloğundan
- Sihirli sayı yok — tüm eşikler adlandırılmış sabitler veya yapılandırma alanları
- Türkçe karakter kod tanımlayıcılarında kullanılmaz; yorumlar ve dokümantasyon Türkçe veya İngilizce olabilir, **kod İngilizce**

### 17.4 Ürün adını değiştirme

`scripts/rename-product.sh` tek komutla ürün adını, bundle kimliğini, daemon etiketini ve yerelleştirme dizelerini günceller. Ad, kod tabanının hiçbir yerine gömülmez; yalnızca `project.yml` içindeki değişkenlerde ve `.xcstrings` içinde geçer.

---

## 18. README Spesifikasyonu

README, projenin vitrinidir. **Sırasıyla** şunları içermelidir:

### 18.1 Zorunlu bölümler

| # | Bölüm | İçerik |
|---|---|---|
| 1 | **Başlık ve tek cümlelik tanım** | Ürün adı, logo, ne yaptığı tek cümlede |
| 2 | **Rozetler** | Derleme durumu, sürüm, lisans, desteklenen macOS, desteklenen mimari |
| 3 | **Ekran görüntüsü / kısa GIF** | Menü çubuğu paneli + eğri editörü. Karanlık ve aydınlık tema |
| 4 | **Neden bu proje var** | §1.2'deki problem tanımı, kısaltılmış. **Hiçbir rakip ürün adı geçmez** |
| 5 | **Öne çıkan özellikler** | 6–10 madde, her biri tek satır, faydaya odaklı |
| 6 | **Gereksinimler ve test edilen donanım** | Apple Silicon (M1+), macOS 14.0+. **Ayrıca hangi modelde fiilen test edildiği açıkça yazılır** — R8 gereği dürüstlük şartı (§21). Test edilmemiş model sınıfları için topluluk raporu çağrısı yapılır |
| 7 | **Kurulum** | Homebrew komutu (birincil) + DMG indirme bağlantısı. İlk açılış ve Gatekeeper adımları |
| 8 | **Hızlı başlangıç** | 3 adım: aç → profil seç → (isteğe bağlı) fan kontrolünü etkinleştir |
| 9 | **İzinler ve neden gerekli** | §6.1 tablosu + §6.2'deki "istemediklerimiz" listesi. **Kullanıcı güveninin kazanıldığı bölüm — üstte tutulmalı** |
| 10 | **Nasıl çalışır** | 6–8 cümlelik mimari özeti + katman diyagramı |
| 11 | **Güvenlik** | Ölü adam anahtarı, güvenlik zinciri, daemon yüzeyinin darlığı |
| 12 | **Gizlilik** | Sıfır telemetri taahhüdü, açık ve net |
| 13 | **Yapılandırma** | Dosya konumu, örnek parça, şema bağlantısı |
| 14 | **CLI kullanımı** | Komut listesi ve örnekler |
| 15 | **Sorun giderme** | En sık 8–10 sorun ve çözümü; ayrıntı için `docs/troubleshooting.md` |
| 16 | **Kaldırma** | Tam kaldırma adımları, geriye hiçbir şey bırakmadığının garantisi |
| 17 | **Yol haritası** | Kısa; ayrıntı için Projects sekmesi |
| 18 | **Katkı** | `CONTRIBUTING.md`'ye yönlendirme + "yeni donanım raporu" çağrısı |
| 19 | **Sorumluluk reddi** | §2.7 metni |
| 20 | **Lisans** | Apache-2.0 + `NOTICE`'a atıf |

### 18.2 README'de olmaması gerekenler

| Olmayacak | Neden |
|---|---|
| Herhangi bir rakip ürün adı | **Kural 2 ve 5** |
| "X alternatifi" / "X gibi ama ücretsiz" ifadesi | **Kural 6** — karşılaştırmalı pazarlama riski |
| Karşılaştırma tablosu (biz vs onlar) | Aynı gerekçe |
| Abartılı performans iddiası ("%40 daha serin") | Kanıtlanamaz iddia; ölçüm metodolojisi olmadan yazılmaz |
| Bağış/sponsorluk baskısı | İlerde eklenebilir; ilk sürümde odağı dağıtır |
| Uzun kişisel hikâye | README teknik bir belgedir |

### 18.3 Ton

Sade, dürüst, abartısız. Neyi yapamadığını da söyler (ör. "donanım fanları kapattığında kontrol mümkün değildir"). **Dürüstlük, bu kategoride en güçlü pazarlamadır.**

### 18.4 Keşfedilebilirlik

**İlke: marka adı ile arama anahtar kelimeleri aynı şey olmak zorunda değildir.**

Ürün adı `Boreas` markayı taşır; anahtar kelimeler ise adın dışındaki katmanlarda taşınır. Bu ayrım sayesinde hem ayırt edici bir marka hem de yüksek keşfedilebilirlik aynı anda elde edilir.

#### Katman haritası

| Katman | Değer | Neden önemli |
|---|---|---|
| **Depo adı** | `boreas-mac-fan-control` | URL'deki kelimeler güçlü sinyaldir; hem markayı hem anahtar kelimeyi taşır |
| **Depo açıklaması** (GitHub `description`) | *"Free, open-source Mac fan control and temperature monitoring for Apple Silicon (M1–M5). Native menu bar app — no kernel extension, no SIP changes."* | **En kritik alan.** Arama motorlarının meta açıklama olarak kullandığı yer; GitHub arama sıralamasında da ağırlıklı |
| **GitHub topics** | `mac-fan-control` `fan-control` `macos` `apple-silicon` `temperature-monitor` `thermal` `menu-bar` `swift` `swiftui` `m1` `m2` `m3` `m4` `macos-app` `system-monitor` | GitHub'ın konu sayfaları kendi başına organik trafik kaynağıdır |
| **README `<h1>` + tagline** | `# Boreas` → *Mac Fan Control & Temperature Monitoring for Apple Silicon* | Arama sonucunda başlık olarak görünen satır |
| **README ilk paragraf** | Anahtar kelimeleri doğal biçimde içeren 2–3 cümle | Snippet olarak çekilen metin |
| **Homebrew cask `desc`** | Anahtar kelimeli tek satır | `brew search` sonuçlarında görünür |
| **Release başlıkları** | Sürüm + kısa özellik özeti | Sürüm sayfaları ayrıca indekslenir |
| **README çevirileri** | `README.tr.md` · `ru` · `es` · `zh-Hans` | Yerel dilde arama yapan kullanıcıya erişim (§9.7) |

#### Hedef arama niyetleri

Bunlar, insanların gerçekten arattığı ifadelerdir ve README içeriği bunları **doğal biçimde** karşılamalıdır:

- `mac fan control` · `macbook fan control` · `apple silicon fan control`
- `mac temperature monitor` · `m4 mac temperature`
- `macbook running hot` · `mac fan always on` · `mac fan noise`
- `free mac fan control app` · `open source mac fan control`
- `control mac mini fan speed`

#### README'de bir SSS bölümü

README'nin sonuna, **gerçekten faydalı olduğu için** doğal olarak bu ifadeleri barındıran kısa bir soru-cevap bölümü konur:

- *"Why is my Mac running hot?"*
- *"Can I control fan speed on Apple Silicon Macs?"*
- *"Does this require disabling SIP or installing a kernel extension?"* → **Hayır** (aynı zamanda en güçlü satış argümanı)
- *"Is it safe to lower fan speeds?"*
- *"What happens if the app crashes?"*

Bu bölüm iki işi birden yapar: kullanıcının gerçek sorusunu cevaplar ve arama görünürlüğü sağlar.

#### Yapılmayacaklar

| Yapılmayacak | Neden |
|---|---|
| Anahtar kelime tıkıştırma | Ters teper; GitHub'da sahtelik hissi verir, güveni düşürür |
| Rakip ürün adını anahtar kelime olarak kullanma | **§2 Y5/Y6** — mutlak yasak |
| Yanıltıcı topic etiketleri | Konuyla ilgisiz etiket, GitHub tarafından cezalandırılır |
| Yapay yıldız / sahte etkileşim | Hesap kapatılma riski, itibar kaybı |
| Ölçülemeyen performans iddiası | *"%40 daha serin"* gibi kanıtsız ifade (§18.2) |

---

## 19. Diğer Depo Dosyaları

| Dosya | İçerik özeti |
|---|---|
| `LICENSE` | Apache-2.0 tam metni |
| `NOTICE` | Telif bildirimi, üçüncü taraf atıfları, ilham alınan açık kaynak projelere teşekkür (§2.6) |
| `CONTRIBUTING.md` | Geliştirme ortamı kurulumu, kod stili, commit kuralları, PR süreci, **§2.4 bağımsız geliştirme beyanı**, yeni sensör desteği ekleme rehberi |
| `CODE_OF_CONDUCT.md` | Contributor Covenant 2.1 |
| `SECURITY.md` | Açık bildirimi süreci, iletişim, yanıt süresi taahhüdü, kapsam |
| `CHANGELOG.md` | Keep a Changelog formatı, `Unreleased` bölümüyle başlar |
| `.github/PULL_REQUEST_TEMPLATE.md` | §2.4 onay kutuları + test kontrol listesi + ekran görüntüsü alanı |
| `.github/ISSUE_TEMPLATE/unknown_sensor.yml` | Çip modeli, ham sensör adları, beklenen grup — topluluk katkısını yapılandırır |
| `docs/control-engine.md` | Motorun matematiği: eğri, histerezis, hız sınırlama, arbitraj — formüllerle |
| `docs/hardware-access.md` | Erişim yolları, riskler, yedek stratejiler, sensör keşif süreci |

---

## 20. Yol Haritası

| Kilometre taşı | Kapsam | Tahmini süre* |
|---|---|---|
| **M0 — İskelet** | Repo, XcodeGen, CI, lisans, dokümantasyon iskeleti, `Core` paket yapısı, imzalama sertifikası doğrulaması | 1 hafta |
| **M1 — Okuma + Mock** | Sensör keşfi, sıcaklık ve fan okuma, **Mock ve Replay katmanları (§15.4 gereği ertelenemez)**, menü çubuğu ile ilk görsel çıktı | 2,5 hafta |
| **M2 — Ayrıcalık** | Daemon, XPC, imza doğrulaması, kur/kaldır akışı, watchdog | 2 hafta |
| **M3 — Kontrol** | Manuel kontrol, güvenlik zinciri K1–K5, devral/geri ver döngüsü, donanım duman testleri | 2 hafta |
| **M4 — Motor** | Eğri değerlendirme, histerezis, hız sınırlama, profil arbitrajı, kapsamlı birim ve özellik testleri | 2 hafta |
| **M5 — Arayüz** | Ana pencere, grafikler, eğri editörü, ayarlar, erişilebilirlik, yerelleştirme altyapısı + `en`/`tr` | 3 hafta |
| **M6 — Olgunlaşma** | Bildirimler, log, tanılama, CLI, sorun giderme dokümantasyonu, `ru`/`es`/`zh-Hans` çevirileri, pseudo-locale düzen testi | 2,5 hafta |
| **M7 — Yayın** | İmzalama, notarizasyon, DMG, Homebrew cask, README + 4 çeviri, §18.4 keşfedilebilirlik kurulumu, sürüm 1.0 | 1,5 hafta |

*Tek geliştirici, yarı zamanlı varsayımıyla — toplam ~16,5 hafta. Sıralama bağımlılık zinciridir; M2 tamamlanmadan M3'e geçilmez.

**M1 sonunda elde edilecek şey zaten kullanışlı bir üründür** (izleme aracı). Bu, erken geri bildirim almayı ve motivasyonu korumayı sağlar.

**M5'te yalnızca iki dil doldurulur** (`en` kaynak, `tr`). Kalan üç dil M6'ya bırakılır çünkü arayüz metinleri M5 boyunca değişmeye devam eder — erken çeviri boşa emek olur. Yerelleştirme **altyapısı** ise M5'te kurulur, sonraya bırakılmaz.

---

## 21. Riskler ve Azaltımlar

| # | Risk | Olasılık | Etki | Azaltım |
|---|---|---|---|---|
| R1 | Dokümante edilmemiş sensör API'si macOS güncellemesiyle bozulur | Orta | Yüksek | Protokol soyutlaması + ikinci kaynak (SMC) + zarif düşüş; asla çökme |
| R2 | Yeni çip nesli farklı sensör adlandırması getirir | Yüksek | Orta | Çalışma zamanı keşfi, koda gömülü çip listesi yok, `uncategorized` görünürlüğü, topluluk raporu şablonu |
| R3 | Firmware fan yazımını engeller / geri alır | Orta | Yüksek | Kapalı çevrim doğrulama, sapma tespiti, kullanıcıya dürüst bildirim ("bu modelde kontrol sınırlı") |
| R4 | Kullanıcı fanı çok düşük ayarlayıp donanımı riske atar | Orta | Yüksek | K1–K3 katmanları kapatılamaz; eğri editörü riskli bölgeyi görsel olarak işaretler |
| R5 | Daemon kurulumu macOS güvenlik akışında takılır | Orta | Orta | Durum tespiti + Sistem Ayarları'na doğrudan yönlendirme + ayrıntılı sorun giderme dokümanı |
| R6 | Hukuki iddia | Düşük | Çok yüksek | §2'nin tamamı: bağımsız geliştirme protokolü, ürün adı geçmeme kuralı, PR beyanı, atıf disiplini, özgün algoritma tasarımı |
| R7 | Tek geliştirici tükenmişliği | Yüksek | Yüksek | Kilometre taşları küçük ve her biri kendi başına kullanışlı; M1 sonunda çalışan ürün; kapsam dışı listesi disiplini korur |
| R8 | **Test edilemeyen donanım çeşitliliği** — geliştirme donanımı tek model (Mac mini M4, tek fanlı, pilsiz) | **Kesin** | **Yüksek** | Mock + Replay altyapısı M1'de zorunlu (§15.4); README'de dürüst kapsam beyanı; topluluk rapor şablonları; doğrulanmamış kod yolları sürüm notlarında işaretlenir |
| R9 | Apple marka kuralları nedeniyle ad değişikliği gerekir | Düşük | Düşük | "Mac" öneki baştan kullanılmadı; ad tek noktada, `rename-product.sh` ile tek komutluk iş (§17.4) |
| R10 | Çeviri bayatlaması — 5 dil, tek geliştirici | Yüksek | Düşük | Eksik çeviri kaynak dile düşer, asla boş görünmez; CI uyarısı sürümü engellemez; `TRANSLATORS.md` ile sorumluluk dağıtılır; dokümantasyon bilinçli olarak çeviri kapsamı dışında (§9.7) |
| R11 | Çok dilli arayüzde düzen bozulması (Rusça uzun dizeler) | Orta | Orta | Sabit genişlikli/yükseklikli metin kabı yasağı; CI'da pseudo-locale düzen testi (§9.7) |

---

## 22. Sözlük

| Terim | Tanım |
|---|---|
| **Görev oranı (duty)** | Fanın minimum ve maksimum hızı arasındaki konumu, 0.0–1.0 |
| **Eğri** | Sıcaklığı görev oranına dönüştüren parçalı doğrusal fonksiyon |
| **Histerezis** | Salınımı önlemek için yükselen ve düşen yönlerde farklı eşik kullanma |
| **Hız sınırlama (slew)** | Çıktının birim zamandaki değişimini kısıtlama |
| **EWMA** | Üstel ağırlıklı hareketli ortalama — girdi yumuşatma yöntemi |
| **Profil** | Eğriler, parametreler ve tetikleyicilerden oluşan adlandırılmış yapılandırma seti |
| **Arbitraj** | Birden fazla aday profil arasından aktif olanı seçme süreci |
| **Güvenlik zinciri** | Motor çıktısının donanıma ulaşmadan geçtiği koruma katmanları (K1–K5) |
| **Ölü adam anahtarı** | Kalp atışı kesildiğinde otomatik güvenli duruma dönen mekanizma |
| **Devralma** | Fan kontrolünün firmware'den yazılıma geçmesi |
| **Devretme** | Fan kontrolünün yazılımdan firmware'e iade edilmesi |
| **Termal baskı** | İşletim sisteminin bildirdiği sistem geneli termal durum |

---

## 23. Karar Kaydı

Tüm açılış kararları verilmiştir. Bir kararı değiştirmek isteyen, önce buradaki satırı ve etkilediği bölümleri günceller (§0 değişiklik politikası).

| # | Karar | Sonuç | Etkilediği bölümler |
|---|---|---|---|
| **A1** | Ürün adı | **Boreas** · depo `boreas-mac-fan-control` · bundle `com.bubiapps.boreas` · CLI `boreas` | §2.8, §17.1, §18.4 |
| **A2** | Minimum macOS | **14.0 Sonoma** — `SMAppService` olgunluğu, `@Observable`, kararlı `MenuBarExtra` | §3.2 |
| **A3** | Depo sahibi | **Kişisel GitHub hesabı.** İleride organizasyona taşınabilir; GitHub eski URL'i yönlendirir. Bundle ID buna bağlı değil, sahip olunan alan adına dayanır | §17.1 |
| **A4** | Developer ID | **Mevcut, aktif üyelik.** İmzalama + notarizasyon + Homebrew cask zinciri planlandığı gibi uygulanır; plan değişikliği yok | §16 |
| **A5** | Test donanımı | **Yalnızca Mac mini (M4, 2024) — `Mac16,10`.** Tek fanlı, pilsiz masaüstü. Fansız model, çok fanlı arbitraj, pil/güç tetikleyicileri ve diğer nesiller gerçek donanımda doğrulanamaz | §15.4, §18.1, §20 (M1), §21 (R8) |
| **A6** | Dil kapsamı | **Arayüz 5 dil:** `en` (kaynak), `tr`, `ru`, `es`, `zh-Hans`. **Dokümantasyon:** README 5 dilde (İngilizce yetkili), geri kalan her şey yalnızca İngilizce | §9.7, §17.1, §20 (M5–M7), §21 (R10, R11) |

### 23.1 Kararların birbirini etkilediği noktalar

- **A5 → A1'i güçlendirdi.** Tek donanımda test edilen bir projenin dürüst olması gerekiyor; kapsamı abartmayan bir marka ve README, güvenin tek kaynağı.
- **A5 → §20'yi değiştirdi.** Mock/Replay artık M1'de, "iyi olurdu" değil zorunlu.
- **A6 → §9.6'yı genişletti.** Beş dil, sabit boyutlu metin kabı yasağını genişlik eksenine de taşıdı ve CI'ya pseudo-locale testi ekledi.
- **A1 → §18.4'ü doğurdu.** Ayırt edici marka seçilince keşfedilebilirliğin ayrı bir katmanda çözülmesi gerekti.
- **A4 → riski kaldırdı.** Sertifika mevcut olduğu için dağıtım stratejisinde alternatif plana gerek kalmadı.

### 23.2 Sonraki dalgaya bırakılanlar

Bunlar karar bekleyen konular değil, **bilinçli olarak ertelenmiş** konulardır:

| Konu | Ne zaman |
|---|---|
| Geleneksel Çince (`zh-Hant`) | Talep gelirse |
| Ek diller (de, fr, ja, pt…) | Topluluk katkısı olarak |
| Organizasyona taşıma | Katkıcı sayısı arttığında |
| Sparkle ile uygulama içi güncelleme | v1.1 |
| Yerel metrik uç noktası | v1.1 |
| Kurumsal toplu dağıtım aracı | v2 |

---

## 24. Bu Blueprint'i Uygulamaya Geçirme

Bu belge tamamlanmış bir spesifikasyondur ve tüm açılış kararları verilmiştir (§23). Sonraki adım, onu yürütülebilir bir iş listesine dönüştürmektir:

1. Depo başlatılır: `git init`, Apache-2.0 lisansı, temel dokümantasyon dosyaları.
2. Blueprint; yönetişim dokümanlarına, konu bazlı `docs/` ağacına, ADR kütüphanesine, faz/atomik iş kırılımına ve izlenebilirlik matrisine dönüştürülür.
3. M0'dan başlanarak kilometre taşları sırayla yürütülür; her atomik iş kanıtla (test, ekran görüntüsü, log) kapatılır.

**Yerel klasör adı hakkında not:** Geliştirme klasörü şu an `MacFanMaster`. Depo adı `boreas-mac-fan-control` olacağı için `git init` sırasında klasörün de yeniden adlandırılması önerilir; zorunlu değildir, uzak depo adı yereldeki klasör adından bağımsızdır.

---

**Belge sonu.**
