# Başarım ölçümü (son geçiş): önce-sızıntı

- Tarih: 2026-11-13T23:48:53
- Godot: 4.7.2-stable (official), sürücü: headless, işleyici: gl_compatibility, ekran kartı: 
- İşlemci: Apple M4 (10 çekirdek), işletim sistemi: macOS

Sızıntı döngüsü: 12 seviye tek sahnede Devam ile (L60..), sonra 12 tam sahne döngüsü (ana ekran + harita/mağaza/koleksiyon aç-kapa -> oyun -> serbest). Ölçüm her adımın sonunda; sahne döngüsü satırlarında sahne yoktur. time_scale=3.

| Adım | nesne | kaynak | düğüm | yetim | statik (MiB) | doku (MiB) | tween | LevelPrefetch | bahçe doku önbelleği |
|---|---|---|---|---|---|---|---|---|---|
| başlangıç (sahne yok) | 1575 | 63 | 15 | 0 | 29.9 | 0.0 | 0 | 0 sonuç / 0 görev | 0 (+0 istek) |
| Devam 1 (L60 bitti) | 2261 | 180 | 281 | 0 | 62.1 | 0.0 | 6 | 2 sonuç / 1 görev | 15 (+5 istek) |
| Devam 2 (L61 bitti) | 2330 | 176 | 345 | 0 | 61.2 | 0.0 | 8 | 3 sonuç / 1 görev | 16 (+0 istek) |
| Devam 3 (L62 bitti) | 2316 | 176 | 341 | 0 | 61.4 | 0.0 | 6 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 4 (L63 bitti) | 2317 | 176 | 341 | 0 | 61.4 | 0.0 | 6 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 5 (L64 bitti) | 2362 | 178 | 356 | 0 | 63.5 | 0.0 | 8 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 6 (L65 bitti) | 2399 | 179 | 352 | 0 | 63.6 | 0.0 | 6 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 7 (L66 bitti) | 2402 | 180 | 352 | 0 | 63.7 | 0.0 | 6 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 8 (L67 bitti) | 2403 | 180 | 352 | 0 | 63.7 | 0.0 | 6 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 9 (L68 bitti) | 2425 | 180 | 356 | 0 | 63.7 | 0.0 | 8 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 10 (L69 bitti) | 2387 | 178 | 341 | 0 | 61.9 | 0.0 | 6 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 11 (L70 bitti) | 2425 | 180 | 356 | 0 | 63.7 | 0.0 | 8 | 4 sonuç / 1 görev | 16 (+0 istek) |
| Devam 12 (L71 bitti) | 2404 | 180 | 352 | 0 | 63.7 | 0.0 | 6 | 4 sonuç / 1 görev | 16 (+0 istek) |
| sahne döngüsü 1 (L3) | 1982 | 217 | 16 | 0 | 68.6 | 0.0 | 0 | 4 sonuç / 2 görev | 25 (+0 istek) |
| sahne döngüsü 2 (L8) | 1983 | 217 | 16 | 0 | 68.8 | 0.0 | 0 | 5 sonuç / 3 görev | 25 (+0 istek) |
| sahne döngüsü 3 (L14) | 1990 | 218 | 16 | 0 | 71.1 | 0.0 | 0 | 7 sonuç / 4 görev | 25 (+0 istek) |
| sahne döngüsü 4 (L18) | 1991 | 218 | 16 | 0 | 71.4 | 0.0 | 0 | 9 sonuç / 5 görev | 25 (+0 istek) |
| sahne döngüsü 5 (L22) | 2001 | 219 | 16 | 0 | 73.1 | 0.0 | 0 | 11 sonuç / 6 görev | 25 (+0 istek) |
| sahne döngüsü 6 (L26) | 2001 | 219 | 16 | 0 | 73.1 | 0.0 | 0 | 13 sonuç / 7 görev | 25 (+0 istek) |
| sahne döngüsü 7 (L31) | 2013 | 224 | 16 | 0 | 73.8 | 0.0 | 0 | 15 sonuç / 8 görev | 29 (+0 istek) |
| sahne döngüsü 8 (L36) | 2014 | 224 | 16 | 0 | 73.9 | 0.0 | 0 | 17 sonuç / 9 görev | 29 (+0 istek) |
| sahne döngüsü 9 (L64) | 2015 | 224 | 16 | 0 | 74.4 | 0.0 | 0 | 19 sonuç / 10 görev | 29 (+0 istek) |
| sahne döngüsü 10 (L82) | 2035 | 233 | 16 | 0 | 78.7 | 0.0 | 0 | 21 sonuç / 11 görev | 38 (+0 istek) |
| sahne döngüsü 11 (L94) | 2045 | 237 | 16 | 0 | 79.8 | 0.0 | 0 | 23 sonuç / 12 görev | 42 (+0 istek) |
| sahne döngüsü 12 (L124) | 2046 | 237 | 16 | 0 | 80.0 | 0.0 | 0 | 25 sonuç / 13 görev | 42 (+0 istek) |

