# Başarım ölçümü: after

- Tarih: 2026-11-13T17:34:04
- Godot: 4.7.2-stable (official), işleyici: gl_compatibility, ekran kartı: Apple M4
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS
- Pencere: (1250.0, 1920.0), VSync kapalı (kare süresi = gerçek iş).
- NOT: masaüstü sayıları orta sınıf Android'in VEKİLİDİR; mutlak değer değil önce/sonra oranı anlamlıdır.

## Sahneler

| Sahne | kare ort (ms) | kare p99 (ms) | kare en kötü (ms) | çizim CPU (ms) | 2B çizim çağrısı ort / en çok | 2B öğe | VRAM (MiB) | doku (MiB) | statik (MiB) | düğüm | yetim | ilk etkileşimli kare (ms) | üretim (ms) | Devam karesi (ms) | dokunuş |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| boot -> ilk sahne | 2.41 | 5.27 | 17.4 | 0.47 | 79.0 / 79 | 104 | 37.8 | 31.7 | 50.3 | 161 | 0 | 414 | - | - | 0 |
| home | 2.35 | 4.97 | 5.9 | 0.45 | 79.0 / 79 | 104 | 37.8 | 31.7 | 50.4 | 161 | 0 | 8 | - | - | 0 |
| game L5 | 2.30 | 4.61 | 14.9 | 0.44 | 76.5 / 91 | 92 | 42.3 | 34.1 | 53.3 | 195 | 0 | 210 | 1 | - | 12 (kazandı) |
| game L30 | 2.89 | 5.42 | 7.9 | 0.90 | 172.3 / 235 | 305 | 44.8 | 36.6 | 57.8 | 257 | 0 | 93 | 61 | - | 67 (kazandı) |
| game L60 | 3.11 | 5.89 | 8.6 | 1.06 | 213.2 / 320 | 353 | 45.1 | 36.8 | 60.6 | 310 | 0 | 505 | 482 | - | 92 (kazandı) |
| game L75 | 3.04 | 5.97 | 11.1 | 1.09 | 214.0 / 343 | 356 | 45.1 | 36.8 | 60.7 | 311 | 0 | 402 | 379 | - | 95 (kazandı) |
| game L65 -> 66 (Devam) | 3.27 | 6.51 | 36.9 | 1.14 | 225.9 / 427 | 369 | 48.9 | 40.4 | 66.2 | 472 | 0 | 202 | 180 | 26 | 57 (bitmedi) |
| laundromat (full) | 1.92 | 4.39 | 5.7 | 0.29 | 43.2 / 117 | 83 | 51.3 | 43.1 | 66.0 | 211 | 0 | 72 | - | - | 0 |
| collection | 2.64 | 5.04 | 5.9 | 0.47 | 82.8 / 150 | 161 | 46.7 | 38.4 | 67.0 | 329 | 0 | 49 | - | - | 0 |

## LevelGenerator.generate 1..120 (ana iş parçacığında, eşzamanlı)

- Toplam: 26467 ms
- En kötü: 2498 ms (seviye 96)
- 100 ms üstü seviyeler (ms): 34 (113), 38 (166), 39 (397), 41 (427), 43 (102), 45 (118), 55 (1061), 56 (170), 57 (1262), 58 (109), 59 (116), 60 (482), 61 (537), 62 (157), 63 (542), 64 (203), 65 (178), 66 (1919), 67 (121), 68 (124), 69 (123), 70 (341), 71 (137), 72 (182), 73 (417), 74 (326), 75 (378), 76 (184), 77 (2239), 78 (227), 79 (124), 80 (165), 81 (134), 82 (167), 83 (138), 84 (170), 85 (128), 86 (155), 87 (155), 88 (142), 89 (147), 90 (366), 91 (162), 92 (309), 93 (560), 94 (145), 95 (169), 96 (2498), 97 (107), 98 (164), 99 (857), 100 (176), 101 (160), 102 (138), 103 (240), 104 (240), 105 (342), 106 (136), 107 (221), 108 (1504), 109 (201), 110 (190), 111 (114), 112 (224), 113 (116), 114 (389), 115 (140), 116 (141), 117 (115), 118 (325), 119 (163), 120 (303)


## Önce / sonra özeti (aynı makine yükü, `baseline.md` ile arka arkaya)

| Ölçü | Önce | Sonra | Neden |
|---|---|---|---|
| "Devam" karesi L65 -> 66 | 1944 ms | 26 ms | `LevelPrefetch`: sonraki seviye oynarken iş parçacığında üretilir |
| Boot -> ilk sahne (0.4 sn bekleme dahil) | 654 ms | 414 ms | Bahçe dokuları beklemede paralel yüklenir + kalıcı önbellek; seviye önceden üretilir |
| VRAM ana ekran | 65.7 MiB | 37.8 MiB | Bahçe katmanları VRAM sıkıştırmalı (BPTC/ASTC), çamaşırlar 384 px |
| VRAM oyun (L60) | 75.2 MiB | 45.1 MiB | aynı |
| VRAM çamaşırhane (ana ekran üstünde) | 97.8 MiB | 51.3 MiB | 47 oda katmanı VRAM sıkıştırmalı |
| Çizim çağrısı çamaşırhane | 117 | 43 | Arkadaki (görünmeyen) ana ekran opakken gizlenir |
| Çizim çağrısı koleksiyon | 156 | 83 | aynı |
| Kare ort / p99 çamaşırhane | 3.07 / 5.18 ms | 1.92 / 4.39 ms | aynı |
| Kare ort / p99 oyun L60 | 4.06 / 7.78 ms | 3.11 / 5.89 ms | kare başı yeniden çizim/gradyan/ton yazımları kaldırıldı |
| Üretim en kötü (L96), ana iş parçacığında | 2488 ms | 2498 ms (artık arka planda) | Üretici değişmedi; yalnız ana iş parçacığından çıktı |

Mobil VRAM tahmini: ASTC 4x4 = 1 bayt/piksel (RGBA8'in 1/4'ü). Masaüstü (Apple M4, GL 4.1) BPTC'yi
de 1 bayt/piksel tuttuğu için masaüstü ölçümü mobil kazancın iyi bir vekili; ASTC desteklemeyen eski
GPU'larda Godot dokuyu CPU'da açar (görüntü aynı, bellek kazancı olmaz).

Notlar:
- Kare süreleri VSync kapalı ölçüldü; makine başka bir Godot oturumuyla paylaşıldığı için ±%20
  gürültü var. Çizim çağrısı ve bellek sayıları gürültüsüzdür.
- Oyun sahnesi TTI'si (L60 ~500 ms) probun SEVİYEYİ DOĞRUDAN açmasından gelir (eşzamanlı üretim
  dahil); gerçek akışta seviye ana ekranda/önceki seviyede önceden üretilir ("Devam" satırı).
- Öğretici çözücü çağrıları ölçüldü: seviye 1-12, sapmalı yollar dahil en kötü 0.8 ms (masaüstü);
  kare bütçesinin çok altında olduğu için ana iş parçacığında bırakıldı.
