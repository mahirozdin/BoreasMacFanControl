# İzlenebilirlik Matrisi — Blueprint → Doküman

<!-- gate-names:policy-doc — Bu dosya yasaklı kalıpları TARİF ettiği için gate-names taramasından muaftır. Bkz. LEGAL.md §5.1 -->

> Son güncelleme: 2026-07-31 — P0.10
> Kaynak: `docs/blueprint/boreas-blueprint-v1.1.md` (dondurulmuş)

Blueprint'in **her bölümü** bir hedef dokümana eşlenir. Kayıp bölüm kabul edilemez.

**Tam mı sütunu:** `✅ tam` (içerik eksiksiz taşındı) · `➕ genişletildi` (taşındı ve üzerine eklendi) · `🔗 özet+link` (özet taşındı, ayrıntı başka dosyada)

| § | Blueprint bölümü | Hedef doküman(lar) | Tam mı |
|---|---|---|---|
| 0 | Bu Belge Hakkında | `docs/blueprint/README.md`, `AGENTS.md` | ✅ tam |
| 1 | Ürün Tanımı | `docs/product/overview.md` | ➕ genişletildi |
| 2 | Hukuki ve Etik Çerçeve | `LEGAL.md`, `docs/architecture/adr/0006-independent-development-policy.md`, `docs/architecture/adr/0005-apache-2-license.md` | ➕ genişletildi |
| 3 | Teknoloji Seçimi | `docs/architecture/adr/0001-native-swift.md`, `docs/architecture/adr/0003-minimum-macos-14.md`, `docs/architecture/adr/0004-apple-silicon-only.md`, `docs/development/setup.md` | ➕ genişletildi |
| 4 | Sistem Mimarisi | `docs/architecture/system.md`, `ARCHITECTURE.md` | ➕ genişletildi |
| 5 | Donanım Erişim Katmanı | `docs/architecture/hardware-access.md`, `docs/architecture/adr/0011-hardware-abstraction.md`, `docs/architecture/adr/0018-undocumented-sensor-api.md` | ➕ genişletildi |
| 6 | Ayrıcalık Modeli ve İzinler | `docs/architecture/privilege-model.md`, `docs/architecture/adr/0007-privilege-split.md`, `docs/architecture/adr/0008-smappservice-xpc.md`, `docs/architecture/adr/0009-watchdog-dead-man-switch.md` | ➕ genişletildi |
| 7 | Kontrol Motoru | `docs/product/control-model.md`, `docs/architecture/adr/0010-continuous-curve-model.md` | ➕ genişletildi |
| 8 | Özellik Kapsamı | `docs/product/scope.md`, `TODO.md` | ➕ genişletildi |
| 9 | Kullanıcı Arayüzü | `docs/product/ui.md`, `docs/development/localization.md`, `docs/architecture/adr/0016-language-scope.md` | ➕ genişletildi |
| 10 | Yapılandırma | `docs/architecture/configuration.md`, `docs/architecture/adr/0013-json-config-zero-deps.md` | ➕ genişletildi |
| 11 | Gözlemlenebilirlik | `docs/operations/observability.md` | ✅ tam |
| 12 | Bildirimler ve Otomasyon | `docs/operations/notifications.md`, `docs/architecture/adr/0015-automation-hooks-not-email.md` | ➕ genişletildi |
| 13 | Tanılama | `docs/operations/diagnostics.md` | ✅ tam |
| 14 | Güvenlik ve Gizlilik | `SECURITY.md`, `docs/architecture/adr/0014-zero-telemetry.md` | ➕ genişletildi |
| 15 | Test Stratejisi | `docs/development/testing.md` | ➕ genişletildi |
| 16 | Derleme, İmzalama ve Dağıtım | `docs/release/build-and-sign.md`, `docs/architecture/adr/0017-distribution-channels.md` | ➕ genişletildi |
| 17 | Depo Yapısı | `docs/development/repo-structure.md`, `docs/architecture/adr/0012-core-layer-purity.md` | ➕ genişletildi |
| 18 | README Spesifikasyonu | `docs/release/readme-spec.md`, `docs/release/discoverability.md` | ➕ genişletildi |
| 19 | Diğer Depo Dosyaları | `docs/development/repo-structure.md`, `TODO.md` | 🔗 özet+link |
| 20 | Yol Haritası | `TODO.md` | ➕ genişletildi |
| 21 | Riskler ve Azaltımlar | `docs/reference/risks.md` | ➕ genişletildi |
| 22 | Sözlük | `docs/reference/glossary.md` | ✅ tam |
| 23 | Karar Kaydı | `docs/reference/decisions.md`, `docs/architecture/adr/README.md` | ➕ genişletildi |
| 24 | Uygulamaya Geçirme | `TODO.md`, `BOOT.md` | ➕ genişletildi |

## Kapsama özeti

| Ölçüt | Değer |
|---|---|
| Blueprint bölüm sayısı | 25 |
| Eşlenen bölüm | 25 |
| **Kayıp bölüm** | **0** |
| Üretilen ADR | 18 |

## Ters yön: doküman → blueprint

Bir dokümanın hangi blueprint bölümünden geldiği, o dosyanın başındaki `> Kaynak: blueprint §X` satırında yazar.

## Bu matris nasıl korunur

`make docs-check` şunları doğrular:
- Matriste geçen her hedef dosya **gerçekten var**
- Eşlenmemiş satır yok (kayıp = 0)

Blueprint'ten sapıldığında (yeni ADR ile) bu matris de güncellenir — bkz. `AGENTS.md` §7.
