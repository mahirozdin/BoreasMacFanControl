# Sözlük

> Son güncelleme: 2026-07-31 — P0.13
> Kaynak: blueprint §22

| Terim | Tanım |
|---|---|
| **Görev oranı (duty)** | Fanın minimum ve maksimum hızı arasındaki konumu, 0.0–1.0. `rpm = fanMin + (fanMax − fanMin) × duty` |
| **Eğri** | Sıcaklığı görev oranına dönüştüren parçalı doğrusal fonksiyon. En az 2, en fazla 16 kontrol noktası |
| **Kontrol noktası** | Eğriyi tanımlayan `(sıcaklık, görev oranı)` çifti |
| **Histerezis** | Salınımı önlemek için yükselen ve düşen yönlerde farklı eşik kullanma. Boreas'ta çift eğri yöntemiyle |
| **Hız sınırlama (slew)** | Çıktının birim zamandaki değişimini kısıtlama. Boreas'ta **asimetrik**: yükselme hızlı, düşme yavaş |
| **EWMA** | Üstel ağırlıklı hareketli ortalama — girdi yumuşatma yöntemi |
| **Profil** | Eğriler, parametreler ve tetikleyicilerden oluşan adlandırılmış yapılandırma seti |
| **Tetikleyici** | Bir profilin aktif olma koşulu (güç kaynağı, uygulama, saat, termal durum vb.) |
| **Arbitraj** | Birden fazla aday profil arasından aktif olanı seçme süreci |
| **Toplayıcı (aggregate)** | Bir sensör grubundan tek değer üretme yöntemi: `max`, `mean`, `p95` |
| **Güvenlik zinciri** | Motor çıktısının donanıma ulaşmadan geçtiği koruma katmanları (K1–K5) |
| **Ölü adam anahtarı** | Kalp atışı kesildiğinde otomatik güvenli duruma dönen mekanizma |
| **Kalp atışı (heartbeat)** | Uygulamanın daemon'a düzenli gönderdiği yaşam sinyali |
| **Devralma** | Fan kontrolünün firmware'den yazılıma geçmesi |
| **Devretme** | Fan kontrolünün yazılımdan firmware'e iade edilmesi |
| **Termal baskı** | İşletim sisteminin bildirdiği sistem geneli termal durum (`nominal`/`fair`/`serious`/`critical`) |
| **Panik eşiği** | Aşıldığında çıktının koşulsuz %100 olduğu sıcaklık (K3) |
| **Kapı (gate)** | Bir değişmezi makine ile zorlayan, CI'da bloklayıcı denetim |
| **Sahte kapı** | Çalışıyor görünen ama aslında hiçbir şey kontrol etmeyen denetim |
| **Atomik iş** | Tek oturumda bitirilebilen, tek kabul kanıtı olan görev |
| **Dondurulmuş kaynak** | Başlangıç spesifikasyonunun asla düzenlenmeyen kopyası |
| **Live / Mock / Replay** | Donanım protokollerinin üç uygulaması: gerçek, sahte, log'dan yeniden oynatan |
