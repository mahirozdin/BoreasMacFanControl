# 0012 — `Core` katman saflığı

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §17.2

## Bağlam

Kontrol motorunun donanımsız test edilebilmesi [0011](0011-hardware-abstraction.md)'in ön koşulu. Ancak "test edilebilir tasarım" niyeti, ilk "geçici olarak şunu import edeyim" anında çöker. Geçici hiçbir zaman geçici olmaz.

## Karar

Derleme ve kapı ile zorlanan bağımlılık yönü:

```
App    ──▶ Core, HardwareKit, SharedIPC
CLI    ──▶ Core, HardwareKit, SharedIPC
Daemon ──▶ HardwareKit (yalnızca yazma yüzeyi), SharedIPC
Core   ──▶ (yalnızca Foundation)
HardwareKit ──▶ Core (yalnızca model tipleri)
```

**`Packages/Core` şunları import edemez:** IOKit, SwiftUI, AppKit, Cocoa, Carbon, ServiceManagement, UserNotifications, WidgetKit, AppIntents, Charts, Network.

Ek kurallar: `Core` içinde zorla açma (`!`) yasak; tüm tipler `Sendable`; motor fonksiyonları saf.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Tek modül, katman ayrımı yok | Test edilebilirlik imkânsız; CI'da hiçbir şey doğrulanamaz |
| Katman kuralını yalnızca dokümante etmek | Zorlanmayan kural zamanla ihlal edilir |
| SPM hedef bağımlılığına güvenmek | SPM yanlış import'u yakalar ama hata mesajı açıklayıcı değil; kapı gerekçeyi de söyler |

## Sonuçlar

- ✅ Motor CI'da saniyeler içinde test edilir
- ✅ Yeni platform/donanım desteği yalnızca `HardwareKit`'i etkiler
- ⚠️ Bazı yardımcılar iki kez yazılabilir (`Core` ve `App` tarafında) — kabul edilen maliyet

## Zorlama

`make gate-layers`:
- `Packages/Core/Sources` altında yasaklı `import` satırı → kırmızı
- `Core` içinde zorla açma (`!`) → kırmızı

Kanıtlandı: `Core` altına `import IOKit` içeren bir dosya konduğunda kapı kırmızıya döndü, dosya kaldırılınca yeşile döndü.
