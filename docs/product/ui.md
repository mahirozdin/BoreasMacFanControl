# Kullanıcı Arayüzü

> Son güncelleme: 2026-07-31 — P0.17
> Kaynak: blueprint §9

## Tasarım dili

Görsel kimlik sıfırdan tasarlanır. Bağlayıcı kararlar:

| Öğe | Karar |
|---|---|
| Temel yaklaşım | macOS 26 tasarım dili; sistem malzemeleri, SF Pro, sistem vurgusu |
| Renk sistemi | **Sıcaklık ve fan için ayrı skalalar.** Sıcaklık: soğuk mavi → nötr → sıcak turuncu, **sürekli** geçiş. Fan: nötr gri doluluk. Kırmızı **yalnızca** panik/hata için ayrılmıştır |
| Neden sürekli skala | Ayrık üç renkli bant, sürekli eğri felsefesiyle çelişir. Sürekli veri sürekli görselleştirilir |
| İkonografi | SF Symbols; özel ikon yalnızca uygulama simgesi |
| Uygulama simgesi | Özgün, hava akışı temalı soyut form. **Fan pervanesi klişesinden kaçınılır** |
| Karanlık/aydınlık | İkisi de birinci sınıf |
| Animasyon | Yalnızca anlam taşıyanlar; dekoratif animasyon yok |

**Metin ilkesi:** Tüm arayüz metinleri sıfırdan yazılır. Türkçe metinler çeviri gibi durmaz — Türkçe düşünülerek yazılır, İngilizce ayrıca yazılır. → `docs/development/localization.md`

## Menü çubuğu

**Durum öğesi:** yapılandırılabilir içerik (birincil/ikincil sıcaklık, fan RPM, mini grafik) · yatay veya dikey · kompakt mod · aktif profil göstergesi · fan kontrolü aktifken belirgin ama rahatsız etmeyen gösterge · yer kalmadığında (çentik dahil) bilgilendirme.

**Açılır panel:** profil seçici (tek tıkla değiştirme + geçici geçersiz kılma) · fanlar (ad, RPM, doluluk) · sıcaklıklar (gruplu, katlanabilir) · ana pencere / ayarlar / çıkış.

Panel açıkken ölçüm döngüsü **durmaz**.

## Ana pencere

**① İzleme** — özet kartlar · zaman serisi grafiği (Swift Charts, 5dk/1sa/6sa/24sa) · **fan RPM grafiği aynı zaman ekseninde** (sıcaklık ve tepki görsel olarak hizalanır) · sensör tablosu · maksimumları sıfırlama.

**② Kontrol** — aktif profil **ve neden aktif olduğu** (hangi tetikleyici sağlandı — şeffaflık önemli) · eğri editörü · fan↔sensör grubu eşlemesi · manuel geçersiz kılma (süre seçicili) · güvenlik zinciri durumu.

**③ Tanılama** — `docs/operations/diagnostics.md` içindeki kontroller · sistem ve donanım özeti · log erişimi · **yerel** destek raporu (otomatik gönderim yok).

## Eğri editörü

Ürünün imza arayüzü.

- X: sıcaklık, Y: görev oranı; sürüklenebilir kontrol noktaları
- Çift tıkla ekleme, sağ tıkla silme; **monotonluk kısıtı sürükleme sırasında zorlanır**
- **Canlı katmanlar:** anlık çalışma noktası · son 60 sn'nin izi (soluk bulut — gerçek davranışı eğriyle karşılaştırma) · histerezis bandı gölgesi
- **Sayısal düzenleme:** her nokta tablodan da girilebilir (erişilebilirlik + hassasiyet)
- Hazır şablonlar · geri al/yinele
- Yan panelde canlı parametreler (histerezis, yumuşatma, yükselme/düşme hızı) grafikte anında yansır

## Ayarlar

Sekmeler: **Genel · Görünüm · Sensörler · Kontrol · Bildirimler · Kayıt · Gelişmiş**

## Erişilebilirlik — pazarlık konusu değil

- Tüm etkileşimli öğeler klavyeyle erişilebilir, mantıklı odak sırası
- Grafikler ve eğri editörü için VoiceOver açıklamaları; **eğri, nokta listesi olarak da sunulur**
- `Increase Contrast`, `Reduce Motion`, `Reduce Transparency` uyumu
- **Renk tek başına bilgi taşımaz** — daima sayı veya etiketle desteklenir
- Dynamic Type desteği; **sabit piksel genişlikli veya yükseklikli metin kabı yok**
- Menü çubuğu öğesi anlamlı erişilebilirlik etiketi sunar
