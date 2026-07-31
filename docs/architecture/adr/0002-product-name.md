# 0002 — Ürün adı: Boreas

<!-- gate-names:policy-doc — Bu dosya yasaklı kalıpları TARİF ettiği için gate-names taramasından muaftır. Bkz. LEGAL.md §5.1 -->

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §2.8, §23 A1

## Bağlam

Ürünün ayırt edici, hukuki olarak güvenli ve uluslararası kullanıma uygun bir adı olmalı. İki ayrı kısıt var: (1) mevcut ürünlerle karışmamalı, (2) Apple'ın marka kuralları üçüncü taraf ürün adlarında Apple markalarının **önek** olarak kullanılmasını önermiyor.

Ek olarak, keşfedilebilirlik kaygısı var: kullanıcılar ürünü arama motorlarında bulabilmeli.

## Karar

Ürün adı **Boreas** — Yunan mitolojisinde kuzey rüzgârını, kışın soğuk havasını getiren tanrı.

| Alan | Değer |
|---|---|
| Ürün adı | Boreas |
| Depo | `boreas-mac-fan-control` |
| Bundle ID | `com.bubiapps.boreas` |
| Daemon | `com.bubiapps.boreas.fanhelper` |
| CLI | `boreas` |
| Homebrew cask | `boreas` |

**Marka ile keşfedilebilirlik ayrılır:** ad markayı taşır, anahtar kelimeler depo adı, depo açıklaması, konu etiketleri ve README'nin ilk ekranı tarafından taşınır.

## Alternatifler

| Aday | Neden seçilmedi |
|---|---|
| Apple markası önekli bir ad | Apple marka kurallarına aykırı; ileride ad değişikliği zorunluluğu doğurabilir |
| Imbat / Poyraz | Ayırt ediciliği yüksek ama uluslararası telaffuz ve akılda kalıcılık zayıf |
| Anahtar kelime içeren jenerik ad | Marka olarak korunamaz, ayırt edici değil |

## Sonuçlar

- ✅ Apple marka kuralı riski ortadan kalktı
- ✅ Uluslararası telaffuz ve yazım kolay
- ⚠️ Ad tek başına anahtar kelime taşımıyor → keşfedilebilirlik ayrı bir katmanda çözülmeli ([0016](0016-language-scope.md) ve `docs/release/discoverability.md`)
- ⚠️ Marka tescil araması hâlâ bekliyor (manuel iş M01)

## Zorlama

- Ad koda gömülmez; yalnızca `project.yml` değişkenlerinde ve yerelleştirme kataloğunda geçer
- `scripts/rename-product.sh` ile tek komutluk yeniden adlandırma (P1'de yazılacak)
- `make gate-names` → marka sembolü (™/®) taraması
