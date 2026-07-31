# 0003 — Minimum hedef macOS 14.0 Sonoma

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §3.2, §23 A2

## Bağlam

Ayrıcalıklı daemon kaydı için `SMAppService` gerekiyor (macOS 13.0+). Modern SwiftUI için `@Observable` (14.0+) ve kararlı `MenuBarExtra` isteniyor. Daha düşük hedef daha geniş erişim demek ama sürüm dallanması ve bakım yükü getiriyor.

## Karar

**Minimum macOS 14.0 Sonoma.**

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| **macOS 13.0 Ventura** | `@Observable` yok → `ObservableObject` + Combine (daha çok kod, daha çok hata yüzeyi). `SMAppService`'in 13.0'daki kayıt sorunları için geçici çözüm gerekir. İki sürümde test yükü. Tahmini kazanç ~%3 erişim; maliyet kalıcı |
| **macOS 15.0 Sequoia** | Daha sade kod ama gereksiz yere M1/M2 kullanıcılarının bir kısmını dışarıda bırakır; açık kaynak benimsenmesini yavaşlatır |

## Sonuçlar

- ✅ `SMAppService` olgun sürümü, `@Observable`, kararlı `MenuBarExtra`, olgun Swift Charts, tam String Catalog desteği
- ✅ Tek kod yolu — sürüm dallanması yok
- ⚠️ macOS 13'te kalan kullanıcılar dışarıda (Apple Silicon tabanının tahmini ~%5'i)

## Zorlama

- `project.yml` → `DEPLOYMENT_TARGET: 14.0`
- Derleme, daha düşük sürüm API'si varsayımını yakalar
- CI `macos-latest` üzerinde derler
