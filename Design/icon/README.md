# Boreas — Uygulama Simgesi

> Son güncelleme: 2026-08-03 — M08
> Kaynak: blueprint §9.1 · Karar: [ADR 0002](../../docs/architecture/adr/0002-product-name.md)

## Dosyalar

| Dosya | Rol |
|---|---|
| `boreas-background.svg` | Arka katman — tam kanvas gradyan dolgu |
| `boreas-foreground.svg` | Ön katman — dört kanat + göbek, saydam zemin |
| `preview.html` | Boyut ölçeği, Dock bağlamı, karanlık tema önizlemesi |
| `render/*.png` | Referans render'lar (kaynak değil — kaynak SVG'lerdir) |

## Tasarım

Dört geniş, süpürülmüş kanat ve belirgin bir göbek. Soğuk mavi gradyan (kuzey rüzgârı).

**Neden bu biçim:**

- **Kanatlar geniş.** İnce şeritler "örümcek" veya "X" gibi okunuyor. Dış yayın geniş bir açı taraması (70°) şeklin ilk bakışta fan olarak okunmasını sağlıyor.
- **Dört kanat.** Kare kanvasta 4 katlı simetri 3 katlıdan daha oturuyor; üç kanat pinwheel veya geri dönüşüm işaretiyle karışabiliyor.
- **30° süpürme.** Dönme hissi hareket bulanıklığı olmadan veriliyor — Liquid Glass render'ı bulanıklıkla çakışırdı.
- **Göbek, kanat köklerini yutuyor.** Kök yayı r=130, göbek diski r=145; kanat ve göbek tek siluet oluşturuyor.

## Teknik spesifikasyon

| Parametre | Değer |
|---|---|
| Kanvas | 1024 × 1024 |
| Merkez | (512, 512) |
| Göbek diski | r = 145 |
| Kanat kök yayı | r = 130, 26° tarama |
| Kanat dış yayı | r = 385, 70° tarama |
| Süpürme | dış yay merkezi kök merkezinden +30° |
| Dış sınır | r = 385 → kanvas içinde 127 px boşluk |
| Kanat sayısı | 4, `rotate(n × 90)` |

## Uyulan Liquid Glass kuralları

- ❌ **Platform maskesi yok** — yuvarlatılmış dikdörtgeni sistem uyguluyor
- ❌ **Gömülü gölge yok** — derinliği sistem render ediyor
- ❌ **Specular highlight yok** — ışığı sistem render ediyor
- ❌ **Ön katmanda gradyan yok** — tek düz dolgu, böylece dört görünüm varyantı (default / dark / clear / tinted) temiz türüyor
- ✅ **Ön katman saydam zeminli**
- ✅ **Metin yok** — outline'a çevrilecek bir şey yok
- ✅ **Yuvarlatılmış köşeler** — ışık keskin köşelerde kötü kırılıyor

## Icon Composer ile derleme

Icon Composer, Xcode 26 ile birlikte geliyor (`/Applications/Xcode.app` içinde).

1. Icon Composer'ı aç, yeni belge oluştur.
2. `boreas-background.svg` dosyasını **arka katman** olarak içe aktar.
3. `boreas-foreground.svg` dosyasını **ön katman** olarak içe aktar.
4. Ön katmanda Liquid Glass materyalini etkinleştir; specular ve gölge ayarlarını sistem varsayılanlarında bırak.
5. Dört görünüm varyantını (default, dark, clear, tinted) önizle.
6. `Boreas.icon` olarak dışa aktar ve uygulama hedefine ekle.

> **Not:** `.icon` dosyası bu dizinde tutulmaz; P6'da uygulama hedefi oluşturulduğunda `App/Resources/` altına eklenir. Bu dizin **kaynak** varlıkları barındırır.

## Render'lar hakkında

`render/` altındaki PNG'ler ImageMagick ile üretilmiş **referans** görsellerdir. ImageMagick SVG gradyanlarını render etmediği için arka plan ayrıca üretilip birleştirilmiştir. Gerçek görünüm için `preview.html` (WebKit) veya Icon Composer önizlemesi esas alınmalıdır.

## Üretim yöntemi ve provenans

Bu simge **elle yazılmış SVG geometrisidir** — üretken görsel yapay zekâ kullanılmamıştır.

Gerekçe: üretken modellerle üretilen görsellerin telif kökeni belirsizdir. Projenin hukuki duruşu ([`LEGAL.md`](../../LEGAL.md)) her varlığın kökeninin net olmasını gerektiriyor. Parametrik olarak tanımlanmış, yorumlarında her sayının gerekçesi yazılı bir vektör dosyası bu gereksinimi tartışmasız karşılıyor.

Tasarım süreci: beş dar kanat varyantı üretildi ve elendi (hepsi "X" veya girdap gibi okunuyordu), ardından geniş kanat geometrisiyle beş varyant daha denendi. Tam çözünürlükte rasterleştirme, önizleme boyutunda görünmeyen bir birleşme boşluğunu ortaya çıkardı ve düzeltildi.

## Yeniden üretme

```bash
cd Design/icon
magick -size 1024x1024 gradient:'#5FC8F5-#123E86' /tmp/bg.png
magick -background none boreas-foreground.svg -resize 1024x1024 /tmp/fg.png
magick /tmp/bg.png /tmp/fg.png -composite render/boreas-1024.png
```
