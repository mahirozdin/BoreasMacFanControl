# 0020 — Küme atfedilemeyen çekirdek sensörleri için `compute` grubu

- **Durum:** Kabul
- **Tarih:** 2026-08-04
- **Kaynak:** blueprint §5.5 taksonomisinden **sapma**
- **İlgili:** [0011](0011-hardware-abstraction.md), [0018](0018-undocumented-sensor-api.md)

## Bağlam

Blueprint §5.5 sensör taksonomisini `compute.performance` ve `compute.efficiency` olarak ikiye ayırıyordu; varsayım, her çekirdek sensörünün bir kümeye atfedilebileceğiydi.

Gerçek donanımda (Mac mini M4, HID sensör arayüzü) bu varsayım tutmadı. Rapor edilen 40 sensörün 39'u şu biçimde:

```
PMU tdie1 … PMU tdie14        SoC üzerindeki die sıcaklıkları
PMU2 tdie1 … PMU2 tdie10
PMU tdev1 … PMU tdev8         cihaz sıcaklıkları
PMU tcal, PMU2 tcal           kalibrasyon
```

Bu sensörler **PMU tarafından raporlanıyor** ama **SoC die'ını ölçüyor**. İki sorun doğdu:

1. `pmu → power` kuralı hepsini `power` grubuna atıyordu. Kullanıcı `compute.performance`'a bir fan eğrisi bağlasa **bu makinede hiçbir sensör eşleşmezdi** — eğri sessizce hiçbir şeye bağlı kalırdı.
2. Bu sensörlerin hangi kümeye ait olduğu **bilinmiyor**. `tdie7`'nin performans mı verimlilik kümesinde mi olduğunu söyleyecek bir bilgi yok.

## Karar

Taksonomiye **`compute`** grubu eklendi: *belirli bir kümeye atfedilemeyen çekirdek sıcaklıkları.*

| Desen | Grup | Gerekçe |
|---|---|---|
| `tdie*`, `tdev*`, `die temp` | **`compute`** | SoC die sıcaklığı; küme bilinmiyor |
| `pacc`, `performance`, `p-core` | `compute.performance` | Küme açıkça belirtilmiş |
| `eacc`, `efficiency`, `e-core` | `compute.efficiency` | Küme açıkça belirtilmiş |
| `tcal` | `power` | Kalibrasyon, sıcaklık kontrolü için anlamlı değil |
| `pmu`, `pmgr`, `vrm` (yukarıdakiler dışında) | `power` | Gerçekten güç devresi |

Sıralama kritik: `tdie`/`tdev` kuralları generic `pmu` kuralından **önce** denenir.

`compute`, fan eğrisi girdisi olarak seçilebilir (`curveInputCandidates` içinde).

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| `tdie*` → `compute.performance` | **Yanlış bilgi.** Hangi kümede olduğu bilinmiyor; "performans kümesi" demek uydurmak olur |
| Mevcut hâlde bırakmak (`power`) | Kullanıcının eğrisi sessizce hiçbir şeye bağlanır — en kötü başarısızlık türü, çünkü fark edilmez |
| `uncategorized`'a atmak | Teknik olarak dürüst ama işe yaramaz: soğutmayı yönlendiren asıl sensörler eğriye bağlanamaz hale gelirdi |
| Model bazlı tablo yazmak | Her yeni çip için sürüm gerekir; ADR 0011'in reddettiği yaklaşım |

## Sonuçlar

- ✅ Fan eğrileri bu donanımda anlamlı bir gruba bağlanabiliyor
- ✅ Bilinmeyen, bilinmiyor olarak kalıyor — küme uydurulmuyor
- ✅ Küme bilgisi açıkça raporlayan donanımda ayrım korunuyor
- ⚠️ Taksonomi blueprint'ten farklı; `docs/architecture/hardware-access.md` ve sözlük güncellendi
- ⚠️ Varsayılan profillerin girdi grubu `compute.performance` yerine daha geniş bir seçim kullanmalı — P5.07'de ele alınacak

## Zorlama

- Birim testi: `PMU tdie7` → `.compute`, `PMU tcal` → `.power`, `pACC …` → `.computePerformance`
- Birim testi: sıralama koruması — `tdie` kuralı `pmu` kuralından önce denenmezse test kırılır
- `SensorGroup.curveInputCandidates` `compute` içerir, `uncategorized` içermez
