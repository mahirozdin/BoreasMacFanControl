# 0006 — Bağımsız geliştirme politikası

<!-- gate-names:policy-doc — Bu dosya yasaklı kalıpları TARİF ettiği için gate-names taramasından muaftır. Bkz. LEGAL.md §5.1 -->

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §2

> Bu, projenin en kritik kararıdır. İhlali ürünü durdurur.

## Bağlam

Bu kategoride işlevsel olarak benzer ticari ürünler mevcut. Telif hakkı **fikirleri değil ifadeyi** korur — yani "fan hızını sıcaklığa göre ayarlamak" serbestçe uygulanabilir, ama belirli bir arayüz metni, ikon seti veya veri şeması kopyalanamaz.

Projenin hukuki güvenliği, bu ayrımın disiplinli uygulanmasına bağlı. Ayrıca bir git deposu **kalıcı kayıttır**: kötü niyetsiz yazılmış bir satır bile sonradan delil olabilir.

## Karar

Yedi mutlak yasak (`LEGAL.md` §2'de tam metin):

| # | Yasak |
|---|---|
| Y1 | Üçüncü taraf ticari uygulamayı tersine mühendislikle inceleme, disassemble/decompile |
| Y2 | Metin, etiket, yardım içeriği, hata mesajı kopyalama **veya çevirme** |
| Y3 | İkon, renk paleti, pencere düzeni, görsel kimlik taklidi |
| Y4 | Ayar dosyası şeması, anahtar adı, veri formatı birebir kullanımı |
| Y5 | **Depoda herhangi bir üçüncü taraf ticari ürün adının geçmesi** |
| Y6 | Karşılaştırmalı pazarlama |
| Y7 | Uyumsuz lisanslı kod dahil etme |

Ek olarak: kontrol motoru **kasıtlı olarak farklı bir modelle** tasarlanmıştır ([0010](0010-continuous-curve-model.md)) — özgünlük yapısal hale getirilmiştir, yalnızca beyan edilmemiştir.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Yalnızca "kopyalamayın" demek | Zorlanamayan kural zamanla ihlal edilir |
| Rakip adlarını bir listede tutup taramak | **Yasağın kendisini ihlal ederdi** — o adlar depoya girmiş olurdu |
| Hiç politika yazmamak | Kayıtlı iyi niyet, iddia karşısında en güçlü savunmadır |

## Sonuçlar

- ✅ Kayıtlı, denetlenebilir bağımsız geliştirme süreci
- ✅ Özgünlük mimari düzeyde — yalnızca metinsel değil
- ⚠️ Katkıcılar için ek disiplin; PR şablonunda beyan zorunlu
- ⚠️ Y5 tam otomatik zorlanamıyor (aşağıya bak)

## Zorlama

`make gate-names` üç katman uygular:

| Katman | Ne yakalar |
|---|---|
| Karşılaştırmalı pazarlama kalıpları | "alternative to", "better than", "instead of X", Türkçe karşılıkları |
| Dış alan adı allowlist'i | İzinli listede olmayan her URL insan incelemesi ister — **ad gerektirmez** |
| Marka sembolü taraması | `™` `®` |
| Yerel ad listesi (opsiyonel) | `scripts/gates/.forbidden-names.local` — `.gitignore`'da |

### Eksik katmanın açıkça kaydı

**Y5 için depoda saklanan bir ad listesi yoktur ve olamaz** — yasaklı adları bir dosyada tutmak, o adları depoya sokmak demektir; yani yasağı ihlal eder.

Bu, kaçınılmaz ve bilinçli bir sınırlamadır. Kalan boşluk şu iki katmanla kapatılır:

1. **PR beyanı** — `.github/PULL_REQUEST_TEMPLATE.md` içindeki üç onay kutusu
2. **İnsan incelemesi** — kod incelemesinin kontrol listesinde

Alan adı allowlist'i bu boşluğun büyük kısmını ad kullanmadan kapatır: bir üçüncü taraf ürüne yapılan atıf, neredeyse her zaman o ürünün sitesine bir bağlantı da içerir.
