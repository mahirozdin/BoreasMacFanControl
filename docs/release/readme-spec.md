# README Spesifikasyonu

<!-- gate-names:policy-doc — Bu dosya yasaklı kalıpları TARİF ettiği için gate-names taramasından muaftır. Bkz. LEGAL.md §5.1 -->

> Son güncelleme: 2026-07-31 — P0.30
> Kaynak: blueprint §18

Ürün `README.md` **İngilizce** yazılır (yetkili sürüm) ve 4 dile çevrilir → [ADR 0016](../architecture/adr/0016-language-scope.md)

## Zorunlu bölümler — bu sırayla

| # | Bölüm | İçerik |
|---|---|---|
| 1 | Başlık + tek cümlelik tanım | Ürün adı, logo, ne yaptığı |
| 2 | Rozetler | Derleme durumu, sürüm, lisans, desteklenen macOS, mimari |
| 3 | Ekran görüntüsü / kısa GIF | Menü çubuğu paneli + eğri editörü; karanlık ve aydınlık |
| 4 | Neden bu proje var | Problem tanımı. **Hiçbir üçüncü taraf ürün adı geçmez** |
| 5 | Öne çıkan özellikler | 6–10 madde, tek satır, faydaya odaklı |
| 6 | **Gereksinimler ve test edilen donanım** | Apple Silicon (M1+), macOS 14.0+. **Hangi modelde fiilen test edildiği açıkça yazılır** (R8) |
| 7 | Kurulum | Homebrew (birincil) + DMG. İlk açılış ve Gatekeeper adımları |
| 8 | Hızlı başlangıç | 3 adım: aç → profil seç → (isteğe bağlı) fan kontrolünü etkinleştir |
| 9 | **İzinler ve neden gerekli** | İstenen izinler + **istenmeyenler listesi**. Kullanıcı güveninin kazanıldığı bölüm — üstte tutulmalı |
| 10 | Nasıl çalışır | 6–8 cümle + katman diyagramı |
| 11 | Güvenlik | Ölü adam anahtarı, güvenlik zinciri, dar daemon yüzeyi |
| 12 | Gizlilik | Sıfır telemetri taahhüdü, açık ve net |
| 13 | Yapılandırma | Dosya konumu, örnek parça, şema bağlantısı |
| 14 | CLI kullanımı | Komut listesi ve örnekler |
| 15 | Sorun giderme | En sık 8–10 sorun; ayrıntı `docs/` |
| 16 | Kaldırma | Tam adımlar + geriye hiçbir şey bırakmadığının garantisi |
| 17 | Yol haritası | Kısa |
| 18 | Katkı | `CONTRIBUTING.md` + **bilinmeyen sensör raporu çağrısı** |
| 19 | SSS | → `discoverability.md` |
| 20 | Sorumluluk reddi | `LEGAL.md` §8 |
| 21 | Lisans | Apache-2.0 + `NOTICE` |

## Olmaması gerekenler

| Olmayacak | Neden |
|---|---|
| Herhangi bir üçüncü taraf ürün adı | `LEGAL.md` Y5 |
| "X alternatifi" / "X gibi ama ücretsiz" | Y6 — karşılaştırmalı pazarlama riski |
| Karşılaştırma tablosu (biz vs onlar) | Aynı gerekçe |
| Abartılı performans iddiası ("%40 daha serin") | Kanıtlanamaz; ölçüm metodolojisi olmadan yazılmaz |
| Bağış/sponsorluk baskısı | İlk sürümde odağı dağıtır |
| Uzun kişisel hikâye | README teknik bir belgedir |

## Ton

Sade, dürüst, abartısız. **Neyi yapamadığını da söyler** (ör. donanım fanları kapattığında kontrol mümkün değildir).

> Dürüstlük, bu kategoride en güçlü pazarlamadır.
