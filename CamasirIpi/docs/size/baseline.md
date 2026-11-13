# Boyut taban cizgisi (baseline)

Olcum tarihi: 2026-11-13, Godot 4.7.2, dal `orch/r-size`, taban commit `a5edf38`.
Araclar: `tools/size_report.py`, `tools/pck_check.py`, `tools/audio_quality.py` (bu belge `python3 tools/size_report.py --pck build/size/naive.pck` ile uretildi).

## Yontem

* `export_presets.cfg` icinde `Pack baseline (no filters)` onayari (Android, tum kaynaklar, filtre yok) ile
  `godot --headless --path . --export-pack "Pack baseline (no filters)" build/size/naive.pck` calistirildi.
  Android SDK/JDK/keystore GEREKMEZ; `--export-pack` yalniz PCK uretir (sablon APK'si okunmaz).
* PCK dizini (GDPC v4) `size_report.read_pck` ile ayristirildi: dosya dokumu ve her dosyanin DEFLATE ile
  sikistirilmis boyutu (APK/AAB icindeki asset'ler deflate edilir; indirme boyutuna daha yakin bir olcu).
* Gercek APK/AAB uretilemedi: bu makinede Android SDK/keystore yok (kurulum yasak). Motor kismi sablon
  APK'sindan (`export_templates/4.7.2.stable/android_release.apk`) olculdu.

## Ozet (taban cizgisi)

| olcu | deger |
|---|---:|
| PCK (filtresiz) | **42.08 MiB** (44 124 212 bayt), 1221 dosya |
| PCK DEFLATE tahmini | **25.25 MiB** |
| `libgodot_android.so` arm64-v8a (sablon) | 67.8 MiB ham / 22.9 MiB deflate |
| 4 ABI'nin tamami (sablon APK'si varsayilani) | 4 x ~70 MiB ham `.so` |
| `docs/` (gdignore, paketlenmez) | 422.8 MiB, 692 dosya |

Onemli bulgular:

1. Paketin %80'i ASTC dokulari (33.86 MiB). Yalniz ASTC gider; BPTC (33.86 MiB, masaustu) PCK'ya girmez
   (`Desktop pack check (Linux)` onayariyla dogrulandi: orada BPTC gider, ASTC gitmez; ikisi birden asla gitmez).
   ETC2 de uretilmiyor/gonderilmiyor (`compress/high_quality=true` -> ASTC 4x4 + BPTC).
2. Kaynak PNG'ler (29 MiB) ve 768 px garment kaynaklari PAKETE GIRMEZ; yalniz `.ctex` girer (dogrulandi).
3. Filtresiz paket `tests/`, `tools/` betiklerini (~0.3 MiB), AdMob editor/mock/export kodunu ve kullanilmayan
   `crate_wood.glb`, `icon_dryer/icon_washer.png` dosyalarini da tasiyordu.
4. `garden_ambience.wav` tek tipti ki sikistirilmamisti (PCM 1.85 MiB); diger uc ambiyans ve 37 SFX zaten QOA.
5. Font (`Baloo2.ttf`) 336 KiB ice aktarilmisti; oyun yalniz Latin (tr/en/es) kullaniyor.
6. Android'de asil agirlik MOTOR: arm64 `libgodot_android.so` 67.8 MiB ham. Pakete gore ~3 kat buyuk (bkz. `docs/size/after.md`, "yapilmayanlar").

# Ayrintili rapor (otomatik)

## 1. Kaynak boyutu (calisma agaci, klasor basina)

| klasor | boyut | dosya |
|---|---:|---:|
| docs | 422.79 MB | 692 |
| assets/sprites | 29.17 MB | 327 |
| assets/audio | 10.98 MB | 86 |
| tools | 1.16 MB | 59 |
| scripts | 1.12 MB | 308 |
| addons/admob | 658.07 KB | 234 |
| tests | 259.13 KB | 110 |
| data | 105.47 KB | 27 |
| assets/fonts | 102.57 KB | 3 |
| assets/third_party | 93.75 KB | 3 |
| assets/icons | 49.88 KB | 70 |
| (kok dosyalar) | 15.27 KB | 9 |
| assets/shaders | 7.16 KB | 6 |
| assets/theme | 6.92 KB | 1 |
| scenes | 5.90 KB | 10 |
| .godot (yerel onbellek) | 242.69 MB | - |
| build (yerel onbellek) | 121.86 MB | - |

## 2. Ice aktarilan boyut (.godot/imported, bicim basina)

| bicim | .godot/imported toplami | Android paketine giren |
|---|---:|---:|
| doku BPTC (masaustu) | 33.86 MB | 0 B |
| doku ASTC | 33.86 MB | 33.86 MB |
| ses WAV/QOA (.sample) | 1.99 MB | 1.99 MB |
| doku (kayipsiz/yan bicim) | 1.57 MB | 1.57 MB |
| ses OGG | 1.21 MB | 1.21 MB |
| font | 56.15 KB | 56.15 KB |
| sahne/kaynak (ikili) | 53.47 KB | 53.47 KB |
| data/ (ham) | 34.44 KB | 34.44 KB |

(docs/tests/tools/dislanan kaynaklarin .godot onbellegi, rapora girmez: 156.99 MB)

Kaynak PNG toplami (gonderilmez, yalniz .ctex gider): 29.01 MB

## 3. Ses (kaynak dosya, sure, bit hizi, ice aktarilan boyut)

| dosya | sure | kaynak | bit hizi | ice aktarilan | bicim |
|---|---:|---:|---:|---:|---|
| assets/audio/music/music_garden.ogg | 57.03s | 1.19 MB | 175 kbps | 1.21 MB | vorbis 44100Hz 2ch |
| assets/audio/sfx/basket_slide.wav | 0.50s | 42.78 KB | 706 kbps | 9.08 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/beach_ambience.wav | 22.00s | 1.85 MB | 706 kbps | 383.86 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/bird_chirp.wav | 0.78s | 67.68 KB | 706 kbps | 14.11 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/bird_flutter.wav | 0.49s | 41.98 KB | 706 kbps | 8.92 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/bird_splat.wav | 0.13s | 11.54 KB | 706 kbps | 2.76 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/blocked.wav | 0.48s | 41.42 KB | 706 kbps | 8.81 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/cat_meow.wav | 0.88s | 75.88 KB | 706 kbps | 15.77 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/cat_purr.wav | 1.48s | 127.56 KB | 706 kbps | 26.22 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/chest_open.wav | 1.28s | 110.33 KB | 706 kbps | 22.75 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/cloth.wav | 0.42s | 36.56 KB | 706 kbps | 7.81 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/cloth_1.wav | 0.42s | 36.56 KB | 706 kbps | 7.81 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/cloth_2.wav | 0.38s | 32.61 KB | 706 kbps | 7.02 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/cloth_3.wav | 0.40s | 34.84 KB | 706 kbps | 7.46 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/coin.wav | 0.46s | 39.49 KB | 706 kbps | 8.39 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/dryer_tumble.wav | 1.83s | 157.70 KB | 706 kbps | 32.32 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/fold_puff.wav | 0.46s | 39.27 KB | 706 kbps | 8.36 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/garden_ambience.wav | 22.00s | 1.85 MB | 706 kbps | 383.86 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/level_start.wav | 0.93s | 80.50 KB | 706 kbps | 16.71 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/lock_rattle.wav | 0.21s | 17.86 KB | 706 kbps | 4.03 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/lose.wav | 1.47s | 126.66 KB | 706 kbps | 26.04 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/machine_done.wav | 0.54s | 46.52 KB | 706 kbps | 9.82 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/machine_door.wav | 0.40s | 34.38 KB | 706 kbps | 7.38 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/machine_tumble.wav | 1.45s | 124.97 KB | 706 kbps | 25.71 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/mud_squish.wav | 0.26s | 22.35 KB | 706 kbps | 4.95 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/night_ambience.wav | 22.00s | 1.85 MB | 706 kbps | 383.86 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/note.wav | 0.83s | 71.68 KB | 706 kbps | 14.93 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/pin_click.wav | 0.08s | 7.36 KB | 706 kbps | 1.90 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/pin_click_1.wav | 0.08s | 7.36 KB | 706 kbps | 1.90 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/pin_click_2.wav | 0.11s | 9.31 KB | 706 kbps | 2.29 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/pin_click_3.wav | 0.10s | 8.66 KB | 706 kbps | 2.16 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/purchase.wav | 0.58s | 50.36 KB | 706 kbps | 10.62 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/rack_hang.wav | 0.12s | 9.98 KB | 706 kbps | 2.43 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/rain_patter.wav | 2.48s | 213.69 KB | 706 kbps | 43.66 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/rooftop_ambience.wav | 22.00s | 1.85 MB | 706 kbps | 383.86 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/sparkle.wav | 0.66s | 57.32 KB | 706 kbps | 12.01 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/success.wav | 1.76s | 151.64 KB | 706 kbps | 31.07 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/ui_soft.wav | 0.14s | 11.84 KB | 706 kbps | 2.82 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/ui_tap.wav | 0.48s | 41.42 KB | 706 kbps | 8.81 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/unlock.wav | 0.21s | 17.96 KB | 706 kbps | 4.04 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/win.wav | 1.54s | 133.10 KB | 706 kbps | 27.36 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/wind.wav | 2.32s | 199.85 KB | 706 kbps | 40.85 KB | 44100Hz 1ch 16bit |
| assets/audio/sfx/wring.wav | 1.00s | 86.21 KB | 706 kbps | 17.86 KB | 44100Hz 1ch 16bit |

Ses toplami: kaynak 10.96 MB, ice aktarilan 3.20 MB

## 4. En buyuk 40 gonderilen dosya (GERCEK PCK: build/size/naive.pck)

| boyut | dosya |
|---:|---|
| 1.85 MB | .godot/imported/garden_ambience.wav-2460a7c04c81563d1d84f36c8a6529a6.sample |
| 1.21 MB | .godot/imported/music_garden.ogg-6344fc5e4df0d46fbcaa6d9383cbf2ef.oggvorbisstr |
| 1.12 MB | .godot/imported/room_wall_old.png-2379990a1d4ad36b0092890cb7e4fe59.astc.ctex |
| 1.12 MB | .godot/imported/room_wall_0.png-e7af6e93883768def475e73cb6803bf9.astc.ctex |
| 1.12 MB | .godot/imported/room_wall_1.png-d5e4748f8ffa48313384ea369dc0f0f1.astc.ctex |
| 1.12 MB | .godot/imported/room_wall_2.png-0bc6e462d87d972d41e4c087175beca0.astc.ctex |
| 1.01 MB | .godot/imported/room_floor_0.png-abe8bb96f5522a30eeac9792d2e4aa12.astc.ctex |
| 970.36 KB | .godot/imported/room_floor_1.png-dbed4845d89fe1a6f698db294591b97d.astc.ctex |
| 957.71 KB | .godot/imported/room_floor_2.png-c470396b37d7819227ccf14616771488.astc.ctex |
| 949.27 KB | .godot/imported/bg_far.png-4020123b9694b03cdf7a6c58ad168e4f.astc.ctex |
| 949.27 KB | .godot/imported/bg_far.png-9824475237774912550dc6f7f34101a4.astc.ctex |
| 949.27 KB | .godot/imported/bg_far.png-b963f6018076051920ea7587a67b78b0.astc.ctex |
| 949.27 KB | .godot/imported/room_floor_old.png-20ddb76ce7dd6e1df271546adcfdfd53.astc.ctex |
| 864.89 KB | .godot/imported/bg_grass.png-3a28b86142300096055390e0c3f8954a.astc.ctex |
| 864.89 KB | .godot/imported/bg_ground.png-69f5af2f0d0f362622f2daf2bad01753.astc.ctex |
| 864.89 KB | .godot/imported/bg_ground.png-c5858fd17477c8b28cea328108a788e7.astc.ctex |
| 738.33 KB | .godot/imported/bg_mid.png-215a2e659ecc2d80191428527951f42e.astc.ctex |
| 738.33 KB | .godot/imported/bg_mid.png-4d47fb42a32d4dac2268b3d821ece805.astc.ctex |
| 738.33 KB | .godot/imported/bg_mid.png-7780a60456ba1aa5ba4750b861287aa0.astc.ctex |
| 443.02 KB | .godot/imported/beach_fence.png-fd87809f15eaa812f977e9e4cb77c0f5.astc.ctex |
| 443.02 KB | .godot/imported/bg_fence.png-3cfd0ba8d2500528534ecb86890a98a1.astc.ctex |
| 443.02 KB | .godot/imported/bg_fence.png-6face7d1d2320d593347991301717302.astc.ctex |
| 443.02 KB | .godot/imported/bg_fence.png-ec8de69deae8a672ac4034588be6764d.astc.ctex |
| 443.02 KB | .godot/imported/garden_fence.png-d33180931d3194bfa0037d85f6bbe221.astc.ctex |
| 443.02 KB | .godot/imported/rooftop_fence.png-754672e5363fc21f485d74f8f754b308.astc.ctex |
| 400.05 KB | .godot/imported/beach_crown.png-68b397163bdc2e26822fbf717aa5206a.astc.ctex |
| 400.05 KB | .godot/imported/beach_crown.png-865c90a64600fc5eff5840bfc655340c.astc.ctex |
| 400.05 KB | .godot/imported/beach_crown.png-a13e1e4bb7c5971a1712ace757765754.astc.ctex |
| 400.05 KB | .godot/imported/garden_crown.png-ad7d780b60265387b7506cf813311503.astc.ctex |
| 400.05 KB | .godot/imported/garden_crown.png-e222c637e0ca8a7dca6ca9aff42ba6aa.astc.ctex |
| 400.05 KB | .godot/imported/garden_crown.png-fb175a895e23d0254590a66af96160f7.astc.ctex |
| 400.05 KB | .godot/imported/hero_crown.png-a4c1799c291f471f5de38556f4baddeb.astc.ctex |
| 400.05 KB | .godot/imported/hero_crown.png-f99a83c82bae57103bf93c55958354c7.astc.ctex |
| 400.05 KB | .godot/imported/rooftop_crown.png-0531e366feff326799a4b7a6ffa4c7e3.astc.ctex |
| 400.05 KB | .godot/imported/rooftop_crown.png-79b63d49b709821de1f834e322ccf3ad.astc.ctex |
| 400.05 KB | .godot/imported/rooftop_crown.png-b55325b3c160c74be78c6a8aedf5b992.astc.ctex |
| 400.05 KB | .godot/imported/tree_crown.png-131e8c83a787f40e920044e6a783064a.astc.ctex |
| 383.86 KB | .godot/imported/beach_ambience.wav-e71e256f338062f87acd1d773105613b.sample |
| 383.86 KB | .godot/imported/night_ambience.wav-e2793532c01f01d029de4c14f5a7d129.sample |
| 383.86 KB | .godot/imported/rooftop_ambience.wav-cefd67b7b7e56890fdf4f90c1df182db.sample |

## 5. Paket boyutu (GERCEK PCK: build/size/naive.pck)

| kategori | boyut | % | deflate |
|---|---:|---:|---:|
| doku ASTC | 33.86 MB | 80.7% | 17.77 MB |
| ses WAV/QOA (.sample) | 3.47 MB | 8.3% | 3.03 MB |
| doku (kayipsiz/yan bicim) | 1.57 MB | 3.7% | 1.55 MB |
| ses OGG | 1.21 MB | 2.9% | 1.18 MB |
| scripts/ (ham) | 776.39 KB | 1.8% | 770.04 KB |
| font | 336.46 KB | 0.8% | 332.56 KB |
| tests/ (ham) | 208.44 KB | 0.5% | 206.94 KB |
| addons/ (ham) | 200.76 KB | 0.5% | 200.54 KB |
| tools/ (ham) | 91.72 KB | 0.2% | 91.67 KB |
| data/ (ham) | 85.83 KB | 0.2% | 31.43 KB |
| diger | 71.47 KB | 0.2% | 14.18 KB |
| assets/ (ham) | 61.24 KB | 0.1% | 46.83 KB |
| sahne/kaynak (ikili) | 53.47 KB | 0.1% | 52.62 KB |
| betik/sahne (ikili belirteclenmis) | 16.13 KB | 0.0% | 6.32 KB |
| scenes/ (ham) | 997 B | 0.0% | 993 B |
| **TOPLAM** | **41.97 MB** | 100% | **25.25 MB** |

Dosya sayisi: 1221
PCK dosya boyutu (dizin dahil): 42.08 MB

Not: APK/AAB = PCK (Android'de 'assets/' altinda) + libgodot_android.so (arm64 icin yaklasik bkz. templates) + dex/kaynaklar; motor kismi sablon APK'sindan olculur (bkz. docs/size/baseline.md).
