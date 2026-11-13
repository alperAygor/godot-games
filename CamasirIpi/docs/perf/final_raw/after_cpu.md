# Başarım ölçümü (son geçiş): sonra-cpu

- Tarih: 2026-11-13T23:56:21
- Godot: 4.7.2-stable (official), sürücü: headless, işleyici: gl_compatibility, ekran kartı: 
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS

Başsız kip: kare süresi = betik + motor CPU (çizim yok). Çizim/doku sütunları anlamsız (0).

| Sahne | açılış eşzamanlı (ms) | ilk kare (ms) | kare ort (ms) | p99 (ms) | en kötü (ms) | düğüm _process/kare (ms) | çizim çağrısı ort / en çok | doku (MiB) | statik (MiB) | düğüm | işlenen düğüm | tween | takılma (eşik üstü kare) | Devam (ms) | kaplama (ekran) | saydam ama çizilen (ekran) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| boot -> ana ekran (0.4 sn bekleme dahil) | 419 | 3 | 0.02 | 0.02 | 0.1 | 0.01 | 0 / 0 | 0.0 | 63.5 | 293 | 1 | 2 | 0 | - | 5.3 | 0.00 |
| home | 3 | 1 | 0.01 | 0.02 | 0.1 | 0.01 | 0 / 0 | 0.0 | 62.7 | 198 | 1 | 1 | 0 | - | 3.8 | 0.00 |
| map açılış (soğuk) + boşta | 1 | 1 | 0.00 | 0.01 | 0.3 | 0.00 | 0 / 0 | 0.0 | 81.4 | 210 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (soğuk) | 9 | 12 | 0.00 | 0.01 | 0.3 | 0.00 | 0 / 0 | 0.0 | 87.7 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (soğuk) | 15 | 4 | 0.00 | 0.02 | 0.3 | 0.00 | 0 / 0 | 0.0 | 80.1 | 366 | 0 | 3 | 0 | - | 2.0 | 0.00 |
| map açılış (ılık) + boşta | 0 | 1 | 0.00 | 0.01 | 0.1 | 0.00 | 0 / 0 | 0.0 | 83.8 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (ılık) | 8 | 2 | 0.00 | 0.01 | 0.3 | 0.00 | 0 / 0 | 0.0 | 88.0 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (ılık) | 14 | 4 | 0.00 | 0.02 | 0.2 | 0.00 | 0 / 0 | 0.0 | 80.2 | 365 | 0 | 3 | 0 | - | 2.0 | 0.00 |
| map kaydırma | 0 | 1 | 0.03 | 0.14 | 0.2 | 0.03 | 0 / 0 | 0.0 | 67.0 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| game L5 | 12 | 1 | 0.02 | 0.03 | 1.9 | 0.02 | 0 / 0 | 0.0 | 77.4 | 252 | 4 | 2 | 0 | - | 5.4 | 0.00 |
| game L70 | 19 | 1 | 0.04 | 0.05 | 1.2 | 0.03 | 0 / 0 | 0.0 | 88.4 | 357 | 5 | 4 | 0 | - | 5.8 | 0.00 |
| game L88 | 15 | 1 | 0.04 | 0.06 | 1.7 | 0.04 | 0 / 0 | 0.0 | 83.7 | 389 | 6 | 4 | 0 | - | 5.0 | 0.02 |
| game L100 | 16 | 2 | 0.03 | 0.05 | 2.2 | 0.03 | 0 / 0 | 0.0 | 85.5 | 350 | 5 | 4 | 0 | - | 5.2 | 0.00 |
| game L65 -> 66 (Devam) | 19 | 2 | 0.04 | 0.06 | 13.0 | 0.03 | 0 / 0 | 0.0 | 96.5 | 631 | 5 | 0 | 2 | 12 | 5.2 | 0.00 |
| zen (2 tahta) | 7 | 1 | 0.03 | 0.04 | 7.3 | 0.03 | 0 / 0 | 0.0 | 88.4 | 289 | 16 | 2 | 1 | - | 3.5 | 0.02 |
| game L100 (ikinci açılış) | 12 | 1 | 0.03 | 0.05 | 1.6 | 0.03 | 0 / 0 | 0.0 | 89.7 | 350 | 5 | 4 | 0 | - | 5.2 | 0.00 |

## Saydam (alfa 0) ama çizim listesinde kalan büyük öğeler (ekranın >%25'i)


## Takılma kareleri (eşik: 4.0 ms; @ = karenin öncesindeki son olay)

- game L65 -> 66 (Devam): 13 ms @tahta 2, 6 ms @tahta 2
- zen (2 tahta): 7 ms @dokunuş 13

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
- game L5 (4): game.gd×1, basket_view.gd×2, garden_backdrop.gd×1
- game L70 (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- game L88 (6): game.gd×1, rain_cloud_view.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- game L100 (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- game L65 -> 66 (Devam) (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1
- zen (2 tahta) (16): game.gd×1, basket_view.gd×2, garment_view.gd×12, garden_backdrop.gd×1
- game L100 (ikinci açılış) (5): game.gd×1, basket_view.gd×3, garden_backdrop.gd×1

