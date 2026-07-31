# LEGAL.md — Bağımsız Geliştirme ve Hukuki Sınırlar

> Son güncelleme: 2026-07-31 — P0.06
> Kaynak: blueprint §2
> **Her oturumda okunur.** İhlali projeyi durdurur.
> **Bu belge hukuki tavsiye değildir.** Yayın öncesi bir avukatla görüşülmelidir.

---

## 1. Temel duruş

Bu proje **bağımsız bir üründür**. İşlevsel olarak aynı problemi çözen başka yazılımlar mevcuttur; bu normaldir ve yasaldır.

Telif hakkı **fikirleri, işlevleri veya çözülen problemi değil, ifadeyi** korur:

| Kategori | Örnek | Korunuyor mu |
|---|---|---|
| **Fikir** | "Fan hızını sıcaklığa göre ayarlamak" | ✗ Serbestçe uygulanabilir |
| **İşlev** | "Menü çubuğunda sıcaklık göstermek" | ✗ Serbestçe uygulanabilir |
| **İfade** | Belirli arayüz metni, ikon seti, yardım dokümanı, kaynak kodu, veri tablosu | ✅ Kopyalanamaz |

Projenin güvenliği bu ayrımı **disiplinli biçimde uygulamaktan** gelir.

---

## 2. Mutlak yasaklar

İhlali durumunda katkı reddedilir; gerekirse geçmiş yeniden yazılır.

| # | Yasak | Gerekçe |
|---|---|---|
| **Y1** | Herhangi bir üçüncü taraf ticari uygulamayı tersine mühendislikle çözmek, disassemble/decompile etmek veya ikili dosyasını incelemek | En ağır iddia sınıfı; çoğu EULA'yı da ihlal eder |
| **Y2** | Başka bir üründen metin, etiket, yardım içeriği, hata mesajı, pazarlama kopyası veya dokümantasyon kopyalamak **veya çevirmek** | Çeviri de türev eserdir |
| **Y3** | Başka bir ürünün ikonlarını, renk paletini, pencere düzenini veya görsel kimliğini taklit etmek | Trade dress iddiası |
| **Y4** | Başka bir ürünün ayar dosyası şemasını, anahtar adlarını veya veri formatını birebir kullanmak | Yapısal kopyalama kanıtı olur |
| **Y5** | Repoda, commit mesajlarında, issue'larda, kodda, yorumlarda veya dokümantasyonda **herhangi bir üçüncü taraf ticari ürünün adını geçirmek** | Aşağıya bak |
| **Y6** | Karşılaştırmalı pazarlama: "X'in alternatifi", "X gibi ama ücretsiz", "X'ten daha iyi" | Marka ihlali + haksız rekabet riski |
| **Y7** | Lisansı uyumsuz üçüncü taraf kodu (GPL/LGPL/AGPL) projeye dahil etmek | Apache-2.0 ile bağdaşmaz; tüm projeyi kirletir |

### Y5 neden bu kadar sert

Bir rakip ürün adının geçtiği commit, issue veya yorum — **iyi niyetle yazılmış olsa bile** — "geliştirici o ürünü biliyordu ve ona bakarak yazdı" iddiasına delil oluşturur. Niyet önemli değildir; kayıt kalıcıdır ve git geçmişi silinmez.

**Bunun yerine kullanılacak ifadeler:**

- *"ticari muadiller"*
- *"kapalı kaynak alternatifler"*
- *"bu kategorideki diğer araçlar"*
- *"mevcut çözümler"*

Somut bir davranışı tarif etmek gerekiyorsa, kaynağı değil **davranışı** tarif et: ~~"X uygulaması 10 saniyelik rampa kullanıyor"~~ → *"kademeli rampa yaklaşımı yaygındır ve şu nedenle tercih edilir: ..."*

---

## 3. İzin verilenler

| İzinli kaynak | Kapsam |
|---|---|
| Apple resmî dokümantasyonu | IOKit, ServiceManagement, HIDDriverKit, Human Interface Guidelines |
| Apple SDK açık başlık dosyaları | Public header'lar |
| Uyumlu lisanslı açık kaynak | MIT / BSD / Apache-2.0 — **atıf zorunlu**, `NOTICE`'a yazılır |
| Kamusal teknik bilgi | SMC anahtar adlandırma kuralları, IOKit servis isimleri |
| Kendi ölçümlerimiz | Kendi donanımımızda yapılan sensör keşfi, log analizi, termal testler |
| Akademik/mühendislik literatürü | Kontrol teorisi, histerezis, PID, termal modelleme |

---

## 4. Bağımsız geliştirme beyanı

Her PR'da onaylanır (`.github/PULL_REQUEST_TEMPLATE.md` içine gömülüdür):

```
[ ] Bu katkıdaki kod ve metinler tamamen benim tarafımdan yazıldı veya
    uyumlu lisanslı, kaynağı NOTICE dosyasında belirtilmiş koddan türetildi.
[ ] Bu katkıyı hazırlarken hiçbir ticari yazılımı tersine mühendislikle
    incelemedim, ikili dosyasını analiz etmedim.
[ ] Bu katkıda hiçbir üçüncü taraf ticari ürün adı geçmiyor.
```

---

## 5. Nasıl zorlanıyor

Y5 ve Y6'nın **tam otomatik** zorlanamamasının nedeni ve kalan katmanlar:

### 5.1 Otomatik katman — `make gate-names`

| Kontrol | Ne yakalar |
|---|---|
| **Karşılaştırmalı pazarlama kalıpları** | "alternative to", "better than", "instead of", "replacement for", "X yerine", "X gibi ama", "rakibi" gibi jenerik yapılar |
| **Dış alan adı allowlist'i** | Depoda geçen her URL'in alan adı, izinli listede mi? Değilse insan incelemesi ister |
| **Marka sembolü taraması** | `™` `®` — üçüncü taraf marka referansının işareti |
| **Yerel ad listesi** (opsiyonel) | `scripts/gates/.forbidden-names.local` varsa kullanılır — **bu dosya `.gitignore`'dadır** |

### 5.2 Neden ad listesi depoya konmuyor

Yasaklı ürün adlarını bir dosyada saklamak, **yasağın kendisini ihlal ederdi** — o adlar depoya girmiş olurdu. Bu, Y5'in kaçınılmaz bir sonucudur.

Bunun yerine:
- Otomatik katman **jenerik kalıpları** ve **alan adı allowlist'ini** kullanır (ad gerektirmez)
- Geliştirici isterse yerel, `.gitignore`'lu bir ad listesi tutar (CI'da yok, yerelde çalışır)
- Kalan boşluk **insan incelemesi** ve **PR beyanı** ile kapatılır

> Bu, bilinçli ve kayıtlı bir sınırlamadır. Ayrıntı: [ADR 0006](docs/architecture/adr/0006-independent-development-policy.md) `Zorlama` bölümü.

### 5.3 Lisans katmanı — `make gate-deps`

Bağımlılık eklendiğinde lisansı kontrol edilir; GPL/LGPL/AGPL tespit edilirse kapı kırmızıya döner.

---

## 6. Lisanslama

| Konu | Karar |
|---|---|
| Proje lisansı | **Apache-2.0** — açık patent hibesi, katkıcılardan da patent hibesi, ticari kullanıma açık |
| İzinli bağımlılık lisansları | MIT, BSD (2/3-clause), Apache-2.0, ISC |
| Yasaklı bağımlılık lisansları | GPL, LGPL, AGPL, SSPL, ticari/tescilli |
| Atıf dosyası | `NOTICE` — proje adı, sürüm, lisans, URL, kullanım amacı |
| Fikir alınan projeler | `NOTICE` "Acknowledgements" bölümünde belirtilir — **şeffaflık iyi niyetin en güçlü kanıtıdır** |

Ayrıntı: [ADR 0005](docs/architecture/adr/0005-apache-2-license.md)

---

## 7. Marka

| Konu | Durum |
|---|---|
| Ürün adı | **Boreas** — Yunan mitolojisinde kuzey rüzgârı tanrısı |
| Apple markası kullanımı | Yalnızca **niteleyici** konumda: *"Boreas for Mac"* ✅ · *"MacBoreas"* ❌ |
| Apple ile ilişki beyanı | README ve uygulama içinde: proje Apple Inc. ile ilişkili değildir, onaylanmamıştır |
| Bekleyen doğrulama | TÜRKPATENT + EUIPO/USPTO marka araması (manuel iş M01) |

---

## 8. Sorumluluk reddi

README ve uygulama içi ilk çalıştırma ekranında, **kendi sözlerimizle** yazılmış olarak bulunacak:

- Yazılım "olduğu gibi" sunulur, garanti verilmez
- Fan hızlarını düşürmek termal riski artırır; sorumluluk kullanıcıdadır
- Proje Apple Inc. ile ilişkili değildir, onaylanmamıştır
- Donanım garantisi üzerindeki etki kullanıcının sorumluluğundadır

---

## 9. Şüphe durumunda

Bir katkının bu sınırların içinde olup olmadığından emin değilsen:

1. **Yapma.** Devam etme.
2. Şüpheyi issue'da (ürün adı geçirmeden) tarif et.
3. Proje sahibinin kararını bekle.

Şüpheli bir katkıyı geri almak, onu hiç almamaktan çok daha pahalıdır.
