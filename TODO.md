# Boreas Master TODO — P0 → P8

- **Plan sürümü:** 1.0
- **Baseline tarihi:** 2026-07-31
- **Kaynak blueprint:** v1.1 (dondurulmuş: `docs/blueprint/boreas-blueprint-v1.1.md`)
- **Genel durum:** P0–P2 tamam, P3 ilerliyor. **Ayrıcalıklı yardımcı bu makinede kurulu ve çalışıyor:** XPC bağlantısı kuruldu, imza doğrulaması iki yönde de kanıtlandı, fan ayrıcalıklı yoldan okundu. 77 test, 9 kapı. Sıradaki: P3.04.

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
| P1 | `DONE` | Depo iskeleti ve araç zinciri | (tamamlandı) |
| P2 | `DONE` | Donanım okuma + Mock/Replay | (tamamlandı) |
| P3 | `IN_PROGRESS` | Ayrıcalık katmanı ve daemon | **P3.04 — kurulum akışı (UI)** |
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
- **Durum:** `DONE`
- **Bağımlılık:** P0
- **Amaç:** Kod yazmaya hazır, kapıları çalışan, CI'sı ayakta bir depo.

### Alt işler

- [x] **P1.01 — `Brewfile` ve `scripts/bootstrap.sh`.** Araçları *var mı* değil **çalışıyor mu** diye kontrol et (`--version`); eksikte uygulanabilir çözüm öner. Idempotent olduğunu iki kez çalıştırarak kanıtla.
- [x] **P1.02 — `project.yml` (XcodeGen).** App ve CLI hedefleri (**Daemon hedefi P3.02'ye taşındı**: boş bir daemon iskeleti `gate-daemon`'ı haklı olarak kırıyor, çünkü XPC imza doğrulaması arıyor); `DEPLOYMENT_TARGET: 14.0`, `ARCHS: arm64`. Ürün adı **tek değişkende**. `make generate` çalıştığını kanıtla.
- [x] **P1.03 — SPM paket iskeletleri.** `Core`, `HardwareKit`, `SharedIPC` — boş ama derlenebilir. `Core`'un yalnızca Foundation'a bağlandığını `make gate-layers` ile kanıtla.
- [x] **P1.04 — `LICENSE`.** Apache-2.0 tam metnini **kanonik kaynaktan** indir (elle yazma — hata riski). SHA ile doğrula.
- [x] **P1.05 — `NOTICE`.** Telif bildirimi + boş atıf bölümü + "Acknowledgements".
- [x] **P1.06 — `CONTRIBUTING.md`.** Kurulum, stil, commit kuralları, PR süreci, **bağımsız geliştirme beyanı** (`LEGAL.md` §4), yeni sensör desteği ekleme rehberi. İngilizce.
- [x] **P1.07 — `CODE_OF_CONDUCT.md`.** Contributor Covenant 2.1.
- [x] **P1.08 — `CHANGELOG.md`.** Keep a Changelog, `Unreleased` bölümüyle.
- [x] **P1.09 — `.github/PULL_REQUEST_TEMPLATE.md`.** `LEGAL.md` §4 beyanının üç onay kutusu + test kontrol listesi.
- [x] **P1.10 — Issue şablonları.** `bug_report.yml`, `feature_request.yml`, **`unknown_sensor.yml`** (çip modeli, ham sensör adları, beklenen grup) ve **`translation_fix.yml`** (tek dize düzeltme — ADR 0016 eki).
- [x] **P1.11 — `.swiftlint.yml` ve `.swift-format`.** `Core` için zorla açma yasağı kuralı dahil. `make lint` hedefini etkinleştir.
- [x] **P1.12 — CI iş akışı.** lint → generate → build → test → kapılar. Var olmayan hedefler **sessizce atlanmalı**, kırmamalı.
- [x] **P1.13 — `scripts/rename-product.sh`.** Ürün adını tek komutla değiştirir. Sahte bir adla çalıştırıp geri alarak kanıtla.

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
- **Durum:** `DONE`
- **Bağımlılık:** P1
- **Amaç:** Ayrıcalıksız izleme çalışsın; **soyutlama katmanı ilk günden yerinde olsun**.

> **Bu faz ertelenemez bir yatırım içerir.** Geliştirme donanımı tek model olduğu için (R8), Mock ve Replay katmanları olmadan kod yollarının çoğu asla doğrulanamaz. → [ADR 0011](docs/architecture/adr/0011-hardware-abstraction.md)

### Alt işler

- [x] **P2.01 — Protokoller.** `SensorSource`, `FanSource`, `PowerSource` (**`FanActuator` P4.01'e taşındı** — yazma yolu, `Live` uygulaması daemon'a bağlı) — `SharedIPC`/`HardwareKit` içinde. Model tipleri `Core`'da, hepsi `Sendable`.
- [x] **P2.02 — `MockSensorSource` + `MockFanSource`.** Senaryo dosyasından beslenen deterministik sahte donanım. Aynı senaryonun aynı çıktıyı verdiğini testle kanıtla.
- [x] **P2.03 — `ReplaySensorSource`.** JSONL log'unu yeniden oynatır. Kaydedilmiş bir oturumun birebir yeniden üretildiğini kanıtla.
- [x] **P2.04 — `LiveSensorSource`.** HID sensör servisleri üzerinden sıcaklık okuma. Gerçek donanımda sensör listesi ve makul değerler alındığını kanıtla.
- [x] **P2.05 — `SMCSensorSource` (yedek kaynak).** Birincil başarısız olduğunda devreye girer. Birincili zorla bozup yedeğe düştüğünü testle kanıtla.
- [x] **P2.06 — `LiveFanSource`.** Fan sayısı, anlık/min/max RPM okuma. Ayrıcalık **gerektirmediğini** kanıtla.
- [x] **P2.07 — Sensör adı normalleştirme ve gruplama.** Desen tabanlı sınıflandırma; eşleşmeyen sensör `uncategorized`'a düşer ve **gizlenmez**.
- [x] **P2.08 — Zarif düşüş.** Her iki kaynak da başarısızken uygulama izleme moduna düşer, **çökmez**. Testle kanıtla.
- [x] **P2.09 — Menü çubuğu iskeleti.** `MenuBarExtra`, tek sıcaklık + fan RPM. İlk görsel çıktı.
- [x] **P2.10 — `Core` kapsam kapısı.** CI'da `Core` kapsamı ≥ %85 bloklayıcı hale getir; eşiğin **gerçekten uygulandığını** kasıtlı düşük kapsamla kanıtla.

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
- **Durum:** `IN_PROGRESS`
- **Bağımlılık:** P2
- **Amaç:** Güvenli, dar yüzeyli, kendini denetleyen ayrıcalıklı yardımcı.

### Alt işler

- [x] **P3.00 — Development sertifikasıyla ampirik doğrulama.** `SMAppService` daemon kaydının ve XPC imza doğrulamasının ücretsiz hesap Development sertifikasıyla gerçekten çalıştığını **kanıtla** (varsayma). Çalışmıyorsa [ADR 0019](docs/architecture/adr/0019-signing-identity-deferred.md) revize edilir.
- [x] **P3.01 — XPC protokolü (`SharedIPC`).** Yalnızca dört metot. `make gate-daemon` yüzeyi doğruluyor.
- [x] **P3.02 — Daemon iskeleti + launchd plist.** `SMAppService.daemon` ile kayıt.
- [x] **P3.03 — Çift yönlü imza doğrulaması.** `SecCodeCheckValidity` + `SecRequirement`. **İmzasız bir istemcinin reddedildiğini testle kanıtla.**
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
- **Bağımlılık:** P7
- **Amaç:** İmzalı, notarize, keşfedilebilir bir v1.0.

### Alt işler

- [ ] **P8.01 — İmzalama betiği.** Uygulama, daemon ve CLI ayrı ayrı; Hardened Runtime. ⛔ M03
- [ ] **P8.02 — Notarizasyon betiği.** `notarytool` + `stapler`. **Başarısızsa sürüm üretilmez.** ⛔ M03 M04
- [ ] **P8.03 — DMG üretimi.** SHA-256 yayınlanır. ⛔ M03
- [ ] **P8.04 — CI release job'ı.** Etiketle tetiklenir. ⛔ M03 M04
- [ ] **P8.05 — Ürün `README.md` (İngilizce).** Simge kaynağı hazır: `Design/icon/`. `docs/release/readme-spec.md`'ye göre; **"Test edilen donanım" bölümü dürüst**.
- [ ] **P8.06 — README çevirileri.** `tr`, `ru`, `es`, `zh-Hans` + "geride kalmış olabilir" notu.
- [ ] **P8.07 — Keşfedilebilirlik kurulumu.** Depo açıklaması, topics, Homebrew cask `desc`, README SSS.
- [ ] **P8.08 — Homebrew cask.** Gönderim (M05'e bağlı). ⛔ M05
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
| 2026-08-03 | kurulum | Seçim mekanizması + P1 (11 iş) | DONE | **Yapısal değişiklik:** sıradaki iş seçimi `scripts/next-task.py` ile makineye devredildi. Manuel işe bağlı her iş atlanıyor, faz sınırı tanınmıyor. P8 işlerine ⛔ işaretleri kondu; üç senaryoyla kanıtlandı (bloke olmayan iş seçilir · yalnız bloke kalınca exit=1 + hangi manuel iş gerektiği · manuel iş çözülünce iş açılır). `AGENTS.md` §4 ve `BOOT.md` §4 buna bağlandı. **P1:** araç zinciri kuruldu (xcodegen/swiftlint/xcbeautify), `swift format`'ın Swift 6.2'ye yerleşik olduğu görülüp ayrı paket bağımlılığı düşürüldü. Üç SPM paketi (Core/HardwareKit/SharedIPC) derleniyor, 4 test geçiyor. `project.yml` yazıldı, App ve CLI derleniyor, CLI çalıştırıldı. Lint, LICENSE, NOTICE, CONTRIBUTING, CODE_OF_CONDUCT, CHANGELOG, PR ve 4 issue şablonu, CI. **Dört gerçek hata yakalandı ve düzeltildi:** (1) `bootstrap.sh` komutu tek string olarak geçiriyordu, zsh kelime ayırması yapmadığı için sağlıklı Xcode'u bozuk sanıyordu — argüman dizisine çevrildi. (2) SwiftLint özel kuralında `^` satır başına değil dosya başına bağlanıyor; `\b` + `match_kinds: [identifier]` ile düzeltildi. (3) `rename-product.sh` BSD sed'de çalışmayan `\b` kelime sınırı kullanıyordu, ad sessizce değişmiyordu — `[[:<:]]` `[[:>:]]` ile düzeltildi. (4) `docs-check` İngilizce düzyazıdaki 'make participation' fiilini Makefile hedefi sanıyordu — yalnızca ters tırnak veya kod bloğu bağlamı sayılacak şekilde daraltıldı. **Kapsam düzeltmesi:** Daemon hedefi P1.02'den çıkarılıp P3.02'ye taşındı; boş bir daemon iskeleti `gate-daemon`'ı haklı olarak kırıyor. | `make check` 8/8 PASS · `make build` PASS · `make test` 4/4 PASS · `make lint` PASS · Xcode App ve CLI derlemesi PASS · CLI çalıştırıldı · next-task 3 senaryo · lint özel kuralları 4 vaka · rename script gerçek dosyalarda · docs-check 3 vaka | `scripts/next-task.py` `scripts/bootstrap.sh` `scripts/rename-product.sh` `Brewfile` `project.yml` `Packages/**` `App/**` `CLI/**` `.swiftlint.yml` `.swift-format` `.github/**` `CONTRIBUTING.md` `CODE_OF_CONDUCT.md` `CHANGELOG.md` | — | Next: P2.01 |
| 2026-08-03 | kurulum | P1.12 doğrulama | DONE | CI uzakta çalıştırıldı ve **gerçek bir uyumsuzluk yakaladı**: runner'ın varsayılan Xcode'u Swift 6.1 sunuyordu, paketler `swift-tools-version: 6.2` istiyor → 'Could not resolve package dependencies'. Yerelde görünmeyen bir hataydı. İş akışına en yeni `Xcode*.app`'i seçen ve Swift < 6.2 ise **sessizce geçmek yerine açık hata veren** bir adım eklendi. Runner Xcode 26.6.0 / Swift 6.3 seçti. Üç job da yeşil. | GitHub Actions: Gates ✓ · Lint ✓ · Build and test ✓ · 4/4 test · App ve CLI derlemesi ✓ | `.github/workflows/ci.yml` | — | Next: P2.01 |
| 2026-08-03 | kurulum | P2.07 + Core model tipleri | DONE | Core'a beş model tipi (`SensorGroup`, `SensorReading`, `FanState`, `Duty`, `PowerContext`) ve `SensorClassifier` yazıldı; 21 test geçiyor. **Tasarım kararı — `Duty` bir tip, `Double` değil:** her çağrı yerinin clamp etmeyi hatırlaması gerekseydi, unutan biri donanımın kabul etmediği bir fan komutu üretirdi. Geçersiz değeri tutamayan bir tip bu hata sınıfını test etmek yerine ortadan kaldırıyor. **Test gerçek bir boşluk yakaladı:** `Duty(.infinity)` sıfıra çöküyordu — yanlış yön. Fan kontrolünde iki hata simetrik değil: fazla hava gürültü, az hava ısı. Belirsiz girdi artık YUKARI çözülüyor (`+inf`→1, `NaN`→1, gerekçesi kodda yazılı). Bu, güvenlik zincirinin 'hiçbir katman çıktıyı düşüremez' kuralının tip düzeyindeki karşılığı. **Sınıflandırma sıralaması kritik:** `efficiency` kuralı generic `cpu`'dan ÖNCE denenmezse her verimlilik kümesi performans olarak dosyalanır — test bunu koruyor. Eşleşmeyen sensör `uncategorized`'a düşüyor ve gizlenmiyor; donanım desteğinin eksik olduğunu gösteren tek sinyal bu. | `swift test` 21/21 PASS · `make check` 8/8 · `make lint` PASS | `Packages/Core/Sources/Core/Models/*` `Sensors/SensorClassifier.swift` + testler | — | Next: P2.01 |
| 2026-08-03 | kurulum | P2.01–P2.03, P2.05–P2.07 | DONE | Donanım katmanı: 3 protokol, 3 Mock, Replay, 3 Live uygulaması (SMC sensör, SMC fan, IOKit güç). 48 test geçiyor. **Gerçek donanımda doğrulandı:** Mac mini M4'te 174 sensör ve 1 fan (1000 rpm, 1000–4900) okunuyor. **En değerli bulgu — mock'un yakalayamayacağı bir hata:** `SMCKeyData_t`'yi Swift struct olarak tanımlamıştım; alan boyutları doğru görünüyordu ama C hizalama dolgusu tutmuyordu ve her çağrı `kIOReturnBadArgument` dönüyordu. Birim testler bunu asla yakalayamazdı — bir mock struct dolgusu konusunda anlaşmazlığa düşemez. 80 baytlık tampona açık offsetlerle yazmaya çevrildi, offset tablosu kodda yazılı. **İkinci bulgu:** SMC anahtarları `TCMz` gibi opak kodlar, okunabilir adlar değil — 174 sensörün 174'ü `uncategorized` düşüyordu. Gerçek donanımdaki önek dağılımı incelenip SMC anahtar sezgileri eklendi (Tp/Te/Tg/Ts/TH…); artık yalnızca 5'i sınıflandırılamıyor. Okunabilir adlar için HID kaynağı (P2.04) hâlâ gerekli. **Üçüncü:** Swift 6 strict concurrency `NSLock`'u async bağlamda reddediyor — durumlu mock'lar `actor`'a çevrildi. **Araç çakışması:** `swift-format` trailing comma ekliyor, SwiftLint yasaklıyordu; `make format` her çalıştığında `make lint` kırılıyordu. Sınır netleştirildi: biçim swift-format'ın, anlam SwiftLint'in işi. **Kapı hatası:** `grep -i` yüzünden `instead of [A-Z]` kalıbındaki büyük harf şartı anlamsızlaşmış, 'instead of returning' bile eşleşiyordu — harf duyarlı kalıplar ayrıldı. Ayrıca kapıların `**/*.swift` glob'u alt dizinleri bulamıyordu, dizin yoluna çevrildi. **Kapsam:** `FanActuator` P4.01'e taşındı (yazma yolu, `Live` uygulaması daemon'a bağlı). | `swift test` 48/48 PASS · `make check` 8/8 · `make lint` PASS · gerçek donanımda `boreas status` ve `boreas sensors` çalıştırıldı | `Packages/Core/Sources/Core/{Models,Sensors}` `Packages/HardwareKit/Sources/HardwareKit/{Protocols,Mock,Replay,Live,SMC}` `CLI/Sources/main.swift` + testler | — | Next: P2.04 |
| 2026-08-04 | kurulum | P2.04, P2.08–P2.10 + ADR 0020 | DONE | **HID sensör kaynağı** yazıldı — `dlsym` ile çözülen dokümante edilmemiş arayüz; her sembol opsiyonel, çözülemezse SMC'ye düşülüyor. Gerçek donanımda **40 adlandırılmış sensör** (`PMU tdie1`, `NAND CH0 temp`) döndürüyor, SMC yolunun 174 opak anahtarı yerine. **Gerçek donanım bir sınıflandırma hatası ortaya çıkardı:** 40 sensörün 39'u `PMU tdie<n>` biçiminde ve `pmu → power` kuralı hepsini güç grubuna atıyordu. Kullanıcı `compute.performance`'a eğri bağlasa bu makinede **hiçbir sensör eşleşmezdi** — sessizce hiçbir şeye bağlı bir eğri, en kötü başarısızlık türü çünkü fark edilmiyor. Blueprint taksonomisinde bu sensörler için karşılık yoktu; **ADR 0020** ile `compute` grubu eklendi (küme atfedilemeyen die sıcaklıkları). `tdie`/`tdev` kuralları generic `pmu`'dan önce deneniyor ve bu sıralama testle korunuyor. Şimdi 37 sensör `compute`'ta. **Zarif düşüş** `FallbackSensorSource` olarak ayrıldı ki mock'larla test edilebilsin — iki gerçek arka ucu bağlayıp ummak test değil. Tek hata demote etmiyor (3 ardışık gerekiyor), toparlanma anında. 8 test. **Menü çubuğu uygulaması** canlı veriyle çalışıyor: gerçek donanımda başlatıldı, CPU %0,0, Dock simgesi yok, hata log'u yok. Bellek 73,4 MB — hedef 60 MB, ancak bu Debug derlemesi; Release ölçümü P6'da yapılmalı. **Kapsam kapısı** eklendi ve eşiği gerçekten zorladığı kanıtlandı (%99 eşikle kırmızı, %50 ile yeşil). Kapı bir boşluk gösterdi: `PowerContext` Core'daydı ama testi HardwareKit'teydi, kapsamı %0 görünüyordu — Core testleri eklendi, kapsam %95,8 → %99,4. | `swift test` 69/69 PASS · `make check` 9/9 · `make lint` PASS · gerçek donanımda CLI ve uygulama çalıştırıldı · kapsam kapısı iki eşikle kanıtlandı | `HIDSensorSource` `FallbackSensorSource` `LiveSensorSource` `SMCSensorSource` `App/Sources/**` `scripts/gates/check-coverage.sh` ADR 0020 | Bellek hedefi Release'te doğrulanmalı | Next: P3.00 |
| 2026-08-04 | kurulum | P3.01–P3.03 | DONE | Ayrıcalıklı yardımcı yazıldı: dört metotluk XPC yüzeyi, K4 güvenlik süzgeci, watchdog, IOKit güç bildirimleri. Uygulama paketine gömüldü, ikisi de `WWRZ5CG3DW` takımıyla imzalandı. **Sertifika bulgusu (P3.00'ın yarısı):** `security find-identity` çıktısındaki parantez içi değer **Team ID değil** — `B5PZ4CX3SA` etiketli sertifikanın gerçek takımı `QB8VR32GWN`. İlk denemem bu yüzden reddedildi. Ayrıca bu makinede zaten bir **Developer ID Application** sertifikası var; ADR 0019'un 'Yol A kapalı' öncülü aslında geçerli değil. **Daha iyi bir tasarıma dönüştü:** takım kimliğini derleme zamanında gömmek yerine yardımcı kendi imzasından okuyor (`SecCodeCopySelf`). Yapılandırılacak değer yok, imza ayarlarıyla drift yok, aynı ikili hem Development hem Developer ID imzasıyla doğru. **Elle imza doğrulaması terk edildi:** `connection.auditToken` Swift'e açık değil; macOS 13'ten beri desteklenen `setCodeSigningRequirement` var. Apple'ın doğru yaptığı bir güvenlik kararını yeniden yazmak sahiplenilecek yeni bir hata yüzeyi demek. Kapı bu API'yi de kabul edecek şekilde güncellendi. **Kapı boşluğu kapatıldı:** gate-daemon protokol yüzeyini yalnızca daemon kaynağı varsa denetliyordu ve `public func` biçimindeki bir metodu kaçırırdı. Artık protokol gövdesinden metot çıkarıyor ve daemon'dan bağımsız çalışıyor; üç senaryoyla kanıtlandı (yeni func, gizlenmiş public func, eksilen metot). **İkinci sahte kapı bulundu:** `make lint` içindeki `swift format ... || echo ✓` gerçek biçim ihlallerini başarı gibi gösteriyordu. Var olan dizinler açıkça toplanıyor, çıkış kodu yutulmuyor; ihlalle kanıtlandı. **Test edilemeyen güvenlik katmanı düzeltildi:** K4 süzgeci Daemon hedefindeydi ve orada test bundle'ı yok. Saf mantık `Core.FanTargetGuard`'a taşındı, 8 test yazıldı; daemon ince bir adaptör. | `swift test` 77/77 PASS · `make check` 9/9 · `make lint` PASS (sahte kapı düzeltildikten sonra) · uygulama+yardımcı imzalı derlendi, paket yapısı doğrulandı | `Daemon/**` `Packages/SharedIPC/**` `Core/FanTargetGuard` `project.yml` `Makefile` | **Kök daemon kaydı onay bekliyor** | Next: P3.00 (kayıt denemesi) |
| 2026-08-04 | kurulum | P3.00 + P3.03 doğrulaması | DONE | **Ayrıcalıklı yardımcı gerçekten kuruldu ve çalıştı.** Kayıt Development sertifikasıyla başarılı; ADR 0019'un varsayımı doğrulandı, revizyon gerekmiyor. `register()` `Operation not permitted` döndürdü ama durum `notFound` → `requiresApproval` oldu — bu bir hata değil, macOS 13+'ın belgelenmiş onay akışı. Proje sahibi Sistem Ayarları'ndan onayladıktan sonra durum `enabled` oldu, daemon talep üzerine başladı (`runs = 1`). **G5 üç senaryoyla kanıtlandı:** doğru takım+kimlik kabul edildi (nonce doğru döndü, fan ayrıcalıklı yoldan okundu: 1001 rpm, 1000–4900); **farklı takımla** imzalı geçerli bir Apple istemcisi daemon tarafından reddedildi; **doğru takım ama yanlış bundle kimliğiyle** imzalı istemci de reddedildi. Hem takım hem kimlik zorlanıyor. **Test koşumumda gerçek bir kilitlenme buldum:** `HelperCommands` `@MainActor` bağlamında çalışıyor, `Task {}` bu izolasyonu miras alıyor ve ben ana thread'i semaforla blokluyordum — task hiç çalışamıyordu. Belirti 'daemon cevap vermiyor' gibi görünüyordu; `runs = 0` ve sıfır log, sorunun daemon'da değil çağıranda olduğunu gösterdi. `Task.detached` ile düzeltildi. **Lint kırmızıyken bir commit attım** — disiplin ihlali, düzeltici commit'le kapatıldı. Dört elemanlı tuple `FanSnapshot` tipine çevrildi: ayrıcalık sınırı geçen dört etiketsiz sayı, refactor'da yer değiştirmeye açık. | Kayıt: `enabled`, `runs=1`, `pid` atandı · ping: nonce eşleşti · describeFans: 1 fan · reddetme: 2/2 senaryo · `make check` 9/9 · 77 test | `App/Sources/Helper/**` `BoreasApp.swift` | Yardımcı bu makinede kurulu kaldı | Next: P3.04 |

### Run Log kayıt şablonu

```
| YYYY-MM-DD | <oturum> | P<n>.<nn> | DONE/BLOCKED | <ne yapıldı ve NEDEN öyle yapıldı; beklenmedik bulgular> | <komutlar + PASS/FAIL/NOT RUN+neden> | <dosyalar> | <risk> | Next: P<n>.<nn> |
```

**Kurallar:**
- `NOT RUN` yazmaktan çekinme — "yazdım, çalışıyordur" sistemi yalancı yapar
- Beklenmedik bulguyu **kanıtıyla** yaz; bir sonraki oturum aynı tuzağa düşmesin
- `Handoff` tek ve kesin bir iş olmalı
