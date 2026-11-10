# PROJECT_SPEC — Çanta Fiziği

> **Tek cümle:** Kırılabilir ve yaylı paketleri bir kurye çantasına fizik kurallarıyla dizersin, tümsekli yolda aracı sürersin, paketleri hasarsız teslim edip para kazanırsın.

| Alan | Değer |
|---|---|
| Platform | Android (Play Store), dikey (portrait) |
| Motor | Godot 4.7.2, `gl_compatibility` |
| Çözünürlük | 1080x1920 (referans tasarım alanı) |
| Tür | Fizik tabanlı bulmaca + beceri/refleks |
| Oturum uzunluğu | 45–120 sn / teslimat, 8–15 dk / seans |
| Maliyet modeli | Ücretsiz + ödüllü reklam (IAP v2) |
| Hedef kitle | 16–45, hyper-casual + fizik komedisi izleyicisi |

---

## 1. Konsept ve oyuncu fantezisi

Oyuncu bir kuryedir. Motoru çalışmıyor; motor onun **denge ve dikkati**. Çanta yeterince dolu değilse para az, çok doluysa paketler kırılır. Asıl gerilim: **"Bunu sığdırabilir miyim? Dayanır mı?"**

İki zıt kural aynı anda işler:

1. **Sığdır:** Çantada ne kadar çok paket = o kadar çok para. Paketler `RigidBody3D`'dir, üst üste yığılır, birbirini iter, kayar.
2. **Korumala:** Kırılabilir paket düşerse kırılır; yaylı paket zıplayıp diğerlerini fırlatır. Hasarlı teslimat para vermez, itibar düşürür.

Mizah buradan doğar: mükemmel dizilmiş bir çanta, ilk tümsekte çorba olur. Oyuncu izler, güler, tekrar dener.

### Neden eğlenceli
- **Anlık fizik geri bildirimi:** her çarpma duyulur ve görülür (kamera sarsıntısı, çıt sesi, çatlak efekti).
- **Yüksek tekrar değeri:** aynı paket seti her seferinde farklı yerleşir.
- **Okunabilir başarısızlık:** "Şu köşeye koymasaydım kırılmazdı" hissi. Hata oyuncunun, şansın değil.
- **Mikro ilerleme:** her teslimat bir yükseltme satın almaya yaklaştırır.

---

## 2. Core loop

```
        ┌──────────────────────┐
        │  1. SİPARİŞ SEÇ       │  (haritada 2-3 sipariş, zorluk/ödül farkı)
        └───────────┬──────────┘
                    ▼
        ┌──────────────────────┐
        │  2. PAKETLE           │  çantaya sürükle-bırak, denge kur
        └───────────┬──────────┘
                    ▼
        ┌──────────────────────┐
        │  3. SÜR               │  gaz/fren, tümsekten kaçın ya da yavaş geç
        └───────────┬──────────┘
                    ▼
        ┌──────────────────────┐
        │  4. TESLİMAT + PUAN   │  0-3 yıldız, hasar raporu
        └───────────┬──────────┘
                    ▼
        ┌──────────────────────┐
        │  5. ÖDÜL + YÜKSELTME  │  para → çanta kapasitesi, süspansiyon...
        └───────────┬──────────┘
                    └─────────► başa dön
```

Ortalama tur 60–90 saniye. Bir seansta 6–10 tur.

### Aşama detayları

**1. Sipariş seçimi.**
Haritada aynı anda 3 sipariş kartı: paket listesi, mesafe, ücret, risk etiketi. Oyuncu birini seçer. Siparişe göre paket karışımı değişir (kolay: 3 standart; zor: 2 kırılabilir + 1 yaylı).

**2. Paketleme (asıl bulmaca).**
Çanta boş, paketler yanda bir rafta. Oyuncu parmağıyla paketi çantaya sürükler; bıraktığında fizik devreye girer.
- Paket gizmo'su (döndürme) tek dokunuşla 90° adımlarla döner.
- Çanta içinde **ağırlık merkezi** göstergesi var; ağır paketler altta olmalı.
- Kırılabilir paketler **köpük/bant** ile sabitlenebilir (sınırlı sayıda).
- Hazır olunca "SÜR" butonu.

**3. Sürüş.**
Üstten/arkadan sabit kamera. Araç otomatik ilerler, oyuncu **fren/gaz** ve **şerit** kontrol eder.
- Yol boyunca tümsekler (`speed bump`), çukurlar, çukurlu asfalt bandı.
- Hız arttıkça çantadaki sarsıntı üstel artar.
- Doğru şerit seçimi ve zamanlama = düşük hasar.
- Son %20'de "son viraj" — karar anı.

**4. Teslimat ve puanlama.**
Her paket tek tek teslim edilir; hasar yüzdesi hesaplanır.

| Hasar | Sonuç |
|---|---|
| %0 | 3 yıldız, tam ücret + %20 bonus |
| %1–25 | 2 yıldız, tam ücret |
| %26–60 | 1 yıldız, ücretin %60'ı |
| %61–99 | 0 yıldız, ücretin %20'si, itibar −1 |
| %100 (kırıldı) | Ücret yok, itibar −2, "Paketi Bandıyla Kurtar" teklifi |

**5. Ödül ve yükseltme.**
Para birimi: **₺ (TL)**. Yükseltmeler:
- Çanta kapasitesi (0.35 m → 0.55 m genişlik)
- Süspansiyon (sarsıntı absorbsiyonu)
- Bant stoğu
- Cep sayısı (ayrıca reklamla geçici açılır)
- Kasko (bir turda ilk kırılmayı engeller)

---

## 3. Paket tipleri

| Tip | Görsel | Davranış | Kırılma eşiği | Ücret | Kural |
|---|---|---|---|---|---|
| **Standart** | Kraft kutu | Sert, kaymaz | — (kırılmaz) | ×1.0 | Referans kütle |
| **Kırılabilir** | "KIRILIR" etiketli, cam çizim | Sert, hafif, **impuls > eşik = kırılır** | 4.0 m/s hız değişimi | ×1.8 | Köpük/bant ister |
| **Yaylı** | Yay simgesi, hafif | Çok esnek (`bounce = 0.9`), **komşularını fırlatır** | — | ×1.4 | En üste, tek başına konmalı |
| **Ağır** | Koyu, metal köşe | Yüksek kütle (3×), alt sırada olmalı | — | ×1.2 | Dengenin çapası |
| **Sıvı** (v2) | Damla simgesi | Sürekli sarsıntı hasarı birikir | birikimli | ×2.2 | En kısa sürede teslim |

Paket verisi `data/packages.json`'dan okunur; kodda sabit değer yoktur.

Her paket şu alanları taşır: `id`, `mass`, `size`, `friction`, `bounce`, `fragility_threshold`, `reward_multiplier`, `allowed_in_pocket`.

---

## 4. Çanta mekaniği

- Çanta = **açık üstlü, 6 duvarlı** bir kaptır. İç yüzey `StaticBody3D` duvarlarla modellenir.
- Sürüş sırasında çanta, aracın süspansiyonuna bağlıdır: aracın dikey hareketini **gecikmeli ve sönümlü** takip eder (`SpringArm3D` benzeri, ama fizik gövdesiyle). Sarsıntı buradan gelir; kamera da çantayı takip eder ki oyuncu durumu okusun.
- Çanta eğimi: virajlarda çanta 8–12° yatar → paketler kayar. Bu bir "risk" göstergesidir.
- **Cep (pocket):** çantanın içinde/yanında ayrı bir bölme. Cepteki paket sarsıntıdan **%70 daha az** etkilenir ama kapasitesi küçüktür (1–2 paket).

### "Ekstra Cep Aç" (ödüllü reklam)
- Nerede: paketleme ekranında, "CEP DOLU" durumuna gelindiğinde.
- Ne yapar: tur boyunca **+1 cep** (2 paket kapasiteli, sarsıntıya %70 dayanıklı) açar.
- Süre: yalnızca o tur. Kalıcı kazanım yok.
- Etik: reklam **isteğe bağlı**. Oyuncu reklam izlemeden de turu oynayabilir; cep sadece kolaylaştırıcı.

### "Paketi Bandıyla Kurtar" (ödüllü reklam)
- Nerede: bir paket kırılmak üzereyken (hasar %80–99) veya kırıldığı anda, **3 saniyelik** geri dönüşsüz fırsat penceresinde.
- Ne yapar: paketi bantla sarar → hasar %80'den **%40'a** iner ve o paket **o tur için kırılamaz** hâle gelir.
- Süre: tur başına **1 kez**.
- Adalet: kurtarma sonucu yıldız **en fazla 2** olur. Reklam, 3 yıldızı satın almaz.
- Etik: "kurtar ya da kaybet" baskısı yaratmamak için teklif nazik dille sunulur ("Bandıyla kurtar?") ve reddetmek cezalandırılmaz.

### Reklam yerleşim kimlikleri
| Placement (enum) | Tetik | Ödül | Limit |
|---|---|---|---|
| `EXTRA_POCKET` | Paketleme ekranı, cep doluyken | +1 geçici cep | Tur başına 1, oturumda 3 |
| `TAPE_RESCUE` | Hasar %80+ | Paket kurtarılır (%40 hasar) | Tur başına 1 |
| `DOUBLE_REWARD` | Sonuç ekranı | Ücret ×2 | Tur başına 1 |
| `FREE_UPGRADE` (v2) | Yükseltme ekranı | 1 seviye ücretsiz | Günlük 1 |

Kurallar: reklam yüklemesi başarısızsa sessizce devam edilir; oyuncuya "reklam yok" diye hata gösterilmez; ödül yalnızca `rewarded_finished` doğrulandıktan sonra verilir.

---

## 5. Yol ve sürüş

- Yol prosedürel değil, **elle tasarlanmış segmentlerden** kurulur (`scenes/road/road_segment_*.tscn`). Tranche: 6 segment ≈ 40 sn.
- Segment parametreleri: `bump_density`, `bump_height`, `pothole_chance`, `turn_count`, `speed_limit`.
- Araç hızı: 0–90 km/s (oyun içi ölçek, gerçek değil). Fren = dokunma basılı tutma.
- **Denge göstergesi:** çanta eğimi + ağırlık merkezi HUD'da 3 çizgili bir inklinometre ile gösterilir.
- Kaybetme yok, **kayıp** var: paket kırılınca tur bitmez, sadece para/itibar kaybedersin. Bu, negatif geri bildirimi yumuşatır.

---

## 6. Meta ve ilerleme

- **Harita:** 5 mahalle × 6 teslimat. Her mahalle yeni bir paket tipi veya tümsek türü tanıtır.
- **İtibar:** 0–5 yıldız. Düşerse sipariş seçenekleri azalır. Onarım için para veya 1 reklam.
- **Günlük görev:** "3 kırılabilir paketi sıfır hasarla teslim et" → küçük para ödülü.
- **Koleksiyon:** teslim edilen "nadir paketler" galerisi (retention, v2).

---

## 7. Ses ve görsel yön

- **Sanat:** düşük poligon, yumuşak pastel palet, sıcak ışık. Fizik komedisi tonu → abartılı ama sevimli.
- **Kamera:** çantaya kilitli, 3/4 üstten; sarsıntı `Camera3D`'ye değil **hedefe** uygulanır (motion sickness önlemi).
- **Ses:** çarpma = paket tipine göre farklı malzeme sesi (karton, cam çıtırtısı, yay boing). Kırılma anı **tek ve net** duyulmalı.
- ElevenLabs ile üretilen SFX `assets/audio/sfx/` altında, `.ogg` 128 kbps. Müzik döngüsü ≤ 60 sn.

---

## 8. UX ve erişilebilirlik

- Tek elle oynanabilir; tüm etkileşim ekranın alt %60'ında.
- Dokunma hedefleri ≥ 88 px (1080 genişlikte ~96 px).
- Renk körlüğü: kırılabilir/yaylı ayrımı **sadece renkle değil**, ikon + desenle verilir.
- Titreşim (haptik): çarpma ve kırılma için; ayarlardan kapatılabilir.
- Kamera sarsıntısı azaltma seçeneği.
- Metinler `assets/translations/strings.csv` üzerinden TR/EN.

---

## 9. Başarı ölçütleri (KPI)

| Metrik | Hedef (ilk 3 ay) |
|---|---|
| D1 retention | ≥ %38 |
| D7 retention | ≥ %14 |
| Ortalama seans | ≥ 8 dk |
| Tur tamamlama oranı | ≥ %85 |
| Ödüllü reklam gösterim/tur | 0.6–1.2 (1.5 üstü = baskı, ayarla) |
| ANR / crash-free | ≥ %99.2 |

---

## 10. Kapsam dışı (v1)

- Çok oyunculu, sosyal, klan.
- Aracın gerçek araba simülasyonu (vites, hasar modeli yok).
- Gerçek harita/GPS entegrasyonu.
- IAP mağazası (v2; önce ödüllü reklamla doğrula).
- iOS build (altyapı hazır tutulur, mağaza v2).

---

## 11. Riskler ve önlemler

| Risk | Etki | Önlem |
|---|---|---|
| Fizik performansı düşük cihazlarda çöker | Yüksek | Paket sayısı ≤ 12, `sleeping` agresif, cep başına ayrı fizik izolasyonu |
| Rastgelelik "haksız" hisseder | Yüksek | Deterministik tohum + aynı setin yeniden oynanabilmesi |
| Kırılma anı okunmaz | Orta | Kırılma öncesi 200 ms görsel/işitsel uyarı, hasar barı |
| Reklam baskısı hissi | Orta | Tur başına limit, 3 yıldızı reklamla satmama kuralı |
| Portrait'ta çanta + yol sığmaz | Orta | Çanta üst 55%, yol alt 45% sabit split; UI overlay |

---

## 12. Sürüm yol haritası

| Sürüm | Hedef |
|---|---|
| **0.1.0** | İskelet + dokümantasyon (bu sürüm) |
| 0.2.0 | Oynanabilir fizik prototipi: çanta + 3 paket, sürükle-bırak |
| 0.3.0 | Sürüş, yol segmentleri, hasar/puanlama |
| 0.4.0 | Menü, sonuç ekranı, kalıcı kayıt |
| 0.5.0 | AdManager + iki ödüllü yerleşim (mock sağlayıcıyla) |
| 0.6.0 | Ses, görsel cila, TR/EN |
| **1.0.0** | Android yayın (Play Store, internal → production) |
