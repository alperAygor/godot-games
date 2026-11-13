# Başarım ölçümü: baseline (sakin makine, ilk ölçüm)

> İşin başında, makine boşken alınan ilk ölçüm (probun ilk sürümü: "boot" satırı yok). Önce/sonra
> karşılaştırması için `baseline.md` + `after.md` (aynı yükte, arka arkaya) kullanılmalı.

- Tarih: 2026-11-13T16:41:03
- Godot: 4.7.2-stable (official), işleyici: gl_compatibility, ekran kartı: Apple M4
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS
- Pencere: (1255.0, 1920.0), VSync kapalı (kare süresi = gerçek iş).
- NOT: masaüstü sayıları orta sınıf Android'in VEKİLİDİR; mutlak değer değil önce/sonra oranı anlamlıdır.

## Sahneler

| Sahne | kare ort (ms) | kare p99 (ms) | kare en kötü (ms) | çizim CPU (ms) | 2B çizim çağrısı ort / en çok | 2B öğe | VRAM (MiB) | doku (MiB) | statik (MiB) | düğüm | yetim | ilk etkileşimli kare (ms) | üretim (ms) | Devam karesi (ms) | dokunuş |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| home | 1.48 | 3.12 | 9.7 | 0.24 | 79.0 / 79 | 104 | 65.0 | 58.8 | 48.6 | 161 | 0 | 199 | - | - | 0 |
| game L5 | 1.55 | 3.12 | 8.7 | 0.24 | 76.6 / 93 | 92 | 67.3 | 59.1 | 51.5 | 195 | 0 | 111 | 1 | - | 12 (kazandı) |
| game L30 | 1.97 | 3.49 | 4.6 | 0.46 | 171.6 / 235 | 304 | 74.3 | 66.0 | 56.0 | 257 | 0 | 54 | 31 | - | 67 (kazandı) |
| game L60 | 2.26 | 3.81 | 4.8 | 0.56 | 212.3 / 320 | 351 | 74.5 | 66.2 | 58.6 | 311 | 0 | 265 | 248 | - | 92 (kazandı) |
| game L75 | 2.25 | 3.81 | 5.1 | 0.57 | 214.5 / 343 | 356 | 74.5 | 66.2 | 58.5 | 311 | 0 | 213 | 195 | - | 95 (kazandı) |
| game L65 -> 66 (Devam) | 2.32 | 4.02 | 1027.2 | 0.57 | 219.7 / 427 | 360 | 80.6 | 72.1 | 63.9 | 472 | 0 | 108 | 93 | 1017 | 57 (bitmedi) |
| laundromat (full) | 1.71 | 3.30 | 3.7 | 0.33 | 117.0 / 117 | 182 | 97.2 | 89.0 | 63.9 | 211 | 0 | 60 | - | - | 0 |
| collection | 1.91 | 3.44 | 3.9 | 0.42 | 155.5 / 156 | 258 | 78.5 | 70.2 | 64.9 | 329 | 0 | 25 | - | - | 0 |

## LevelGenerator.generate 1..120 (ana iş parçacığında, eşzamanlı)

- Toplam: 13690 ms
- En kötü: 1292 ms (seviye 96)
- 100 ms üstü seviyeler (ms): 39 (204), 41 (219), 55 (547), 57 (652), 60 (250), 61 (276), 63 (280), 64 (104), 66 (993), 70 (175), 73 (215), 74 (168), 75 (194), 77 (1157), 78 (117), 90 (189), 92 (160), 93 (287), 96 (1292), 99 (445), 103 (125), 104 (125), 105 (177), 107 (115), 108 (787), 109 (105), 112 (117), 114 (202), 118 (170), 120 (158)

