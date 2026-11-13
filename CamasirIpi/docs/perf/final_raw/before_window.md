# Başarım ölçümü (son geçiş): önce-pencere

- Tarih: 2026-11-13T23:45:00
- Godot: 4.7.2-stable (official), sürücü: macOS, işleyici: gl_compatibility, ekran kartı: Apple M4
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS

Pencere kipi, VSync kapalı: kare süresi = kare başına gerçek iş.

| Sahne | açılış eşzamanlı (ms) | ilk kare (ms) | kare ort (ms) | p99 (ms) | en kötü (ms) | düğüm _process/kare (ms) | çizim çağrısı ort / en çok | doku (MiB) | statik (MiB) | düğüm | işlenen düğüm | tween | takılma (eşik üstü kare) | Devam (ms) | kaplama (ekran) | saydam ama çizilen (ekran) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| boot -> ana ekran (0.4 sn bekleme dahil) | 697 | 19 | 1.21 | 2.62 | 3.4 | 0.02 | 161 / 161 | 19.7 | 55.1 | 293 | 1 | 3 | 0 | - | 5.7 | 0.00 |
| home | 3 | 3 | 1.21 | 3.06 | 3.9 | 0.02 | 108 / 108 | 19.7 | 54.3 | 198 | 1 | 1 | 0 | - | 4.1 | 0.00 |
| map açılış (soğuk) + boşta | 2 | 6 | 1.03 | 3.23 | 4.2 | 0.00 | 151 / 252 | 20.5 | 56.7 | 210 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (soğuk) | 9 | 20 | 0.91 | 2.71 | 3.6 | 0.00 | 138 / 239 | 22.4 | 61.5 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (soğuk) | 14 | 10 | 0.97 | 3.10 | 4.7 | 0.00 | 85 / 183 | 22.3 | 60.0 | 366 | 0 | 3 | 0 | - | 2.2 | 0.00 |
| map açılış (ılık) + boşta | 1 | 8 | 1.22 | 3.56 | 4.7 | 0.00 | 150 / 252 | 20.9 | 58.8 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (ılık) | 8 | 6 | 0.93 | 2.75 | 3.7 | 0.00 | 137 / 239 | 22.4 | 61.8 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (ılık) | 14 | 9 | 0.83 | 2.58 | 3.2 | 0.00 | 83 / 185 | 22.3 | 60.0 | 365 | 0 | 3 | 0 | - | 2.2 | 0.00 |
| map kaydırma | 0 | 4 | 1.47 | 3.64 | 3.9 | 0.36 | 128 / 258 | 20.9 | 58.8 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| game L5 | 137 | 11 | 1.12 | 2.58 | 10.5 | 0.03 | 85 / 112 | 22.1 | 64.4 | 252 | 6 | 2 | 0 | - | 5.5 | 0.00 |
| game L70 | 38 | 14 | 1.60 | 2.97 | 11.2 | 0.05 | 214 / 311 | 30.2 | 66.3 | 357 | 7 | 4 | 0 | - | 6.2 | 0.00 |
| game L88 | 32 | 7 | 1.72 | 3.22 | 4.1 | 0.05 | 290 / 382 | 34.4 | 66.6 | 389 | 8 | 4 | 0 | - | 5.6 | 0.03 |
| game L100 | 22 | 14 | 1.75 | 3.98 | 10.2 | 0.04 | 239 / 452 | 39.0 | 68.1 | 350 | 7 | 4 | 0 | - | 5.4 | 0.00 |
| game L65 -> 66 (Devam) | 20 | 8 | 1.76 | 3.41 | 19.4 | 0.05 | 268 / 485 | 48.1 | 69.6 | 631 | 7 | 1 | 0 | 14 | 6.6 | 0.00 |
| zen (2 tahta) | 11 | 6 | 1.28 | 2.79 | 13.9 | 0.04 | 128 / 157 | 45.5 | 67.9 | 289 | 18 | 3 | 0 | - | 4.4 | 0.03 |
| game L100 (ikinci açılış) | 11 | 6 | 1.80 | 4.01 | 6.3 | 0.04 | 240 / 452 | 40.8 | 68.8 | 350 | 7 | 4 | 0 | - | 5.4 | 0.00 |

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
- game L5 (6): game.gd×1, basket_view.gd×2, tutorial_director.gd×1, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L70 (7): game.gd×1, basket_view.gd×3, tutorial_director.gd×1, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L88 (8): game.gd×1, rain_cloud_view.gd×1, basket_view.gd×3, tutorial_director.gd×1, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L100 (7): game.gd×1, basket_view.gd×3, tutorial_director.gd×1, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L65 -> 66 (Devam) (7): game.gd×1, basket_view.gd×3, tutorial_director.gd×1, tutorial_hand.gd×1, garden_backdrop.gd×1
- zen (2 tahta) (18): game.gd×1, basket_view.gd×2, garment_view.gd×12, tutorial_director.gd×1, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L100 (ikinci açılış) (7): game.gd×1, basket_view.gd×3, tutorial_director.gd×1, tutorial_hand.gd×1, garden_backdrop.gd×1

