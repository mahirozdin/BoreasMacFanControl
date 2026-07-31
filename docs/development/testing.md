# Test Stratejisi

> Son güncelleme: 2026-07-31 — P0.24
> Kaynak: blueprint §15 · Karar: [ADR 0011](../architecture/adr/0011-hardware-abstraction.md)

## Katmanlar

| Katman | Kapsam | Araç |
|---|---|---|
| **Birim** | Eğri değerlendirme, histerezis, hız sınırlama, arbitraj, güvenlik zinciri, yapılandırma doğrulama, göç | Swift Testing |
| **Özellik (property-based)** | Motor değişmezleri üretilmiş girdilerle | Swift Testing |
| **Altın dosya** | Kaydedilmiş termal senaryolar → beklenen fan komut dizisi | `Tests/Fixtures/` |
| **Entegrasyon** | XPC el sıkışması, daemon kur/kaldır, watchdog zaman aşımı | Sahte + gerçek daemon |
| **Donanım duman testi** | Gerçek Mac'te devral/geri ver döngüsü | `scripts/smoke-test-hardware.sh` |
| **UI** | Kurulum, profil değiştirme, eğri düzenleme | XCUITest |
| **Erişilebilirlik** | VoiceOver etiket kapsamı, klavye gezinme, pseudo-locale düzen | Denetim + otomatik |

## Kritik senaryolar

Bunlar geçmeden **hiçbir sürüm yayınlanmaz**:

- [ ] `kill -9` sonrası fanlar ≤ watchdog süresi içinde firmware'e döner
- [ ] Sistem uykusunda fanlar firmware'e devredilir
- [ ] Daemon kurulu değilken uygulama tam işlevli izleme yapar, hata göstermez
- [ ] Bozuk yapılandırma uygulamayı çökertmez, son geçerli hale döner
- [ ] `T_panic` aşıldığında çıktı %100 olur ve tutma süresi boyunca kilitli kalır
- [ ] Termal durum `critical` iken kullanıcı eğrisi ne olursa olsun çıktı %100
- [ ] Sensör kaynağı hata verdiğinde izleme moduna düşülür, çökme yok
- [ ] Fansız modelde uygulama anlamlı davranır
- [ ] Profil geçişinde fan hızı sıçraması olmaz
- [ ] Şema göçü veri kaybı olmadan taşır

## Donanım kapsama sınırları

Geliştirme donanımı **tek model**: Mac mini (M4, 2024) — tek fanlı, pilsiz masaüstü.

| Kod yolu | Gerçek donanımda | Nasıl doğrulanır |
|---|---|---|
| M4 nesli sensör keşfi ve gruplama | ✅ | Doğrudan |
| Tek fan devral / geri ver | ✅ | Doğrudan |
| Güvenlik zinciri K1–K5, watchdog | ✅ | Doğrudan |
| Masaüstü (pilsiz) kod yolu | ✅ | Doğrudan |
| Termal baskı yükselmesi | ✅ | Yük testiyle |
| **Fansız model davranışı** | ❌ | Mock + topluluk raporu |
| **Çok fanlı arbitraj, fan başına eğri** | ❌ | Mock + topluluk raporu |
| **Pil / güç kaynağı tetikleyicileri** | ❌ | Mock + topluluk raporu |
| **Pil sağlığı tanılaması** | ❌ | Mock + topluluk raporu |
| **M1 / M2 / M3 sensör adlandırması** | ❌ | Mock + topluluk raporu |

**Üç bağlayıcı sonuç:**

1. **Mock ve Replay katmanları P2'de inşa edilir**, sonraya bırakılamaz
2. **README'de "Test edilen donanım" bölümü zorunludur** — kapsamı abartmamak güvenin tek kaynağı
3. **Doğrulanmamış kod yolları için özel issue şablonu** bulunur; kullanıcı log'u `Replay` ile yerel olarak yeniden oynatılır

## CI

`macos-latest` (arm64): lint → `xcodegen generate` → derleme (uyarılar hata) → birim + özellik + altın dosya testleri → kapsam (`Core` ≥ %85 bloklayıcı) → etiketli sürümlerde imzalama + notarizasyon + DMG.

**Donanım gerektiren testler CI'da çalışmaz.** Mock katmanı sayesinde motorun tamamı yine de test edilir.

## Kanıt kuralı

Doğrulama çalıştırılamadıysa Run Log'a **`NOT RUN` + neden** yazılır ve iş `DONE` yapılmaz. "Yazdım, çalışıyordur" yasaktır.
