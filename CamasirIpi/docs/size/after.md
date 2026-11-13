# Boyut sonrasi (after) ve oncesi/sonrasi tablosu

Olcum: Godot 4.7.2, dal `orch/r-size`. Ayrintili otomatik rapor: `python3 tools/size_report.py --pck build/size/game.pck`
(`game.pck` = `godot --headless --path . --export-pack "Android (release)" build/size/game.pck`).

## Oncesi / sonrasi

| olcu | once (filtresiz) | sonra (`Android (release)`) | fark |
|---|---:|---:|---:|
| PCK dosya boyutu | 42.08 MiB | **39.79 MiB** | -2.29 MiB (-5.4%) |
| PCK DEFLATE tahmini (APK/AAB ici) | 25.25 MiB | **23.32 MiB** | -1.93 MiB (-7.6%) |
| PCK dosya sayisi | 1221 | 976 | -245 |
| ASTC dokular | 33.86 MiB | 33.86 MiB | 0 (gorsel degismedi) |
| ses `.sample` (WAV/QOA) | 3.47 MiB | 1.99 MiB | -1.48 MiB |
| ses OGG (muzik) | 1.21 MiB | 1.21 MiB | 0 |
| font (`.fontdata`) | 336 KiB | 56 KiB | -280 KiB |
| `tests/` + `tools/` betikleri | 300 KiB | 0 | -300 KiB |
| `addons/admob` (editor/mock/export) | 200 KiB | 60 KiB | -140 KiB |
| kullanilmayan varliklar (`crate_wood.glb`, 2 ikon) | ~100 KiB | 0 | -100 KiB |
| BPTC (masaustu) dokular | PCK'ya girmiyor | PCK'ya girmiyor | - |
| arm64 `libgodot_android.so` (sablon) | 67.8 MiB ham / 22.9 MiB deflate | ayni | motor, bu isin kapsami disi |
| tahmini arm64 release indirme (so + dex + PCK deflate) | ~50.3 MiB | **~48.4 MiB** | ~ -1.9 MiB |

Yeni onayar yalniz arm64-v8a uretir; sablonun 4 ABI'li varsayilani (arm64 + armv7 + x86 + x86_64) ile kiyaslandiginda
`.so` tarafinda ek ~3 x 20 MiB (deflate) tasarruf vardir; bunu "Android (release)" onayari saglar (onceki taban cizgisi
onayarinda da arm64-only idi, bu yuzden tabloya yazilmadi).

Gercek APK/AAB bu makinede uretilemedi (Android SDK/JDK/keystore yok, kurulum yasak). Rakamlar PCK dokumunden ve sablon
APK'sindan tahmindir; kesin degeri gercek export verir.

## Yapilan degisiklikler (ve tasarruflari)

| degisiklik | tasarruf | gorsel/isitsel etki |
|---|---:|---|
| `export_presets.cfg` (yeni): `Android (release)` filtreleri: `docs/ tests/ tools/ build/ *.md *.py *.sh *.blend .gitattributes requirements.txt assets/third_party/*`, kullanilmayan 2 ikon, AdMob editor/mock/export/android-ikili/ios/csharp/assets | ~0.55 MiB | yok (calisma zamani taramasi + paketten acilis dogrulandi) |
| `garden_ambience.wav` ice aktarimi `compress/mode=0` -> `2` (QOA; diger 3 ambiyans ve 37 SFX zaten QOA) | 1.46 MiB | SNR 35.9 dB (kardesleri 29-43 dB); dongu sinirinda adim -37 dBFS (orijinalde -42); `AudioService._looped` sureden hesapladigi icin degisiklik gerekmedi |
| `Baloo2.ttf` -> Latin alt kumesi (348 karakter / 435 glif; 683 KB -> 100 KB; GPOS/GSUB/degisken eksen/hinting korundu). Tam font `tools/fontsrc/Baloo2-full.ttf`; yeniden uretim `tools/subset_font.py` | 280 KiB | yok: 8 ekran x tr/en/es oncesi/sonrasi; statik metinler piksel piksel ayni (harita ekranlari 0 farkli piksel) |
| `script_export_mode=2` (sikistirilmis ikili belirtec) | betikler ham 1.1 MiB yerine ikili | yok |
| arm64-only (armv7 kapali) | ~20 MiB (deflate, `.so` basina) | armv7 (32-bit) cihazlar kurulamaz; bkz. risk |
| `tools/size_report.py`, `tools/pck_check.py`, `tools/audio_quality.py`, `tools/subset_font.py` (yeni) | - | - |

Sunlar DEGISMEDI: dokular (ASTC 4x4 yuksek kalite), music OGG, SFX'ler, tum kod ve veri dosyalari, `data/sounds.json`,
`AudioService`.

## Yapilmayanlar ve nedenleri (olculmus)

1. **Doku formatini kayipsiz WebP'ye cevirmek** (en buyuk 99 VRAM dokusu: ASTC 35.5 MB -> kayipsiz WebP 13.9 MB, kaynak
   -21.6 MiB PCK). YAPILMADI: GPU bellegi 4x artar (RGBA8; aktif mekan x mevsim setinde ~20 MB ASTC -> ~80 MB), yukleme
   suresi artar ve perf gecisinin (VRAM sikistirma) amacini geri alir. DEFLATE sonrasi indirme farki yalniz ~3.9 MiB
   (ASTC deflate'te yarisina iner, WebP inmez). Kalite acisindan kayipsiz daha iyi, ama bellek/akicilik maliyeti var.
   Karar urun sahibinindir; istenirse yalniz en buyuk 6-8 arka plan katmani icin denenebilir.
2. **Seffaf kenar kirpma** (yalniz y/x kirpma, 4 px hizali): toplam 3.3 MB ASTC baytlari (arka plan 1.1, tac 1.4, govde 0.35,
   cit 0.27, diger 0.2). YAPILMADI: seffaf bloklar DEFLATE'te ~%25-50'ye iner (olculdu: `hero_trunk` 316 KB -> 73 KB,
   `bg_far` 949 KB -> 385-518 KB), yani APK'ya net etkisi ~0.3 MiB; buna karsilik `locations.json` konumlari, tac/govde
   pivotlari, `lights` pikselleri ve `tools/blender/make_locations.py` ciktisi ile tutarlilik riski var.
3. **Uzak katmanlari (bg_far) dusuk cozunurlukle ice aktarmak:** evler/cati karolari keskin kenarli; 0.75x/0.5x
   yumusama riski yuksek, kazanc 1.3-2 MB. Kullanici kurali (bulaniklik yok) geregi yapilmadi.
4. **Sureli ambiyans/muzigi OGG/MP3 yapmak:** ffmpeg'de yalniz deneysel `vorbis` kodlayicisi var (libvorbis/libopus yok;
   libopus'u Godot icin ice aktaramaz): bitrate parametresini yok sayiyor (96/128/192 kbps ayni 374-443 KB), SNR 10.6 dB ->
   kullanilamaz. `libmp3lame` V2: 196-229 KB (QOA 384 KB) ama SNR 26-28 dB (QOA 30-36) ve Godot'un MP3 cozucusu kodlayici
   gecikmesini kirpmaz -> dongu sinirinda bosluk/tik riski (ambiyans kodda tam uzunlukla donguye alinir). Kazanc ~0.6 MiB
   toplam; guvenli secim QOA (mevcut). Muzik zaten OGG Vorbis 175 kbps; kayipli->kayipli tekrar kodlama yapilmadi.
5. **SFX'leri PCM/IMA-ADPCM'e cevirmek:** 37 SFX zaten QOA (hata -45...-70 dBFS, tepe -6...-31 dBFS). PCM'e donmek
   +1.8 MiB; ADPCM QOA'dan kotu. Oldugu gibi birakildi.
6. **`menu`/`result` sahneleri ve `success.wav`/`ui_tap.wav`:** olu iskelet ama `GameManager.SCENES` sozlugunde yol dizgesi
   olarak gecer (`finish_run` cagrilmiyor); toplam ~25 KB. Kod temizligi olmadan dislanmadi.
7. **Ozel Godot motoru (kullanilmayan modulleri kapat, `optimize=size`):** en buyuk tek kaldirac (.so 67.8 MiB ham; tipik
   %30-40 azalma). Bu makinede derleme/indirme yok; asagida oneri.
8. **ETC2 yedegi gondermek:** ASTC ile birlikte +~34 MiB PCK. ASTC arm64 Android'de fiilen evrenseldir; yoksa Godot
   `CompressedTexture2D` yazilimsal cozer (RGBA8, bellek+yukleme maliyeti). Gercek cihazda dogrulanmali (asagi).

## Calisma zamani dogrulamasi

* `tools/pck_check.py build/size/game.pck`: koddan/veriden 305 gerekli yol (sablonlar `%s` -> glob, dizin sabitleri +
  govde adi); hepsi pakette -> `gecti`. Olumsuz kontrol: `coin.wav`, `bg_beach/bg_mid.png`, `data/zen.json` bilerek
  dislaninca 3 `MISSING` basildi ve cikis kodu 1 oldu.
* Paketten acilis: `godot --main-pack build/size/game.pck --headless --quit-after 240 res://scenes/<X>.tscn`
  (Boot, Home, Game, Menu, Result, DailyCalendar, LevelMap, Collection, Laundromat, Shop): 10/10 cikis 0, "error/failed/
  missing/not found" satiri yok.
* `tools/verify.sh`: 423 test, 18742 dogrulama, 0 basarisiz; SONUC: gecti.
* Probe'lar: bkz. asagidaki "Probe sonuclari".
* Oncesi/sonrasi gercek-pencere ekran goruntuleri (810x1440, tr): home, bahce yazi, sahil kis gece, cati bahar, camasirhane dolu,
  koleksiyon, magaza, harita: gozle ve piksel farkiyla karsilastirildi. Farklar yalniz canli animasyonlardan (sallanan camasir,
  bulut, ates bocegi, sayac); ayni sahneyi iki kez ALMAK da ayni buyuklukte fark verir (home: oncesi-oncesi2 253k piksel,
  oncesi-sonrasi 227k; koleksiyon 29k vs 30k). Statik sayfalar (harita x3 dil) 0 farkli piksel. Doku ve ses degisikligi yok.

## Ses olcumleri (QOA kodunu cozerek; `tools/audio_quality.py`)

| dosya | once | sonra | SNR | not |
|---|---|---|---:|---|
| garden_ambience | PCM 1895 KB | QOA 384 KB | 35.9 dB | 4 kHz alti SNR 35-52 dB; dongu adimi -37 dBFS (orijinal -42) |
| night_ambience | QOA 384 KB | ayni | 30.5 dB | degismedi |
| beach_ambience | QOA 384 KB | ayni | 29.0 dB | degismedi |
| rooftop_ambience | QOA 384 KB | ayni | 43.4 dB | degismedi |
| Adaylar (22 s ambiyans): vorbis-exp 96/128/192k | - | 374-443 KB | 10.6 dB | reddedildi |
| Adaylar: mp3 lame 128k / V2 | - | 345 / 196-229 KB | 25.7-27.9 dB | gecikme kirpilmiyor, reddedildi |

## Export onayari (`export_presets.cfg`)

* `Android (release)`: AAB (`gradle_build/export_format=1`), Gradle build acik (AdMob eklentisi gerektirir), yalniz
  `arm64-v8a`, `script_export_mode=2`, filtreler yukarida. Imza bilgisi YOK (docs/MONETIZATION.md 6.).
* `Pack baseline (no filters)`: olcum icindir. `Desktop pack check (Linux)`: BPTC/ASTC secimini dogrulamak icindir.
* Gelistirme makinelerinde masaustu dokulari (BPTC) yine uretilir (`.godot` onbellegi, paketlenmez) — Mac OpenGL'de ASTC
  yok, yerel calistirma icin gerekli.

## Riskler / gercek Android export'un dogrulamasi gerekenler

1. Gercek AAB boyutu: PCK'nin APK'da deflate edilip edilmedigi, AdMob/Google Mobile Ads Gradle bagimliliklari (dex), Play
   cihaz-ozel dagitimi. Burada yalniz PCK ve sablon olculdu.
2. ASTC'siz eski GPU'lar: yazilimsal cozumleme yolu cihazda denenmeli (acilis suresi, bellek).
3. arm64-only: Play 64-bit zorunlu; armv7 cihazlar (cok eski/ucuz) kurulamaz. Gerekirse `architectures/armeabi-v7a=true`
   eklenir: +~22 MiB (deflate) indirme; AAB'de cihaz yalniz kendi ABI'sini indirir, bu yuzden AAB kullanilirsa ek maliyet
   kullanici basina yoktur — yalniz AAB dosyasi buyur.
4. Font alt kumesi: yeni dil/sembol eklenirse `python3 tools/subset_font.py` yeniden calistirilmali (aksi halde eksik glif
   sistem yedek fontuna duser).
5. `docs/MONETIZATION.md`'deki dislama listesine `internal/handlers/*` ve `csharp/*` eklendi (yalniz editor yollari);
   `MobileSingletonPlugin` mock'u yalniz `OS.has_feature("editor")`'de yukler. Gercek cihazda "[AdMob] Native plugin ... not
   found" satiri OLMAMALI.
6. `tools/make_el_sfx.py` yeni WAV uretirse `.import` ayarlari (QOA) korunur; bir ses silinip yeniden eklenirse `compress/mode=2`
   elle yeniden verilmeli.

## Oneri: motor boyutu (en buyuk kaldirac, yapilmadi)

Ozel export sablonu: `scons platform=android target=template_release arch=arm64 optimize=size lto=full disable_3d=yes
module_<kullanilmayan>_enabled=no` (3B, navigasyon, fizik 3B, XR, gltf/csg/gridmap, vb.). Bu proje yalniz 2B + gl_compatibility
kullanir; tipik kazanc 25-35 MiB ham / 8-12 MiB deflate. Sablon `Project > Export > Custom Template`'e baglanir.
AdMob icin gradle build kalir. Bunun disinda: Play Asset Delivery (install-time/fast-follow asset pack) ile 12 MiB'lik
mekan dokularini (plaj/cati) ilk indirmeden ayirmak mumkundur (`assetPackInstallTime` sablonda mevcut), ama oyun akisini
etkiler — urun karari.

## Repo hijyeni: `docs/art` temizlik plani (UYGULANMADI)

Olculen: `docs/art` 416.9 MiB (393 PNG + `.import` dosyalari, 669 izlenen dosya), `docs/perf` 17.7 MiB; `.git` (paylasilan
`godot-games` deposu) pack boyutu 430.7 MiB, `.git` 560 MiB. En buyukler `q_ui_after_a_tr.png` 6.8 MB, `q_ui_after_c_tr.png`
6.4 MB, `r_wire_cvd_badges.png` 3.4 MB. Onek dagilimi: i* 114, q* 60, r* 40, retention* 33, shop* 15, rules* 14, places* 12.
Tumu `tools/*_shot.gd` ile yeniden uretilebilir ekran goruntuleridir; `docs/.gdignore` oldugu icin motor taramaz ama
`.godot` onbellegine 157 MiB eski `.import` hedefi birikmistir.

Oneri (onaylanirsa, sirayla):
1. Simdi (geri alinabilir): `docs/art/**.png.import` izlenen dosyalarini `git rm --cached` yap, `.gitignore`'a `docs/art/*.import`,
   `docs/perf/*.import` ekle. Yeni ekran goruntuleri 1080 px genislikte kayipsiz yerine WebP q85 (~150-250 KB) kaydedilsin.
2. Secilmis kume: ~40 temsili dosyayi (her ekran/dil icin 1) `docs/art/curated/` altinda 810x1440 WebP olarak tut (~6-8 MiB);
   geri kalani depo disina tasi (ortak surucu/GitHub Release asset'i/ayri `camasiripi-art` deposu veya git-lfs) ve
   `docs/art/INDEX.md` icinde adlariyla + uretim komutuyla listele.
3. `.gitignore`: `docs/art/*` + `!docs/art/curated/`.
4. Gecmis: yukaridaki adimlar `.git`'i KUCULTMEZ (430 MiB pack). Kucultmek icin taze klonda `git filter-repo --path docs/art
   --path docs/perf --invert-paths` gerekir; bu gecmis yeniden yazimi, paylasilan `godot-games` deposunu ve tum dal/
   worktree'leri etkiler, bu yuzden ayri, koordineli ve onayli bir adim olmali. Alternatif: kimse gecmisi yeniden yazmadan
   yeni klonlarda `git clone --filter=blob:limit=1m`.
5. `export_presets.cfg` icindeki `docs/*` filtresi zaten `docs/`'u paketlemez; `.gdignore` da motoru korur.

## Probe sonuclari

`play_probe`: `PROBE SONUC: gecti`; `daily_probe`: gecti; `retention_probe`: gecti; `map_probe`: gecti; `lang_probe`: gecti;
`eco_probe`: `ECO SONUC: gecti`. (`map_probe`/`eco_probe` cikisinda "Lambda capture ... was freed" satirlari taban kodda da
aynen var; bu degisiklikle ilgisiz.)
