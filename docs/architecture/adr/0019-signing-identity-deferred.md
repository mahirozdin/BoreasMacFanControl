# 0019 — İmzalama kimliği P8'e ertelendi

- **Durum:** Kabul
- **Tarih:** 2026-08-03
- **İlgili:** [0008](0008-smappservice-xpc.md), [0017](0017-distribution-channels.md) · `docs/reference/decisions.md` A4

## Bağlam

Proje sahibi, Developer ID sertifikasını şimdilik yapılandırmak istemedi ve şunu sordu: uygulama App Store'da yayınlanmayacağına, yalnızca GitHub deposundan DMG olarak sunulacağına göre sertifika zorunlu mu?

Soruda yaygın bir yanılgı var ve kaydedilmesi gerekiyor:

> **Developer ID, App Store için değildir. Tam tersine, App Store *dışında* dağıtım için vardır.**
> App Store dağıtımı bambaşka bir sertifika tipi kullanır (Mac App Distribution).
> "GitHub'dan DMG" senaryosu, Developer ID'nin var oluş sebebinin ta kendisidir.

Ayrıca ayrı bir teknik kısıt var: Apple, ayrıcalıklı yardımcı + XPC senaryosunda **"Sign to Run Locally" (ad-hoc imza) yaklaşımının desteklenmediğini** belirtiyor; çünkü ad-hoc imza, uygulama ile yardımcıyı güvenli biçimde tanımlayabilen bir kod imzası gereksinimi üretemiyor. Bu doğrudan [ADR 0008](0008-smappservice-xpc.md)'in G5 değişmezini (çift yönlü imza doğrulaması) etkiliyor.

## Karar

**İmzalama kimliği P1–P7 için gerekli değildir; P8'in ön koşuludur.**

| Faz | İmzalama ihtiyacı |
|---|---|
| P1 · P2 (iskelet, ayrıcalıksız okuma) | **Hiçbiri.** Sensör ve fan okuma ayrıcalık gerektirmiyor ([ADR 0007](0007-privilege-split.md)) |
| P3–P7 (daemon, kontrol, arayüz) | **Apple Development sertifikası.** Ücretsiz Apple hesabıyla alınabilir; kişisel Team ID üretir, XPC imza doğrulaması yerel makinede çalışır |
| P8 (yayın) | **Developer ID + notarizasyon.** Aksi halde dağıtılabilir bir ürün yok |

Manuel işler M03 ve M04 `OPEN` kalır ancak **yalnızca P8'i bloke eder** olarak işaretlenir. P1–P7 boyunca hiçbir işi durdurmazlar.

## P8'de iki yol

Karar P8'e geldiğinde verilecek. İkisinin sonuçları eşit değildir:

### Yol A — Developer ID + notarizasyon (önerilen)

- Apple Developer Program üyeliği gerekir (yıllık ücretli)
- Gatekeeper uyarısı yok, kurulum tek tık
- `SMAppService` daemon kaydı ve XPC imza doğrulaması tasarlandığı gibi çalışır
- Homebrew cask sorunsuz
- **Blueprint ve tüm ADR'ler değişmeden geçerli kalır**

### Yol B — imzasız / yalnızca development sertifikası

- Kullanıcı, DMG'yi açtıktan sonra Sistem Ayarları → Gizlilik ve Güvenlik'ten elle izin vermek zorunda. macOS 15'ten beri Control-tık kısayolu kaldırıldığı için adım sayısı arttı
- **Ayrıcalıklı daemon güvenilir çalışmaz.** Apple'ın belirttiği kısıt nedeniyle XPC kod imzası gereksinimi uygulamayı ve yardımcıyı güvenli biçimde tanımlayamaz → G5 değişmezi karşılanamaz
- Homebrew cask pratikte kullanılamaz
- **Ürün fiilen ikiye bölünür:** izleme yarısı çalışır, fan kontrolü çalışmaz

Yol B seçilirse bu, ürün kapsamının temel bir değişimidir ve **yeni bir ADR ile** kaydedilmelidir: `docs/product/scope.md` fan kontrolünü "yalnızca kaynaktan derleyenler için" konumuna taşımalı, README bunu açıkça belirtmelidir.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Sertifikayı P1'de zorunlu tutmak | Gereksiz blokaj; P1–P2 imzasız tamamen çalışıyor |
| Ad-hoc imzayla daemon dağıtmak | Apple desteklemiyor; G5 değişmezi karşılanamaz, güvenlik modeli çöker |
| Kararı belirsiz bırakmak | P8'de sürpriz blokaj; bilinen bir bağımlılık kayda geçmeli |

## Sonuçlar

- ✅ P1–P7 boyunca hiçbir iş bloke değil
- ✅ Bağımlılık ve maliyeti kayıt altında, P8'de sürpriz yok
- ✅ Yol B'nin ürün üzerindeki etkisi önceden yazılı
- ⚠️ Yol B seçilirse projenin ana özelliği (fan kontrolü) dağıtılamaz hale gelir

## Zorlama

- `TODO.md` manuel işler tablosu: M03 ve M04 yalnızca P8 bağımlılığı olarak işaretli
- `TODO.md` faz üstü blokaj **B4** zaten yerinde: notarizasyon başarısızsa sürüm yayınlanmaz
- P8.09 sürüm kapıları kontrol listesi imzalama zincirini doğrular
- P3'te bir doğrulama işi eklendi: development sertifikasıyla `SMAppService` kaydının ve XPC imza doğrulamasının gerçekten çalıştığı **ampirik olarak** kanıtlanacak (varsayılmayacak)
