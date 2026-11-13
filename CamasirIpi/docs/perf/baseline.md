# Başarım ölçümü: baseline

> Değişiklik öncesi kod (HEAD e320dbe'nin `git archive` kopyası, aynı `tools/perf_probe.gd`),
> `after.md` ile ARKA ARKAYA aynı makine yükünde ölçüldü. Makinede başka bir Godot oturumu
> çalışıyordu: mutlak süreler `baseline_quiet.md`deki (sakin makine, ilk ölçüm) değerlerin ~2 katı.

- Tarih: 2026-11-13T17:30:50
- Godot: 4.7.2-stable (official), işleyici: gl_compatibility, ekran kartı: Apple M4
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS
- Pencere: (1250.0, 1920.0), VSync kapalı (kare süresi = gerçek iş).
- NOT: masaüstü sayıları orta sınıf Android'in VEKİLİDİR; mutlak değer değil önce/sonra oranı anlamlıdır.

## Sahneler

| Sahne | kare ort (ms) | kare p99 (ms) | kare en kötü (ms) | çizim CPU (ms) | 2B çizim çağrısı ort / en çok | 2B öğe | VRAM (MiB) | doku (MiB) | statik (MiB) | düğüm | yetim | ilk etkileşimli kare (ms) | üretim (ms) | Devam karesi (ms) | dokunuş |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| boot -> ilk sahne | 2.26 | 4.41 | 5.8 | 0.46 | 79.0 / 79 | 104 | 65.7 | 59.5 | 49.9 | 161 | 0 | 654 | - | - | 0 |
| home | 2.32 | 4.56 | 5.8 | 0.46 | 79.0 / 79 | 104 | 65.7 | 59.5 | 50.0 | 161 | 0 | 9 | - | - | 0 |
| game L5 | 2.68 | 5.11 | 17.6 | 0.49 | 76.0 / 93 | 91 | 67.9 | 59.7 | 52.8 | 195 | 0 | 214 | 1 | - | 12 (kazandı) |
| game L30 | 3.52 | 6.81 | 10.6 | 1.00 | 170.4 / 235 | 302 | 74.9 | 66.7 | 57.1 | 257 | 0 | 103 | 59 | - | 67 (kazandı) |
| game L60 | 4.06 | 7.78 | 13.0 | 1.27 | 212.9 / 320 | 352 | 75.2 | 66.9 | 59.8 | 311 | 0 | 512 | 486 | - | 92 (kazandı) |
| game L75 | 4.07 | 8.33 | 16.6 | 1.29 | 212.9 / 343 | 354 | 75.2 | 66.9 | 59.7 | 311 | 0 | 411 | 378 | - | 95 (kazandı) |
| game L65 -> 66 (Devam) | 4.09 | 8.50 | 1959.2 | 1.24 | 212.6 / 427 | 351 | 81.3 | 72.8 | 65.1 | 472 | 0 | 208 | 191 | 1944 | 57 (bitmedi) |
| laundromat (full) | 3.07 | 5.18 | 5.9 | 0.63 | 117.0 / 117 | 182 | 97.8 | 89.6 | 64.9 | 211 | 0 | 116 | - | - | 0 |
| collection | 3.31 | 5.28 | 5.5 | 0.94 | 155.5 / 156 | 258 | 79.0 | 70.7 | 65.9 | 329 | 0 | 53 | - | - | 0 |

## LevelGenerator.generate 1..120 (ana iş parçacığında, eşzamanlı)

- Toplam: 26319 ms
- En kötü: 2488 ms (seviye 96)
- 100 ms üstü seviyeler (ms): 34 (111), 38 (165), 39 (394), 41 (423), 43 (101), 45 (117), 55 (1053), 56 (168), 57 (1250), 58 (109), 59 (115), 60 (477), 61 (531), 62 (156), 63 (536), 64 (200), 65 (176), 66 (1892), 67 (119), 68 (122), 69 (121), 70 (337), 71 (135), 72 (180), 73 (412), 74 (323), 75 (374), 76 (182), 77 (2224), 78 (225), 79 (122), 80 (164), 81 (133), 82 (165), 83 (137), 84 (169), 85 (127), 86 (153), 87 (153), 88 (140), 89 (145), 90 (362), 91 (161), 92 (305), 93 (557), 94 (145), 95 (169), 96 (2488), 97 (106), 98 (164), 99 (858), 100 (177), 101 (161), 102 (139), 103 (240), 104 (241), 105 (343), 106 (137), 107 (222), 108 (1513), 109 (202), 110 (190), 111 (115), 112 (225), 113 (117), 114 (390), 115 (140), 116 (142), 117 (116), 118 (326), 119 (164), 120 (304)

