# Gözlemlenebilirlik

> Son güncelleme: 2026-07-31 — P0.26
> Kaynak: blueprint §11 · Karar: [ADR 0014](../architecture/adr/0014-zero-telemetry.md)

## Uygulama içi log

`OSLog` / `Logger` kullanılır.

**Kategoriler:** `sensor` · `fan` · `engine` · `daemon` · `xpc` · `ui` · `config`
**Seviyeler:** `debug` (varsayılan kapalı) · `info` · `notice` · `error` · `fault`

> **Hiçbir log satırı kişisel veri içermez.** Kullanıcı adı, dosya yolu, ağ bilgisi loglanmaz (P3).

## Ölçüm kaydı — kullanıcı isteğine bağlı

| Format | Kullanım |
|---|---|
| **JSONL** | Varsayılan. Satır başına bir örnekleme; araçla işlemesi kolay, şema evrimine dayanıklı |
| **CSV** | Tablo uygulamalarına doğrudan aktarım |

**Döndürme:** günlük veya boyut tabanlı; varsayılan 14 gün saklama. Disk dolmasına karşı **sert üst sınır** (varsayılan 500 MB) — aşılırsa en eski dosyalar silinir ve kullanıcı bilgilendirilir.

**Kaydedilen alanlar:** zaman damgası · sensörler · fanlar · aktif profil · devrede olan güvenlik katmanı.

Aktif güvenlik katmanının kaydedilmesi kritiktir: "fan neden %100'de?" sorusunun cevabı budur.

## Metrik dışa aktarımı — sonraki dalga

- Prometheus metin formatında yerel HTTP uç noktası
- **Yalnızca `127.0.0.1`**, yapılandırılabilir port, **varsayılan kapalı**
- Açıldığında arayüzde **kalıcı bir gösterge** belirir — kullanıcı ağ dinlendiğini her zaman bilir
- Örnek Grafana panosu repoda sunulur

Bu özellik `ARCHITECTURE.md` §12'de ertelenmiş karar olarak izlenir.

## Destek raporu

Kullanıcı isterse **yerel** bir tanılama dosyası oluşturulur. **Otomatik gönderim yoktur** — kullanıcı dosyayı kendisi inceler ve isterse issue'ya ekler.

İçerik: anonim sistem özeti · uygulama log'u · yapılandırma (gizli değer içermez) · sensör ve fan anlık görüntüsü · keşfedilen donanım haritası.
