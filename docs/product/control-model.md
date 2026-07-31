# Kontrol Modeli — Çekirdek Soyutlama

> Son güncelleme: 2026-07-31 — P0.15
> Kaynak: blueprint §7 · Karar: [ADR 0010](../architecture/adr/0010-continuous-curve-model.md)

> **Bu, ürünün çekirdek soyutlamasıdır.** Sistemin geri kalanı buna göre şekillenir.

## Temel model

Fan davranışı **parçalı doğrusal, sürekli bir transfer fonksiyonu** ile tanımlanır:

```
Girdi: sıcaklık (°C)  →  Çıktı: görev oranı (duty, 0.0 – 1.0)
```

Eğri sıralı kontrol noktalarından oluşur, noktalar arası **doğrusal enterpolasyon** yapılır:

```
[(35, 0.00), (50, 0.20), (65, 0.45), (78, 0.75), (88, 1.00)]
```

**Kısıtlar:** sıcaklığa göre artan sıralı, görev oranı azalmayan, 2–16 nokta. İlk noktanın altında çıktı ilk noktanın değeri; son noktanın üstünde son noktanın değeri.

**RPM dönüşümü:**
```
rpm = fanMin + (fanMax − fanMin) × duty
```

`duty = 0` fanı **durdurmaz**, donanım minimumuna indirir.

## İşleme zinciri

Üç aşama, her biri farklı bir problem çözer:

| # | Aşama | Parametre | Varsayılan | Problem |
|---|---|---|---|---|
| 1 | Girdi yumuşatma | EWMA `α` | 0.30 | Sensör gürültüsü, anlık tepe |
| 2 | Histerezis | `H` (°C) | 3.0 | Eşik çevresi salınım |
| 3 | Çıktı hız sınırı | `maxRise`/`maxFall` | 600/150 RPM/sn | Duyulabilir ani ses değişimi |

**Histerezis — çift eğri:** düşen yönde eğri `H` kadar sola kaydırılır. Motor sıcaklığın yönüne göre eğri seçer ve seçilen eğride **kilitli kalır**, ta ki diğerini kesecek kadar ters hareket olana dek.

**Hız sınırı asimetriktir** ve bu kasıtlıdır: yükselme hızlı olmalı (güvenlik), düşme yavaş (akustik konfor + termal kararlılık). Tek bir "geçiş süresi" parametresi bunu ifade edemez.

## Girdi seçimi

Her eğri bir **sensör toplayıcıya** bağlanır:

```
input: { group: "compute.performance", aggregate: "max", smoothing: 0.30 }
```

`max` varsayılandır (güvenlik yanlı). `mean` daha yumuşak davranış, `p95` sapkın sensör etkisini azaltmak için.

## Profiller ve arbitraj

**Profil** = ad + fan başına eğri seti + yumuşatma parametreleri + tetikleyici + öncelik.

Yerleşik profiller: `Sessiz`, `Dengeli` (varsayılan), `Performans`, `Sistem` (motor devre dışı).

**Tetikleyici türleri:** güç kaynağı · çalışan/ön plandaki uygulama · zaman aralığı · pil seviyesi · harici ekran · termal durum · elle seçim.

**Arbitraj kuralları:**
1. Elle seçim her şeyi yener (süreli olabilir)
2. Aksi halde koşulu sağlanan profiller arasından **en yüksek öncelikli**
3. Eşitlikte listede önce gelen
4. Hiçbiri sağlanmazsa varsayılan profil
5. Geçişler hız sınırlayıcıdan geçer — sıçrama olmaz

Bir profil **her fan için ayrı eğri ve ayrı sensör grubu** tanımlayabilir.

## Güvenlik zinciri

Motor çıktısı donanıma ulaşmadan beş katmandan geçer. **Her katman yalnızca yukarı düzeltebilir.**

| Katman | Nerede | Kural | Kapatılabilir |
|---|---|---|---|
| K1 Fan tabanı | Motor | Donanım minimumunun altına inilmez | Hayır |
| K2 Termal durum | Motor | `serious` → taban %55; `critical` → %100 | Hayır |
| K3 Panik eşiği | Motor | Sensör > `T_panic` → %100, ≥30 sn kilitli | Hayır (yalnızca düşürülebilir) |
| K4 Daemon guard | Daemon | Sınır dışı komut reddedilir | Hayır |
| K5 Watchdog | Daemon | Kalp atışı yoksa firmware'e devret | Hayır |

K2 resmî `ProcessInfo.thermalState` API'sine dayanır — dokümante edilmemiş API'ye bağımlı **değildir**.

## Durum makinesi

```
MONITORING ──(kontrol açılır + daemon hazır)──▶ CONTROLLING
CONTROLLING ──(K3)──▶ PANIC ──(normale döner)──▶ CONTROLLING
* ──(watchdog / uyku / çıkış / hata)──▶ RELEASING ──▶ MONITORING
```

`RELEASING` **idempotenttir**.

## Invariantlar

Bu modelin doğruluğunu koruyan silinemez testler `ARCHITECTURE.md` §7'de listelenir.
