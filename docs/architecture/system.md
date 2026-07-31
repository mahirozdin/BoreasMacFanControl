# Sistem Mimarisi

> Son güncelleme: 2026-07-31 — P0.18
> Kaynak: blueprint §4 · Bağlayıcı invariantlar: `ARCHITECTURE.md`

## Bileşenler

```
KULLANICI ALANI (yetkisiz)                    KÖK ALANI (root)
┌────────────────────────────────┐  NSXPC   ┌──────────────────────┐
│ Boreas.app                     │◀────────▶│ FanDaemon            │
│  ├─ UI (SwiftUI)               │  çift    │  ├─ XPCListener      │
│  ├─ ControlEngine              │  yönlü   │  ├─ SMCWriter        │
│  ├─ SensorReader ──────────────┼──┐ imza  │  ├─ SafetyGovernor   │
│  ├─ ConfigStore                │  │ doğr. │  ├─ Watchdog         │
│  ├─ Telemetry (yerel)          │  │       │  └─ StateRestorer    │
│  └─ DaemonClient (kalp atışı)  │  │       └──────────┬───────────┘
└────────────────────────────────┘  │                  │ IOKit
┌────────────────────────────────┐  │                  ▼
│ boreas (CLI)                   │  └──────────▶ ┌──────────────┐
└────────────────────────────────┘   ayrıcalıksız│  DONANIM     │
                                      okuma      └──────────────┘
```

## Mimarinin kilit noktası

**Sıcaklık okumak hiçbir ayrıcalık gerektirmez. Yalnızca fan yazmak gerektirir.**

Bu bulgu mimarinin tamamını belirler → [ADR 0007](adr/0007-privilege-split.md)

Sonuçları:
- Kullanıcı daemon'u **hiç kurmasa bile** uygulama tam işlevli izleme aracıdır
- Yönetici şifresi yalnızca bir kez, yalnızca fan kontrolü istendiğinde
- Ayrıcalıklı yüzey birkaç yüz satırla sınırlı: daemon yalnızca "şu fana şu hedefi yaz" ve "firmware'e dön" bilir
- Eğri değerlendirmesi, profil mantığı, yapılandırma okuma — **hiçbiri root tarafında değil**

## Modül bağımlılıkları

```
App    ──▶ Core, HardwareKit, SharedIPC
CLI    ──▶ Core, HardwareKit, SharedIPC
Daemon ──▶ HardwareKit (yalnızca yazma yüzeyi), SharedIPC
Core   ──▶ (yalnızca Foundation)
HardwareKit ──▶ Core (yalnızca model tipleri)
```

`Core`'un saflığı `make gate-layers` ile zorlanır → [ADR 0012](adr/0012-core-layer-purity.md)

## Güven sınırları

| Sınır | Doğrulama |
|---|---|
| App → Daemon | `SecCodeCheckValidity` + `SecRequirement`; Team ID ve bundle ID eşleşmezse red |
| Daemon → App | Uygulama daemon imzasını doğrular |
| Daemon → Donanım | `SafetyGovernor` tüm yazmaları süzer |
| Config → Motor | Şema doğrulaması; geçersizse son geçerli hale dönülür |

Ayrıntı: [ADR 0008](adr/0008-smappservice-xpc.md)

## Eşzamanlılık modeli

- Sensör okuma: özel `actor SensorPoller`, sabit periyot
- Kontrol motoru: **saf fonksiyonlar** (`Sendable` girdi → `Sendable` çıktı), yan etkisiz
- UI: `@MainActor`, `@Observable` model
- XPC: kendi kuyruğu; sonuç daemon'a `async` gönderilir

**Kural:** Donanım erişen hiçbir kod `@MainActor` üzerinde çalışmaz. Arayüz asla donmaz.

## Hata senaryoları

Tam liste: `ARCHITECTURE.md` §9.

Ortak ilke: **hiçbir donanım hatası uygulamayı çökertmez.** Zarif düşüş uygulanır, kullanıcı dürüstçe bilgilendirilir, fanlar güvenli duruma döner.
