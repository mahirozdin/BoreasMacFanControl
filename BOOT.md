# BOOT.md — Oturum Başlangıç Protokolü

> Son güncelleme: 2026-07-31 — P0.04
> Her oturum buradan başlar. Adımları atlama.

---

## 1. Başlangıç kontrolü

```bash
pwd
git status --short
git branch --show-current
git log --oneline -3
```

**Beklenen kök göstergeleri** — bunlar yoksa yanlış dizindesin:

```bash
ls BLUEPRINT.md AGENTS.md TODO.md ARCHITECTURE.md LEGAL.md docs/blueprint/
```

---

## 2. Zorunlu bağlam yükleme

Bu sırayla oku:

1. `AGENTS.md` — değişmezler ve çalışma disiplini
2. `TODO.md` — durum özeti + sıradaki iş
3. `ARCHITECTURE.md` — dokunacağın katmanın MUST/MUST NOT kuralları
4. `LEGAL.md` — **her oturumda**
5. `TODO.md`'deki işin gösterdiği `docs/` dosyası

---

## 3. Sağlık snapshot'ı

Hepsini çalıştır. **Kırmızı olan varsa önce onu düzelt**, yeni iş alma.

### 3.1 Kapılar

```bash
make check
```

Tek tek çalıştırmak gerekirse:

```bash
make gate-names       # H1 — üçüncü taraf ürün adı / karşılaştırmalı pazarlama
make blueprint-check  # dondurulmuş kaynak dokunulmamış mı
make docs-check       # kırık link, matris hedefleri, ADR senkronu
make gate-layers      # Core katman saflığı (kaynak yoksa atlanır)
make gate-deps        # bağımlılık lisansı ve sıfır-bağımlılık kuralı
make gate-privacy     # telemetri / ağ izi
make gate-i18n        # sabit yazılmış kullanıcı metni
make gate-daemon      # daemon XPC yüzeyi sınırları
```

### 3.2 İş durumu taraması

```bash
# Aktif faz ve sıradaki iş
grep -nE '^\| P[0-9]+ ' TODO.md

# Bloke işler
grep -nE 'BLOCKED' TODO.md

# Açık manuel işler
grep -nE '^\| M[0-9]+ .*OPEN' TODO.md
```

### 3.3 Riskli tracked dosya taraması

```bash
# Gizli değer veya imzalama materyali depoya girmiş mi
git ls-files | grep -iE '\.(p12|mobileprovision|provisionprofile|p8)$|^\.env$' \
  && echo "!!! GIZLI DEGER DEPODA — DERHAL KALDIR" || echo "OK: gizli materyal yok"

# Üretilen proje dosyası commit edilmiş mi (T5)
git ls-files | grep -E '\.xcodeproj/' \
  && echo "!!! .xcodeproj commit edilmis — T5 ihlali" || echo "OK: .xcodeproj temiz"
```

> **Not:** Değişmez taramaları yalnızca kaynak uzantılarını tarar. Dokümanlar yasağın kendi metnini içerir ve daraltılmamış tarama yanlış pozitif üretir.

---

## 4. Sıradaki işi seç

`AGENTS.md` §4'teki algoritmayı uygula. Özet:

En düşük numaralı tamamlanmamış faz → bağımlılıkları `DONE` mu → ilk işaretlenmemiş atomik iş → bloke ise atla, sonrakine geç.

---

## 5. İşi yap

- `TODO.md`'deki iş metnindeki kısıtlara uy
- Kabul kriterini karşılayacak **kanıtı** üret
- Yeni değişmez eklediysen **kapısını da ekle ve kasıtlı ihlalle kanıtla**

---

## 6. Oturumu kapat

Üçü birden, **aynı değişiklikte**:

1. `TODO.md` checkbox `[x]`
2. `TODO.md` durum özeti tablosu
3. `TODO.md` Run Log kaydı + `Next: P<n>.<nn>`

Sonra commit:

```bash
git add -A
git commit -m "<tip>: <özet> (P<n>.<nn>)"
```

---

## 7. Hangi soruya hangi dosya cevap verir

| Soru | Dosya |
|---|---|
| Ne yapmalıyım? | `TODO.md` |
| Neyi yapmamalıyım? | `AGENTS.md` §2, §12 |
| Bu karar neden böyle? | `docs/architecture/adr/` |
| Hukuki sınır nedir? | `LEGAL.md` |
| Katman kuralları neler? | `ARCHITECTURE.md` |
| Kontrol motoru nasıl çalışır? | `docs/product/control-model.md` |
| Donanıma nasıl erişilir? | `docs/architecture/hardware-access.md` |
| Ayrıcalık modeli nedir? | `docs/architecture/privilege-model.md` |
| Yapılandırma şeması nedir? | `docs/architecture/configuration.md` |
| Nasıl test edilir? | `docs/development/testing.md` |
| Nasıl derlenir/imzalanır? | `docs/release/build-and-sign.md` |
| Blueprint'in şu bölümü nereye gitti? | `docs/reference/blueprint-map.md` |
| Hangi riskler takip ediliyor? | `docs/reference/risks.md` |
| Bu terim ne demek? | `docs/reference/glossary.md` |
| Hangi kararlar kesinleşti? | `docs/reference/decisions.md` |
| Başlangıçta ne planlanmıştı? | `docs/blueprint/` (referans) |

---

## 8. Oturumun ilk mesajı şablonu

```
BOOT tamam.
- Dizin: <pwd> · Dal: <branch> · Son commit: <hash> <özet>
- Kapılar: make check → <PASS / FAIL: hangisi>
- Aktif faz: P<n> (<durum>) — <tema>
- Sıradaki iş: P<n>.<nn> — <başlık>
- Bloke: <varsa manuel iş numaraları, yoksa "yok">

Başlıyorum.
```
