# 0009 — Ölü adam anahtarı (watchdog)

- **Durum:** Kabul
- **Tarih:** 2026-07-31
- **Kaynak:** blueprint §6.4, §7.6

## Bağlam

Fan kontrolünü devralan bir yazılım, kendi başarısızlığında donanımı savunmasız bırakmamalı. Uygulama çökebilir, `kill -9` ile öldürülebilir, donabilir, kullanıcı oturumu kapanabilir. Bu senaryoların **hepsinde** fanlar firmware kontrolüne dönmeli.

Kritik gözlem: kontrolü elinde tutan taraf (daemon), kendi sağlığını değil **karşı tarafın** sağlığını denetlemeli. Uygulamanın "ben ölüyorum" mesajı gönderebileceğini varsaymak, tam da çöktüğü senaryoda işe yaramaz.

## Karar

- Uygulama daemon'a düzenli **kalp atışı** gönderir (varsayılan 5 sn)
- Daemon ardışık **3 kalp atışını** kaçırırsa (≈15 sn) fanları koşulsuz firmware'e iade eder
- Daemon ayrıca şunlarda **anında** devreder: sistem uykusu, sistem kapanışı, daemon durdurulması
- Zaman aşımı **10–60 sn aralığında kilitlidir**, devre dışı bırakılamaz

## Alternatifler

| Aday | Neden reddedildi |
|---|---|
| Uygulamanın çıkışta temizlik yapması | `kill -9`, çökme ve donma senaryolarını kapsamaz |
| `atexit` / sinyal işleyici | `SIGKILL` yakalanamaz |
| Watchdog'u kullanıcıya kapatılabilir yapmak | Güvenlik özelliği isteğe bağlı olamaz |

## Sonuçlar

- ✅ Tüm başarısızlık modları tek mekanizmayla kapanır
- ✅ Kullanıcı yanlış yapılandırmayla donanımı riske atamaz
- ⚠️ En kötü durumda ~15 sn boyunca fanlar son ayarda kalır — kabul edilen pencere
- ⚠️ Kalp atışı trafiği sürekli; maliyeti ölçülmeli (hedef: ihmal edilebilir)

## Zorlama

Invariant testleri (silinemez):

```
test("watchdog zaman aşımı 10-60 sn dışına ayarlanamaz")
test("kalp atışı kesildiğinde daemon firmware'e devreder")
test("releaseToFirmware idempotenttir")
```

Donanım duman testi: `kill -9` sonrası fanların ≤ watchdog süresi içinde firmware'e döndüğü ölçülür (`scripts/smoke-test-hardware.sh`).
