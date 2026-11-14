# Ses (Aşama 2)

Tüm sesler ElevenLabs ile `tools/make_sfx.py` tarafından üretilir (kodla sentez yok). Tarifler betikteki `RECIPES` / `MUSIC`
tablolarındadır; ham API çıktısı `build/sfx_raw/` altında önbelleklidir (git dışı), yeniden işleme kredi harcamaz.
`python3 tools/make_sfx.py --report` ölçüm tablosunu (süre, tepe, RMS, baş/son sessizlik, döngü dikişi) yazar.
Sesler `data/sounds.json` içinde kimliğiyle kayıtlıdır; tabloda olmayan kimlik sessizce yok sayılır.

## Bus düzeni (AudioService çalışma anında kurar)

| Bus | Varsayılan dB | İçerik |
|---|---|---|
| Master | -1 | Sert sınırlayıcı (`AudioEffectHardLimiter`, tavan -1 dB) |
| SFX | 0 | tek atımlık sesler (`play`, `play_pitched`, `play_variant`) |
| Loops | -6 | adlı döngü katmanları (`start_loop`) |
| Ambience | -4 | ortam döngüsü (`play_ambience`) |
| Music | -5 | müzik döngüsü (`play_music`) ve kısa parçalar (`play_jingle`) |

Hepsi Master'a gider. `duck()` yalnız Loops, Ambience ve Music'i kısar; SFX kısılmaz.

## AudioService API

- `start_loop(id, sound_name, volume_db = -6, fade_in = 0.5)`: adlı katman başlatır. Aynı id + aynı ses: yalnız seviyeyi ayarlar.
  Aynı id + başka ses: katman o sese geçer. En çok 32 katman; oynatıcılar yeniden kullanılır.
- `stop_loop(id, fade_out = 0.5)`, `stop_all_loops(fade_out = 0.5)`: kısıp bırakır.
- `set_loop_pitch(id, pitch, glide_seconds = 0)`: perde 0.25-4 aralığına kenetlenir. `set_loop_volume(id, db, glide_seconds = 0)`.
- `is_loop_playing(id)`, `loop_ids()`, `loop_volume_target(id)`, `loop_pitch_target(id)`, `loop_player(id)`, `loop_player_count()`.
- `duck(seconds, depth_db = -14)`: 50 ms'de iner, `seconds` kısık kalır, 0.6 sn'de geri açılır. Art arda çağrı yeniler.
- `play_jingle(sound_name, volume_db = 0)`: kısa, döngüsüz müzik parçası (kazanma); havuz turu onu kesmez.
- `set_sound_enabled(false)`: döngü katmanları kaydolu kalır ama duraklar; açılınca kaldığı yerden sürer.
  `set_music_enabled` müzik ve `play_jingle` içindir.

## Ses kimlikleri

Tek atımlıklar (`assets/audio/sfx/`, WAV, 44.1 kHz mono; tepe hedefi dB):

| Kimlik | Kullanım | Tepe |
|---|---|---|
| `plug_seat_1..3` | Fişin prize oturması: oyunun en net sesi. `play_variant("plug_seat", 3, pitch)`; ayrıca ±%3 perde oynat. İçe aktarma PCM (sıkıştırmasız). | -1.5 |
| `breaker_flip` | Sigorta kutusu kolu | -4 |
| `start_day` | "Günü başlat" büyük şalter: ağır tak + yükselen uğultu (~2.1 sn) | -5 |
| `fuse_blow` | Sigorta atması "çat"; hemen ardından `duck(1.5, -24)` ve `stop_all_loops` | -3 |
| `plug_unplug` | Fiş çekme pop'u | -6 |
| `plug_pickup` | Fişi tepsiden alma | -8 |
| `plug_reject` | Reddedilen fiş: yumuşak donuk sekme (uyarı sesi değil) | -9 |
| `power_down` | Cihazların sönüp sessizliğe düşmesi (~1.8 sn) | -10 |
| `lose` | Kaybetme, yumuşak | -10 |
| `slice_transition` | Dilim geçişi: yumuşak çın + hışırtı | -9 |
| `window_light` | Pencere/lamba yanması "tink"; kazanma sahnesinde yükselen dizi: `play_pitched("window_light", 1.0 + 0.12 * i)` | -9 |
| `plug_magnet` | Fiş mıknatıs çekimi, çok hafif | -12 |
| `socket_tick` | Priz/hat vurgusu | -12 |
| `lamp_flicker` | Sınıra yaklaşırken lamba titremesi (kısa) | -12 |
| `ui_soft`, `coin`, `win` | Kabuk şablonundan (değişmedi). UI dokunuşu = `ui_soft` | -10/-9/-6 |

Cihaz ve elektrik döngüleri (`assets/audio/loops/`, WAV 32 kHz mono, 4.4-5.4 sn, kuyruk başa 0.4-0.6 sn eşit-güçlü çapraz geçişle bağlı):
`loop_fridge`, `loop_oven`, `loop_kettle`, `loop_washer`, `loop_tv`, `loop_fan`, `loop_toaster`, `loop_lamp` (neredeyse sessiz),
`hum_mains`. Tepe: cihazlar -18 (TV, tost makinesi -20, lamba -28), uğultu -20.

Ortam döngüleri (`assets/audio/ambience/`, WAV 22.05 kHz mono, 14.5 sn, 1.5 sn çapraz geçiş, tepe -22):
`ambience_morning`, `ambience_noon`, `ambience_evening`, `ambience_night`. `play_ambience(name)` ile (tek ortam, geçişte kısılıp açılır).

Müzik (`assets/audio/music/`, OGG stereo): `music_win` (~6 sn, döngüsüz; `play_jingle`), `music_plan` (~30 sn döngü, 2 sn çapraz
geçişli; `play_music("music_plan", -13)`). Otomatik başlayan `music_main` / `ambience_main` adları tanımlı DEĞİL; sahne seçer.

## Katmanlama yönergesi

- Cihaz döngüleri yalnız cihaz takılıyken: `start_loop("dev_<cihaz_id>", "loop_<tür>", -10, 0.6)`; çıkarılınca `stop_loop(id, 0.5)`.
  Her cihaz farklı spektrumda üretildi (fırın hava, çamaşır ritmik, su tıkırtısı, TV orta bant murmur); aynı anda 8 katman çamurlaşmaz.
  Katman başı -8..-12 dB başla; 4'ten fazla cihazda yeni katmanı -2 dB daha kıs. Başlangıç noktası rastgele, faz toplanması olmaz.
- Elektrik uğultusu tek katman: `start_loop("hum", "hum_mains", -16, 1.0)`; hat doldukça `set_loop_pitch("hum", 1.0 + 0.6 * doluluk, 0.4)`
  (1.0 → 1.6). Perde değişince hız da değişir; bu istenen etki.
- Ortam (`play_ambience`) en altta, -6 dB civarı; müzik `music_plan` -13 dB. Efektler (SFX) hep önde.
- Sigorta atması: `play("fuse_blow")`, `duck(1.5, -24)`, `stop_all_loops(0.25)`, `play("power_down")`.
- Kazanma: `stop_all_loops`, `play_jingle("music_win", -3)`, pencereler `window_light` yükselen perdeyle.

## Boyut

Kaynak WAV'lar ~7 MB (PCM); içe aktarmada döngüler/ortam/tek atımlıklar QOA'ya (≈3.5x) sıkışır, `plug_seat_*` PCM kalır.
Pakete giren toplam ~2.9 MB (içe aktarılmış örnekler ~2.2 MB + müzik OGG ~0.66 MB).

## İnsan kulağı gerektirenler

Betikle yalnız ölçülebilir şeyler (süre, tepe, RMS, sessizlik, dikiş) doğrulandı. Dinlenmeli: `plug_seat_1..3` (üçü de "tık" gibi mi),
`fuse_blow`, `hum_mains` (baskın frekans ~105 Hz çıktı, 50 Hz değil), `loop_toaster` (seyrek tıkırtı, çoğu sessiz), `loop_tv`,
ortam döngüleri (kuş/cırcır dikişi), `music_win` (çözülüyor mu) ve `music_plan` döngü dikişi.
