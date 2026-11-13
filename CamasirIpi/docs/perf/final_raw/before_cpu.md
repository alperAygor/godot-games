# Başarım ölçümü (son geçiş): önce-cpu

- Tarih: 2026-11-13T23:52:41
- Godot: 4.7.2-stable (official), sürücü: headless, işleyici: gl_compatibility, ekran kartı: 
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS

Başsız kip: kare süresi = betik + motor CPU (çizim yok). Çizim/doku sütunları anlamsız (0).

| Sahne | açılış eşzamanlı (ms) | ilk kare (ms) | kare ort (ms) | p99 (ms) | en kötü (ms) | düğüm _process/kare (ms) | çizim çağrısı ort / en çok | doku (MiB) | statik (MiB) | düğüm | işlenen düğüm | tween | takılma (eşik üstü kare) | Devam (ms) | kaplama (ekran) | saydam ama çizilen (ekran) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| boot -> ana ekran (0.4 sn bekleme dahil) | 699 | 2 | 0.02 | 0.02 | 0.1 | 0.01 | 0 / 0 | 0.0 | 60.6 | 293 | 1 | 2 | 0 | - | 5.3 | 0.00 |
| home | 2 | 1 | 0.01 | 0.02 | 0.1 | 0.01 | 0 / 0 | 0.0 | 59.8 | 198 | 1 | 1 | 0 | - | 3.8 | 0.00 |
| map açılış (soğuk) + boşta | 1 | 1 | 0.00 | 0.01 | 0.2 | 0.00 | 0 / 0 | 0.0 | 78.5 | 210 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (soğuk) | 9 | 11 | 0.00 | 0.01 | 0.3 | 0.00 | 0 / 0 | 0.0 | 84.9 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (soğuk) | 14 | 4 | 0.00 | 0.02 | 0.3 | 0.00 | 0 / 0 | 0.0 | 77.4 | 366 | 0 | 3 | 0 | - | 2.0 | 0.00 |
| map açılış (ılık) + boşta | 0 | 1 | 0.00 | 0.01 | 0.1 | 0.00 | 0 / 0 | 0.0 | 81.1 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| shop açılış (ılık) | 8 | 2 | 0.00 | 0.01 | 0.3 | 0.00 | 0 / 0 | 0.0 | 85.2 | 455 | 0 | 1 | 0 | - | 2.0 | 0.00 |
| collection açılış (ılık) | 14 | 4 | 0.00 | 0.02 | 0.3 | 0.00 | 0 / 0 | 0.0 | 77.5 | 365 | 0 | 3 | 0 | - | 2.0 | 0.00 |
| map kaydırma | 0 | 1 | 0.04 | 0.14 | 0.2 | 0.03 | 0 / 0 | 0.0 | 64.2 | 211 | 0 | 1 | 0 | - | 1.3 | 0.00 |
| game L5 | 136 | 1 | 0.02 | 0.04 | 2.0 | 0.02 | 0 / 0 | 0.0 | 77.4 | 252 | 5 | 2 | 0 | - | 5.4 | 0.00 |
| game L70 | 19 | 1 | 0.04 | 0.05 | 1.4 | 0.03 | 0 / 0 | 0.0 | 88.4 | 357 | 6 | 4 | 0 | - | 5.8 | 0.00 |
| game L88 | 15 | 1 | 0.04 | 0.06 | 1.7 | 0.04 | 0 / 0 | 0.0 | 87.9 | 389 | 7 | 4 | 0 | - | 5.0 | 0.02 |
| game L100 | 16 | 2 | 0.03 | 0.05 | 1.6 | 0.03 | 0 / 0 | 0.0 | 94.0 | 350 | 6 | 4 | 0 | - | 5.2 | 0.00 |
| game L65 -> 66 (Devam) | 17 | 2 | 0.04 | 0.06 | 12.9 | 0.03 | 0 / 0 | 0.0 | 101.8 | 631 | 6 | 0 | 2 | 12 | 5.2 | 0.00 |
| zen (2 tahta) | 4 | 1 | 0.03 | 0.04 | 7.3 | 0.03 | 0 / 0 | 0.0 | 94.4 | 289 | 17 | 2 | 1 | - | 3.5 | 0.02 |
| game L100 (ikinci açılış) | 9 | 1 | 0.03 | 0.05 | 1.6 | 0.03 | 0 / 0 | 0.0 | 95.6 | 350 | 6 | 4 | 0 | - | 5.2 | 0.00 |

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
- game L5 (5): game.gd×1, basket_view.gd×2, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L70 (6): game.gd×1, basket_view.gd×3, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L88 (7): game.gd×1, rain_cloud_view.gd×1, basket_view.gd×3, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L100 (6): game.gd×1, basket_view.gd×3, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L65 -> 66 (Devam) (6): game.gd×1, basket_view.gd×3, tutorial_hand.gd×1, garden_backdrop.gd×1
- zen (2 tahta) (17): game.gd×1, basket_view.gd×2, garment_view.gd×12, tutorial_hand.gd×1, garden_backdrop.gd×1
- game L100 (ikinci açılış) (6): game.gd×1, basket_view.gd×3, tutorial_hand.gd×1, garden_backdrop.gd×1

