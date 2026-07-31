# Keşfedilebilirlik

<!-- gate-names:policy-doc — Bu dosya yasaklı kalıpları TARİF ettiği için gate-names taramasından muaftır. Bkz. LEGAL.md §5.1 -->

> Son güncelleme: 2026-07-31 — P0.31
> Kaynak: blueprint §18.4 · Karar: [ADR 0002](../architecture/adr/0002-product-name.md)

## İlke

**Marka adı ile arama anahtar kelimeleri aynı şey olmak zorunda değildir.**

Ürün adı `Boreas` markayı taşır; anahtar kelimeler adın dışındaki katmanlarda taşınır. Bu ayrım sayesinde ayırt edici marka ve yüksek keşfedilebilirlik aynı anda elde edilir.

## Katman haritası

| Katman | Değer | Neden önemli |
|---|---|---|
| **Depo adı** | `boreas-mac-fan-control` | URL'deki kelimeler güçlü sinyal; hem marka hem anahtar kelime |
| **Depo açıklaması** | *"Free, open-source Mac fan control and temperature monitoring for Apple Silicon (M1–M5). Native menu bar app — no kernel extension, no SIP changes."* | **En kritik alan.** Arama motorlarının meta açıklama olarak kullandığı yer |
| **GitHub topics** | `mac-fan-control` `fan-control` `macos` `apple-silicon` `temperature-monitor` `thermal` `menu-bar` `swift` `swiftui` `m1` `m2` `m3` `m4` `macos-app` `system-monitor` | Konu sayfaları kendi başına organik trafik kaynağı |
| **README `<h1>` + tagline** | `# Boreas` → *Mac Fan Control & Temperature Monitoring for Apple Silicon* | Arama sonucundaki başlık |
| **README ilk paragraf** | Anahtar kelimeleri doğal içeren 2–3 cümle | Snippet olarak çekilen metin |
| **Homebrew cask `desc`** | Anahtar kelimeli tek satır | `brew search` sonuçlarında görünür |
| **Release başlıkları** | Sürüm + kısa özellik özeti | Sürüm sayfaları ayrıca indekslenir |
| **README çevirileri** | `tr` `ru` `es` `zh-Hans` | Yerel dilde arama yapan kullanıcıya erişim |

## Hedef arama niyetleri

İnsanların gerçekten arattığı ifadeler. README içeriği bunları **doğal biçimde** karşılamalıdır:

- `mac fan control` · `macbook fan control` · `apple silicon fan control`
- `mac temperature monitor` · `m4 mac temperature`
- `macbook running hot` · `mac fan always on` · `mac fan noise`
- `free mac fan control app` · `open source mac fan control`
- `control mac mini fan speed`

## README SSS bölümü

README'nin sonuna, **gerçekten faydalı olduğu için** doğal olarak bu ifadeleri barındıran kısa bir soru-cevap konur:

- *"Why is my Mac running hot?"*
- *"Can I control fan speed on Apple Silicon Macs?"*
- *"Does this require disabling SIP or installing a kernel extension?"* → **No** (aynı zamanda en güçlü satış argümanı)
- *"Is it safe to lower fan speeds?"*
- *"What happens if the app crashes?"*

Bu bölüm iki işi birden yapar: kullanıcının gerçek sorusunu cevaplar ve arama görünürlüğü sağlar.

## Yapılmayacaklar

| Yapılmayacak | Neden |
|---|---|
| Anahtar kelime tıkıştırma | Ters teper; sahtelik hissi verir, güveni düşürür |
| Üçüncü taraf ürün adını anahtar kelime olarak kullanma | `LEGAL.md` Y5/Y6 — **mutlak yasak** |
| Yanıltıcı topic etiketleri | Platform tarafından cezalandırılır |
| Yapay yıldız / sahte etkileşim | Hesap kapatılma riski, itibar kaybı |
| Ölçülemeyen performans iddiası | Kanıtsız ifade |
