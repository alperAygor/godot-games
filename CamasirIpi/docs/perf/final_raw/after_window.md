# Başarım ölçümü (son geçiş): sonra-pencere-2

- Tarih: 2026-11-14T00:07:35
- Godot: 4.7.2-stable (official), sürücü: macOS, işleyici: gl_compatibility, ekran kartı: Apple M4
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS

Pencere kipi, VSync kapalı: kare süresi = kare başına gerçek iş.

| Sahne | açılış eşzamanlı (ms) | ilk kare (ms) | kare ort (ms) | p99 (ms) | en kötü (ms) | düğüm _process/kare (ms) | çizim çağrısı ort / en çok | doku (MiB) | statik (MiB) | düğüm | işlenen düğüm | tween | takılma (eşik üstü kare) | Devam (ms) | kaplama (ekran) | saydam ama çizilen (ekran) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| boot -> ana ekran (0.4 sn bekleme dahil) | 420 | 17 | 1.43 | 4.00 | 7.3 | 0.02 | 160 / 160 | 19.7 | 58.0 | 293 | 1 | 3 | 0 | - | 5.7 | 0.00 |
| home | 3 | 3 | 1.18 | 2.84 | 5.0 | 0.02 | 107 / 107 | 19.7 | 57.2 | 198 | 1 | 1 | 0 | - | 4.1 | 0.00 |
| map açılış (soğuk) + boşta | 2 | 5 | 1.01 | 2.85 | 4.0 | 0.00 | 152 / 251 | 20.5 | 59.6 | 210 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (soğuk) | 10 | 26 | 0.91 | 2.72 | 3.5 | 0.00 | 138 / 238 | 22.4 | 64.2 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (soğuk) | 15 | 11 | 0.85 | 2.59 | 3.2 | 0.00 | 84 / 182 | 22.3 | 62.7 | 366 | 0 | 3 | 0 | - | 2.2 | 0.00 |
| map açılış (ılık) + boşta | 0 | 4 | 1.17 | 3.27 | 4.4 | 0.00 | 153 / 251 | 20.9 | 61.5 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (ılık) | 9 | 6 | 1.20 | 3.55 | 4.7 | 0.00 | 137 / 238 | 22.4 | 64.6 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (ılık) | 14 | 9 | 0.98 | 2.95 | 3.7 | 0.00 | 83 / 184 | 22.3 | 62.8 | 365 | 0 | 3 | 0 | - | 2.2 | 0.00 |
| map kaydırma | 0 | 4 | 1.54 | 3.66 | 4.4 | 0.38 | 128 / 257 | 20.9 | 61.5 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| game L5 | 13 | 9 | 1.17 | 2.69 | 8.5 | 0.03 | 86 / 110 | 22.1 | 64.5 | 252 | 5 | 2 | 0 | - | 5.5 | 0.00 |
| game L70 | 39 | 14 | 1.59 | 3.02 | 11.9 | 0.04 | 214 / 311 | 30.2 | 66.3 | 357 | 5 | 4 | 0 | - | 6.2 | 0.00 |
| game L88 | 31 | 6 | 1.70 | 3.23 | 3.9 | 0.05 | 290 / 382 | 28.8 | 66.5 | 389 | 6 | 4 | 0 | - | 5.6 | 0.03 |
| game L100 | 22 | 13 | 1.76 | 4.17 | 10.5 | 0.04 | 239 / 453 | 27.9 | 67.9 | 350 | 5 | 4 | 0 | - | 5.4 | 0.00 |
| game L65 -> 66 (Devam) | 37 | 8 | 1.73 | 3.36 | 20.2 | 0.05 | 267 / 485 | 41.5 | 69.2 | 631 | 5 | 1 | 0 | 14 | 6.6 | 0.00 |
| zen (2 tahta) | 26 | 6 | 1.24 | 2.75 | 11.2 | 0.03 | 128 / 157 | 38.2 | 67.3 | 289 | 17 | 3 | 0 | - | 4.4 | 0.03 |
| game L100 (ikinci açılış) | 30 | 7 | 1.75 | 4.05 | 6.5 | 0.04 | 239 / 452 | 33.5 | 68.3 | 350 | 5 | 4 | 0 | - | 5.4 | 0.00 |

## Saydam (alfa 0) ama çizim listesinde kalan büyük öğeler (ekranın >%25'i)


## Takılma kareleri (eşik: 33.3 ms; @ = karenin öncesindeki son olay)


## Ölçüm sonunda `_process` alan düğümler (script başına)

- boot -> ana ekran (0.4 sn bekleme dahil) (1): garden_backdrop.gd×1
- home (1): garden_backdrop.gd×1
- map açılış (soğuk) + boşta (0): 
- shop açılış (soğuk) (0): 
- collection açılış (soğuk) (0): 
- map açılış (ılık) + boşta (0): 
- shop açılış (ılık) (0): 
- collection açılış (ılık) (0): 
- map kaydırma (0): 
- game L5 (5): game.gd×1, basket_view.gd×2, tutorial_director.gd×1, garden_backdrop.gd×1
- game L70 (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- game L88 (6): game.gd×1, rain_cloud_view.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- game L100 (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- game L65 -> 66 (Devam) (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- zen (2 tahta) (17): game.gd×1, basket_view.gd×2, garment_view.gd×12, tutorial_director.gd×1, garden_backdrop.gd×1
- game L100 (ikinci açılış) (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1

