# Mimari Karar Kayıtları (ADR)

> Son güncelleme: 2026-07-31 — P0.08
> Kaynak: blueprint §3, §5, §6, §7, §23

Format: Michael Nygard — `Bağlam` / `Karar` / `Alternatifler` / `Sonuçlar` / **`Zorlama`**.

**`Zorlama` bölümü zorunludur.** Bir karar kodda veya CI'da zorlanamıyorsa, o karar bir dilektir.

## İndeks

| # | Karar | Durum | Alan |
|---|---|---|---|
| [0001](0001-native-swift.md) | Native Swift + SwiftUI | Kabul | Teknoloji |
| [0002](0002-product-name.md) | Ürün adı: Boreas | Kabul | Kimlik |
| [0003](0003-minimum-macos-14.md) | Minimum macOS 14.0 Sonoma | Kabul | Teknoloji |
| [0004](0004-apple-silicon-only.md) | Yalnızca Apple Silicon (arm64) | Kabul | Kapsam |
| [0005](0005-apache-2-license.md) | Apache License 2.0 | Kabul | Hukuk |
| [0006](0006-independent-development-policy.md) | **Bağımsız geliştirme politikası** | Kabul | Hukuk |
| [0007](0007-privilege-split.md) | Ayrıcalıksız okuma / ayrıcalıklı yazma | Kabul | Mimari |
| [0008](0008-smappservice-xpc.md) | SMAppService + imza doğrulamalı XPC | Kabul | Güvenlik |
| [0009](0009-watchdog-dead-man-switch.md) | Ölü adam anahtarı (watchdog) | Kabul | Güvenlik |
| [0010](0010-continuous-curve-model.md) | Sürekli eğri kontrol modeli | Kabul | Ürün |
| [0011](0011-hardware-abstraction.md) | Donanım soyutlaması: Live/Mock/Replay | Kabul | Mimari |
| [0012](0012-core-layer-purity.md) | `Core` katman saflığı | Kabul | Mimari |
| [0013](0013-json-config-zero-deps.md) | JSON yapılandırma + sıfır bağımlılık | Kabul | Mimari |
| [0014](0014-zero-telemetry.md) | Sıfır telemetri | Kabul | Gizlilik |
| [0015](0015-automation-hooks-not-email.md) | E-posta yerine otomasyon kancaları | Kabul | Kapsam |
| [0016](0016-language-scope.md) | 5 dil arayüz / İngilizce dokümantasyon | Kabul | Ürün |
| [0017](0017-distribution-channels.md) | Dağıtım kanalları; App Store dışlandı | Kabul | Yayın |
| [0018](0018-undocumented-sensor-api.md) | Dokümante edilmemiş sensör API'si kabulü | Kabul | Risk |
| [0019](0019-signing-identity-deferred.md) | İmzalama kimliği P8'e ertelendi | Kabul | Yayın |

## Yeni ADR yazarken

1. Sıradaki numarayı al, `NNNN-kisa-slug.md` olarak oluştur
2. Beş bölümü de doldur — **`Zorlama` boş bırakılamaz**
3. Bu indekse satır ekle
4. `ARCHITECTURE.md` §11 tablosuna satır ekle
5. `make docs-check` çalıştır — üçlü senkron denetlenir

## Ne zaman ADR yazılır

- Blueprint'ten sapma (**zorunlu**)
- Yeni teknoloji/çatı seçimi
- Yeni değişmez veya "asla/daima" kuralı
- Ayrıcalıklı yüzeyin genişletilmesi
- Geri alınması pahalı olacak her karar
