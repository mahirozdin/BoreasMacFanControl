# Yapılandırma

> Son güncelleme: 2026-07-31 — P0.21
> Kaynak: blueprint §10 · Karar: [ADR 0013](adr/0013-json-config-zero-deps.md)

## Format ve konum

| Konu | Değer |
|---|---|
| Format | **JSON** — Codable-native, sıfır bağımlılık, şema doğrulanabilir |
| Konum | `~/Library/Application Support/Boreas/config.json` |
| Şema | `schema/config.schema.json` — repoda yayınlanır ve sürümlenir |
| Sürümleme | `schemaVersion` alanı; otomatik göç + göç öncesi yedek |
| Yedek | Her başarılı yazımdan önce `config.backup.json` |

## Yapı

```
{
  "schemaVersion": 1,
  "general":   { samplingIntervalSeconds, temperatureUnit, launchAtLogin, language },
  "safety":    { panicTemperatureCelsius, panicHoldSeconds, watchdogTimeoutSeconds },
  "profiles":  [ { id, name, priority, triggers[], smoothing, slew, fanCurves[] } ],
  "sensorOverrides": [ { match, displayName, group } ],
  "notifications":   { enabled, suppressionWindowMinutes, rules[] },
  "logging":         { enabled, format, path, rotation, fields[] }
}
```

Tam örnek ve alan açıklamaları `schema/config.schema.json` içindedir (P4'te yazılacak). **Bu dosyada şema kopyası tutulmaz** — drift kaynağı olur.

## Doğrulama kuralları

| Alan | Kısıt |
|---|---|
| Eğri noktaları | Sıcaklığa göre artan sıralı, görev oranı azalmayan |
| `duty` | `[0.0, 1.0]` |
| Sıcaklık | `[0, 120]` °C |
| `panicTemperatureCelsius` | `[70, 105]` |
| `watchdogTimeoutSeconds` | `[10, 60]` — **kilitli** |
| `samplingIntervalSeconds` | `[1, 60]` |
| Profil `id` | Benzersiz |
| Bilinmeyen alan | **Hata değil uyarı** (ileri uyumluluk), loglanır |

## Geçersiz yapılandırma davranışı

**Uygulama başlamayı reddetmez.** Son geçerli yapılandırmaya döner, kullanıcıya net hata mesajı ve hangi alanın sorunlu olduğunu gösterir. **Bu süreçte fanlar firmware kontrolündedir.**

Bu davranış invariant testiyle korunur (G6).

## Göç

Şema sürümü arttığında göç fonksiyonu yazılır ve **veri kaybı olmadan taşıdığı testle kanıtlanır**. Göç öncesi yedek otomatik alınır.

Şema kırılması **MAJOR** sürüm gerektirir.
