# Boreas Master TODO — P0 → P8

- **Plan sürümü:** 1.0
- **Baseline tarihi:** 2026-07-31
- **Kaynak blueprint:** v1.1 (dondurulmuş: `docs/blueprint/boreas-blueprint-v1.1.md`)
- **Genel durum:** P0 tamamlandı. Uzak depo kuruldu (**private**). P1 başladı: LICENSE, NOTICE ve uygulama simgesi yerinde. İmzalama kimliği P8'e ertelendi (ADR 0019) — P1–P7 bloke değil. Sıradaki: P1.01.

---

## Durum sözlüğü

| Durum | Tanım |
|---|---|
| `NOT_STARTED` | Hiçbir alt iş başlamadı |
| `IN_PROGRESS` | En az bir alt iş bitti, hepsi bitmedi |
| `BLOCKED` | Kalan tüm işler dış bağımlılık bekliyor (manuel iş) |
| `DONE` | Tüm alt işler bitti **ve** kabul kriterleri kanıtlandı |

---

## Durum özeti

| Faz | Durum | Tema | Sıradaki tamamlanmamış iş |
|---|---|---|---|
| P0 | `DONE` | Doküman sistemi ve kapılar | (tamamlandı) |
| P1 | `IN_PROGRESS` | Depo iskeleti ve araç zinciri | **P1.01 — Brewfile + bootstrap.sh** |
| P2 | `NOT_STARTED` | Donanım okuma + Mock/Replay | P2.01 |
| P3 | `NOT_STARTED` | Ayrıcalık katmanı ve daemon | P3.01 |
| P4 | `NOT_STARTED` | Fan kontrolü ve güvenlik zinciri | P4.01 |
| P5 | `NOT_STARTED` | Kontrol motoru | P5.01 |
| P6 | `NOT_STARTED` | Kullanıcı arayüzü | P6.01 |
| P7 | `NOT_STARTED` | Olgunlaşma | P7.01 |
| P8 | `NOT_STARTED` | Yayın | P8.01 |

---

## "Sıradaki işi yap" algoritması

1. `BOOT.md` sağlık snapshot'ını çalıştır. **Kırmızı kapı varsa önce onu düzelt.**
2. Yukarıdaki durum özetinden en düşük numaralı tamamlanmamış fazı bul.
3. O fazın bağımlılıkları `DONE` mu? Değilse bağımlılığa geç.
4. Fazdaki ilk işaretlenmemiş atomik işi seç.
5. İş bir manuel işe bağlıysa **atla, bir sonrakine geç.** Blokaj işi dondurmaz.
6. İşi yap. Doğrulama komutlarını **çalıştır**, çıktıyı gör.
7. `AGENTS.md` §8 Definition of Done listesini geç.
8. Oturumu kapat: checkbox + durum özeti + Run Log — **aynı değişiklikte**.

---

## P0 — Doküman sistemi ve kapılar

- **ID:** P0
- **Durum:** `DONE`
- **Bağımlılık:** yok
- **Amaç:** Bir kod ajanının hiç soru sormadan inşa edebileceği, makine ile zorlanan bir yürütme sistemi kurmak.

### Alt işler

- [x] **P0.01 — Depoyu başlat.** `git init`, `.gitignore`.
- [x] **P0.02 — Blueprint'i dondur.** `docs/blueprint/` altına birebir kopya; `diff` ve SHA-256 ile kanıtla.
- [x] **P0.03 — `AGENTS.md`.** Değişmezler (hukuki, kimlik, teknoloji, mimari, güvenlik, gizlilik, izin, yerelleştirme), seçim algoritması, doküman güncelleme protokolü, DoD.
- [x] **P0.04 — `BOOT.md` ve `CLAUDE.md`.** Oturum protokolü, sağlık snapshot'ı, en sık ihlal edilen 10 kural.
- [x] **P0.05 — `ARCHITECTURE.md`.** MUST/MUST NOT invariantları, güven sınırları, ADR indeksi, ertelenmiş kararlar.
- [x] **P0.06 — `LEGAL.md`.** Yedi mutlak yasak, izinli kaynaklar, bağımsız geliştirme beyanı, zorlama katmanları ve **eksik katmanın açık kaydı**.
- [x] **P0.07 — Sekiz kapı + `Makefile`.** Her birini kasıtlı ihlalle kanıtla.
- [x] **P0.08 — ADR kütüphanesi.** 18 ADR; her birinde `Zorlama` bölümü dolu.
- [x] **P0.09 — `docs/README.md`.** Gezinme haritası.
- [x] **P0.10 — İzlenebilirlik matrisi.** 25 bölüm eşlenir, kayıp = 0.
- [x] **P0.11–P0.13 — `docs/reference/`.** Karar kaydı, risk kaydı, sözlük.
- [x] **P0.14–P0.17 — `docs/product/`.** Genel bakış, kontrol modeli, kapsam, arayüz.
- [x] **P0.18–P0.21 — `docs/architecture/`.** Sistem, donanım erişimi, ayrıcalık modeli, yapılandırma.
- [x] **P0.22–P0.25 — `docs/development/`.** Kurulum, depo yapısı, test, yerelleştirme.
- [x] **P0.26–P0.28 — `docs/operations/`.** Gözlemlenebilirlik, bildirimler, tanılama.
- [x] **P0.29–P0.31 — `docs/release/`.** Derleme/imzalama, README spesifikasyonu, keşfedilebilirlik.
- [x] **P0.32 — `SECURITY.md`.** Güvenlik modeli ve açık bildirimi.
- [x] **P0.33 — Kök `README.md`.** Geliştirme aşaması giriş noktası + doküman haritası. Ürün README'si P8'de yazılacak.
- [x] **P0.34 — `make check` tam yeşil.** Tüm kapıların geçtiğini çıktıyla kanıtla ve Run Log'a yaz.

### Kabul kriterleri

- Blueprint'in 25 bölümünün tamamı bir hedef dokümana eşlenmiş; **kayıp = 0**
- 18 ADR'nin her birinde `Zorlama` bölümü dolu
- Sekiz kapının her biri **kasıtlı ihlalle kanıtlanmış**
- `make check` sıfır hata ile geçiyor

### Doğrulama

```bash
make check
grep -c 'Kayıp bölüm' docs/reference/blueprint-map.md
ls docs/architecture/adr/*.md | wc -l    # 18 olmalı
```

### Artifact'ler
`AGENTS.md` · `BOOT.md` · `CLAUDE.md` · `ARCHITECTURE.md` · `LEGAL.md` · `SECURITY.md` · `TODO.md` · `Makefile` · `scripts/gates/` · `docs/**`

### Riskler
R6 (hukuki iddia) — `LEGAL.md` ve ADR 0006 ile azaltıldı.

---

## P1 — Depo iskeleti ve araç zinciri

- **ID:** P1
- **Durum:** `IN_PROGRESS`
- **Bağımlılık:** P0
- **Amaç:** Kod yazmaya hazır, kapıları çalışan, CI'sı ayakta bir depo.

### Alt işler

- [ ] **P1.01 — `Brewfile` ve `scripts/bootstrap.sh`.** Araçları *var mı* değil **çalışıyor mu** diye kontrol et (`--version`); eksikte uygulanabilir çözüm öner. Idempotent olduğunu iki kez çalıştırarak kanıtla.
- [ ] **P1.02 — `project.yml` (XcodeGen).** App, Daemon, CLI hedefleri; `DEPLOYMENT_TARGET: 14.0`, `ARCHS: arm64`. Ürün adı **tek değişkende**. `make generate` çalıştığını kanıtla.
- [ ] **P1.03 — SPM paket iskeletleri.** `Core`, `HardwareKit`, `SharedIPC` — boş ama derlenebilir. `Core`'un yalnızca Foundation'a bağlandığını `make gate-layers` ile kanıtla.
- [x] **P1.04 — `LICENSE`.** Apache-2.0 tam metnini **kanonik kaynaktan** indir (elle yazma — hata riski). SHA ile doğrula.
- [x] **P1.05 — `NOTICE`.** Telif bildirimi + boş atıf bölümü + "Acknowledgements".
- [ ] **P1.06 — `CONTRIBUTING.md`.** Kurulum, stil, commit kuralları, PR süreci, **bağımsız geliştirme beyanı** (`LEGAL.md` §4), yeni sensör desteği ekleme rehberi. İngilizce.
- [ ] **P1.07 — `CODE_OF_CONDUCT.md`.** Contributor Covenant 2.1.
- [ ] **P1.08 — `CHANGELOG.md`.** Keep a Changelog, `Unreleased` bölümüyle.
- [ ] **P1.09 — `.github/PULL_REQUEST_TEMPLATE.md`.** `LEGAL.md` §4 beyanının üç onay kutusu + test kontrol listesi.
- [ ] **P1.10 — Issue şablonları.** `bug_report.yml`, `feature_request.yml`, **`unknown_sensor.yml`** (çip modeli, ham sensör adları, beklenen grup) ve **`translation_fix.yml`** (tek dize düzeltme — ADR 0016 eki).
- [ ] **P1.11 — `.swiftlint.yml` ve `.swift-format`.** `Core` için zorla açma yasağı kuralı dahil. `make lint` hedefini etkinleştir.
- [ ] **P1.12 — CI iş akışı.** lint → generate → build → test → kapılar. Var olmayan hedefler **sessizce atlanmalı**, kırmamalı.
- [ ] **P1.13 — `scripts/rename-product.sh`.** Ürün adını tek komutla değiştirir. Sahte bir adla çalıştırıp geri alarak kanıtla.

### Kabul kriterleri
- `make bootstrap` temiz bir makinede çalışır ve eksikleri raporlar
- `make generate && make build` başarılı
- CI yeşil
- `make check` yeşil kalır

### Doğrulama
```bash
make bootstrap && make generate && make build && make check
```

### Riskler
R7 (tükenmişlik) — P1 mekanik ve kısa tutulmalı.

---

## P2 — Donanım okuma + Mock/Replay

- **ID:** P2
- **Durum:** `NOT_STARTED`
- **Bağımlılık:** P1
- **Amaç:** Ayrıcalıksız izleme çalışsın; **soyutlama katmanı ilk günden yerinde olsun**.

> **Bu faz ertelenemez bir yatırım içerir.** Geliştirme donanımı tek model olduğu için (R8), Mock ve Replay katmanları olmadan kod yollarının çoğu asla doğrulanamaz. → [ADR 0011](docs/architecture/adr/0011-hardware-abstraction.md)

### Alt işler

- [ ] **P2.01 — Protokoller.** `SensorSource`, `FanSource`, `FanActuator`, `PowerSource` — `SharedIPC`/`HardwareKit` içinde. Model tipleri `Core`'da, hepsi `Sendable`.
- [ ] **P2.02 — `MockSensorSource` + `MockFanSource`.** Senaryo dosyasından beslenen deterministik sahte donanım. Aynı senaryonun aynı çıktıyı verdiğini testle kanıtla.
- [ ] **P2.03 — `ReplaySensorSource`.** JSONL log'unu yeniden oynatır. Kaydedilmiş bir oturumun birebir yeniden üretildiğini kanıtla.
- [ ] **P2.04 — `LiveSensorSource`.** HID sensör servisleri üzerinden sıcaklık okuma. Gerçek donanımda sensör listesi ve makul değerler alındığını kanıtla.
- [ ] **P2.05 — `SMCSensorSource` (yedek kaynak).** Birincil başarısız olduğunda devreye girer. Birincili zorla bozup yedeğe düştüğünü testle kanıtla.
- [ ] **P2.06 — `LiveFanSource`.** Fan sayısı, anlık/min/max RPM okuma. Ayrıcalık **gerektirmediğini** kanıtla.
- [ ] **P2.07 — Sensör adı normalleştirme ve gruplama.** Desen tabanlı sınıflandırma; eşleşmeyen sensör `uncategorized`'a düşer ve **gizlenmez**.
- [ ] **P2.08 — Zarif düşüş.** Her iki kaynak da başarısızken uygulama izleme moduna düşer, **çökmez**. Testle kanıtla.
- [ ] **P2.09 — Menü çubuğu iskeleti.** `MenuBarExtra`, tek sıcaklık + fan RPM. İlk görsel çıktı.
- [ ] **P2.10 — `Core` kapsam kapısı.** CI'da `Core` kapsamı ≥ %85 bloklayıcı hale getir; eşiğin **gerçekten uygulandığını** kasıtlı düşük kapsamla kanıtla.

### Kabul kriterleri
- Daemon **olmadan** tüm sensörler ve fan hızları okunuyor
- `make gate-layers` her protokol için `Live` + `Mock` bulunduğunu doğruluyor
- Sensör kaynağı hatasında uygulama çökmüyor
- `Core` kapsamı ≥ %85 ve eşik bloklayıcı

### Doğrulama
```bash
make test && make check
```

### Riskler
R1 (API kırılması), R2 (yeni çip adlandırması), R8 (donanım kapsaması)

---

## P3 — Ayrıcalık katmanı ve daemon

- **ID:** P3
- **Durum:** `NOT_STARTED`
- **Bağımlılık:** P2
- **Amaç:** Güvenli, dar yüzeyli, kendini denetleyen ayrıcalıklı yardımcı.

### Alt işler

- [ ] **P3.01 — XPC protokolü (`SharedIPC`).** Yalnızca dört metot. `make gate-daemon` yüzeyi doğruluyor.
- [ ] **P3.02 — Daemon iskeleti + launchd plist.** `SMAppService.daemon` ile kayıt.
- [ ] **P3.00 — Development sertifikasıyla ampirik doğrulama.** `SMAppService` daemon kaydının ve XPC imza doğrulamasının ücretsiz hesap Development sertifikasıyla gerçekten çalıştığını **kanıtla** (varsayma). Çalışmıyorsa [ADR 0019](docs/architecture/adr/0019-signing-identity-deferred.md) revize edilir.
- [ ] **P3.03 — Çift yönlü imza doğrulaması.** `SecCodeCheckValidity` + `SecRequirement`. **İmzasız bir istemcinin reddedildiğini testle kanıtla.**
- [ ] **P3.04 — Kurulum akışı (UI).** Ne olacağı, hangi dosyaların nereye yazılacağı ve nasıl geri alınacağı **kurulumdan önce** gösterilir.
- [ ] **P3.05 — Sistem Ayarları yönlendirmesi.** Arka plan onayı gerekiyorsa durumu algıla ve doğrudan ilgili panele götür.
- [ ] **P3.06 — Kaldırma akışı.** UI düğmesi + `boreas uninstall --all`. Kaldırma sonrası hiçbir dosya kalmadığını kanıtla.
- [ ] **P3.07 — `Watchdog`.** Kalp atışı denetimi, 3 kaçırmada devretme. **`kill -9` ile kanıtla.**
- [ ] **P3.08 — `StateRestorer`.** Uyku, kapanış, daemon durdurma olaylarında anında devretme. Idempotent olduğunu kanıtla.
- [ ] **P3.09 — Watchdog invariant testleri.** Zaman aşımı 10–60 sn dışına ayarlanamaz; kalp atışı kesilince devredilir.

### Kabul kriterleri
- Tek yönetici kimlik doğrulaması ile kurulum
- `kill -9` sonrası fanlar ≤ watchdog süresinde firmware'e dönüyor (**gerçek donanımda ölçüldü**)
- `make gate-daemon` yeşil
- İmzasız istemci reddediliyor

### Doğrulama
```bash
make test && make check && scripts/smoke-test-hardware.sh
```

### Riskler
R5 (kurulum akışı takılması)

---

## P4 — Fan kontrolü ve güvenlik zinciri

- **ID:** P4
- **Durum:** `NOT_STARTED`
- **Bağımlılık:** P3
- **Amaç:** Fanları güvenle devralıp geri verebilmek.

### Alt işler

- [ ] **P4.01 — `LiveFanActuator`.** Devralma dizisi: orijinal durumu sakla → mod zorlamalı → hedef yaz. Kapalı çevrim doğrulama.
- [ ] **P4.02 — `releaseToFirmware`.** Devretme dizisi + üstel geri çekilmeli yeniden deneme. Idempotent.
- [ ] **P4.03 — `SafetyGovernor` (K4).** Fizikî sınır dışı komut reddedilir ve loglanır. Sınır dışı komutla kanıtla.
- [ ] **P4.04 — K1 fan tabanı.** Çıktı donanım minimumunun altına inmez.
- [ ] **P4.05 — K2 termal durum.** `ProcessInfo.thermalState`; `serious` → %55 taban, `critical` → %100. **Kapatılamaz.**
- [ ] **P4.06 — K3 panik eşiği.** `T_panic` aşımında %100, ≥30 sn kilitli. Eşik yalnızca düşürülebilir.
- [ ] **P4.07 — Güvenlik zinciri invariant testleri.** "Hiçbir katman çıktıyı düşüremez" dahil.
- [ ] **P4.08 — Manuel kontrol (tek kaydırıcı).** Tüm fanlar; güvenlik zinciri devrede.
- [ ] **P4.09 — Durum makinesi.** MONITORING / CONTROLLING / PANIC / RELEASING geçişleri loglanır.
- [ ] **P4.10 — Donanım duman testi betiği.** `scripts/smoke-test-hardware.sh` — devral/geri ver, `kill -9`, uyku/uyanma.

### Kabul kriterleri
- Fanlar güvenle devralınıp geri veriliyor
- K1–K5 invariant testleri geçiyor
- `T_panic` ve `critical` senaryoları kullanıcı ayarından bağımsız %100 üretiyor
- Duman testi gerçek donanımda geçiyor

### Doğrulama
```bash
make test && scripts/smoke-test-hardware.sh
```

### Riskler
R3 (firmware geri alması), R4 (kullanıcı kaynaklı termal risk)

---

## P5 — Kontrol motoru

- **ID:** P5
- **Durum:** `NOT_STARTED`
- **Bağımlılık:** P4
- **Amaç:** Sürekli eğri modelinin tam ve kanıtlı uygulaması.

### Alt işler

- [ ] **P5.01 — `Curve` modeli ve enterpolasyon.** Monotonluk kısıtı tip düzeyinde zorlanır.
- [ ] **P5.02 — Özellik testleri (eğri).** "Monoton eğri monoton çıktı üretir", "çıktı her zaman `[fanMin, fanMax]` aralığında".
- [ ] **P5.03 — EWMA yumuşatma.** `α` parametresi; sınır davranışı (0.0 ve 1.0) testli.
- [ ] **P5.04 — Çift eğri histerezis.** Yön kilidi dahil. Eşik çevresinde salınım olmadığını testle kanıtla.
- [ ] **P5.05 — Asimetrik hız sınırlayıcı.** `maxRise` / `maxFall` bağımsız uygulanır.
- [ ] **P5.06 — Sensör toplayıcı.** `max` / `mean` / `p95`; grup bazlı seçim.
- [ ] **P5.07 — Profil modeli ve tetikleyiciler.** Güç kaynağı, uygulama, zaman, pil, ekran, termal durum, elle.
- [ ] **P5.08 — Arbitraj.** Öncelik sırası + elle seçimin üstünlüğü + geçişlerde sıçrama olmaması.
- [ ] **P5.09 — Karşılaştırma testi.** "Ayrık basamaklı model uygulansaydı eşikte sıçrama olurdu" — ADR 0010'u kodda yaşatır.
- [ ] **P5.10 — Yapılandırma şeması + doğrulama.** `schema/config.schema.json`; aralık kısıtları; **bozuk yapılandırma çökertmez** testi.
- [ ] **P5.11 — Şema göçü altyapısı.** Sürüm alanı, göç fonksiyonu, göç öncesi yedek. Veri kaybı olmadığını testle kanıtla.
- [ ] **P5.12 — Altın dosya senaryoları.** Kaydedilmiş termal senaryolar → beklenen komut dizisi.

### Kabul kriterleri
- Tüm motor invariantları geçiyor
- Bozuk yapılandırma uygulamayı çökertmiyor, son geçerli hale dönüyor
- Altın dosya testleri geçiyor
- `Core` kapsamı ≥ %85

### Doğrulama
```bash
make test && make check
```

---

## P6 — Kullanıcı arayüzü

- **ID:** P6
- **Durum:** `NOT_STARTED`
- **Bağımlılık:** P5
- **Amaç:** Ürünün yüzü — eğri editörü dahil.

### Alt işler

- [ ] **P6.01 — Tasarım sistemi.** Sıcaklık ve fan için **ayrı sürekli renk skalaları**; kırmızı yalnızca panik/hata.
- [ ] **P6.02 — Menü çubuğu paneli.** Profil seçici, fanlar, gruplu sıcaklıklar.
- [ ] **P6.03 — Menü çubuğu durum öğesi.** Yapılandırılabilir içerik, yatay/dikey, kompakt mod, gizlenme uyarısı.
- [ ] **P6.04 — Ana pencere — İzleme sekmesi.** Swift Charts; **sıcaklık ve fan grafiği aynı zaman ekseninde**.
- [ ] **P6.05 — Ana pencere — Kontrol sekmesi.** Aktif profil **ve neden aktif olduğu**; güvenlik zinciri durumu.
- [ ] **P6.06 — Eğri editörü.** Sürüklenebilir noktalar, monotonluk kısıtı, canlı çalışma noktası, 60 sn izi, histerezis bandı.
- [ ] **P6.07 — Eğri editörü — sayısal düzenleme.** Tablo görünümü; erişilebilirlik ve hassasiyet için.
- [ ] **P6.08 — Ayarlar penceresi.** Yedi sekme.
- [ ] **P6.09 — Ana pencere — Tanılama sekmesi.** Dürüstlük kuralına uygun ifadeler.
- [ ] **P6.10 — Global kısayollar.**
- [ ] **P6.11 — Yerelleştirme altyapısı + `en`/`tr`.** String Catalog; `make gate-i18n` yeşil.
- [ ] **P6.12 — Erişilebilirlik geçişi.** VoiceOver, klavye gezinme, eğrinin nokta listesi olarak sunumu, renk-bağımsız bilgi.
- [ ] **P6.13 — Pseudo-locale düzen testi.** CI'da; yapay uzatılmış dize ile taşma denetimi.

### Kabul kriterleri
- `make gate-i18n` yeşil
- VoiceOver ile tüm kritik akışlar tamamlanabiliyor
- Pseudo-locale testinde taşma yok
- Eğri editörü monotonluk kısıtını zorluyor

---

## P7 — Olgunlaşma

- **ID:** P7
- **Durum:** `NOT_STARTED`
- **Bağımlılık:** P6
- **Amaç:** Günlük kullanımda güvenilir bir ürün.

### Alt işler

- [ ] **P7.01 — Bildirim sistemi.** Tetikleyiciler + **bastırma penceresi** + oturum başına bir kez kuralı + toplama.
- [ ] **P7.02 — Log altyapısı.** JSONL/CSV, döndürme, sert disk üst sınırı. **Aktif güvenlik katmanı kaydedilir.**
- [ ] **P7.03 — Tanılama kontrolleri.** Fan tepkisi, fan dengesi, sensör geçerliliği, termal geçmiş, pil, depolama.
- [ ] **P7.04 — CLI (`boreas`).** `status`, `profile`, `install`, `uninstall --all`, `export`, `import`.
- [ ] **P7.05 — Destek raporu üreteci.** **Yerel dosya**, otomatik gönderim yok.
- [ ] **P7.06 — `ru` / `es` / `zh-Hans` çevirileri.** Rusça çoğul biçimleri doğru.
- [ ] **P7.07 — `TRANSLATORS.md`.**
- [ ] **P7.08 — Sorun giderme dokümantasyonu.** `docs/` altında; README'ye özet.
- [ ] **P7.09 — Bilinmeyen sensör raporu akışı.** UI'dan tek tıkla issue şablonu doldurma.

---

## P8 — Yayın

- **ID:** P8
- **Durum:** `NOT_STARTED`
- **Bağımlılık:** P7, M01, M02, M03, M04
- **Amaç:** İmzalı, notarize, keşfedilebilir bir v1.0.

### Alt işler

- [ ] **P8.01 — İmzalama betiği.** Uygulama, daemon ve CLI ayrı ayrı; Hardened Runtime.
- [ ] **P8.02 — Notarizasyon betiği.** `notarytool` + `stapler`. **Başarısızsa sürüm üretilmez.**
- [ ] **P8.03 — DMG üretimi.** SHA-256 yayınlanır.
- [ ] **P8.04 — CI release job'ı.** Etiketle tetiklenir.
- [ ] **P8.05 — Ürün `README.md` (İngilizce).** Simge kaynağı hazır: `Design/icon/`. `docs/release/readme-spec.md`'ye göre; **"Test edilen donanım" bölümü dürüst**.
- [ ] **P8.06 — README çevirileri.** `tr`, `ru`, `es`, `zh-Hans` + "geride kalmış olabilir" notu.
- [ ] **P8.07 — Keşfedilebilirlik kurulumu.** Depo açıklaması, topics, Homebrew cask `desc`, README SSS.
- [ ] **P8.08 — Homebrew cask.** Gönderim (M05'e bağlı).
- [ ] **P8.09 — Sürüm kapıları kontrol listesi.** `ARCHITECTURE.md` §10'daki tüm kapılar yeşil.

---

<a id="manuel-isler"></a>
## Manuel işler — sistem dışı

Ajanın yapamayacağı, **proje sahibinin** yapması gereken işler. *"Bende ne var?"* sorusunun kanonik cevabı burasıdır.

| # | İş | Neden gerekli | Bloke ettiği | Durum |
|---|---|---|---|---|
| M01 | Marka araması (`Boreas`) | Ad kesinleşmeden yayın yapılmamalı | P8 | **DONE** (2026-08-03, engel yok) |
| M02 | GitHub deposu oluştur: `boreas-mac-fan-control`, açıklama ve topics ayarla | Depo olmadan CI ve dağıtım yok | P1.12, P8 | **DONE** (2026-08-02, private) |
| M03 | Developer ID sertifikasını dışa aktar, GitHub secret olarak tanımla | Yalnızca dağıtım için. P1–P7 gerektirmiyor — bkz. [ADR 0019](docs/architecture/adr/0019-signing-identity-deferred.md) | **yalnızca P8** | OPEN (ertelendi) |
| M04 | App Store Connect API anahtarı üret (notarytool için), secret olarak tanımla | Notarizasyon için zorunlu | **yalnızca P8** | OPEN (ertelendi) |
| M05 | Homebrew cask adı müsaitliğini doğrula ve gönderim yap | Birincil dağıtım kanalı | P8.08 | OPEN |
| M06 | ~~Anadili konuşuru çeviri incelemesi~~ | **KALDIRILDI** (2026-08-03). Çeviriler proje içinde üretilir; köken `TRANSLATORS.md`'de işaretlenir — [ADR 0016 eki](docs/architecture/adr/0016-language-scope.md) | — | İPTAL |
| M07 | Topluluktan farklı Mac modelleri için sensör/fan raporu toplama | R8 — doğrulanamayan kod yolları | Sürekli | OPEN |
| M08 | Uygulama simgesi tasarımı | Görsel kimlik | P8.05 | **DONE** (2026-08-03, `Design/icon/`) |

**Girmez:** yerel araç kurulumu (`brew install …`), bozuk yerel kurulum onarımı, `xcodegen generate`. **Bunlar ajanın işidir.**

---

## Faz üstü yayın blokajları

Checkbox sırasından bağımsız, yayını **durduran** koşullar:

| # | Blokaj |
|---|---|
| B1 | Depoda herhangi bir üçüncü taraf ticari ürün adı bulunması (`LEGAL.md` Y5) |
| B2 | `make check` kapılarından herhangi birinin kırmızı olması |
| B3 | Bir güvenlik zinciri invariant testinin geçmemesi |
| B4 | Notarizasyonun başarısız olması |
| B5 | `kill -9` duman testinin gerçek donanımda geçmemiş olması |
| B6 | README'de "Test edilen donanım" bölümünün eksik veya kapsamı abartıyor olması |
| B7 | Herhangi bir dilde eksik çeviri nedeniyle boş arayüz metni görünmesi |
| B8 | Depoda imzalama materyali veya gizli değer bulunması |

---

## Run Log

Append-only. Geçmiş **yeniden yazılmaz**; yanlış kayıt yeni bir satırla düzeltilir.

| UTC | Oturum | İş | Sonuç | Özet | Doğrulama | Artifact'ler | Risk/Blokaj | Handoff |
|---|---|---|---|---|---|---|---|---|
| 2026-07-31 | kurulum | P0.01–P0.07 | DONE | Depo başlatıldı, blueprint donduruldu (SHA-256 eşleşmesi kanıtlandı), yönetişim katmanı ve sekiz kapı yazıldı. **Bulgu:** kapılar ilk yazımda `mapfile` kullanıyordu; macOS `/bin/bash` 3.2.57'de bu komut yok, tarama hiç çalışmıyor ve kapı yine de PASS veriyordu — klasik sahte kapı. `scripts/gates/_lib.sh` ile bash 3.2 uyumlu hale getirildi ve `require_tools` eklenerek eksik komutta sessiz geçiş imkânsız kılındı. | `make gate-names` PASS · `make blueprint-check` PASS · sekiz kapının tamamı kasıtlı ihlalle kanıtlandı (8/8 yakaladı) | `AGENTS.md` `BOOT.md` `CLAUDE.md` `ARCHITECTURE.md` `LEGAL.md` `Makefile` `scripts/gates/*` | — | Next: P0.08 |
| 2026-07-31 | kurulum | P0.08–P0.32 | DONE | 18 ADR (`Zorlama` bölümleri dolu), `docs/` ağacı, izlenebilirlik matrisi (25/25 eşlendi, kayıp 0), `SECURITY.md`. **Bulgu:** `privilege-model.md` yazılırken yanlışlıkla bir üçüncü taraf helper yolu metne girdi — Y5 ihlali. Dosya commit edilmeden düzeltildi; git geçmişi taranarak temiz olduğu doğrulandı. Bu olay ADR 0006'daki "otomatik katman ad listesi tutamaz" sınırlamasının neden insan incelemesi katmanı gerektirdiğini somutlaştırıyor. **İkinci bulgu:** geçmiş taraması için yazdığım `... \| grep \| head` komutu her zaman 0 dönüyordu (`head` exit kodu) — kontrol komutunun kendisi sahte kapıydı; sayım tabanlı kontrole çevrildi. | Yasaklı terim taraması: geçmişte 0, çalışma ağacında 0 eşleşme | 18 ADR · `docs/**` (44 dosya) · `SECURITY.md` | R6 azaltıldı | Next: P0.33 |
| 2026-07-31 | kurulum | P0.33–P0.34 | DONE | Kök README (geliştirme giriş noktası) yazıldı ve `make check` tam yeşile alındı. **Bulgu 1:** gate-names, kuralı TARİF eden dosyaları yakalıyordu (readme-spec, ADR 0002 vb.). Sabit istisna listesi yerine `gate-names:policy-doc` işaretleyici konvansiyonu kuruldu; dosya kendi muafiyetini beyan eder, kapı muaf dosya sayısını her çalıştığında raporlar. Muafiyet eklendikten sonra kapı **yeniden kanıtlandı** (işaretleyicisiz ihlal yakalanıyor, işaretleyicili muaf oluyor). **Bulgu 2:** docs-check, `AGENTS.md`'de var olmayan bir kapıya (`gate-repo` hedefi) referans verdiğimi yakaladı; referans `gate-layers` hedefine düzeltildi ve `format`/`release` hedefleri Makefile'a eklendi. Dondurulmuş blueprint bu denetimden çıkarıldı (planlanan hedefleri tarif ediyor, mevcut durumu değil). **Bulgu 3:** probe temizliğinde `git checkout` iki kez staged bozuk sürümü geri getirdi — probe'lardan sonra `git checkout` değil, doğrudan içerik onarımı yapılmalı. | `make check` exit=0, 8/8 kapı PASS · docs-check 3 ayrı ihlalle kanıtlandı (kırık link, matriste var olmayan hedef, indekste olmayan ADR) | `README.md` `TODO.md` `LEGAL.md` `Makefile` `scripts/gates/check-docs.sh` | — | Next: P1.01 |
| 2026-07-31 | kurulum | P0.34 (düzeltme) | DONE | Önceki kayıt commit edilirken `make check` kırmızıydı ve bu fark edilmeden commit atıldı — disiplin ihlali, düzeltici commit ile kapatıldı. Sebep özyineleme: docs-check, **Run Log'un kendisinde** var olmayan bir hedefe `make <hedef>` biçiminde referans verdiğimi yakaladı. Metin, hedef adını `make` öneki olmadan yazacak şekilde düzeltildi. **Ders:** doküman metni de kapı kapsamındadır; bir bulguyu anlatırken kullanılan söz dizimi kapıyı tetikleyebilir. | `make check` exit=0, 8/8 PASS | `TODO.md` | — | Next: P1.01 |
| 2026-08-02 | kurulum | M02, P1.04, P1.05 | DONE | GitHub deposu `mahirozdin/boreas-mac-fan-control` oluşturuldu ve push edildi; açıklama ile 16 konu etiketi §18.4'e göre ayarlandı; wiki ve projects kapatıldı. **Depo bilinçli olarak PRIVATE açıldı:** o an `LICENSE` yoktu ve lisanssız yayınlanan bir depo varsayılan olarak "tüm hakları saklıdır" sayılır — açık kaynak niyetinin tersi. Ardından P1.04 ve P1.05 yapıldı, artık public'e çevirmeyi engelleyen bir şey yok; karar proje sahibinde. LICENSE metni GitHub Licenses API'sinden alındı (yeni bir dış kaynağa gerek kalmadı, gh zaten yetkiliydi); 202 satır, patent hibesi maddesi doğrulandı. LICENSE içindeki apache.org bağlantısı nedeniyle gate-names allowlist'ine `apache.org` eklendi. | `make check` exit=0, 8/8 PASS · LICENSE bütünlük kontrolleri PASS (başlık, sürüm, patent maddesi, 202 satır) | `LICENSE` `NOTICE` `TODO.md` `scripts/gates/check-names.sh` | M02 kapandı | Next: P1.01 |
| 2026-08-03 | kurulum | M01, M06, M08 + ADR 0019 | DONE | **M01** kapandı (proje sahibi marka araması yaptı, engel yok). **M06 iptal** — çeviriler proje içinde üretilecek; ADR 0016'ya ek yazıldı: köken `TRANSLATORS.md`'de açıkça işaretlenir, `translation_fix.yml` şablonu eklenir. Kaliteyi garanti edemediğimiz yerde en azından dürüst oluyoruz. **M08 tamamlandı** — dört kanatlı fan simgesi elle yazılmış SVG geometrisiyle üretildi (üretken görsel YZ kullanılmadı: telif kökeni belirsiz olurdu, LEGAL.md bunu kaldırmaz). On varyant elendi. **Rasterleştirme gerçek bir geometri hatası yakaladı:** kanat kökleri r=110'da, göbek r=88'de — 22px boşluk, önizleme boyutunda görünmüyordu, tam çözünürlükte kırık eklem olarak çıktı; kök göbeğin içine alındı. İlk beş varyant (ince kanat) 'örümcek/X' gibi okunuyordu, geniş kanat geometrisine geçildi. **ADR 0019** yazıldı: imzalama kimliği P8 ön koşulu, P1–P7 bloke değil; Yol B (imzasız) seçilirse ayrıcalıklı daemon'un çalışmayacağı ve ürünün ikiye bölüneceği önceden kayda geçti. | `make check` exit=0 · docs-check 19 ADR senkronu PASS · simge 1024/512/256/128/64/32'de görsel doğrulandı | `Design/icon/*` · `docs/architecture/adr/0019-*` · ADR 0016 eki · `ARCHITECTURE.md` `decisions.md` `ui.md` `TODO.md` | M03/M04 P8'e ertelendi | Next: P1.01 |

### Run Log kayıt şablonu

```
| YYYY-MM-DD | <oturum> | P<n>.<nn> | DONE/BLOCKED | <ne yapıldı ve NEDEN öyle yapıldı; beklenmedik bulgular> | <komutlar + PASS/FAIL/NOT RUN+neden> | <dosyalar> | <risk> | Next: P<n>.<nn> |
```

**Kurallar:**
- `NOT RUN` yazmaktan çekinme — "yazdım, çalışıyordur" sistemi yalancı yapar
- Beklenmedik bulguyu **kanıtıyla** yaz; bir sonraki oturum aynı tuzağa düşmesin
- `Handoff` tek ve kesin bir iş olmalı
