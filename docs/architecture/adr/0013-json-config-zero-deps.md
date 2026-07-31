# 0013 — JSON yapılandırma + sıfır çalışma zamanı bağımlılığı

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §10, §3.3

## Bağlam

Yapılandırma insan tarafından düzenlenebilir, sürüm kontrolüne alınabilir ve araçlarla işlenebilir olmalı. TOML/YAML daha okunaklı ama **bağımlılık gerektiriyor**. Açık kaynak bir projede her bağımlılık, katkıcı için bir kurulum adımı ve proje için bir güvenlik/lisans yüzeyi.

## Karar

- **Format: JSON.** Codable-native, sıfır bağımlılık, şema doğrulanabilir, araç dostu
- **Konum:** `~/Library/Application Support/Boreas/config.json`
- **Şema:** `schema/config.schema.json` — repoda yayınlanır ve sürümlenir
- **Sürümleme:** `schemaVersion` alanı; eski sürümler otomatik göç ettirilir, göç öncesi yedek alınır
- **Çalışma zamanı bağımlılığı: sıfır.** Yalnızca Apple çatıları

Doğrulama **sıkı**: aralık dışı değer reddedilir. **Geçersiz yapılandırma uygulamayı çökertmez** — son geçerli hale dönülür, hatalı alan kullanıcıya gösterilir, fanlar firmware'de kalır.

Bilinmeyen alanlar **hata değil uyarıdır** (ileri uyumluluk).

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| TOML | Daha okunaklı ama bağımlılık gerektirir; katkıcı deneyimi ve lisans yüzeyi maliyeti |
| YAML | Aynı sorun + ayrıştırma belirsizlikleri (Norway problem vb.) |
| `UserDefaults` / plist | İnsan tarafından düzenlenmesi zor, sürüm kontrolüne uygun değil, dotfiles ile taşınamaz |

## Sonuçlar

- ✅ Kullanıcı yapılandırmayı dotfiles ile taşıyabilir
- ✅ MDM ile dağıtım zaten mümkün (kurumsal araç yazmaya gerek yok)
- ✅ Sıfır bağımlılık → sıfır tedarik zinciri riski
- ⚠️ JSON'da yorum yok — şema dosyası ve dokümantasyon bunu telafi eder

## Zorlama

- `make gate-deps` → `Package.swift` içinde `.package(url:` varsa kırmızı (T4)
- Birim testi: geçersiz yapılandırma → son geçerli hale dönülür, çökme yok (G6)
- Göç testi: eski şema sürümü veri kaybı olmadan taşınır
