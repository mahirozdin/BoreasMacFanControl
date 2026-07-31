# Yerelleştirme

> Son güncelleme: 2026-07-31 — P0.25
> Kaynak: blueprint §9.7 · Karar: [ADR 0016](../architecture/adr/0016-language-scope.md)

## Kapsam

**Uygulama arayüzü — 5 dil, v1.0'da eksiksiz:**

| Kod | Dil | Not |
|---|---|---|
| `en` | English | **Kaynak dil** — anahtarlar önce burada yazılır |
| `tr` | Türkçe | Çeviri değil, Türkçe düşünülerek yazılır |
| `ru` | Русский | Uzun dizeler, üç çoğul biçimi |
| `es` | Español | |
| `zh-Hans` | 简体中文 | Basitleştirilmiş |

**Dokümantasyon:** `README.md` İngilizce (yetkili) + 4 çeviri. `CONTRIBUTING.md`, `SECURITY.md`, `docs/**`, kod, yorum, commit → **yalnızca İngilizce**. Proje yönetim dokümanları (`TODO.md`, `AGENTS.md`, `BOOT.md`) → Türkçe.

## Teknik kurallar

- **String Catalog** (`.xcstrings`) tek kaynak
- `String(localized:)` zorunlu — sabit yazılmış metin yasak (Y1)
- Her dize için **`comment` alanı zorunlu** (Y2) — çevirmen bağlam olmadan doğru çeviremez
- Rusça'nın üç çoğul biçimi (`one`/`few`/`many`) doğru ele alınmalı
- Sıcaklık, sayı ve tarih biçimleri `Locale` ve `Measurement` üzerinden — **elle biçimlendirme yasak**
- Sıralama ve arama `localizedStandardCompare`
- Eksik çeviri kaynak dile (`en`) düşer, **asla boş görünmez** (Y4)

## Düzen sonucu

Rusça dizeler İngilizcenin **%30–50 fazlası** olabilir; Çince belirgin kısadır. Bu yüzden:

> **Sabit piksel genişlikli veya yükseklikli metin kabı yoktur.** Tüm etiketler içeriğe göre büyür, gerekirse sarar. Menü çubuğu öğesi hariç hiçbir yerde taşma kısaltma (`…`) ile çözülmez.

CI'da **pseudo-locale** (yapay uzatılmış dize) düzen testiyle denetlenir.

## Çeviri bakımı

- `TRANSLATORS.md` — dil başına sorumlu katkıcılar
- Yeni dize eklendiğinde çeviriler eksikse CI **uyarı** verir (hata değil — sürümü engellemez)
- Çeviri kalite onayı **anadili konuşuru** gerektirir → manuel iş

## Metin yazım ilkesi

Arayüz metinleri sıfırdan yazılır. Sade, doğrudan, jargonsuz.

**Türkçe metinler İngilizceden çeviri gibi durmaz** — Türkçe düşünülerek yazılır, İngilizce sürüm ayrıca yazılır. İkisi de kaynak kalitesindedir.

Ton: neyi yapamadığını da söyler. Dürüstlük bu kategoride en güçlü iletişimdir.

## Kapı

`make gate-i18n` şunları zorlar: sabit yazılmış kullanıcı metni yok · 5 dilin hepsi katalogda mevcut · `comment` alanı boş dize yok.
