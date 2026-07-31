# SECURITY.md — Güvenlik Modeli ve Açık Bildirimi

> Son güncelleme: 2026-07-31 — P0.32
> Kaynak: blueprint §14

## Güvenlik açığı bildirimi

Bir güvenlik açığı bulduysanız **lütfen herkese açık issue açmayın.**

- **İletişim:** `mahirozdin@bubiapps.com`
- **Hedef ilk yanıt:** 72 saat
- **Kapsam:** uygulama, ayrıcalıklı daemon, XPC arayüzü, yapılandırma işleme, kurulum/kaldırma akışı
- **Kapsam dışı:** macOS'un kendi açıkları, üçüncü taraf araçlar, sosyal mühendislik

Sorumlu açıklama tercih edilir. Düzeltme yayınlandıktan sonra, isterseniz `NOTICE` dosyasında adınıza yer verilir.

## Uygulama sertleştirme

| Önlem | Durum |
|---|---|
| Hardened Runtime | Zorunlu |
| Kütüphane doğrulaması | Açık |
| Apple notarizasyonu | Her sürümde zorunlu |
| Code signing (Developer ID) | Zorunlu |
| XPC istemci/sunucu imza doğrulaması | **Çift yönlü**, zorunlu |
| Yazılabilir bellekte kod çalıştırma | Devre dışı |
| Ağ istemcisi yetkisi | Yalnızca güncelleme ve otomasyon modüllerinde |

## Ayrıcalıklı yüzey

Daemon root olarak çalışır. Yüzeyi kasıtlı olarak minimaldir:

```
describeFans()             // salt okunur
applyTargets([FanTarget])  // sınırlar dahilinde
releaseToFirmware()
heartbeat(nonce:)
```

Daemon:
- Dosya yolu, komut, betik veya rastgele veri **kabul etmez**
- Yapılandırma **okumaz** — root tarafında ayrıştırılacak kullanıcı verisi yoktur
- Ağ erişimi **yoktur**
- Alt süreç **başlatmaz**
- Gelen her komut fizikî sınırlara karşı doğrulanır; aralık dışıysa reddedilir ve loglanır

Bunların hepsi `make gate-daemon` ile zorlanır. Ayrıntı: [ADR 0007](docs/architecture/adr/0007-privilege-split.md), [ADR 0008](docs/architecture/adr/0008-smappservice-xpc.md)

## Güvenlik zinciri

Fan komutları donanıma ulaşmadan beş katmandan geçer (K1–K5). **Hiçbir katman fan hızını düşüremez, yalnızca yükseltebilir.** K2 ve K3 kapatılamaz.

Ölü adam anahtarı: uygulama yanıt vermeyi kestiğinde daemon fanları koşulsuz firmware'e iade eder. → [ADR 0009](docs/architecture/adr/0009-watchdog-dead-man-switch.md)

Ayrıntı: `ARCHITECTURE.md` §7, `docs/product/control-model.md`

## Gizlilik taahhüdü

- Hiçbir kullanım verisi toplanmaz veya iletilmez
- Analitik SDK'sı, çökme raporlama SDK'sı, reklam kimliği **yoktur**
- **Varsayılan durumda uygulama hiçbir ağ bağlantısı kurmaz**
- Güncelleme kontrolü açıksa yalnızca sürüm bilgisi indirilir
- Tüm veriler kullanıcının makinesinde, kullanıcının erişebildiği dosyalarda kalır

Bu iddialar `make gate-privacy` ile **kod düzeyinde doğrulanabilir**. → [ADR 0014](docs/architecture/adr/0014-zero-telemetry.md)

## Kaldırma

Uygulamayı kaldırmak sistemi kurulumdan önceki haline döndürür. Kalıcı firmware veya NVRAM değişikliği yapılmaz. Fan ayarları anında macOS varsayılanlarına döner.
