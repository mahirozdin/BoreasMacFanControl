# Boreas

**Apple Silicon Mac'ler için açık kaynak termal izleme ve fan kontrolü.**

> ⚠️ **Geliştirme aşaması.** Bu dosya şu an projenin geliştirme giriş noktasıdır.
> Ürün README'si (İngilizce, son kullanıcıya yönelik) P8'de `docs/release/readme-spec.md` spesifikasyonuna göre yazılacaktır.

---

## Proje nedir

Boreas; Apple Silicon Mac'lerde dahili sıcaklık sensörlerini gerçek zamanlı izleyen, fan hızlarını kullanıcı tanımlı **sürekli eğrilerle** yöneten, sistem güvenliğinden ödün vermeden çalışan, ücretsiz ve açık kaynak bir menü çubuğu uygulamasıdır.

**Ayırt edici yanı:** hassas hiçbir izin istemez. SIP devre dışı bırakma yok, kernel extension yok, Recovery Mode adımı yok. Sıcaklık okumak zaten ayrıcalık gerektirmez; yalnızca fan yazımı için, yalnızca bir kez yönetici onayı istenir.

## Sabit kararlar

| Konu | Karar | ADR |
|---|---|---|
| Dil / çatı | Swift 6.2 + SwiftUI, tamamen native | [0001](docs/architecture/adr/0001-native-swift.md) |
| Ürün adı | Boreas · `com.bubiapps.boreas` | [0002](docs/architecture/adr/0002-product-name.md) |
| Minimum macOS | 14.0 Sonoma | [0003](docs/architecture/adr/0003-minimum-macos-14.md) |
| Mimari | arm64 (Apple Silicon) — Intel desteği yok | [0004](docs/architecture/adr/0004-apple-silicon-only.md) |
| Lisans | Apache-2.0 | [0005](docs/architecture/adr/0005-apache-2-license.md) |
| Bağımsız geliştirme | Yedi mutlak yasak, makine ile zorlanıyor | [0006](docs/architecture/adr/0006-independent-development-policy.md) |
| Ayrıcalık modeli | Ayrıcalıksız okuma / ayrıcalıklı yazma | [0007](docs/architecture/adr/0007-privilege-split.md) |
| Kontrol modeli | Sürekli eğri + çift eğri histerezis + asimetrik hız sınırı | [0010](docs/architecture/adr/0010-continuous-curve-model.md) |
| Telemetri | Sıfır | [0014](docs/architecture/adr/0014-zero-telemetry.md) |
| Diller | Arayüz 5 dil · dokümantasyon İngilizce | [0016](docs/architecture/adr/0016-language-scope.md) |

Tam liste: [`docs/architecture/adr/README.md`](docs/architecture/adr/README.md)

## Depo haritası

| Yol | İçerik |
|---|---|
| `Packages/Core/` | Kontrol motoru, modeller, yapılandırma — **yalnızca Foundation** |
| `Packages/HardwareKit/` | IOKit sarmalayıcıları, `Live`/`Mock`/`Replay` |
| `Packages/SharedIPC/` | XPC protokol tanımları |
| `App/` | SwiftUI arayüz |
| `Daemon/` | Ayrıcalıklı yardımcı |
| `CLI/` | `boreas` komut satırı aracı |
| `scripts/gates/` | Makine ile zorlanan kapılar |
| `docs/` | Tüm dokümantasyon |

Ayrıntı: [`docs/development/repo-structure.md`](docs/development/repo-structure.md)

## Nereden başlamalı

| Rolündeysen | Oku |
|---|---|
| Bu depoda çalışacaksan | [`BOOT.md`](BOOT.md) → [`AGENTS.md`](AGENTS.md) → [`TODO.md`](TODO.md) |
| Mimariyi anlamak istiyorsan | [`ARCHITECTURE.md`](ARCHITECTURE.md) → [`docs/architecture/system.md`](docs/architecture/system.md) |
| Ürünün ne olduğunu merak ediyorsan | [`docs/product/overview.md`](docs/product/overview.md) |
| Kontrol modelini öğrenmek istiyorsan | [`docs/product/control-model.md`](docs/product/control-model.md) |
| Hukuki sınırları bilmen gerekiyorsa | [`LEGAL.md`](LEGAL.md) |
| Güvenlik modelini inceleyeceksen | [`SECURITY.md`](SECURITY.md) |
| Tam doküman haritası | [`docs/README.md`](docs/README.md) |

## Komutlar

```bash
make help          # tüm hedefleri listeler
make check         # tüm kapıları çalıştırır
make bootstrap     # yerel ortamı kurar ve doğrular
make generate      # project.yml'den Xcode projesini üretir
```

Kapı listesi ve kurulum ayrıntısı: [`docs/development/setup.md`](docs/development/setup.md)

## Çalışma disiplini

Bu depo **makine ile zorlanan** bir çalışma sistemi kullanır:

- **Blueprint dondurulmuştur** ([`docs/blueprint/`](docs/blueprint/README.md)) — sapmalar ADR ile kaydedilir
- **Her değişmezin bir kapısı vardır** — zorlanmayan kural bir dilektir
- **Kanıtsız checkbox yoktur** — doğrulama çalıştırılamadıysa Run Log'a `NOT RUN` + neden yazılır
- **Her kapı kasıtlı ihlalle kanıtlanmıştır** — çalıştığı gösterilmemiş kapı, kapı değildir

## Durum

Faz durumu ve sıradaki iş: [`TODO.md`](TODO.md) durum özeti.

## Lisans

Apache-2.0 (P1'de eklenecek). Proje Apple Inc. ile ilişkili değildir, onaylanmamıştır.
