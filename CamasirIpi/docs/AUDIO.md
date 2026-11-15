# Ses sistemi — Çamaşır İpi

Tüm sesler ElevenLabs ile ücretli plan (Starter) altında üretildi; lisans ve istem kaydı `docs/AUDIO_LICENSE.md`.
Bu çalışmada kulakla dinleme YAPILMADI; ölçümler ffmpeg/ffprobe ile, aşağıdaki "İnsan kulağı" listesi dinlenmeli.

## Müzik

| ad | nerede çalar | süre |
|---|---|---:|
| `music_menu` | ana ekran ve oyun dışı tüm ekranlar (harita, mağaza, çamaşırhane...) | 75 sn |
| `music_garden` | bahçe seviyeleri (gündüz) | 95 sn |
| `music_beach` | sahil seviyeleri (gündüz) | 95 sn |
| `music_rooftop` | çatı katı seviyeleri (gündüz) | 95 sn |
| `music_night` | gece aşamaları (her mekânda; ortam sesi `night_ambience` iken) | 85 sn |

Hepsi kesintisiz döngü, OGG Vorbis (ffmpeg yerleşik kodlayıcı, kalite 4, çift kanallı), -17 LUFS, tepe <= -2,4 dBTP.
Müzik ortak "kalimba" motifi etrafında; menü temasında daha belirgin bir melodi var, oyun parçaları seyrek, davulsuz.

### Hangi parça ne zaman (kod: `scripts/core/music_router.gd` + `AudioService`)

- Açılışta menü teması çalar (`play_music("music_garden")` ana ekranda menü temasına çözülür).
- `Game.tscn` açılınca ya da oyun `play_ambience(ad)` çağırınca bağlam OYUN olur; parça ortam adından seçilir
  (`garden_ambience` -> `music_garden`, `beach_ambience` -> `music_beach`, `rooftop_ambience` -> `music_rooftop`,
  `night_ambience` -> `music_night`). Başka sahneye geçilince menü teması döner.
- Geçişler eşit güçlü çapraz geçiştir (menü<->oyun 2,5 sn, mekân/gece 4 sn); aynı parça tekrar istenirse yeniden başlamaz.
- Ortam döngüsü de eski döngü sönerken yenisi açılarak değişir. Reklam/arka plan dönüşünde (`NOTIFICATION_APPLICATION_RESUMED`,
  pencere odağı) müzik ve ortam kaldığı yerden yeniden kurulur (`AudioService.resume_audio()`).
- `win`, `lose`, `success`, `chest_open` çalarken Music bus 4 dB kısılır (0,12 sn giriş, jingle süresi kadar tutma,
  0,9 sn dönüş).

## Efektler (hepsi `data/sounds.json` içinde; adlar değişmedi)

Kategori -> hedef LUFS-I / gerçek tepe tavanı (dosya düzeyi, `tools/make_el_sfx.py` `LEVELS`):

| kategori | hedef | tavan | sesler |
|---|---:|---:|---|
| basket (en net) | -13 | -1,5 dBTP | `fold_puff`, `note` (çamaşır sepete girer) |
| reward | -15 | -1,5 | `win`, `success`, `lose`, `coin`, `chest_open`, `purchase`, `unlock`, `machine_done`, `level_start`, `sparkle` |
| core | -16 | -2 | `pin_click_1..3` (+`pin_click`), `cloth_1..3` (+`cloth`), `rack_hang`, `basket_slide`, `blocked`, `lock_rattle`, `wring`, `mud_squish`, `machine_door` |
| ui | -17 | -3 | `ui_tap`, `ui_soft` |
| spot | -21 | -3 | `bird_*`, `cat_*`, `rain_patter`, `wind`, `machine_tumble`, `dryer_tumble` |
| amb | -25 | -3 | `garden/beach/rooftop/night_ambience` (döngü) |
| music | -17 | -1,5 | `music_*` |

Kazanç = min(hedef - ölçülen, tavan - tepe, +24 dB). Çok kısa/darbeli seslerde (mandal tıkı) tavan belirler: LUFS hedefine
ulaşmaz ama tepe tavanda olur. 70 Hz altı süzülür; baş sessizlik ve sondaki sessizlik tepeye göre kırpılır, 50 ms çıkış
solması eklenir.

## Miks kuralları

- Bus'lar `AudioService._setup_buses()` ile çalışma anında kurulur: `Music`, `SFX`, `Ambience` -> `Master`.
  Master'da `AudioEffectHardLimiter` (ön kazanç +2 dB, tavan -1 dB, bırakma 0,15 sn). Bus kazançları 0 dB; ayar yok.
- Oyun içi sıra (yüksekten alçağa): sepet/ödül efektleri > çekirdek efektler > müzik (-17 LUFS dosya, oyunda -4 dB) >
  ortam yatağı (-25 LUFS dosya, oyunda 0 dB). Ana ekranda müzik 0 dB, ortam -6 dB.
- Yeni ses eklerken kategori seç; ham dosyayı `make_el_sfx.py` tablosuna koy; dosyayı elle seviyelendirme.
- En kötü durum yığını (müzik + ortam + 6 efekt aynı anda) `python3 tools/audio_report.py --stack` ile ölçülür:
  sınırlayıcısız tepe 0 dBFS'e dayanır, sınırlayıcıdan sonra -0,9 dBTP.
- Ses/müzik anahtarları (`set_sound_enabled`, `set_music_enabled`) duraklatma ile çalışır; ses ayarı yoktur.

## Bir varlığı yeniden üretmek

```bash
python3 tools/make_el_sfx.py --account        # plan ve kalan kredi (yalnız sayılar)
python3 tools/make_el_sfx.py --estimate       # plan süresi ve tahmini kredi
python3 tools/make_el_sfx.py --retry cloth_2  # TEK varlık, kredi harcar; eski ham dosya .try1 olur
python3 tools/make_el_sfx.py --process        # ham önbellekten yeniden işle (kredi YOK; seviye/kırpma değişince)
python3 tools/audio_report.py                 # tüm dosyaların LUFS/tepe/sessizlik/dikiş tablosu
```

Tarif ve süre `tools/make_el_sfx.py` içindeki `SFX`, `AMBIENCE`, `MUSIC` tablolarındadır. Ham önbellek `build/sfx_raw_v2/`
(git dışı). Yeni müzik `.ogg` için Godot içe aktarmadan sonra `.import` dosyasında `loop=true` kalmalı (servis ayrıca
koda da yazar). Yeni WAV `.import` ayarı `compress/mode=2` (QOA) olmalı.

## Döngü dikişi

Müzik: üretilen parçanın son 4 sn'si baştaki 4 sn ile eşit güçlü karıştırılır ve uzunluk 2048 örneğin katına
ayarlanır (yerleşik vorbis kodlayıcı sonu 64'e yuvarlayıp sıfırla dolduruyordu: dikişte ~12 örneklik tık). Doğrulama:
OGG'nin son granülü = çözülmüş uzunluk; ilk ve son örnek arası sıçrama / çevre örnek farkı oranı <= 3,3.
Ortam: 1,5 sn çapraz geçiş; oran <= 1,4.

## Ölçümler (son hâl)

| dosya | süre sn | LUFS-I | gerçek tepe dBTP | KB |
|---|---:|---:|---:|---:|
| music/music_beach.ogg | 95.02 | -17.0 | -3.4 | 1044 |
| music/music_garden.ogg | 95.02 | -16.9 | -3.3 | 759 |
| music/music_menu.ogg | 75.05 | -17.0 | -3.0 | 1052 |
| music/music_night.ogg | 84.98 | -17.0 | -2.0 | 620 |
| music/music_rooftop.ogg | 95.02 | -16.9 | -2.4 | 664 |
| sfx/basket_slide.wav | 0.73 | -16.9 | -2.0 | 63 |
| sfx/beach_ambience.wav | 20.48 | -25.0 | -3.5 | 1764 |
| sfx/bird_chirp.wav | 0.65 | -21.0 | -11.4 | 56 |
| sfx/bird_flutter.wav | 0.61 | -24.6 | -3.0 | 53 |
| sfx/bird_splat.wav | 0.46 | -25.6 | -3.0 | 39 |
| sfx/blocked.wav | 0.48 | -21.9 | -4.0 | 41 |
| sfx/cat_meow.wav | 0.88 | -21.0 | -9.0 | 76 |
| sfx/cat_purr.wav | 1.48 | -21.0 | -4.9 | 128 |
| sfx/chest_open.wav | 1.11 | -20.9 | -1.5 | 95 |
| sfx/cloth.wav | 0.73 | -20.4 | -2.0 | 63 |
| sfx/cloth_1.wav | 0.73 | -20.4 | -2.0 | 63 |
| sfx/cloth_2.wav | 0.74 | -21.7 | -2.0 | 64 |
| sfx/cloth_3.wav | 0.69 | -19.9 | -2.0 | 60 |
| sfx/coin.wav | 0.56 | -24.8 | -1.5 | 48 |
| sfx/dryer_tumble.wav | 2.00 | -25.7 | -3.0 | 172 |
| sfx/fold_puff.wav | 0.65 | -19.6 | -1.5 | 56 |
| sfx/garden_ambience.wav | 20.48 | -25.0 | -9.1 | 1764 |
| sfx/level_start.wav | 1.20 | -21.0 | -1.5 | 103 |
| sfx/lock_rattle.wav | 0.39 | -27.2 | -2.0 | 34 |
| sfx/lose.wav | 1.71 | -23.0 | -1.5 | 147 |
| sfx/machine_done.wav | 1.00 | -15.0 | -4.1 | 86 |
| sfx/machine_door.wav | 0.57 | -24.0 | -2.0 | 49 |
| sfx/machine_tumble.wav | 1.90 | -23.7 | -3.0 | 163 |
| sfx/mud_squish.wav | 0.39 | -23.3 | -2.0 | 34 |
| sfx/night_ambience.wav | 20.48 | -24.9 | -10.2 | 1764 |
| sfx/note.wav | 1.20 | -18.6 | -1.5 | 103 |
| sfx/pin_click.wav | 0.27 | -26.5 | -2.0 | 23 |
| sfx/pin_click_1.wav | 0.27 | -26.5 | -2.0 | 23 |
| sfx/pin_click_2.wav | 0.40 | -27.8 | -2.0 | 35 |
| sfx/pin_click_3.wav | 0.48 | -25.3 | -2.0 | 41 |
| sfx/purchase.wav | 0.48 | -22.3 | -1.5 | 41 |
| sfx/rack_hang.wav | 0.50 | -23.7 | -2.0 | 43 |
| sfx/rain_patter.wav | 2.41 | -26.3 | -9.9 | 208 |
| sfx/rooftop_ambience.wav | 20.48 | -25.0 | -11.3 | 1764 |
| sfx/sparkle.wav | 0.88 | -18.9 | -1.5 | 76 |
| sfx/success.wav | 1.76 | -15.0 | -3.6 | 152 |
| sfx/ui_soft.wav | 0.40 | -24.7 | -3.0 | 34 |
| sfx/ui_tap.wav | 0.31 | -23.2 | -3.0 | 27 |
| sfx/unlock.wav | 1.02 | -27.1 | -1.5 | 88 |
| sfx/win.wav | 2.38 | -16.9 | -1.5 | 205 |
| sfx/wind.wav | 2.93 | -21.0 | -6.4 | 253 |
| sfx/wring.wav | 1.00 | -22.8 | -2.0 | 86 |

Önce/sonra (dosya düzeyinde LUFS-I, dBTP): menü müziği yoktu -> -17,0 / -3,0; oyun müziği `music_garden` -23,5 / -9,0 -> -16,9 / -3,3
(oyunda çalma kazancı -13 dB idi, şimdi -4 dB: etkin düzey -36,5 -> -20,9 LUFS); sepet sesi `fold_puff` -28,8 / -7,0 -> -19,6 / -1,5;
`note` -31,1 / -9,9 -> -18,6 / -1,5; `win` -22,4 / -6,2 -> -16,9 / -1,5; `ui_tap` -54,1 / -31,7 (neredeyse sessizdi) -> -23,2 / -3,0.
Ortam (bahçe) -32,8 (çalma -6 dB) -> -25,0 (çalma 0 dB).

## İnsan kulağı gerekenler

1. Menü teması: melodi "akılda kalıcı ama sakin" mi; 79 sn içinde sıkıcı tekrar var mı.
2. Oyun müzikleri: bas/pedin telefon hoparlöründe uğultu yapması (menüde düşük frekans enerjisi %47); çatı katı parçasında dikiş
   bölgesinde yaklaşık 5 dB'lik düzey çukuru ölçüldü (son ~3,5 sn); gece parçasında çok sessiz aralıklar var.
3. Dikiş noktaları: her müzik ve ortam döngüsünün başa sarma anı.
4. `rain_patter` kaynak kaydı çok kısıktı (+24 dB kazanç, parazit olabilir); `chest_open` ve `machine_done` yeniden denendi.
5. Genel düzey: sınırlayıcı +2 dB ön kazançla; telefonda efektler/müzik dengesi ve sınırlayıcı pompalaması.
