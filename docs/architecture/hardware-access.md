# Donanım Erişim Katmanı

> Son güncelleme: 2026-07-31 — P0.19
> Kaynak: blueprint §5 · Kararlar: [ADR 0011](adr/0011-hardware-abstraction.md), [ADR 0018](adr/0018-undocumented-sensor-api.md)

## Sıcaklık okuma — ayrıcalıksız

Apple Silicon'da sıcaklık sensörleri HID sensör servisleri olarak sunulur:

1. HID olay sistemi istemcisi oluşturulur
2. Eşleştirme sözlüğü ile sıcaklık sensörü sınıfındaki servisler filtrelenir
3. Her servisten ürün özelliği okunarak sensörün donanım adı alınır
4. Her servisten sıcaklık olayı çekilir ve float değer okunur

**Karakteristikleri:** root gerektirmez · sensör adları çipe göre değişir, **koda gömülmez, çalışma zamanında keşfedilir** · ham adlar kullanıcı dostu değildir, eşleme katmanı gerekir.

⚠️ **Risk (R1):** Bu API resmî olarak dokümante edilmemiştir. Azaltım: `SensorSource` protokolü + SMC üzerinden ikinci kaynak + zarif düşüş. Ayrıntı [ADR 0018](adr/0018-undocumented-sensor-api.md).

📌 **Notarizasyon:** Dokümante edilmemiş API kullanımı **App Store inceleme** kuralıdır; doğrudan dağıtım + notarizasyon akışını engellemez.

## Fan okuma ve yazma — SMC

`AppleSMC` IOService üzerinden dört karakterlik anahtarlarla:

| İhtiyaç | Yön | Ayrıcalık |
|---|---|---|
| Fan sayısı, anlık hız, min, max | Oku | Yok |
| Hedef hız, kontrol modu | **Yaz** | **Root** |

**Devralma dizisi (daemon içinde):**
1. Mevcut mod ve hedef okunur, **orijinal durum saklanır**
2. Mod "zorlamalı"ya alınır
3. Hedef hız yazılır
4. Sonraki döngüde gerçek hız okunur, sapma varsa düzeltilir (**kapalı çevrim doğrulama**)

**Devretme dizisi:**
1. Hedef orijinal değere geri yazılır
2. Mod "otomatik"e alınır
3. Doğrulama okuması; başarısızsa üstel geri çekilmeyle en fazla 5 deneme

**Veri tipleri:** SMC anahtarları tipli veri döndürür. Tip bilgisi anahtarla birlikte okunur; **tip varsayılmaz**. Bilinmeyen tip → sensör atlanır, uyarı loglanır.

## Diğer veri kaynakları

| Kaynak | Ayrıcalık | Ne verir |
|---|---|---|
| `ProcessInfo.thermalState` | Yok | **Tamamen resmî API** — güvenlik zinciri K2 katmanının temeli |
| Güç kaynağı API'si | Yok | Adaptör/pil, şarj yüzdesi |
| Pil IORegistry düğümü | Yok | Döngü sayısı, kapasite, sıcaklık, durum |
| Dahili SSD SMART | Yok | Disk sıcaklığı, kullanım ömrü |
| CPU yükü | Yok | "Neden ısındı?" bağlamı |
| Ön plandaki uygulama | Yok | Uygulama tetikleyicili profiller |
| Ekran bağlantısı | Yok | Harici ekran tetikleyicisi |

## Soyutlama ve test edilebilirlik

```
protocol SensorSource   { func snapshot() async throws -> [SensorReading] }
protocol FanSource      { func fans() async throws -> [FanState] }
protocol FanActuator    { func apply(_:) async throws; func releaseToFirmware() async throws }
protocol PowerSource    { func current() -> PowerContext }
```

Her birinin **üç** uygulaması: `Live` (gerçek) · `Mock` (deterministik) · `Replay` (log'dan yeniden oynatan).

**Bu, projenin en değerli mühendislik yatırımıdır** — [ADR 0011](adr/0011-hardware-abstraction.md). `make gate-layers` ile zorlanır.

## Sensör adlandırma ve gruplama

Ham adlar iki katmandan geçer: **normalleştirme** (önek/sonek temizliği, kısaltma açma) → **sınıflandırma** (desen tabanlı grup ataması).

Grup taksonomisi: **`compute`** · `compute.performance` · `compute.efficiency` · `graphics` · `memory` · `storage` · `power` · `battery` · `chassis` · `airflow` · `wireless` · `uncategorized`

> **`compute`**, blueprint taksonomisine sonradan eklendi. Apple Silicon die sensörlerinin çoğu (`PMU tdie<n>`) hangi kümede olduğunu söylemiyor; küme uydurmak yerine atfedilemeyen die sıcaklıkları bu grupta toplanıyor. Gerekçe ve alternatifler: [ADR 0020](adr/0020-compute-die-sensor-group.md).

**Kural:** Eşleşmeyen sensör **asla gizlenmez.** `uncategorized` altında gösterilir ve kullanıcı tek tıkla rapor oluşturabilir. Bu, yeni çip nesillerine adaptasyonu topluluk eliyle hızlandırır (R2 azaltımı).

**Kullanıcı geçersiz kılması:** Yapılandırmadan herhangi bir sensöre özel ad ve grup atanabilir.
