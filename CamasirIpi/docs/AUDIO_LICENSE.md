# Ses lisansı ve üretim kaydı

Tarih: 2026-11-15. Tüm gönderilen sesler (müzik, efekt, ortam döngüleri) ElevenLabs **ücretli plan** altında
yeniden üretildi; eski (ücretsiz plan) dosyaların hiçbiri kullanılmadı.

## Plan (API'nin bildirdiği)

- `tier`: **starter**, `status`: active, aylık dönem.
- Kredi: sınır 34 163, üretimden önce kullanılan 0, sonra 7 799, kalan 26 364 (sınırın %22,8'i; bütçe tavanı %60 idi).
  Sıfırlanma: 2026-12-14.
- İstek sayısı: **48** (45 ilk üretim + 3 yeniden deneme: `machine_done`, `rain_patter`, `chest_open`; ilk sonuçları
  aşırı kısık/kısaydı, her biri yalnız bir kez yeniden üretildi, eski ham dosya `.try1` olarak saklı).
- Modeller: ses efektleri/ortam `eleven_text_to_sound_v3` (çıktı `mp3_44100_128`), müzik `music_v2_5` (`force_instrumental`).
- Müzik toplamı 465 sn, efekt+ortam yaklaşık 129 sn.

## Ticari kullanım (ElevenLabs şartları)

Şartlar: <https://elevenlabs.io/terms-of-use> ve fiyatlar: <https://elevenlabs.io/pricing/api>.
Şartların 1(c) maddesine göre ücretsiz kullanıcı "yalnız ticari olmayan amaçla" kullanabilir; ücretli planda
"ticari amaçla kullanabilir" (Yasaklı Kullanım Politikası'na uymak koşuluyla). Fiyat sayfası müzik için
"Starter+ planlarda ticari kullanım lisansı" der. **Atıf (attribution) şartı yoktur**; çıktının hakları kullanıcıdadır
(madde 4(c)); ayrıca çıktıyı dağıtmadan önce gözden geçirmek kullanıcının sorumluluğudur (4(k)).
Not: bu belge hukuki görüş değildir; Yasaklı Kullanım Politikası ve hizmete özel şartlar ayrıca okunmalıdır.

## Üretilen varlıklar

Ham dosyalar: `build/sfx_raw_v2/` (git dışı); her istek `build/sfx_raw_v2/ledger.json` içinde zaman damgasıyla.
Tarifin sonuna efektlerde `STYLE` eki otomatik eklenir (tools/make_el_sfx.py).

| ad | tür | model | süre sn | yeniden deneme | tarif |
|---|---|---|---:|---|---|
| `ui_tap` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A soft clean wooden tap on a small wooden block, pleasant mid pitch, short, for a cozy mobile game button. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `music_menu` | music | music_v2_5 | 79.0 | - | Warm, inviting main-menu theme for a cozy laundry puzzle game. A gentle memorable melodic hook of four bars played on warm kalimba and felt piano, answered by soft nylon-string guitar, airy sustained pad underneath, very light shaker only. 88 bpm, C major, calm and hopeful, a little more melodic and present than the in-game music. Instrumental only, no vocals. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix with soft highs, nothing sharp or harsh. |
| `pin_click_1` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A single wooden clothespin being unclipped from a clothesline, tiny crisp wood and spring click. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `pin_click_2` | sfx | eleven_text_to_sound_v3 | 0.5 | - | One small wooden clothespin snapping open, gentle woody tick with a faint metal spring. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `pin_click_3` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A wooden clothes peg released from a rope, soft dry wooden click. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `cloth_1` | sfx | eleven_text_to_sound_v3 | 0.8 | - | A cotton shirt pulled off a clothesline with a soft fabric swish through the air. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `cloth_2` | sfx | eleven_text_to_sound_v3 | 0.8 | - | Soft linen fabric whooshing gently through the air, short cloth rustle. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `cloth_3` | sfx | eleven_text_to_sound_v3 | 0.8 | - | A light cotton towel flicked once, soft airy fabric flutter. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `fold_puff` | sfx | eleven_text_to_sound_v3 | 0.9 | - | A freshly folded soft cotton towel dropped into a wicker basket, a gentle soft thump with an airy fabric poof, warm and satisfying. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `note` | sfx | eleven_text_to_sound_v3 | 1.2 | - | A single warm soft kalimba note, one pluck, C5, gentle natural decay, dry, no reverb. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `wring` | sfx | eleven_text_to_sound_v3 | 1.0 | - | Wringing out a wet cloth by hand, short squeeze with a few water drips falling. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `unlock` | sfx | eleven_text_to_sound_v3 | 1.4 | - | A small wooden latch clicking open followed by two soft pleasant glass chime notes rising. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `wind` | sfx | eleven_text_to_sound_v3 | 3.0 | - | A sudden strong gust of wind sweeping through a garden, leaves and laundry flapping, swelling then fading. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `win` | sfx | eleven_text_to_sound_v3 | 3.0 | - | A short gentle success jingle on kalimba and soft glockenspiel, five rising notes with a soft shimmer, cozy and satisfying, ends on a warm resolved chord. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `success` | sfx | eleven_text_to_sound_v3 | 2.0 | - | A short cheerful success jingle, bright soft marimba arpeggio with a gentle glockenspiel shimmer, uplifting, warm, resolves cleanly. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `basket_slide` | sfx | eleven_text_to_sound_v3 | 0.8 | - | A wicker laundry basket sliding softly across grass, short gentle rustling drag. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `sparkle` | sfx | eleven_text_to_sound_v3 | 0.9 | - | A very soft delicate magical sparkle, tiny high bells twinkling briefly, gentle. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `blocked` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A soft muffled tug on a piece of fabric that does not come loose, gentle dull cloth pull. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `lock_rattle` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A tiny wooden latch rattling briefly, locked, soft and small. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `rack_hang` | sfx | eleven_text_to_sound_v3 | 0.6 | - | A wooden clothes hanger being hooked onto a wooden rail, soft woody clack with a little fabric rustle. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `ui_soft` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A very soft rounded wooden button tap for a cozy game interface, short and gentle. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `level_start` | sfx | eleven_text_to_sound_v3 | 1.3 | - | A light fresh breeze whoosh followed by one gentle warm chime, calm and inviting. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `coin` | sfx | eleven_text_to_sound_v3 | 0.9 | - | Three small coins dropping softly into a cloth pouch, gentle muted clinks. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `lose` | sfx | eleven_text_to_sound_v3 | 2.2 | - | A soft sad descending three-note kalimba phrase fading into a gentle sigh of wind, tender not harsh. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `machine_door` | sfx | eleven_text_to_sound_v3 | 0.7 | - | A washing machine door closing with a soft rubbery clunk and a small click, close and gentle. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `machine_tumble` | sfx | eleven_text_to_sound_v3 | 2.0 | - | A washing machine drum turning slowly with soft sloshing water and fabric tumbling, gentle, short. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `machine_done` | sfx | eleven_text_to_sound_v3 | 1.0 | - | A soft friendly washing machine finished chime, two warm rounded notes, cozy. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `dryer_tumble` | sfx | eleven_text_to_sound_v3 | 2.0 | - | A tumble dryer drum turning with soft dry fabric tumbling and a low warm hum, gentle, short. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `bird_chirp` | sfx | eleven_text_to_sound_v3 | 0.8 | - | A small songbird chirping twice, cute, close, clear, gentle. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `bird_flutter` | sfx | eleven_text_to_sound_v3 | 0.7 | - | A small bird taking off with quick soft wing flutters, light and airy. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `bird_splat` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A tiny soft wet plop, cartoonish but subtle, a small drop landing on fabric. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `rain_patter` | sfx | eleven_text_to_sound_v3 | 2.5 | - | A brief gentle rain shower starting on fabric and grass, soft pattering drops, cozy, fading out. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `cat_meow` | sfx | eleven_text_to_sound_v3 | 0.9 | - | A small cute cat meowing once, soft and sleepy. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `cat_purr` | sfx | eleven_text_to_sound_v3 | 1.5 | - | A cat purring contentedly, close and soft, short. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `mud_squish` | sfx | eleven_text_to_sound_v3 | 0.5 | - | A soft muddy squish, small and gentle, wet cloth. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `chest_open` | sfx | eleven_text_to_sound_v3 | 1.4 | - | A small wooden treasure chest opening with a soft creak and a gentle magical shimmer. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `purchase` | sfx | eleven_text_to_sound_v3 | 1.0 | - | A soft satisfying cash register style ding with a gentle coin sparkle, cozy game shop purchase. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `garden_ambience` | ambience | eleven_text_to_sound_v3 | 22.0 | - | Calm sunny garden ambience, very gentle breeze in leaves, a few distant soft songbirds, peaceful and quiet, no people, no traffic. |
| `beach_ambience` | ambience | eleven_text_to_sound_v3 | 22.0 | - | Calm beach ambience, gentle small waves lapping on sand, soft sea breeze, a few distant seagulls, peaceful and quiet, no people. |
| `rooftop_ambience` | ambience | eleven_text_to_sound_v3 | 22.0 | - | Quiet city rooftop ambience, soft distant city hum, light breeze, occasional far away pigeons, peaceful, no traffic horns, no voices. |
| `night_ambience` | ambience | eleven_text_to_sound_v3 | 22.0 | - | Calm summer night garden ambience, soft crickets, gentle breeze, very peaceful and quiet. |
| `music_garden` | music | music_v2_5 | 99.0 | - | Sparse soft ambient in-game music for a relaxing puzzle in a sunny garden. Slow fingerpicked nylon guitar and a few spaced kalimba notes, airy warm pad, lots of space between notes. 72 bpm, C major, ASMR-soft, very low dynamics, no drums, no percussion, no bass drum, nothing rhythmic that competes with sound effects. Instrumental only, no vocals. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix with soft highs, nothing sharp or harsh. |
| `music_beach` | music | music_v2_5 | 99.0 | - | Sparse soft ambient in-game music for a relaxing puzzle on a calm beach. Gentle plucked ukulele and a few spaced kalimba notes, soft marimba, airy shimmering pad like distant sea haze. 76 bpm, G major, ASMR-soft, very low dynamics, no drums, no percussion, nothing rhythmic that competes with sound effects. Instrumental only, no vocals. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix with soft highs, nothing sharp or harsh. |
| `music_rooftop` | music | music_v2_5 | 99.0 | - | Sparse soft ambient in-game music for a relaxing puzzle on a quiet city rooftop at golden hour. Mellow electric piano and a few spaced kalimba notes, soft vibraphone, warm low pad, dreamy and a little urban. 70 bpm, F major, ASMR-soft, very low dynamics, no drums, no percussion, nothing rhythmic that competes with sound effects. Instrumental only, no vocals. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix with soft highs, nothing sharp or harsh. |
| `music_night` | music | music_v2_5 | 89.0 | - | Very quiet sparse night-time ambient in-game music for a relaxing puzzle under the stars. Celesta, music-box and kalimba with a few slow spaced notes, deep soft warm pad, dreamy. 60 bpm, C major, lullaby-like, extremely low dynamics, no drums, no percussion, nothing rhythmic. Instrumental only, no vocals. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix with soft highs, nothing sharp or harsh. |
| `machine_done` | sfx | eleven_text_to_sound_v3 | 1.0 | evet | A clear friendly chime from a washing machine finishing its cycle: two warm rounded bell-like notes, medium loud, clean, cozy. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `rain_patter` | sfx | eleven_text_to_sound_v3 | 2.5 | evet | A gentle rain shower pattering clearly on fabric and grass, close microphone, steady soft drops at medium volume, cozy, fading out at the end. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |
| `chest_open` | sfx | eleven_text_to_sound_v3 | 1.4 | evet | A small wooden treasure chest lid slowly creaking open with a soft wooden creak, then a gentle magical shimmer of tiny bells ringing out and fading, about one second long. Close-mic ASMR recording, soft, warm, clean, dry, no music, no voice, no background noise. |

## Yeniden üretim

`python3 tools/make_el_sfx.py --retry <ad>` (kredi harcar), `--process` (harcamaz). Bkz. `docs/AUDIO.md`.
