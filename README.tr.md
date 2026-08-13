<div align="center">

<img src="Design/icon/render/boreas-256.png" width="128" alt="Boreas simgesi">

# Boreas

**Apple Silicon Mac'ler için fan kontrolü ve sıcaklık izleme**

Ücretsiz ve açık kaynak. Çekirdek uzantısı yok, SIP değişikliği yok, telemetri yok.

[![CI](https://github.com/mahirozdin/boreas-mac-fan-control/actions/workflows/ci.yml/badge.svg)](https://github.com/mahirozdin/boreas-mac-fan-control/actions/workflows/ci.yml)
[![Lisans](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-14.0%2B-lightgrey.svg)](#gereksinimler)
[![Mimari](https://img.shields.io/badge/arch-Apple%20Silicon-orange.svg)](#gereksinimler)
[![Swift](https://img.shields.io/badge/Swift-6.2-F05138.svg)](https://swift.org)

**Türkçe** · [English](README.md) · [Русский](README.ru.md) · [Español](README.es.md) · [简体中文](README.zh-Hans.md)

</div>

---

> **Bu bir çeviridir ve İngilizce sürümün gerisinde kalabilir.** Bağlayıcı metin
> her zaman [`README.md`](README.md)'dir; bir çelişki görürseniz İngilizce
> olanı doğru kabul edin.

> **Beta — 0.1.0.** İmzalı, noter onaylı ve kurulabilir. **Tek bir Mac'te**
> çalıştı: Mac mini (M4, 2024). Diğer tüm Apple Silicon modellerin çalışması
> bekleniyor ama hiçbiri denenmedi. Bunu test aşamasındaki bir yazılım gibi
> değerlendirin: ilk süre boyunca sıcaklıklara göz atın ve bir tuhaflık
> görürseniz Boreas'tan çıkın — çıkmak fanları anında firmware'e geri verir.
> Yalnızca izleme hiçbir ayrıcalık gerektirmez ve hiçbir şeyi değiştirmez;
> başlamanın güvenli yolu odur.

## Ne yapar

<div align="center">
<img src="docs/images/panel-light.png" width="330" alt="Açık temada menü çubuğu paneli: profil seçici, 2755 dev/dk'da bir fan ve işlemci, grafik, bellek, depolama ve güç olarak gruplanmış sıcaklıklar">
<img src="docs/images/panel-dark.png" width="330" alt="Aynı menü çubuğu paneli, koyu temada">
</div>

Boreas, Mac'inizin içinde neler olduğunu gösteren ve nasıl soğutulacağına sizin
karar vermenizi sağlayan bir menü çubuğu uygulamasıdır.

- **Mac'inizin sunduğu her sıcaklık sensörünü okuyun** — performans ve verimlilik
  çekirdekleri, GPU, bellek, depolama, güç dağıtımı, kasa
- **Fan hızlarını** gerçek en düşük ve en yüksek değerleriyle görün
- **Fan eğrisini kendiniz şekillendirin** — aç/kapa kurallarının listesi yerine
  sürekli bir eğriyle, böylece hız değişimleri basamaklı değil yumuşak olur
- **Profilleri otomatik değiştirin** — güç kaynağına, çalışan uygulamaya, saate
  ya da termal baskıya göre
- **Ölçümleri kaydedin** — JSONL veya CSV olarak, asla aşmayacağı bir disk
  tavanıyla
- **Bir şey değiştiğinde haberdar olun** — eşikler, termal baskı, hedefini
  tutturamayan bir fan — panik bildiriminin yine de geçebildiği gürültü
  denetimleriyle
- **Kendi araçlarınıza bağlayın** — kimsenin bakımını üstlenmek istemediği bir
  e-posta istemcisi yerine bir webhook ya da bir betik
- **Beş dilde okuyun** — İngilizce, Türkçe, Rusça, İspanyolca ve Basitleştirilmiş
  Çince
- **Sessiz kalın ya da serin kalın** — bu takas firmware'in değil, sizin

## Neden

Apple Silicon'da soğutma tamamen firmware denetiminde ve hiçbir ayar sunmuyor.
Bu, iki yönde birden sorun.

**Bazen fazla sessiz.** Uzun bir derleme, bir video dışa aktarımı ya da bir sanal
makine çalışırken firmware geç ve temkinli davranıyor. Yonga hız kısıyor ve daha
hızlı bitebilecek iş bitmiyor.

**Bazen fazla gürültülü.** Ses kaydederken, gece çalışırken, bir toplantıda
otururken — birkaç derece daha sıcak olmanın sessizlik için gayet iyi bir takas
olduğu anlar.

İkisi de aynı yerden geliyor: karar size kapalı. Boreas onu açıyor.

## Gereksinimler

| | |
|---|---|
| **Mac** | Apple Silicon — M1 veya yenisi. Intel, tasarım gereği kapsam dışı |
| **macOS** | 14.0 Sonoma veya yenisi |
| **Disk** | Birkaç megabayt |

### Sınanmış donanım

Boreas tek bir makinede geliştiriliyor, dolayısıyla kapsam konusunda dürüstlük
uzun bir uyumluluk tablosundan daha önemli.

| Donanım | Durum |
|---|---|
| Mac mini (M4, 2024) — `Mac16,10` | **Gerçek donanımda doğrulandı**: 40 adlandırılmış sensör, düzenlenmiş bir eğride 1000'den 4021 dev/dk'ya kadar ölçülen ve her hata yolunda geri verilen 1 fan |
| Diğer tüm Apple Silicon Mac'ler | **Çalışması bekleniyor; doğrulanmadı.** Henüz kimse birinde çalıştırmadı |


**Dizüstüler için bir not.** Buradaki bütün ölçümler bir masaüstü Mac'ten
geliyor. Bir MacBook'un termal payı daha az ve daha sert hız kısıyor; yani Mac
mini'de rahat olan bir eğri bir dizüstünde fazla sessiz kalabilir — pilde ise
firmware daha da temkinli. Tasarımda masaüstüne özgü hiçbir şey yok; sadece
orada sınanmadı ve bir MacBook sensör raporu en az diğerleri kadar değerli olur.

**"Doğrulanmadı" pratikte ne demek.** Sensör adlandırması yonga kuşakları
arasında değişiyor ve çok fanlı modeller, ikinci bir fanla hiç karşılaşmamış
dengeleme kodunu çalıştırıyor. Buradaki hiçbir şey kuramsal değil — eşleme,
donanım anahtarları üzerinde bir sezgisel yöntem ve sizinki Boreas'ın tanımadığı
sensörler üretebilir.

Mac'iniz sensörleri `uncategorized` olarak gösteriyorsa bu değerli bir bilgidir —
**Ayarlar → Sensörler → Bu Sensörleri Bildir**, tarayıcınızda önceden doldurulmuş
bir [bilinmeyen sensör raporu](https://github.com/mahirozdin/boreas-mac-fan-control/issues/new?template=unknown_sensor.yml)
açar; içinde Mac'inizin model kimliği, yongası, tanınmayan sensör adları ve fan
sayısı bulunur, başka hiçbir şey yoktur. Eşlenmemiş sensörler tam da
bildirilebilsinler diye gizlenmez, gösterilir.

## Kurulum

**Beta.** İmzalı ve noter onaylı, dolayısıyla Gatekeeper uyarısı olmadan kurulur.

```bash
brew tap mahirozdin/boreas
brew trust mahirozdin/boreas   # Homebrew, üçüncü taraf bir tap'i çalıştırmadan önce onay ister
brew install --cask boreas
```

Ya da imzalı `.dmg` dosyasını
[son sürümden](https://github.com/mahirozdin/boreas-mac-fan-control/releases/latest)
indirip yanındaki `.sha256` ile doğrulayın:

```bash
shasum -a 256 -c Boreas-0.1.0.dmg.sha256
```

Kaynaktan derlemek de çalışır ve bir şeyi değiştirmek istiyorsanız tek yol odur:

```bash
git clone https://github.com/mahirozdin/boreas-mac-fan-control.git
cd boreas-mac-fan-control
brew bundle          # xcodegen, swiftlint, xcbeautify
make generate        # Xcode projesini project.yml'den üretir
```

Sonra `Boreas.xcodeproj`'i açıp çalıştırın. **İzleme imzasız çalışır.** Fan
kontrolü ayrıcalıklı yardımcıyı gerektirir ve macOS yalnızca Developer ID ile
imzalanmış bir yardımcıyı kaydeder — yani `Local.xcconfig` içinde kendi imzalama
kimliğiniz gerekir (`Local.xcconfig.example` dosyasını kopyalayıp takım
kimliğinizi girin). O olmadan Boreas hiçbir şey istemeyen eksiksiz bir izleyicidir.

## Hızlı başlangıç

1. **Boreas'ı açın.** Menü çubuğunda belirir ve hemen sensörleri okumaya başlar —
   izin yok, kurulum yok, yapılandıracak bir şey yok.
2. **Panelden bir profil seçin**: Sessiz, Dengeli, Performans ya da her şeyi
   firmware'e geri vermek için Sistem.
3. **Fan kontrolünü etkinleştirin** — eğrinin fanları gerçekten sürmesini
   istediğinizde. Yönetici parolanızı isteyen tek adım budur, bir kez.

1. ve 2. adımlar tek başlarına da işe yarar. 3. adım isteğe bağlı ve geri
alınabilir.

## İzinler

Fanlarınıza dokunan bir şeyi kurmadan önce okunmaya değer bölüm burası.

**Boreas neyi ister**

| İzin | Ne zaman | Ne sıklıkta |
|---|---|---|
| Yönetici parolası | Yalnızca fan kontrolünü etkinleştirirken | **Bir kez** |
| Arka plan izni | Fan yardımcısı kaydedilirken | Bir kez, Sistem Ayarları'nda |
| Bildirimler | Yalnızca uyarıları açarsanız | Bir kez |

**Boreas neyi asla istemez**

- ❌ System Integrity Protection'ı devre dışı bırakmak
- ❌ Çekirdek uzantısı ya da DriverKit sürücüsü
- ❌ Recovery'ye açılmak ya da güvenlik ilkesini değiştirmek
- ❌ Tam Disk Erişimi
- ❌ Erişilebilirlik ya da Ekran Kaydı
- ❌ Kamera, mikrofon, konum, kişiler ya da takvim

**Sıcaklıkları okumak hiçbir ayrıcalık gerektirmez.** Fan kontrolünü hiç
etkinleştirmezseniz Boreas, hiçbir şey istemeyen eksiksiz bir izleme aracıdır.

Uygulamayı kaldırmak her şeyi eski hâline döndürür. Firmware'e ya da NVRAM'e
dokunulmaz ve Boreas durduğu anda fan ayarları macOS varsayılanlarına döner.

## Nasıl çalışır

```
Oturumunuz (ayrıcalıksız)            Root                     Donanım
┌──────────────────────┐   XPC     ┌────────────────┐  IOKit ┌──────────────┐
│ Boreas.app           │◀────────▶ │ Fan yardımcısı │◀─────▶ │ SMC          │
│  kontrol motoru      │ iki yönlü │  güvenlik filt.│        │ HID sensörler│
│  sensör okuma  ──────┼───────────┼────────────────┼──────▶ │ güç kaynağı  │
│  yapılandırma        │  imza     │  watchdog      │        └──────────────┘
└──────────────────────┘  doğrular └────────────────┘
```

Sıcaklıkları okumak hiçbir ayrıcalık gerektirmediği için doğrudan donanıma gider.
Yalnızca fan hızlarını yazmak yardımcıyı gerektirir ve yardımcının tüm yüzeyi
dört metottur: fanları tarif et, hedefleri uygula, geri ver ve bir kalp atışı.

Hiçbir yapılandırma okumaz, hiçbir ağ bağlantısı açmaz ve hiçbir süreç başlatmaz.

## Eğri editörü

<div align="center">
<img src="docs/images/curve-editor.png" width="820" alt="Kontrol sekmesi: 0–120 derece arası çizilmiş, beş sürüklenebilir noktalı bir fan eğrisi, sayısal nokta tablosu, histerezis ve hız sınırı kaydırıcıları, kurulu beş güvenlik katmanı ve süreli bir manuel devralma">
</div>

Eğri süreklidir, eşiklerden oluşan bir merdiven değil. Bir noktayı sürükleyin,
eklemek için çift tıklayın, kaldırmak için sağ tıklayın. Şekil geçersiz hâle
getirilemez — düzenlemeler reddedilmek yerine kırpılır, dolayısıyla hiçbir
sürükleme dizisi ısındıkça düşen bir eğri üretemez. Her düzenleme fanlara bir
döngü içinde ulaşır.

## Güvenlik

Bunu yanlış yapan bir fan kontrol yazılımı donanıma zarar verir; bu yüzden
tasarım, beş yerde güvenliği kullanıcı tercihinin önüne koyar.

| Katman | Kural | Kapatılabilir mi? |
|---|---|---|
| Fan tabanı | Donanım minimumunun altına asla inilmez | Hayır |
| Termal durum | macOS `serious` bildirirse yükselt; `critical` ise tam hız | Hayır |
| Panik eşiği | Herhangi bir sensör sınırı geçerse → tam hız, tutulur | Hayır, yalnızca düşürülür |
| Yardımcı koruması | Aralık dışı komutlar kırpılmaz, reddedilir | Hayır |
| **Watchdog** | Kalp atışı yoksa → fanlar firmware'e geri verilir | Hayır |

En önemlisi watchdog. Boreas çökerse, kilitlenirse, zorla kapatılırsa ya da
oturumu kapatırsanız, yardımcı sessizliği fark eder ve denetimi kendiliğinden
firmware'e döndürür. Uygulamanın kendi ardını toplamasına güvenmez, çünkü önemli
olan durumlar tam da bunu yapamadığı durumlardır.

Her katman yalnızca fan hızını yükseltebilir. Hiçbiri düşüremez.

**Boreas'ın yapamadıkları:** firmware'in fanları çoktan durdurduğu bir Mac'i
soğutamaz ve donanımın bildirdiği en yüksek hızı aşamaz. Firmware bir komutu
reddediyorsa yardımcı da yeniden denemek yerine reddeder.

## Gizlilik

- **Telemetri yok.** Analitik SDK'sı yok, çökme raporlama SDK'sı yok, reklam
  kimliği yok
- **Varsayılan olarak ağ yok.** Kutudan çıktığı hâliyle Boreas hiçbir bağlantı
  kurmaz. Bağlantı açabilecek tek kod tek bir dizinde yaşar ve yalnızca kendiniz
  bir webhook yapılandırırsanız çalışır
- **Verileriniz sizin kalır** — okuyabileceğiniz dosyalarda, kendi makinenizde

Bunlar niyet beyanı değil. Bir analitik sembolü ya da beklenmedik bir ağ çağrısı
belirirse **derlemeyi düşüren bir kapı**
([check-privacy.sh](scripts/gates/check-privacy.sh)) tarafından her commit'te
denetleniyorlar.

## Yapılandırma

Her şey okuyabileceğiniz, düzenleyebileceğiniz ve sürüm denetimine
alabileceğiniz tek bir dosyada:

```
~/Library/Application Support/Boreas/config.json
```

```json
{
  "schemaVersion": 1,
  "general": { "samplingIntervalSeconds": 2 },
  "safety": { "panicTemperatureCelsius": 95, "watchdogTimeoutSeconds": 15 },
  "profiles": [
    {
      "name": "Quiet",
      "priority": 0,
      "binding": {
        "input": { "group": "compute", "aggregate": "max" },
        "curve": [
          { "celsius": 40, "duty": 0    },
          { "celsius": 58, "duty": 0.15 },
          { "celsius": 72, "duty": 0.4  },
          { "celsius": 82, "duty": 0.7  },
          { "celsius": 88, "duty": 1    }
        ]
      },
      "hysteresis": 5,
      "smoothing": 0.2,
      "slew": { "maxRisePerSecond": 300, "maxFallPerSecond": 100 }
    }
  ]
}
```

Bu parça elle yazılmadı, gerçek bir `boreas export` çıktısından kopyalandı —
yüklenmeyen bir örnek, hiç örnek olmamasından kötüdür.

Bozuk bir dosya yalnızca geri düşebilir: Boreas son geçerli durumla çalışmaya
devam eder ve anlamadığı bir belgeye göre davranmak yerine fanları firmware'de
bırakır. `config.backup.json` her yazmadan **önce** tazelenir. Aralık dışı
değerler reddedilmez, kırpılır.

Tam şema: [`schema/config.schema.json`](schema/config.schema.json) ·
Başvuru: [`docs/architecture/configuration.md`](docs/architecture/configuration.md)

## Komut satırı

`boreas`, pencere sunucusu olmayan bir makinede menü çubuğunun yaptığı her şeyi
yapar:

```
boreas status            sıcaklıklar, fanlar ve güç, bir bakışta
boreas sensors [--raw]   her sensör, gruplu; --raw donanım adlarını gösterir
boreas profile [ad]      profilleri listeler ya da birini şimdi etkinleştirir
boreas profile --auto    kararı profil tetikleyicilerine geri verir
boreas install           fan kontrol yardımcısını kurar
boreas uninstall [--all] yardımcıyı kaldırır; --all kayıtlı ayarları da siler
boreas export [dosya]    yapılandırmayı yazar; dosya verilmezse stdout'a
boreas import <dosya>    yapılandırmayı doğruladıktan sonra değiştirir
```

```console
$ boreas status
power    : adapter
sensors  : 40  hottest PMU Die 1 75.1 C
fan 0    : Fan 1 1000 rpm (1000-4900, 0%)
control  : etkin
```

Komut satırından seçilen bir profil **yalnızca canlıdır ve diske asla yazılmaz** —
saklanan bir seçim her profil tetikleyicisini kalıcı olarak geçersiz kılardı.

## Sorun giderme

Arıza gibi görünen şeylerin bir kısmı aslında bir güvenlik güvencesinin işini
yapmasıdır; bu yüzden kısa sürümü elinizin altında bulunsun:

| Gördüğünüz | En olası sebep |
|---|---|
| Fan hızları hiç değişmiyor | Fan kontrolü etkin değil — okumak ayrıcalık gerektirmez, yazmak yardımcıyı gerektirir. O olmadan Boreas bir izleyicidir ve tasarım gereği **hata göstermez** |
| Yardımcı "onay bekliyor"da takılı | İkinci adım macOS'un: Sistem Ayarları → Genel → Giriş Öğeleri ve Uzantılar |
| Profil kendiliğinden hiç değişmiyor | Manuel bir seçim her tetikleyiciden üstündür ve süre vermediyseniz sona ermez. `boreas profile --auto` kararı geri verir |
| Hızlar kendiliğinden eski hâline dönüyor | Watchdog. Çıkışta, çökmede, uykuda ya da oturum kapatmada fanlar koşulsuz olarak firmware'e döner — bu bir hata değil, özelliğin kendisi |
| Fanlar tam hızda takılı | Panik eşiği ya da macOS termal durumu. İkisi de kendiliğinden bırakır; ikisi de kapatılamaz |
| Sensörler sınıflandırılmamış görünüyor | Sensör anahtarları opak kodlardır ve eşlenmemiş olanlar bildirilebilsinler diye gizlenmez, gösterilir |
| Bildirim gelmiyor | Uyarıları açana kadar hiçbir şey istenmez ve bir ret, anahtarı geri kapatır |
| Bir ayar kalıcı olmadı | CLI'dan seçilen profil bilerek yalnızca canlıdır. Bozuk bir yapılandırma dosyası son geçerli duruma geri düşer |

Ayrıntının tamamı ve bir konu açmadan önce toplanacaklar:
[`docs/operations/troubleshooting.md`](docs/operations/troubleshooting.md).

## Kaldırma

```bash
boreas uninstall --all
```

Bu, ayrıcalıklı yardımcıyı kaldırır ve
`~/Library/Application Support/Boreas` dizinini siler. Ardından uygulamayı Çöp'e
sürükleyin.

`--all` olmadan yardımcı kaldırılır, ayarlarınız korunur. Her iki durumda da:

- **Fanlar hemen firmware'e döner** — yardımcı dururken devri teslim eder,
  watchdog zaten yapardı
- Hiçbir firmware ayarına, NVRAM değişkenine ya da sistem dosyasına dokunulmaz,
  çünkü hiçbiri hiç yazılmadı
- `LaunchDaemons` içinde hiçbir şey kalmaz ve `launchctl` artık servisi tanımaz

Bu, varsayılmadı; beş açıdan doğrulandı — `SMAppService` durumu, `launchctl`,
sistem klasörleri, silinen destek dizini ve olmayan süreç. **Otomatik olarak
yeniden denetlenmiyor:** `install` ve `uninstall` yardımcının kaydını değiştirip
parola sorar, bu yüzden komut satırı test paketi bu ikisi dışındaki her şeyi
bilerek çalıştırır.

## Yol haritası

| Faz | Durum |
|---|---|
| Doküman sistemi ve kapılar | ✅ Bitti |
| Araç zinciri ve proje iskeleti | ✅ Bitti |
| Sensör ve fan okuma | ✅ Bitti |
| Ayrıcalıklı yardımcı ve XPC | ✅ Bitti |
| Fan kontrolü ve güvenlik zinciri | ✅ Bitti |
| Kontrol motoru — eğriler, histerezis, profiller | ✅ Bitti |
| Kullanıcı arayüzü ve eğri editörü | ✅ Bitti (bir VoiceOver geçişi kaldı) |
| Bildirimler, log, tanılama, CLI, otomasyon | ✅ Bitti |
| İmzalama, noter onayı, sürüm | ✅ Bitti — 0.1.0 imzalı, noter onaylı ve beta olarak yayında |

Sonrasında, ve bilinçli olarak 1.0'dan önce değil: bir WidgetKit widget'ı, App
Intents, yerel bir metrik uç noktası, yapılandırma paylaşımı ve uygulama içi
güncellemeler.

Güncel durum ve sıradaki iş: [`TODO.md`](TODO.md).

## İnsanların gerçekten sorduğu sorular

**Mac'im neden ısınıyor?**
Genellikle sürekli yük — derleme, video dışa aktarma, sanal makine çalıştırma.
Bir MacBook'ta sıcak bir oda ya da tıkalı bir havalandırma aynı yükü daha erken
hız kısmaya çevirir. Boreas yonganın hangi bölümünün sıcak olduğunu gösterir,
böylece meşgul bir CPU ile bir soğutma sorununu ayırt edebilirsiniz.

**Apple Silicon Mac'lerde fan hızı denetlenebilir mi?**
Evet, System Management Controller üzerinden, küçük bir ayrıcalıklı yardımcıyla.
Boreas yönetici parolasını bir kez ister ve bir daha hiç ihtiyaç duymaz.

**SIP'in kapatılması ya da çekirdek uzantısı gerekiyor mu?**
Hayır. İkisi de değil. Bu projenin bu biçimde var olmasının başlıca sebebi bu.

**Fan hızlarını düşürmek güvenli mi?**
Düşürmek termal riski artırır; bu yüzden beş güvenlik katmanı yalnızca hızı
yükseltebilir ve üçü kapatılamaz.

**Uygulama çökerse ne olur?**
Yardımcı kalp atışı almayı keser ve fanları saniyeler içinde firmware'e geri
verir. Bu varsayılmıyor, sınanıyor.

**Intel Mac'imde çalışır mı?**
Hayır. Intel Mac'ler farklı bir sensör ve SMC düzeni kullanıyor; ikisini birden
desteklemek tek kişinin baktığı bir kod tabanını ikiye katlardı.

**Mac'im ısındığında bana e-posta atabilir mi?**
Doğrudan hayır, ve bu bilinçli. Bir webhook ya da tek satırlık bir betik bunu
yapabilir ve ikisi de bu projeyi posta parolanızı saklamaktan sorumlu kılmaz —
hazır bir örnek
[`docs/operations/notifications.md`](docs/operations/notifications.md) içinde.

## Katkı

Hata bildirimleri, donanım raporları ve çeviri düzeltmeleri memnuniyetle
karşılanır. Lütfen önce [`CONTRIBUTING.md`](CONTRIBUTING.md)'yi okuyun — kurulumu,
iş akışını ve bu projenin kendine uyguladığı kuralları anlatıyor.

Şu anda yapabileceğiniz en yararlı katkı, **M4 mini olmayan bir Mac'ten sensör
raporu**. Beş arayüz dilinden üçü de anadili konuşan biri tarafından okunmadı;
[`TRANSLATORS.md`](TRANSLATORS.md) hangileri olduğunu tam olarak söylüyor.

### Geliştirme

```bash
make next            # sıradaki işi söyler
make check           # her kapıyı çalıştırır — push'tan önce yeşil olmalı
make test            # Swift paket testleri
make smoke           # gerçek bir Mac'te donanım duman testi
```

Bu depo, belge güdümlü ve makine tarafından zorlanan kurallara sahip bir iş akışı
kullanıyor. [`BOOT.md`](BOOT.md) ile başlayın, sonra [`AGENTS.md`](AGENTS.md),
sonra [`TODO.md`](TODO.md). Kurulum ve uygulamanın kendi tanılama komutları:
[`docs/development/setup.md`](docs/development/setup.md).

## Sorumluluk reddi

Boreas hiçbir garanti verilmeksizin olduğu gibi sunulur. **Fan hızlarını
düşürmek termal riski artırır ve bunun sorumluluğu size aittir.** Donanım
garantiniz üzerindeki her türlü etki de size aittir. Bu proje Apple Inc. ile
bağlantılı değildir, onun tarafından yetkilendirilmemiş ve onaylanmamıştır.

## Lisans

[Apache-2.0](LICENSE). Atıflar ve ticari marka bildirimleri: [`NOTICE`](NOTICE).

<div align="center">
<sub>Boreas — kuzey rüzgârı.</sub>
</div>
