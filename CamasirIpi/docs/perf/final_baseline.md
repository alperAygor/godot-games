# Son başarım turu — ÖNCE (final_baseline)

- Tarih: 2026-11-13/14. Kod: `ce8f485` (merge: orch/r-size), değişiklik yok.
- Makine: Apple M4 (10 çekirdek), macOS, Godot 4.7.2-stable, `gl_compatibility`. Orta sınıf Android'in
  **vekili**: mutlak değerler değil, önce/sonra oranları ve sayaçlar (düğüm, doku, nesne) anlamlıdır.
- Ölçüm aracı: `tools/perf_probe2.gd` (yeni). "Önce" ölçümü, aynı aracın değiştirilmemiş kodun temiz bir
  kopyasında (`git archive HEAD`) çalıştırılmasıyla alındı; ham çıktılar `docs/perf/final_raw/before_*.md`.

```bash
godot --headless --path . -s res://tools/perf_probe2.gd -- --out=docs/perf/final_raw/before_cpu.md            # CPU (çizimsiz)
godot --path . -s res://tools/perf_probe2.gd -- --out=docs/perf/final_raw/before_window.md                     # gerçek pencere, VSync kapalı
godot --headless --path . -s res://tools/perf_probe2.gd -- --leak --out=docs/perf/final_raw/before_leak.md     # sızıntı döngüsü
```

Yöntem notları:
- Başsız kipte Godot kareyi `low_processor_mode_sleep_usec` (6.9 ms) ile sabitliyordu; prob uykuyu kapatır,
  böylece başsız kare süresi = gerçek CPU işi (betik + motor, çizim yok). Takılma eşiği başsızda 4 ms
  (M4 ≈ orta sınıf Android CPU'sunun 5-8 katı), pencerede 33.3 ms.
- `Performance.TIME_PROCESS` kullanılmadı: saniyede bir güncellenen bir EN BÜYÜK değer döndürüyor, kare başı
  ortalama için yanıltıcı. Yerine en son işlenen bir düğümle "düğüm `_process` süresi" ölçülür.
- "Açılış eşzamanlı" = sahneyi kuran çağrının süresi (ana iş parçacığı donar); "ilk kare" = sonraki karenin
  kalan işi. Oyun sahnelerinde seviye, gerçek akıştaki gibi önceden üretilmiş olarak açılır.
- "Kaplama" = görünür doku/renk kutularının ekranla kesişen alanlarının toplamı / ekran alanı (aşırı çizim vekili).
- Pencere koşuları tek seferlik kısa koşulardır (her biri ~4 dk, sert zaman aşımlı); kare sürelerinde ±%15 gürültü var.

## 1. Kare süresi — gerçek pencere (VSync kapalı)

| Sahne | açılış (ms) | ilk kare (ms) | kare ort / p99 / en kötü (ms) | çizim çağrısı ort / en çok | doku (MiB) | düğüm | kaplama (ekran) |
|---|---|---|---|---|---|---|---|
| boot -> ana ekran (0.4 sn bekleme dahil) | **697** | 19 | 1.21 / 2.62 / 3.4 | 161 / 161 | 19.7 | 293 | 5.7 |
| home | 3 | 3 | 1.21 / 3.06 / 3.9 | 108 / 108 | 19.7 | 198 | 4.1 |
| harita açılış (soğuk) + boşta | 2 | 6 | 1.03 / 3.23 / 4.2 | 151 / 252 | 20.5 | 210 | 1.3 |
| mağaza açılış (soğuk) | 9 | 20 | 0.91 / 2.71 / 3.6 | 138 / 239 | 22.4 | 455 | 2.0 |
| koleksiyon açılış (soğuk) | 14 | 10 | 0.97 / 3.10 / 4.7 | 85 / 183 | 22.3 | 366 | 2.2 |
| harita kaydırma (3000 px/sn) | 0 | 4 | 1.47 / 3.64 / 3.9 | 128 / 258 | 20.9 | 211 | 1.3 |
| oyun L5 (ilk oyun sahnesi) | **137** | 11 | 1.12 / 2.58 / 10.5 | 85 / 112 | 22.1 | 252 | 5.5 |
| oyun L70 (kurutucu, kış) | 38 | 14 | 1.60 / 2.97 / 11.2 | 214 / 311 | 30.2 | 357 | 6.2 |
| oyun L88 (yağmur, kar) | 32 | 7 | 1.72 / 3.22 / 4.1 | 290 / 382 | 34.4 | 389 | 5.6 |
| oyun L100 (kedi, polen, ilkbahar) | 22 | 14 | 1.75 / 3.98 / 10.2 | 239 / 452 | **39.0** | 350 | 5.4 |
| oyun L65 -> 66 (Devam) | 20 | 8 | 1.76 / 3.41 / 19.4 | 268 / 485 | **48.1** | 631 | 6.6 |
| zen (2 tahta) | 11 | 6 | 1.28 / 2.79 / 13.9 | 128 / 157 | **45.5** | 289 | 4.4 |
| oyun L100 (ikinci açılış) | 11 | 6 | 1.80 / 4.01 / 6.3 | 240 / 452 | 40.8 | 350 | 5.4 |

Pencerede 33 ms üstü kare: **yok** (M4). Ana ekran ve oyun 4-6.6 ekran kaplama (katmanlı bahçe) taşır;
mobilde asıl maliyet bu piksel doldurma ve kış/sonbahar/ilkbaharda her katmanda çalışan `season_grade` gölgelendiricisi.

## 2. CPU — başsız (çizim yok, uyku kapalı)

| Sahne | açılış (ms) | kare ort (ms) | en kötü (ms) | düğüm `_process`/kare (ms) | işlenen düğüm | takılma (>4 ms) |
|---|---|---|---|---|---|---|
| boot -> ana ekran (0.4 sn bekleme dahil) | **699** (bekleme sonrası ~300 ms eşzamanlı yükleme) | 0.02 | 0.1 | 0.01 | 1 | 0 |
| home | 2 | 0.01 | 0.1 | 0.01 | 1 | 0 |
| harita / mağaza / koleksiyon (soğuk) | 1 / 9 / 14 | 0.00 | 0.3 | 0.00 | 0 | 0 |
| harita kaydırma | 0 | 0.04 | 0.2 | 0.03 | 0 | 0 |
| oyun L5 (ilk oyun sahnesi) | **136** | 0.02 | 2.0 | 0.02 | 5 | 0 |
| oyun L70 / L88 / L100 | 19 / 15 / 16 | 0.03-0.04 | 1.4-1.7 | 0.03-0.04 | 6-7 | 0 |
| oyun L65 -> 66 (Devam) | 17 (Devam çağrısı 12) | 0.04 | 12.9 | 0.03 | 6 | 2 (13 ms, 6 ms: Devam karesi) |
| zen (2 tahta) | 4 | 0.03 | 7.3 | 0.03 | 17 | 1 (7 ms: sonraki tahtanın kurulumu) |

Ayrıştırma (`load()` süreleri, soğuk): `Home.tscn` 292 ms, ardından `Game.tscn` 124 ms — neredeyse tamamı betik
derleme + bağımlılık yükleme; düğüm kurulumu birkaç ms. Bu iş ana iş parçacığında, Boot beklemesi BİTTİKTEN sonra
ve ilk "Oyna"da ödeniyordu. Devam karesindeki 10 ms'nin çoğu, yeni mekaniğin dokularının (çorap, katlı çamaşır,
makine, çamur...) ilk kez eşzamanlı yüklenmesi (ikinci kurulum 3-5 ms).

Boşta `_process` alan düğümler (ölçüm sonunda): ana ekran yalnız `garden_backdrop` (ortam animasyonu, tasarım);
harita/mağaza/koleksiyon 0; oyunda `game`, `basket_view` (nefes), `garden_backdrop`, `rain_cloud_view` (bulut
görünürken) ve gereksiz olarak **`tutorial_hand` (gizli el her kare)** ve 10. seviye üstünde boşa dönen
**`tutorial_director`** (pencere kipinde).

## 3. Bellek / sızıntı — `--leak` (12 Devam + 12 tam sahne döngüsü, başsız)

| Adım | nesne | kaynak | düğüm | yetim | statik (MiB) | LevelPrefetch | bahçe doku önbelleği |
|---|---|---|---|---|---|---|---|
| başlangıç | 1575 | 63 | 15 | 0 | 29.9 | 0 / 0 | 0 |
| Devam 1 (L60) | 2261 | 180 | 281 | 0 | 62.1 | 2 sonuç / 1 görev | 15 |
| Devam 12 (L71) | 2404 | 180 | 352 | 0 | 63.7 | 4 / 1 | 16 |
| sahne döngüsü 1 (L3) | 1982 | 217 | 16 | 0 | 68.6 | 4 / 2 | 25 |
| sahne döngüsü 5 (L22) | 2001 | 219 | 16 | 0 | 73.1 | 11 / 6 | 25 |
| sahne döngüsü 12 (L124) | 2046 | **237** | 16 | 0 | **80.0** | **25 / 13** | **42** |

- Yetim düğüm, sızan tween/düğüm yok: aynı sahnede 12 Devam boyunca nesne/düğüm sayısı tahta boyutuyla dalgalanır, büyümez.
- **Sızıntı 1 — LevelPrefetch:** hiç `take` edilmeyen istek (tekrar oynanan seviyenin "sonraki"si, yarıda bırakılan
  zen tahtası, ana ekranın istediği ama oynanmayan seviye) `_tasks`ta kalıyor ve evden çıkarma döngüsü en eski
  kayıtta `break` ettiği için önbellek sınırı (4) hiç uygulanmıyordu: 12 döngüde 25 sonuç / 13 asılı görev.
- **Sızıntı 2 — bahçe doku önbelleği:** statik `_textures` sahneler arası paylaşılıyor; yalnız AYNI sahnedeki
  mekân geçişinde budanıyordu. Önceki sahnenin (başka mekân/mevsim) dokuları hiç atılmıyordu: 15 -> 42 doku;
  pencerede doku belleği 19.7 -> 48.1 MiB büyüdü (L100 39.0, zen 45.5).

## 4. İş parçacığı güvenliği (kod incelemesi)

- `LevelPrefetch`: iş yalnız saf üretim (`LevelGenerator`, `ZenMode.build_level`, `DailyPuzzle.build_level`; düğüm/
  autoload yok; tembel statik önbellekler ana iş parçacığında önceden dolduruluyor). Sonuç sözlüğü kilitle yazılır,
  yalnız ana iş parçacığında (kopya olarak) uygulanır. Yarış bulunmadı; tek kusur yukarıdaki sınırsız büyüme.
- Sahne çıkışında görev açık kalabilir ama sahneye dokunmaz; kapanışta `drain()` bekler. `GardenBackdrop` doku
  istekleri ana iş parçacığında alınıyor, çıkışta toplanıyor. Çevrimiçi kapı `HTTPRequest` (iş parçacıksız) yalnız
  denetim sırasında çalışıyor; reklam/elde tutma tarafında yoklama (polling) zamanlayıcısı yok.
- Ses: 43 akış, ilk çalışta eşzamanlı ve küçük (en büyüğü 1.2 MB müzik, 4 × 384 KB ortam); önbellekte ~3 MB.
