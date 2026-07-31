# CLAUDE.md

> Bu dosya otomatik yüklenir. Kısadır — asıl sözleşme `AGENTS.md`'dedir.

## Önce şunu yap

**`BOOT.md`'yi aç ve protokolü uygula.** Sağlık snapshot'ını çalıştırmadan kod yazma.

## Proje tek paragrafta

**Boreas** — Apple Silicon Mac'ler için açık kaynak, ücretsiz termal izleme ve fan kontrol uygulaması. Swift 6.2 + SwiftUI, macOS 14.0+, yalnızca arm64, Apache-2.0. Sıcaklık okuma ayrıcalık gerektirmez; fan yazımı için tek seferlik yönetici onayıyla kurulan ayrıcalıklı bir daemon kullanılır. SIP kapatma, kernel extension veya hassas izin **yoktur**.

## En sık ihlal edilen 10 kural

1. **Hiçbir üçüncü taraf ticari ürün adı depoya girmez** — kod, yorum, commit, issue, doküman, hiçbir yerde. Jenerik ifade kullan. *(AGENTS.md §2.1 H1)*
2. **`Packages/Core` içine IOKit/SwiftUI/AppKit import edilmez.** Geçici bile olsa. *(M1)*
3. **Doğrulama çalıştırılmadan checkbox işaretlenmez.** Çalıştıramadıysan Run Log'a `NOT RUN` + neden yaz. *(§5)*
4. **Kapı yazdıysan kasıtlı ihlalle kanıtla.** Çalıştığı gösterilmemiş kapı, kapı değildir. *(§8)*
5. **Kullanıcıya görünen metin kodda sabit yazılmaz.** `String(localized:)` + `comment` zorunlu. 5 dil var. *(Y1, Y2)*
6. **Blueprint dondurulmuştur.** `BLUEPRINT.md` ve `docs/blueprint/` düzenlenmez; sapma ADR ile kaydedilir. *(§7)*
7. **Donanım hatası `try?` ile yutulmaz.** Fırlat, çağıran zarif düşüş uygular. *(§6.3)*
8. **Güvenlik zinciri yalnızca yukarı düzeltir.** Hiçbir katman fan hızını düşüremez. *(G1)*
9. **Oturum kapanışı üç parçalıdır:** checkbox + durum özeti + Run Log, aynı değişiklikte. *(§9)*
10. **Blokaj işi dondurmaz.** Bloke işi atla, bağımsız bir sonraki işe geç. *(§4)*

## Dokümanlar yaşayan dokümandır

Kod değiştiğinde `AGENTS.md` §7'deki *değişiklik tipi → güncellenecek dosyalar* tablosuna bak. Doküman güncellemeden iş kapanmaz.

## Kanıt kuralı

Bir şeyin çalıştığını **iddia etme, göster**. Komutu çalıştır, çıktıyı gör, Run Log'a yaz.

## Dış yetki

Marka/hukuk, Apple hesabı, GitHub secret, sahip olunmayan donanım → `TODO.md` manuel işler tablosu.
Yerel araç kurulumu, script yazma, test yazma → **senin işin**, manuel işe yazma.

## Sık komutlar

```bash
make check          # tüm kapılar
make gate-names     # H1 — her işte
make blueprint-check
make docs-check
```

## Dil

Kod, yorum, commit mesajı → **İngilizce**.
Proje yönetim dokümanları (bu dosya, `TODO.md`, `docs/`) → **Türkçe**.
Ürün dokümantasyonu (`README.md`, `CONTRIBUTING.md`) → **İngilizce**.
