# 0010 — Sürekli eğri kontrol modeli

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §7

> Ürünün mühendislik kalbi ve özgünlüğünün yapısal temeli.

## Bağlam

Fan davranışını tanımlamanın iki yaygın yolu var: (a) ayrık kural listesi — "sıcaklık X'i geçerse hızı Y yap", (b) sürekli transfer fonksiyonu — sıcaklığı görev oranına eşleyen bir eğri.

Ayrık kural listesinin iki sorunu var: eşiklerde fan hızı **sıçrar** (kulak bu ani değişimi sabit yüksek sesten daha rahatsız edici bulur) ve eşik çevresinde **salınım** üretir.

## Karar

**Parçalı doğrusal, sürekli transfer fonksiyonu.**

```
Girdi: sıcaklık (°C)  →  Çıktı: görev oranı (0.0 – 1.0)
Kontrol noktaları: [(35, 0.00), (50, 0.20), (65, 0.45), (78, 0.75), (88, 1.00)]
Noktalar arası: doğrusal enterpolasyon
rpm = fanMin + (fanMax − fanMin) × duty
```

Kısıtlar: sıcaklığa göre artan sıralı, görev oranı azalmayan, en az 2 en fazla 16 nokta.

Üç aşamalı işleme zinciri — her aşama **farklı** bir problemi çözer:

| Aşama | Parametre | Varsayılan | Çözdüğü problem |
|---|---|---|---|
| Girdi yumuşatma | EWMA `α` | 0.30 | Sensör gürültüsü, anlık tepe |
| Histerezis | `H` (°C) | 3.0 | Eşik çevresi salınım |
| Çıktı hız sınırı | `maxRise` / `maxFall` | 600 / 150 RPM/sn | Duyulabilir ani ses değişimi |

**Histerezis çift eğri ile:** düşen yönde eğri `H` kadar sola kaydırılır; motor yöne göre eğri seçer ve seçilen eğride kilitli kalır.

**Hız sınırı asimetriktir:** yükselme hızlı (güvenlik), düşme yavaş (akustik konfor + termal kararlılık). Tek bir "geçiş süresi" parametresi bu asimetriyi ifade edemez.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Ayrık kural listesi | Basamaklı çıktı → akustik olarak rahatsız edici, eşiklerde salınım |
| Tam PID kontrolcü | Fan sistemleri için aşırı; ayar parametreleri kullanıcıya açıklanamaz; integral windup riski |
| Tek "rampa süresi" parametresi | Yükselme/düşme asimetrisini ifade edemez |

## Sonuçlar

- ✅ Sürekli, öngörülebilir, akustik olarak konforlu çıktı
- ✅ Ayrı bir "zaman gecikmesi" ayarına gerek yok — histerezis + hız sınırı yeterli
- ✅ Kullanıcıya sunulan parametreler anlamlı ("fan ne kadar hızlı tepki versin?")
- ✅ Özgünlük yapısal — yalnızca beyan edilmiş değil ([0006](0006-independent-development-policy.md))
- ⚠️ Eğri editörü ayrık listeye göre daha karmaşık bir arayüz gerektirir

## Zorlama

Invariant testleri (silinemez):

```
test("monoton artan eğri monoton artan çıktı üretir")
test("çıktı her zaman [fanMin, fanMax] aralığındadır")
test("hiçbir güvenlik katmanı çıktıyı düşüremez")
test("eğri noktaları monotonluk kısıtını ihlal edemez")
test("hız sınırı asimetriktir: rise ve fall bağımsız uygulanır")
```

Karşılaştırma testi (ADR'yi kodda yaşatır):
```
test("ayrık basamaklı model uygulansaydı eşikte sıçrama olurdu")
```
