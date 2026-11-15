# Denge simülasyonu raporu

240 koşu · 20 tohum × gemiler ['vektor', 'kasirga', 'mizrak', 'sahin'] × atölye ['fresh', 'mid', 'maxed'] × yapı ['none'] × politika ['random'] · 3 kariyer. Soyut model (sim v1): oranlar ve sürümler arası farklar anlamlıdır, mutlak sayılar değil.

Genel: medyan dalga **25.0** (p10 5.0, p90 40.5), medyan süre 431 sn, medyan öldürme 701, medyan koşu çekirdeği 542.0, zaman sınırına takılan: 0.

## Gemi
| gemi | medyan dalga | p10 | p90 | süre sn | çekirdek/koşu | ana ölüm nedeni |
|---|---|---|---|---|---|---|
| kasirga | 25.0 | 10.0 | 40.0 | 499 | 633.9 | bullet:sniper %23, boss:fan %18 |
| mizrak | 25.0 | 5.0 | 55.0 | 383 | 966.4 | blast:bomber %17, contact:chaser %13 |
| sahin | 20.0 | 5.0 | 41.0 | 356 | 608.0 | blast:bomber %15, boss:slam %13 |
| vektor | 25.0 | 5.0 | 40.5 | 455 | 802.6 | boss:slam %17, blast:bomber %12 |

## Atölye düzeyi
| düzey | medyan dalga | p10 | p90 | çekirdek/koşu | boss öldürme/koşu |
|---|---|---|---|---|---|
| fresh | 10.0 | 5.0 | 25.0 | 218.3 | 1.79 |
| maxed | 27.5 | 15.0 | 55.0 | 1280.6 | 5.47 |
| mid | 25.0 | 10.0 | 50.0 | 759.4 | 4.34 |

## Ölüm nedenleri (genel, canı bitiren son vuruş)
blast:bomber %15, bullet:sniper %14, boss:fan %11, boss:slam %11, boss:wave %10, contact:chaser %7, bullet:shooter %7, boss:aimed %5, bullet:orbiter %4, boss:radial %3, boss:shard %3, contact:swarmer %3

Alınan hasar payı: bullet:sniper %23, blast:bomber %13, boss:fan %11, boss:aimed %7, bullet:shooter %7, bullet:orbiter %6, boss:slam %6, boss:wave %5, boss:radial %4, boss:spiral %3

Medyan dalga zaman çizelgesi (sn → dalga): 30 sn → 4.0, 60 sn → 5.0, 120 sn → 9.0, 180 sn → 11.0, 240 sn → 15.0, 480 sn → 24.0

Düşman türü öldürme payı: swarmer %41, chaser %28, shooter %10, orbiter %6, bomber %6, sniper %5, tank %4

Boss öldürme (tür): sentinel 414, titan 271, frost 243

## Kartlar (rastgele politika: seçim oranı = seçilen/sunulan; kazanç = seçilince kalan dalga - sunulup geçilen)
| kart | kademe | sunulan | seçilen | seçim oranı | kazanç (dalga) ± s.h. | örnek |
|---|---|---|---|---|---|---|
| coklu | rare | 446 | 156 | %35 | +6.52 ± 1.46 | 156 |
| drone | epic | 169 | 60 | %36 | +3.38 ± 2.23 | 60 |
| s_hasat | synergy | 102 | 35 | %34 | +3.18 ± 3.22 | 35 |
| s_kale | synergy | 162 | 48 | %30 | +2.58 ± 2.27 | 48 |
| devmermi | common | 955 | 341 | %36 | +1.94 ± 0.99 | 341 |
| yenilenme | rare | 519 | 169 | %33 | +1.62 ± 1.34 | 169 |
| guc | common | 933 | 275 | %30 | +1.51 ± 0.97 | 275 |
| ikincisans | epic | 161 | 53 | %33 | +1.44 ± 2.53 | 53 |
| s_firtina | synergy | 117 | 32 | %27 | +0.94 ± 1.96 | 32 |
| tetik | common | 960 | 309 | %32 | +0.71 ± 1.01 | 309 |
| sok | rare | 508 | 160 | %32 | +0.53 ± 1.30 | 160 |
| kalkan | epic | 151 | 45 | %30 | +0.45 ± 2.78 | 45 |
| s_kovan | synergy | 43 | 13 | %30 | +0.33 ± 3.65 | 13 |
| zirh | common | 938 | 300 | %32 | +0.12 ± 0.95 | 300 |
| vampir | rare | 520 | 183 | %35 | -0.23 ± 1.28 | 183 |
| s_yildirim | synergy | 171 | 57 | %33 | -0.73 ± 1.73 | 57 |
| kritik | rare | 530 | 182 | %34 | -0.87 ± 1.19 | 182 |
| novacekirdek | rare | 508 | 180 | %35 | -1.10 ± 1.30 | 180 |
| miknatis | common | 948 | 334 | %35 | -1.24 ± 0.97 | 334 |
| diken | rare | 481 | 168 | %35 | -1.59 ± 1.26 | 168 |
| cevik | common | 929 | 318 | %34 | -1.61 ± 0.89 | 318 |
| patlayici | epic | 166 | 63 | %38 | -1.69 ± 2.28 | 63 |
| delici | rare | 486 | 166 | %34 | -2.06 ± 1.28 | 166 |
| atilma | common | 968 | 312 | %32 | -2.39 ± 0.94 | 312 |
| zincir | rare | 514 | 165 | %32 | -2.92 ± 1.26 | 165 |
| s_kiyamet | synergy | 50 | 21 | %42 | -3.01 ± 4.19 | 21 |

Not: rastgele politikada seçim oranı ~%33 beklenir (bilgi taşımaz); anlamlı olan kazançtır. |kazanç| < 2 × s.h. ise gürültüdür (daha çok tohum: --seeds=60).

## Kariyer (atölye + gemi tüketimi, 'greedy' kart politikası)
3/3 kariyerde atölye+gemiler tükendi. Koşu sayısı: medyan 4 (min 3, max 5); oyun süresi medyan 57 dk; toplam çekirdek medyan 7366. İlk 5 koşu ort. dalga 43.1, son 5: 43.1.
Gemi kullanım payı (kariyer boyunca): kasirga %10, mizrak %48, sahin %15, vektor %27 · gemi alınma koşusu: s:kasirga #2, s:mizrak #3, s:sahin #4
Her şey alındıktan sonra (12 koşu): kullanım kasirga %6, mizrak %58, sahin %19, vektor %17 · ort. dalga kasirga 31.0, mizrak 49.1, sahin 40.3, vektor 37.3

## Kariyer (atölye + gemi tüketimi, 'random' kart politikası)
3/3 kariyerde atölye+gemiler tükendi. Koşu sayısı: medyan 7 (min 6, max 8); oyun süresi medyan 63 dk; toplam çekirdek medyan 5807. İlk 5 koşu ort. dalga 26.3, son 5: 30.9.
Gemi kullanım payı (kariyer boyunca): kasirga %19, mizrak %37, sahin %10, vektor %33 · gemi alınma koşusu: s:kasirga #5, s:mizrak #7, s:sahin #7
Her şey alındıktan sonra (12 koşu): kullanım kasirga %17, mizrak %56, sahin %17, vektor %11 · ort. dalga kasirga 37.7, mizrak 35.0, sahin 25.0, vektor 33.8

## Doğrulamalar
geçti
