# Geliştirme Ortamı

> Son güncelleme: 2026-07-31 — P0.22
> Kaynak: blueprint §16.1, §17.3 · Karar: [ADR 0001](../architecture/adr/0001-native-swift.md)

## Gereksinimler

| Araç | Sürüm | Not |
|---|---|---|
| macOS | 14.0+ | Geliştirme makinesi |
| Xcode | 26.0+ | Swift 6.2 için |
| XcodeGen | güncel | `.xcodeproj` üretimi |
| SwiftLint | güncel | Kural denetimi |
| swift-format | güncel | Biçimlendirme |

```bash
brew bundle
```

## Kurulum

```bash
make bootstrap
make generate
```

`make bootstrap` idempotenttir, **volume silmez** ve şunları doğrular: araç sürümleri (beklenenle karşılaştırır) · tüm kapıların çalıştığını. Çıktısı ✓/!/✗ ile okunur.

> **Önemli:** Araçları *var mı* diye değil, **çalışıyor mu** diye kontrol eder. Bozuk bir global kurulum sessizce durabilir.

## Komutlar

| Komut | Ne yapar |
|---|---|
| `make help` | Tüm hedefleri listeler |
| `make check` | **Tüm kapıları çalıştırır** |
| `make gate-names` | Üçüncü taraf ürün adı / karşılaştırmalı pazarlama |
| `make blueprint-check` | Dondurulmuş kaynak bütünlüğü |
| `make docs-check` | Kırık link, matris, ADR senkronu |
| `make gate-layers` | `Core` saflığı, Mock kapsamı |
| `make gate-deps` | Sıfır bağımlılık, lisans uyumu |
| `make gate-privacy` | Telemetri ve ağ izi |
| `make gate-i18n` | Sabit yazılmış kullanıcı metni |
| `make gate-daemon` | Ayrıcalıklı yüzey sınırları |
| `make generate` | `project.yml`'den Xcode projesi üretir |
| `make build` / `make test` / `make lint` | P1–P2'de etkinleşir |
| `make clean` | Derleme çıktılarını temizler |

## Kodlama standartları

- `swift-format` + `SwiftLint` — ikisi de CI'da **bloklayıcı**
- Genel API'ler için dokümantasyon yorumu zorunlu
- `Core` içinde zorla açma (`!`) yasak
- Sihirli sayı yasak — adlandırılmış sabit veya yapılandırma alanı
- **Kod, yorum ve commit mesajları İngilizce.** Proje yönetim dokümanları Türkçe
- Türkçe karakter kod tanımlayıcılarında kullanılmaz

## Commit disiplini

Conventional Commits: `feat:` `fix:` `docs:` `refactor:` `test:` `chore:`

Bir commit bir işi kapatır. Karışık commit yasak.

**Yasak git işlemleri:** paylaşılan dala `push --force` · yayınlanmış commit'e `rebase` · commit edilmemiş iş varken `reset --hard` · geçmiş yeniden yazma.

## Bash uyumluluğu — dikkat

macOS `/bin/bash` sürümü **3.2.57**'dir. Kapı script'lerinde bash 4+ özellikleri **kullanılamaz**: `mapfile`/`readarray`, `${x,,}`, `${x^^}`, ilişkisel diziler.

Ortak yardımcılar `scripts/gates/_lib.sh` içindedir ve `require_tools` ile eksik komutta **sessiz geçişi imkânsız** kılar.
