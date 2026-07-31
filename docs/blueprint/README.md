# Dondurulmuş Blueprint

> Son güncelleme: 2026-07-31 — P0.02
> Kaynak: blueprint §0

## Bu dizin nedir

`boreas-blueprint-v1.1.md`, projenin başlangıç spesifikasyonunun **birebir kopyasıdır**. Tarihsel referanstır.

## Kurallar

1. **Bu dizindeki dosya asla düzenlenmez.** Yazım hatası bile düzeltilmez.
2. Projenin yaşayan gerçeği `docs/` ağacının geri kalanındadır. Bir çelişki varsa `docs/` kazanır, blueprint değil.
3. **Blueprint'ten her sapma bir ADR ile kaydedilir** (`docs/architecture/adr/`). Sessiz sapma yoktur.
4. Blueprint'te bir hata bulunursa: sessizce uygulanmaz, sessizce düzeltilmez. Bulgu kanıtla gösterilir, ADR yazılır, ilgili `docs/` dosyası güncellenir, Run Log'a geçilir.

## Neden donduruldu

Bir spesifikasyon zamanla iki işlevi birden göremez: hem "başlangıçta ne kararlaştırdık" hem "şu an ne doğru". İkisi karışırsa, bir kararın **neden** verildiği kaybolur.

Ayrım şudur:

| Soru | Cevap nerede |
|---|---|
| Başlangıçta ne planlanmıştı? | Bu dizin |
| Şu an ne doğru? | `docs/` ağacının geri kalanı |
| Neden değişti? | `docs/architecture/adr/` |
| Hangi blueprint bölümü nereye gitti? | `docs/reference/blueprint-map.md` |

## Bütünlük kapısı

Kopyanın dokunulmadığı makine ile doğrulanır:

```bash
make blueprint-check
```

Kök dizindeki `BLUEPRINT.md` ile bu dizindeki kopya arasında fark çıkarsa kapı kırmızıya döner.

> **Not:** Kök `BLUEPRINT.md` de düzenlenmemelidir. İkisi birlikte dondurulmuştur; kapı ikisinin de aynı kaldığını doğrular.
