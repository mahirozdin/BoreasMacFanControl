# Risk Kaydı

> Son güncelleme: 2026-07-31 — P0.12
> Kaynak: blueprint §21

| # | Risk | Olasılık | Etki | Azaltım | Sahip |
|---|---|---|---|---|---|
| **R1** | Dokümante edilmemiş sensör API'si macOS güncellemesiyle bozulur | Orta | Yüksek | Protokol soyutlaması + ikinci kaynak (SMC) + zarif düşüş; asla çökme. [ADR 0018](../architecture/adr/0018-undocumented-sensor-api.md) | Geliştirici |
| **R2** | Yeni çip nesli farklı sensör adlandırması getirir | Yüksek | Orta | Çalışma zamanı keşfi; koda gömülü çip listesi yok; `uncategorized` görünürlüğü; topluluk rapor şablonu | Geliştirici |
| **R3** | Firmware fan yazımını engeller veya geri alır | Orta | Yüksek | Kapalı çevrim doğrulama, sapma tespiti, kullanıcıya dürüst bildirim | Geliştirici |
| **R4** | Kullanıcı fanı çok düşük ayarlayıp donanımı riske atar | Orta | Yüksek | K1–K3 katmanları kapatılamaz; eğri editörü riskli bölgeyi görsel işaretler. [ADR 0010](../architecture/adr/0010-continuous-curve-model.md) | Ürün |
| **R5** | Daemon kurulumu macOS güvenlik akışında takılır | Orta | Orta | Durum tespiti + Sistem Ayarları'na doğrudan yönlendirme + sorun giderme dokümanı | Geliştirici |
| **R6** | Hukuki iddia | Düşük | Çok yüksek | `LEGAL.md`'nin tamamı: bağımsız geliştirme protokolü, ürün adı yasağı, PR beyanı, atıf disiplini, **özgün algoritma tasarımı**. [ADR 0006](../architecture/adr/0006-independent-development-policy.md) | Proje sahibi |
| **R7** | Tek geliştirici tükenmişliği | Yüksek | Yüksek | Kilometre taşları küçük ve her biri kendi başına kullanışlı; P2 sonunda çalışan izleme aracı; kapsam dışı listesi disiplini korur | Proje sahibi |
| **R8** | **Test edilemeyen donanım çeşitliliği** — geliştirme donanımı tek model (tek fanlı, pilsiz) | **Kesin** | **Yüksek** | Mock + Replay P2'de zorunlu; README'de dürüst kapsam beyanı; topluluk rapor şablonları; doğrulanmamış kod yolları sürüm notlarında işaretlenir. [ADR 0011](../architecture/adr/0011-hardware-abstraction.md) | Geliştirici |
| **R9** | Apple marka kuralları nedeniyle ad değişikliği gerekir | Düşük | Düşük | "Mac" öneki baştan kullanılmadı; ad tek noktada; `scripts/rename-product.sh`. [ADR 0002](../architecture/adr/0002-product-name.md) | Proje sahibi |
| **R10** | Çeviri bayatlaması — 5 dil, tek geliştirici | Yüksek | Düşük | Eksik çeviri kaynak dile düşer, asla boş görünmez; CI uyarısı sürümü engellemez; `TRANSLATORS.md`; dokümantasyon bilinçli olarak çeviri kapsamı dışında. [ADR 0016](../architecture/adr/0016-language-scope.md) | Topluluk |
| **R11** | Çok dilli arayüzde düzen bozulması (uzun dizeler) | Orta | Orta | Sabit genişlikli/yükseklikli metin kabı yasağı; CI'da pseudo-locale düzen testi | Geliştirici |

## R8 — özel not

Bu risk **kesin** olarak işaretlidir çünkü olasılık değil, mevcut durumdur. Doğrudan doğrulanamayan kod yolları `docs/development/testing.md` içinde tablo halinde listelenir ve her sürümde gözden geçirilir.

## Risk kaydı nasıl güncellenir

Yeni risk fark edildiğinde bu dosyaya satır eklenir ve gerekiyorsa bir azaltım işi `TODO.md`'ye girer. Bir riskin gerçekleşmesi Run Log'a kaydedilir.
