# Tanılama

> Son güncelleme: 2026-07-31 — P0.28
> Kaynak: blueprint §13

Donanım sağlığı hakkında **iddialı olmayan, dürüst** bir görünüm sunulur.

## Kontroller

| Kontrol | Yöntem | Çıktı |
|---|---|---|
| **Fan tepkisi** | Hedef ve gerçek RPM arasındaki sapma zaman içinde izlenir | Komutu izliyor / gecikmeli / yanıt vermiyor |
| **Fan dengesi** | Çok fanlı modellerde fanlar arası RPM farkı | Dengeli / anormal fark |
| **Sensör geçerliliği** | Sabit takılan, aralık dışı veya kaybolan sensörler | Sağlıklı / şüpheli okuma |
| **Termal geçmiş** | Oturum boyunca `serious`/`critical` durumda geçen süre | Süre ve tepe değerler |
| **Pil sağlığı** | Döngü sayısı, kapasite oranı, sıcaklık | Bilgilendirici özet |
| **Depolama sağlığı** | NVMe SMART temel alanları | Bilgilendirici özet |

## Dürüstlük kuralı

> **Uygulama, kesin olarak bilemeyeceği bir şeyi kesinmiş gibi söylemez.**

"Fan arızalı" **demez**. Bunun yerine:

> *"Fan komuta beklenen şekilde yanıt vermiyor — sebebi toz birikmesi, kablo bağlantısı veya donanım arızası olabilir."*

ve kullanıcıya sonraki adımları önerir.

**Gerekçe:** Yanlış pozitif bir "arızalı" etiketi, kullanıcıyı gereksiz servise gönderir. Bu kategoride yanlış teşhisin maliyeti, teşhis koymamanın maliyetinden yüksektir.

## Kapsam sınırı

Pil sağlığı ve çok fanlı denge kontrolleri geliştirme donanımında **doğrulanamaz** (R8). Bunlar Mock ile test edilir ve README'de "topluluk doğrulaması bekleniyor" olarak işaretlenir. → `docs/development/testing.md`
