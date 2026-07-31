# 0001 — Native Swift + SwiftUI

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §3.1, §3.2

## Bağlam

Ürün; SMC üzerinden fan okuma/yazma, ayrıcalıklı bir LaunchDaemon, XPC iletişimi ve bir menü çubuğu öğesi gerektiriyor. Bunların hiçbirine çapraz platform çatılarından erişilemiyor. Ayrıca uygulama sürekli arka planda çalışacağı için boştaki CPU ve enerji maliyeti birinci sınıf bir gereksinim.

## Karar

**Swift 6.2 + SwiftUI** (gerektiğinde `NSViewRepresentable` ile AppKit köprüsü). Proje dosyası **XcodeGen** ile `project.yml`'den üretilir; `.xcodeproj` commit edilmez. Test çatısı **Swift Testing**; UI testlerinde XCTest.

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| **Flutter** | IOKit, ayrıcalıklı daemon, XPC ve `NSStatusItem` için native plugin şart — yani işin en zor kısmı yine Swift'te yazılacaktı. Üstüne ~40–60 MB runtime, yabancı duran arayüz, sürekli render döngüsünün enerji maliyeti. Tek avantajı çapraz platform; bu proje tanımı gereği tek platform |
| **Electron** | ~120 MB+ ikili, ~200 MB bellek. Sürekli çalışan bir termal izleyici için kabul edilemez |
| **Rust + native UI** | FFI ile mümkün ama SwiftUI/AppKit köprüsü zahmetli, erişilebilirlik ücretsiz gelmiyor, macOS katkıcı havuzu dar |

## Sonuçlar

- ✅ IOKit/ServiceManagement/XPC birinci sınıf erişim
- ✅ VoiceOver, Dynamic Type, App Intents, WidgetKit ücretsiz gelir
- ✅ En küçük ikili ve bellek ayak izi
- ⚠️ Çapraz platform imkânsız — kabul edilen kısıt
- ⚠️ Katkıcı Swift bilmeli

## Zorlama

- `make gate-layers` → `.xcodeproj` commit edilmişse kırmızı (T5)
- `.gitignore` → `*.xcodeproj/` hariç tutulur
- CI derlemesi Swift 6 strict concurrency ile; uyarılar hata sayılır
