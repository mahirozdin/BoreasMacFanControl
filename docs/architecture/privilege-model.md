# Ayrıcalık Modeli ve İzinler

> Son güncelleme: 2026-07-31 — P0.20
> Kaynak: blueprint §6 · Kararlar: [ADR 0007](adr/0007-privilege-split.md), [ADR 0008](adr/0008-smappservice-xpc.md), [ADR 0009](adr/0009-watchdog-dead-man-switch.md)

## İstenen izinlerin tam listesi

| İzin | Ne zaman | Sıklık | Zorunlu |
|---|---|---|---|
| Yönetici kimlik doğrulaması | Fan daemon'u ilk kurulurken | **Tek sefer** | Hayır — atlanırsa izleme modu |
| Arka planda çalışma onayı | Daemon kaydı sırasında | Tek sefer | Fan kontrolü için evet |
| Bildirim izni | Kullanıcı bildirimleri açtığında | Tek sefer | Hayır |
| Girişte başlatma | Kullanıcı açarsa | Tek sefer | Hayır |

## İstenmeyen izinler — açık taahhüt

README'de ve uygulama içinde yayınlanır:

- ❌ SIP devre dışı bırakma
- ❌ Kernel extension / DriverKit sürücüsü
- ❌ Recovery Mode veya güvenlik politikası değişikliği
- ❌ Tam Disk Erişimi
- ❌ Erişilebilirlik izni
- ❌ Ekran kaydı izni
- ❌ Kamera / mikrofon / konum / kişiler / takvim
- ❌ NVRAM veya firmware değişikliği

## Kurulan dosyalar

Ayrıcalıklı yardımcı iki konuma yazılır. Kesin yollar P3'te (daemon fazı) belirlenip buraya yazılacaktır; bundle kimliği `com.bubiapps.boreas.fanhelper` olacaktır.

| Yol | Amaç |
|---|---|
| `/Library/PrivilegedHelperTools/<daemon-bundle-id>` | Ayrıcalıklı yardımcı ikilisi |
| `/Library/LaunchDaemons/<daemon-bundle-id>.plist` | launchd tanımı |
| `~/Library/Application Support/Boreas/` | Yapılandırma ve yerel veriler |

Tam kaldırma adımları README'de ve `boreas uninstall --all` komutunda bulunur.

## Daemon kurulumu

**`SMAppService.daemon(plistName:)`** kullanılır — eski `SMJobBless` akışı kullanılmaz.

**Akış:**
1. Kullanıcı arayüzden "Fan kontrolünü etkinleştir" der
2. **Ne olacağı, hangi dosyaların nereye yazılacağı ve nasıl geri alınacağı açıkça gösterilir**
3. Daemon kaydedilir; sistem yönetici kimlik doğrulaması ister
4. macOS Sistem Ayarları onayı isteyebilir — uygulama bu durumu algılar ve doğrudan ilgili panele yönlendirir
5. Bağlantı doğrulanır, sonuç bildirilir

**Kaldırma:** Arayüzde tek düğme + CLI'da `boreas uninstall --all` + README'de manuel adımlar.

## Ölü adam anahtarı

Tasarımın ayırt edici güvenlik unsuru → [ADR 0009](adr/0009-watchdog-dead-man-switch.md)

- Uygulama daemon'a düzenli **kalp atışı** gönderir (varsayılan 5 sn)
- Daemon ardışık **3 kalp atışı** kaçırırsa (≈15 sn) fanları koşulsuz firmware'e iade eder
- Kapsadığı senaryolar: çökme · `kill -9` · donma · oturum kapanması · XPC kopması
- Ayrıca **anında** devreder: sistem uykusu · sistem kapanışı · daemon durdurulması
- Zaman aşımı **10–60 sn arasında kilitli**, devre dışı bırakılamaz

**Tasarım gerekçesi:** Kullanıcı alanındaki bir uygulamanın hatası hiçbir koşulda donanımı savunmasız bırakmamalı. Kontrolü elinde tutan taraf sağlık denetiminden sorumlu olmalıdır.

## Daemon güvenlik yüzeyi

XPC arayüzü kasıtlı olarak minimaldir:

```
describeFans()          // salt okunur
applyTargets([FanTarget])  // sınırlar dahilinde
releaseToFirmware()
heartbeat(nonce:)
```

Daemon: dosya yolu/komut/betik **kabul etmez** · yapılandırma **okumaz** · ağ erişimi **yoktur** · alt süreç **başlatmaz**.

`make gate-daemon` bunların hepsini zorlar.
