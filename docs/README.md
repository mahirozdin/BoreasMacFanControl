# Doküman Haritası

> Son güncelleme: 2026-07-31 — P0.09

*"Şu soruyu soruyorsam nereye bakmalıyım?"*

## Bağlayıcı dosyalar (depo kökü)

| Dosya | Ne için okunur |
|---|---|
| [`AGENTS.md`](../AGENTS.md) | Değişmezler, çalışma disiplini, Definition of Done |
| [`BOOT.md`](../BOOT.md) | Oturum başlangıç protokolü ve sağlık snapshot'ı |
| [`TODO.md`](../TODO.md) | Sıradaki iş, kabul kriteri, Run Log |
| [`ARCHITECTURE.md`](../ARCHITECTURE.md) | MUST/MUST NOT invariantları, ADR indeksi |
| [`LEGAL.md`](../LEGAL.md) | Bağımsız geliştirme sınırları — **her oturumda** |
| [`SECURITY.md`](../SECURITY.md) | Güvenlik modeli ve açık bildirimi |

## `docs/` ağacı

### `product/` — Bu ne, kime, nasıl davranır?

| Dosya | Cevapladığı soru |
|---|---|
| [`overview.md`](product/overview.md) | Ürün ne, kime, hangi ilkelerle? |
| [`control-model.md`](product/control-model.md) | **Çekirdek soyutlama** — fan davranışı nasıl tanımlanır? |
| [`scope.md`](product/scope.md) | Hangi özellik hangi sürümde? Ne yapılmayacak? |
| [`ui.md`](product/ui.md) | Ekranlar, tasarım dili, erişilebilirlik |

### `architecture/` — Nasıl kurulu, hangi kararlarla?

| Dosya | Cevapladığı soru |
|---|---|
| [`system.md`](architecture/system.md) | Bileşenler, güven sınırları, eşzamanlılık |
| [`hardware-access.md`](architecture/hardware-access.md) | Sensör ve fan verisine nasıl erişilir? |
| [`privilege-model.md`](architecture/privilege-model.md) | Hangi izin, neden, ne zaman? |
| [`configuration.md`](architecture/configuration.md) | Yapılandırma şeması ve doğrulama |
| [`adr/`](architecture/adr/README.md) | Bu karar neden böyle verildi? |

### `development/` — Bu depoda nasıl çalışılır?

| Dosya | Cevapladığı soru |
|---|---|
| [`setup.md`](development/setup.md) | Ortamı nasıl kurarım, hangi komutlar var? |
| [`repo-structure.md`](development/repo-structure.md) | Hangi kod nereye yazılır? |
| [`testing.md`](development/testing.md) | Nasıl test edilir, hangi kanıt gerekir? |
| [`localization.md`](development/localization.md) | Metin nasıl yazılır, nasıl çevrilir? |

### `operations/` — Çalışırken ne olur?

| Dosya | Cevapladığı soru |
|---|---|
| [`observability.md`](operations/observability.md) | Log, ölçüm kaydı, metrik |
| [`notifications.md`](operations/notifications.md) | Bildirimler ve otomasyon kancaları |
| [`diagnostics.md`](operations/diagnostics.md) | Donanım sağlığı nasıl raporlanır? |

### `release/` — Ne zaman ve nasıl yayınlanır?

| Dosya | Cevapladığı soru |
|---|---|
| [`build-and-sign.md`](release/build-and-sign.md) | Derleme, imzalama, notarizasyon, dağıtım |
| [`readme-spec.md`](release/readme-spec.md) | Ürün README'sinde ne olmalı? |
| [`discoverability.md`](release/discoverability.md) | Kullanıcı bu projeyi nasıl bulacak? |

### `reference/` — Kesin değerler nerede?

| Dosya | Cevapladığı soru |
|---|---|
| [`blueprint-map.md`](reference/blueprint-map.md) | Blueprint'in şu bölümü nereye gitti? |
| [`decisions.md`](reference/decisions.md) | Hangi açılış kararları kesinleşti? |
| [`risks.md`](reference/risks.md) | Hangi riskler takip ediliyor? |
| [`glossary.md`](reference/glossary.md) | Bu terim ne demek? |

### `blueprint/` — Dondurulmuş kaynak

[`blueprint/README.md`](blueprint/README.md) — **asla düzenlenmez**, yalnızca tarihsel referans.

## Doküman kuralları

1. **Bir dosya = bir konu.** Aynı olgu iki yere yazılmaz; ikincisi birinciye link verir.
2. Her dosyanın başında `> Son güncelleme:` ve `> Kaynak: blueprint §X`.
3. **Kod kopyası tutulmaz** — kod yazıldıktan sonra doküman kaynağa işaret eder.
4. Değişiklik yaptığında `AGENTS.md` §7'deki protokole bak.
