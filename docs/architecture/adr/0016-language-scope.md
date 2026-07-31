# 0016 — Dil kapsamı: 5 dil arayüz, İngilizce dokümantasyon

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §9.7, §23 A6

## Bağlam

Proje uluslararası kullanıcıya açık olacak. Aynı zamanda tek geliştiricili — her çeviri bir bakım yükü. Bayat çeviri, çevirisizlikten daha zararlıdır: kullanıcı yanlış talimat izler.

## Karar

**Uygulama arayüzü — 5 dil, v1.0'da eksiksiz:**

| Kod | Dil | Not |
|---|---|---|
| `en` | English | **Kaynak dil** — anahtarlar önce burada yazılır |
| `tr` | Türkçe | Çeviri değil, Türkçe düşünülerek yazılır |
| `ru` | Русский | Uzun dizeler — düzen esnekliği kritik |
| `es` | Español | |
| `zh-Hans` | 简体中文 | Basitleştirilmiş; geleneksel sonraki dalga |

**Dokümantasyon — farklı kural:**

| Dosya | Diller |
|---|---|
| `README.md` | **İngilizce (yetkili)** |
| `README.{tr,ru,es,zh-Hans}.md` | Çeviri + "geride kalmış olabilir" notu |
| `CONTRIBUTING.md`, `SECURITY.md`, `docs/**` | Yalnızca İngilizce |
| Kod, yorum, commit mesajı | Yalnızca İngilizce |
| Proje yönetim dokümanları (`TODO.md`, `AGENTS.md`, `BOOT.md`) | Türkçe |

**Zorunlu teknik kurallar:** String Catalog (`.xcstrings`); `String(localized:)` zorunlu; her dize için `comment` alanı dolu; Rusça'nın üç çoğul biçimi doğru ele alınır; eksik çeviri kaynak dile düşer, asla boş görünmez.

**Düzen sonucu:** Rusça dizeler İngilizcenin %30–50 fazlası olabilir, Çince belirgin kısadır. Bu yüzden **sabit piksel genişlikli veya yükseklikli metin kabı yoktur**.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Dokümantasyonu da 5 dilde tutmak | `docs/` sürekli değişir; tek geliştiriciyle senkron tutulamaz. Bayat çeviri zararlıdır |
| Yalnızca İngilizce arayüz | Türkçe arayüz bu kategoride nadir — gerçek bir farklılaştırıcı |
| Çeviriyi v1.1'e ertelemek | Yerelleştirme altyapısı sonradan eklenirse tüm dizeler yeniden yazılır |

## Sonuçlar

- ✅ Geniş uluslararası erişim
- ✅ Türkçe birinci sınıf dil
- ⚠️ Her yeni dize 5 çeviri gerektirir → CI **uyarı** verir (hata değil, sürümü engellemez)
- ⚠️ Çeviri kalite onayı anadili konuşuru gerektirir → manuel iş
- ⚠️ Düzen tasarımı çok dilli olmak zorunda

## Zorlama

`make gate-i18n`:
- `App/Sources` altında sabit yazılmış kullanıcı metni → kırmızı (Y1)
- String Catalog'da 5 dilden biri eksikse → kırmızı
- `comment` alanı boş dize varsa → kırmızı (Y2)

Pseudo-locale düzen testi CI'da: yapay uzatılmış dize ile taşma denetimi (P6'da etkinleşir).
