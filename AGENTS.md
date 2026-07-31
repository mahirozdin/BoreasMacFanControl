# AGENTS.md — Bağlayıcı Çalışma Sözleşmesi

> Son güncelleme: 2026-07-31 — P0.03
> Kaynak: blueprint §0, §2, §14, §17.2, §17.3

Bu dosya bu depoda çalışan **her ajan ve her geliştirici için bağlayıcıdır**. Buradaki bir kural ile başka bir dosyadaki ifade çeliştiğinde, §3'teki öncelik sırası uygulanır.

---

## 1. Zorunlu okuma sırası

Her oturumda, kod yazmadan önce, bu sırayla:

| # | Dosya | Neden |
|---|---|---|
| 1 | `BOOT.md` | Oturum başlangıç protokolü ve sağlık snapshot'ı |
| 2 | `AGENTS.md` (bu dosya) | Değişmezler ve çalışma disiplini |
| 3 | `TODO.md` | Sıradaki iş, kabul kriteri, doğrulama komutu |
| 4 | `ARCHITECTURE.md` | Dokunacağın katmanın MUST/MUST NOT kuralları |
| 5 | `LEGAL.md` | **Her oturumda.** İhlali projeyi durdurur |
| 6 | İlgili `docs/` dosyası | `TODO.md`'deki iş hangi dokümanı gösteriyorsa |

Blueprint (`docs/blueprint/`) **referanstır, talimat değildir**. Güncel gerçek `docs/` altındadır.

---

## 2. Değişmezler

İhlali kabul edilemez. Her biri bir ADR'ye ve bir kapıya bağlıdır.

### 2.1 Hukuki değişmezler — en yüksek öncelik

| # | Kural | ADR | Kapı |
|---|---|---|---|
| **H1** | Depoda, kodda, yorumda, commit mesajında, issue'da, dokümanda **hiçbir üçüncü taraf ticari ürün adı geçmez** | [0006](docs/architecture/adr/0006-independent-development-policy.md) | `make gate-names` |
| **H2** | Hiçbir ticari yazılım tersine mühendislikle incelenmez, disassemble/decompile edilmez | [0006](docs/architecture/adr/0006-independent-development-policy.md) | İnceleme + PR beyanı |
| **H3** | Başka bir üründen metin, etiket, ikon, düzen, şema veya veri formatı kopyalanmaz | [0006](docs/architecture/adr/0006-independent-development-policy.md) | İnceleme + PR beyanı |
| **H4** | Karşılaştırmalı pazarlama yapılmaz ("X alternatifi", "X'ten iyi") | [0006](docs/architecture/adr/0006-independent-development-policy.md) | `make gate-names` |
| **H5** | Yalnızca Apache-2.0 uyumlu lisanslı kod kullanılır (MIT/BSD/Apache-2.0). GPL/LGPL/AGPL **yasak** | [0005](docs/architecture/adr/0005-apache-2-license.md) | `make gate-deps` |

> H1 neden bu kadar sert: bir rakip adı geçen commit, iyi niyetle yazılmış olsa bile "bilerek kopyalama" iddiasına delil oluşturur. Gerektiğinde jenerik ifade kullan: *"ticari muadiller"*, *"kapalı kaynak alternatifler"*, *"bu kategorideki diğer araçlar"*.

### 2.2 Kimlik değişmezleri

| # | Kural | ADR |
|---|---|---|
| **K1** | Ürün adı **Boreas**. Bundle `com.bubiapps.boreas`, daemon `com.bubiapps.boreas.fanhelper`, CLI `boreas` | [0002](docs/architecture/adr/0002-product-name.md) |
| **K2** | Ürün adı koda gömülmez; yalnızca `project.yml` değişkenlerinde ve yerelleştirme kataloğunda geçer | [0002](docs/architecture/adr/0002-product-name.md) |
| **K3** | Ürün adında Apple markası önek olarak kullanılmaz | [0002](docs/architecture/adr/0002-product-name.md) |

### 2.3 Teknoloji değişmezleri

| # | Kural | ADR | Kapı |
|---|---|---|---|
| **T1** | Dil **Swift 6.2**, strict concurrency açık. Objective-C yalnızca kaçınılmaz köprülerde | [0001](docs/architecture/adr/0001-native-swift.md) | Derleme |
| **T2** | Minimum hedef **macOS 14.0**. Daha düşük sürüm API'si varsayılmaz | [0003](docs/architecture/adr/0003-minimum-macos-14.md) | Derleme |
| **T3** | Mimari **yalnızca arm64**. Intel kod yolu yazılmaz | [0004](docs/architecture/adr/0004-apple-silicon-only.md) | Derleme |
| **T4** | **Sıfır çalışma zamanı bağımlılığı.** Yalnızca Apple çatıları | [0013](docs/architecture/adr/0013-json-config-zero-deps.md) | `make gate-deps` |
| **T5** | Proje dosyası `project.yml`'den üretilir; `.xcodeproj` commit edilmez | [0001](docs/architecture/adr/0001-native-swift.md) | `.gitignore` + `make gate-layers` |

### 2.4 Mimari değişmezler

| # | Kural | ADR | Kapı |
|---|---|---|---|
| **M1** | `Packages/Core` **IOKit, SwiftUI, AppKit veya herhangi bir donanım API'sine bağlanmaz.** Yalnızca Foundation | [0012](docs/architecture/adr/0012-core-layer-purity.md) | `make gate-layers` |
| **M2** | Tüm donanım erişimi protokol arkasındadır; her protokolün `Live` + `Mock` uygulaması vardır | [0011](docs/architecture/adr/0011-hardware-abstraction.md) | `make gate-layers` |
| **M3** | Sıcaklık okuma **ayrıcalık gerektirmez**. Daemon yalnızca fan yazımı için vardır | [0007](docs/architecture/adr/0007-privilege-split.md) | İnceleme |
| **M4** | Daemon dosya yolu, komut, betik veya rastgele veri **kabul etmez**. XPC yüzeyi §14.2'deki dört metotla sınırlıdır | [0008](docs/architecture/adr/0008-smappservice-xpc.md) | `make gate-daemon` |
| **M5** | Daemon yapılandırma **okumaz**. Root tarafında ayrıştırılan kullanıcı verisi yoktur | [0007](docs/architecture/adr/0007-privilege-split.md) | `make gate-daemon` |
| **M6** | Daemon'un ağ erişimi **yoktur** | [0007](docs/architecture/adr/0007-privilege-split.md) | `make gate-daemon` |

### 2.5 Güvenlik değişmezleri

| # | Kural | ADR | Kapı |
|---|---|---|---|
| **G1** | Güvenlik zinciri katmanları **yalnızca yukarı düzeltir**. Hiçbir katman fan hızını düşüremez | [0010](docs/architecture/adr/0010-continuous-curve-model.md) | Invariant testi |
| **G2** | K2 (termal durum) ve K3 (panik eşiği) **kapatılamaz**. Kullanıcı panik eşiğini düşürebilir, yükseltemez | [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Invariant testi |
| **G3** | Watchdog zaman aşımı **10–60 sn aralığında kilitlidir**, devre dışı bırakılamaz | [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Invariant testi |
| **G4** | Uygulama sonlandığında, çöktüğünde, uyku veya kapanışta fanlar **koşulsuz** firmware'e devredilir | [0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md) | Invariant + duman testi |
| **G5** | XPC bağlantısı **çift yönlü** kod imzası doğrulaması yapar | [0008](docs/architecture/adr/0008-smappservice-xpc.md) | Invariant testi |
| **G6** | Hiçbir yapılandırma hatası uygulamayı çökertmez; son geçerli hale dönülür ve fanlar firmware'de kalır | [0013](docs/architecture/adr/0013-json-config-zero-deps.md) | Birim testi |

### 2.6 Gizlilik değişmezleri

| # | Kural | ADR | Kapı |
|---|---|---|---|
| **P1** | **Sıfır telemetri.** Analitik SDK'sı, çökme raporlama SDK'sı, reklam kimliği yoktur | [0014](docs/architecture/adr/0014-zero-telemetry.md) | `make gate-privacy` |
| **P2** | Varsayılan durumda uygulama **hiçbir ağ bağlantısı kurmaz** | [0014](docs/architecture/adr/0014-zero-telemetry.md) | `make gate-privacy` |
| **P3** | Log satırları kişisel veri içermez: kullanıcı adı, dosya yolu, ağ bilgisi loglanmaz | [0014](docs/architecture/adr/0014-zero-telemetry.md) | İnceleme + birim testi |

### 2.7 İzin değişmezleri

| # | Kural |
|---|---|
| **İ1** | SIP devre dışı bırakma, kernel extension, DriverKit sürücüsü, Recovery Mode adımı **istenmez** |
| **İ2** | Tam Disk Erişimi, Erişilebilirlik, Ekran Kaydı, kamera/mikrofon/konum izni **istenmez** |
| **İ3** | Yönetici kimlik doğrulaması **yalnızca bir kez**, yalnızca daemon kurulumunda istenir |
| **İ4** | Daemon kurulmadığında uygulama **tam işlevli izleme aracıdır**, hata göstermez |

### 2.8 Yerelleştirme değişmezleri

| # | Kural | Kapı |
|---|---|---|
| **Y1** | Kullanıcıya görünen hiçbir metin kodda sabit yazılmaz; `String(localized:)` zorunlu | `make gate-i18n` |
| **Y2** | Her dize için `comment` alanı doldurulur — çevirmen bağlamsız çeviremez | `make gate-i18n` |
| **Y3** | Sabit piksel **genişlikli veya yükseklikli** metin kabı yoktur | Pseudo-locale testi |
| **Y4** | Eksik çeviri kaynak dile (`en`) düşer, asla boş görünmez | Birim testi |

---

## 3. Kaynakların önceliği

Çelişki durumunda yukarıdan aşağı:

1. **Kullanıcının bu oturumdaki açık talimatı**
2. **Hukuki değişmezler (§2.1)** — kullanıcı talebi bile bunları geçersiz kılmaz; çelişki varsa dur ve sor
3. **Güvenlik değişmezleri (§2.5)**
4. **ADR'ler** (`docs/architecture/adr/`)
5. **TODO.md** — sıradaki iş ve kabul kriteri
6. **Bu dosya**
7. `docs/` ağacı
8. `docs/blueprint/` — yalnızca tarihsel referans

---

## 4. "Sıradaki işi yap" algoritması

```
1. BOOT.md sağlık snapshot'ını çalıştır. Kırmızı kapı varsa ÖNCE onu düzelt.
2. TODO.md durum özetini oku.
3. En düşük numaralı, durumu NOT_STARTED veya IN_PROGRESS olan fazı bul.
4. O fazın bağımlılıkları DONE mu? Değilse bağımlılığa geç.
5. Fazdaki ilk işaretlenmemiş atomik işi seç.
6. İş BLOCKED mı (manuel iş bekliyor)?
   → Evet: bir sonraki işaretlenmemiş işe geç. BLOKAJ İŞİ DONDURMAZ.
   → Hepsi bloke ise, bir sonraki fazın bağımsız işlerine geç.
7. İşi yap.
8. Doğrulama komutlarını ÇALIŞTIR. Çıktıyı gör.
9. Definition of Done (§8) kontrol listesini geç.
10. Oturumu kapat (§9): checkbox + durum özeti + Run Log — AYNI DEĞİŞİKLİKTE.
```

**Tek oturumda birden fazla atomik iş yapılabilir**, ama her biri kendi Run Log kaydını alır.

---

## 5. Durum ve Run Log disiplini

### Faz durumları

| Durum | Anlamı |
|---|---|
| `NOT_STARTED` | Hiçbir alt iş başlamadı |
| `IN_PROGRESS` | En az bir alt iş bitti, hepsi bitmedi |
| `BLOCKED` | Kalan tüm işler dış bağımlılık bekliyor |
| `DONE` | Tüm alt işler bitti **ve** kabul kriterleri kanıtlandı |

### Run Log kuralı

| Durum | Ne zaman yazılır |
|---|---|
| `PASS` | Komut çalıştırıldı, geçti |
| `FAIL` | Komut çalıştırıldı, kaldı — iş `DONE` yapılamaz |
| `NOT RUN` | **Komut çalıştırılamadı + nedeni.** İş `DONE` yapılamaz |

> "Yazdım, çalışıyordur" yasaktır. Doğrulanmamış iş bitmemiştir.

---

## 6. Kod kuralları

### 6.1 Genel

- `swift-format` ile biçimlendirme, `SwiftLint` ile denetim — ikisi de CI'da bloklayıcı
- Tüm genel API'ler için dokümantasyon yorumu zorunlu
- **Kod, yorum ve commit mesajları İngilizce.** Proje yönetim dokümanları Türkçe
- Türkçe karakter kod tanımlayıcılarında kullanılmaz
- Sihirli sayı yasak — adlandırılmış sabit veya yapılandırma alanı

### 6.2 `Packages/Core`

- **`import IOKit`, `import SwiftUI`, `import AppKit` YASAK** (M1)
- Zorla açma (`!`) yasak — lint kuralı ile denetlenir
- Tüm tipler `Sendable`
- Motor fonksiyonları **saf**: aynı girdi → aynı çıktı, yan etki yok
- Her genel fonksiyonun birim testi olmalı

### 6.3 `Packages/HardwareKit`

- Her protokolün en az `Live` ve `Mock` uygulaması olmalı (M2)
- `Live` uygulamaları **asla** doğrudan kullanılmaz; enjekte edilir
- Donanım hatası **fırlatılır**, yutulmaz; çağıran zarif düşüş uygular
- Bilinmeyen sensör/anahtar → atla + uyarı logla, **çökme yok**

### 6.4 `Daemon`

- XPC yüzeyi §2.4 M4'teki dört metotla sınırlı — **yeni metot eklemek ADR gerektirir**
- Her gelen komut `SafetyGovernor`'dan geçer
- Gelen hiçbir veri dosya yolu veya komut olarak yorumlanmaz
- Ağ API'si import edilmez (M6)

### 6.5 `App`

- Donanım erişen kod **asla** `@MainActor` üzerinde çalışmaz
- Tüm kullanıcı metinleri `String(localized:)` (Y1)
- Renk tek başına bilgi taşımaz — sayı veya etiketle desteklenir
- Sabit boyutlu metin kabı yok (Y3)

---

## 7. Doküman güncelleme protokolü

Bir değişiklik yaptığında **hangi dosyaları güncelleyeceğin yazılıdır**:

| Değişiklik tipi | Güncellenecek dosyalar |
|---|---|
| Yeni mimari/teknoloji kararı | Yeni ADR + `ARCHITECTURE.md` ADR tablosu + `docs/architecture/adr/README.md` indeksi |
| Blueprint'ten sapma | **ADR zorunlu** + ilgili `docs/` dosyası + `docs/reference/blueprint-map.md` |
| Yeni değişmez | `AGENTS.md` §2 + ADR + **kapı script'i** + `BOOT.md` snapshot |
| Yeni kapı | `Makefile` + `scripts/gates/` + `BOOT.md` + ilgili ADR `Zorlama` bölümü |
| Yeni faz/iş | `TODO.md` faz bloğu + durum özeti |
| Yeni risk | `docs/reference/risks.md` |
| Yeni manuel iş | `TODO.md` manuel işler tablosu |
| Kontrol motoru davranışı | `docs/product/control-model.md` + invariant testi |
| Yapılandırma şeması | `docs/architecture/configuration.md` + `schema/config.schema.json` + göç testi |
| Yeni komut/script | `Makefile` + `docs/development/setup.md` + `README.md` komut tablosu |
| Yeni kullanıcı metni | Yerelleştirme kataloğu (5 dil) + `comment` alanı |

**Kural:** Aynı olgu iki dosyaya yazılmaz. İkinci yer birinciye link verir.

**Kural:** Kod yazıldıktan sonra dokümanda kod kopyası tutulmaz — kaynağa işaret edilir.

---

## 8. Definition of Done

Bir atomik iş, aşağıdakilerin **hepsi** doğruysa `DONE`:

- [ ] İş metnindeki her şey yapıldı
- [ ] Kabul kriteri **kanıtla** karşılandı (test çıktısı, komut çıktısı, ekran görüntüsü)
- [ ] `make check` geçti (veya `NOT RUN` + neden Run Log'da)
- [ ] Yeni davranış için test yazıldı; değişmez etkileniyorsa invariant testi
- [ ] §7'deki protokole göre dokümanlar güncellendi
- [ ] Yeni değişmez eklendiyse kapısı da eklendi **ve kasıtlı ihlalle kanıtlandı**
- [ ] `make gate-names` geçti (H1 — her işte)
- [ ] Checkbox `[x]`, durum özeti ve Run Log **aynı değişiklikte** güncellendi

---

## 9. Oturum kapanışı

Üçü birden, aynı değişiklikte:

1. `TODO.md` içinde checkbox `[x]`
2. `TODO.md` durum özeti tablosu (faz durumu + sıradaki iş)
3. `TODO.md` Run Log kaydı + `Next: P<n>.<nn>`

Üçünden biri eksikse sistem bir sonraki oturumda yalan söyler.

---

## 10. Dış yetki

### Ajanın yapamayacakları — `TODO.md` manuel işler tablosuna yazılır

- Marka tescil araması ve hukuki onay
- Apple Developer hesabı işlemleri, sertifika üretimi, App Store Connect API anahtarı
- GitHub deposu oluşturma, gizli değer (secret) tanımlama
- Homebrew cask gönderimi
- Sahip olunmayan donanımda test
- Çeviri kalite onayı (anadili konuşuru gerektiren)

### Ajanın yapması gerekenler — manuel işe **yazılmaz**

- Yerel araç kurulumu (`brew install xcodegen swiftlint swift-format`)
- Bozuk yerel kurulum onarımı
- `xcodegen generate` çalıştırma
- Script yazma, kapı kurma, test yazma
- Doküman güncelleme

Ayırt edici soru: *"proje sahibinin bir konsola girmesi veya bir karar vermesi gerekiyor mu?"*

---

## 11. Repo hijyeni

- Arama için `rg` (ripgrep) tercih edilir; `grep -r` yavaş ve gürültülü
- **Yasak git işlemleri:** `push --force` (paylaşılan dala), `rebase` (yayınlanmış commit'e), `reset --hard` (commit edilmemiş iş varken), geçmiş yeniden yazma
- Commit mesajları **Conventional Commits**: `feat:` `fix:` `docs:` `refactor:` `test:` `chore:`
- Bir commit bir işi kapatır; karışık commit yasak
- `.xcodeproj` commit edilmez (T5)

---

## 12. Yasak kestirmeler

| Anti-pattern | Neden yasak |
|---|---|
| Doğrulama çalıştırmadan `[x]` işaretlemek | Sistem bir sonraki oturumda yalan söyler |
| Kapı yazıp ihlalle kanıtlamamak | Çalıştığı kanıtlanmamış kapı, kapı değildir |
| Blueprint'i "düzeltmek" | Dondurulmuştur; sapma ADR ile kaydedilir |
| Değişmezi ADR'siz değiştirmek | Kararın gerekçesi kaybolur |
| `Core` içine "geçici olarak" IOKit import etmek | Test edilebilirlik çöker; geçici hiçbir zaman geçici olmaz |
| Donanım hatasını `try?` ile yutmak | Sessiz başarısızlık, teşhis edilemez hata raporu |
| Kullanıcı metnini kodda sabit yazmak | 5 dil kırılır |
| Rakip ürün adını "sadece not olarak" yazmak | **H1 ihlali — mutlak yasak** |
| Blokaj yüzünden çalışmayı durdurmak | Bloke iş atlanır, bağımsız işe geçilir |
| Doküman güncellemeden kod yazmak | Drift başlar |
