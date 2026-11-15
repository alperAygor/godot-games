# Ses lisansı ve üretim kaydı

Tarih: 2026-11-15. Bu belge `docs/RELEASE_ROADMAP.md` T-A1 işinin kaydıdır. **Yalnız 34 / 38 ses ücretli plan altında yeniden üretildi; 4 ses hâlâ ücretsiz plan sesidir (aşağıda).**

## Plan (API'nin bildirdiği)

- `tier`: **starter**, `status`: active, aylık dönem (`billing_period=monthly_period`).
- Kredi: sınır 34 163; bu işten önce kullanılan 7 799; sonra 11 564; kalan 22 599. Bu işin tüketimi **3 765 kredi** (bütçe tavanı 4 000). Sıfırlanma: 2026-12-14.
  (Hesap başka projelerle ortaktır; fark yalnız bu işin istekleri sırasında ölçüldü, sayaç gecikmeli güncellendiği için varlık başına kredi yaklaşıktır, toplam kesindir.)
- İstek sayısı: **39** (34 başarılı üretim + 5 `429 rate_limited` hatası; hatalı istekler ses üretmedi ve kredi düşmedi, aynı varlıklar sonra tek kez başarıyla üretildi). Kalitesizlik nedeniyle yeniden deneme: **0**.
- Modeller: ses efektleri/ortam `eleven_text_to_sound_v3` (`mp3_44100_128`), müzik ve müzik vuruşları `music_v2_5` (`force_instrumental`).

## Ticari kullanım (ElevenLabs şartları)

Şartlar: <https://elevenlabs.io/terms-of-use> (madde 1(c), 2026-11-15'te okundu): ücretsiz kullanıcı için "you may only use the Services for non-commercial purposes"; ücretli kullanıcı için "you may use the Services for commercial purposes" (Yasaklı Kullanım Politikası'na uymak koşuluyla; aynı madde Çıktı kullanımına da uygulanır). Fiyatlar: <https://elevenlabs.io/pricing/api>.
Not: bu belge hukuki görüş değildir. Ücretsiz plan sesleri (26-27 Ekim 2026) ticari yayın için lisans sorusudur.

## Ücretli plan altında yeniden üretilen varlıklar (34)

Ham dosyalar `build/sfx_raw_v2/` (git dışı); her istek `build/sfx_raw_v2/ledger.json`. SHA-256 ve tam tarifler: `assets/audio/PROVENANCE.md`. Gönderilen dosya = ham çıktının kırpılmış/seviyelenmiş mp3'ü (içerik ElevenLabs çıktısıdır). Tarife efektlerde `STYLE` eki (tools/make_sfx.py) eklenmiştir.

| ad | tür | model | süre sn | kredi (≈) | tarif |
|---|---|---|---:|---:|---|
| `stamp` | sfx | eleven_text_to_sound_v3 | 0.6 | 6 | A heavy rubber office stamp with a wooden handle pressed firmly onto a stack of paper on a wooden counter, one solid dry thunk with a short paper slap, very short. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `ink_press` | sfx | eleven_text_to_sound_v3 | 0.6 | 6 | A rubber stamp pressed down on an ink pad, a soft wet dull press, one quick press, no rattle. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `note_drop` | sfx | eleven_text_to_sound_v3 | 0.6 | 6 | A single paper banknote laid down on a wooden counter, soft paper rustle and a very light thud. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `paper_slide` | sfx | eleven_text_to_sound_v3 | 0.8 | 8 | A few sheets of paper sliding across a wooden desk, a short soft slide. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `bell` | sfx | eleven_text_to_sound_v3 | 1.0 | 10 | A small brass service desk bell, a single bright ding with a short natural ring, dry. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `coin` | sfx | eleven_text_to_sound_v3 | 0.8 | 8 | Three coins dropped into a metal cash tray, a short bright metallic clink, dry. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `error` | sfx | eleven_text_to_sound_v3 | 0.6 | 6 | A short low electric buzzer tone for a wrong answer on an old office device, dull and muted, a single soft buzz, not harsh. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `calc_key` | sfx | eleven_text_to_sound_v3 | 0.5 | 5 | A single mechanical calculator key press, a tiny dry plastic click. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `footsteps` | sfx | eleven_text_to_sound_v3 | 1.8 | 18 | Three slow footsteps of a person in leather shoes walking up to a counter on a hard tiled floor indoors, dry. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `page` | sfx | eleven_text_to_sound_v3 | 0.8 | 8 | A page of a printed rulebook turning, a short dry paper rustle. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `drawer` | sfx | eleven_text_to_sound_v3 | 1.0 | 10 | A metal cash register drawer sliding open with a light bell ding, a short mechanical till sound. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `chime_win` | sfx | eleven_text_to_sound_v3 | 1.6 | 16 | A gentle warm bell chime of three rising notes for a finished work day, short, dry office. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `chime_fail` | sfx | eleven_text_to_sound_v3 | 1.6 | 16 | A low dull bell strike with a slow fade, sad and short, dry office. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `door_buzz` | sfx | eleven_text_to_sound_v3 | 1.3 | 13 | An old office door entry buzzer, one short electric buzz, then a heavy door clicking open. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `crumple` | sfx | eleven_text_to_sound_v3 | 0.8 | 8 | A sheet of paper being crumpled in a fist, short. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `siren` | sfx | eleven_text_to_sound_v3 | 1.5 | 15 | A short police siren whoop heard through a window, two rising tones, muffled and distant. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `pen_scratch` | sfx | eleven_text_to_sound_v3 | 1.0 | 10 | A fountain pen scratching a signature on paper, short. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `lens` | sfx | eleven_text_to_sound_v3 | 0.8 | 8 | A magnifying glass sliding on a wooden desk, a short glassy scrape. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `uv_on` | sfx | eleven_text_to_sound_v3 | 1.2 | 12 | An ultraviolet lamp switching on: a soft click then a short electric hum rising, short. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `clock_tick` | sfx | eleven_text_to_sound_v3 | 2.0 | 20 | A large wall clock ticking steadily, four ticks, dry quiet room. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `flicker` | sfx | eleven_text_to_sound_v3 | 1.4 | 14 | A fluorescent tube flickering and buzzing for a moment then steadying, short. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `phone` | sfx | eleven_text_to_sound_v3 | 2.0 | 20 | An old rotary telephone ringing twice in a quiet office, dry. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `tube` | sfx | eleven_text_to_sound_v3 | 1.6 | 16 | A pneumatic tube capsule whooshing down a pipe and landing with a soft metallic thunk in a wooden tray, short, dry. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `stinger_win` | sting | music_v2_5 | 6.0 | 94 | A very short warm victory sting for finishing the story: three soft piano notes rising and a gentle chord, instrumental. |
| `ambient` | loop | eleven_text_to_sound_v3 | 12.0 | 119 | Quiet empty government office room tone, faint fluorescent light hum, distant muffled city noise outside, steady and seamless. Seamless steady room tone, no music, no voice, no sudden events, nothing sharp. |
| `desk_calm` | music | music_v2_5 | 75.0 | 928 | Tense but steady background music for working at a counter all day: a minimal repeating pattern of muted piano and plucked double bass, a soft wood-block clock-like pulse, a low string drone, understated bureaucratic suspense, no melody climax, instrumental. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix, nothing sharp or harsh. |
| `theme_main` | music | music_v2_5 | 75.0 | 928 | Main theme of a melancholic bureaucratic drama game: a slow, wistful waltz in a minor key played by a solo accordion and a muted upright piano, a soft typewriter-like rhythmic ticking, a lonely clarinet answering the melody, restrained and dignified, grey office nostalgia, lo-fi vintage recording, instrumental, memorable simple main melody. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix, nothing sharp or harsh. |
| `morning` | music | music_v2_5 | 45.0 | 557 | A short gentle morning piece for an old city newspaper: pizzicato strings and a soft clarinet playing a light, slightly sleepy tune, a faint typewriter rhythm, tired but warm, instrumental. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix, nothing sharp or harsh. |
| `evening` | music | music_v2_5 | 60.0 | 742 | Quiet evening at a small apartment after a hard day: a tender solo piano with a warm cello, slow and intimate, a little sad, a little grateful, instrumental. Constant gentle dynamics from the first second to the last: no intro, no build-up, no drop, no ending, no fade, so the track loops seamlessly. Smooth warm mix, nothing sharp or harsh. |
| `stinger_fail` | sting | music_v2_5 | 6.0 | 94 | A very short sad sting for a failure: two low piano notes and a muted brass sigh, instrumental. |
| `buzzer` | sfx | eleven_text_to_sound_v3 | 0.7 | 7 | A short office buzzer for denied entry, one dull buzz, dry, not harsh. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `typewriter` | sfx | eleven_text_to_sound_v3 | 2.0 | 20 | An old mechanical typewriter typing a short burst of keys and a carriage return bell, dry. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `cash_slide` | sfx | eleven_text_to_sound_v3 | 0.9 | 9 | Banknotes and a few coins sliding through a metal tray slot, short. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |
| `coins_pile` | sfx | eleven_text_to_sound_v3 | 1.2 | 12 | A handful of coins poured into a tin cup, a short dry jingle. Dry close recording in a quiet small 1980s government office, realistic and tactile, no music, no voice, no reverb, no background noise, not cartoonish, nothing harsh. |

## HÂLÂ ücretsiz plan sesi (4) — ticari yayın için lisans sorusu

Bu dosyalar yalnız seviye eşitlemesi için kazançla yeniden kodlandı (içerik değişmedi); kaynak hâlâ 26-27 Ekim 2026 ücretsiz plan üretimidir. Sahip karar verir: sonra yeniden üret, yerine sessizlik/basit sentez koy, ya da kaldır.

| ad | kullanım | tahmini yeniden üretim kredisi |
|---|---|---:|
| `desk_tense` | günün son bölümü | ~938 |
| `ending_warm` | oyun sonu, oyunda bir kez | ~500 |
| `ending_dark` | oyun sonu, oyunda bir kez | ~500 |
| `ending_escape` | oyun sonu, oyunda bir kez | ~500 |

Toplam: ~2438 kredi (Starter planında kalan ~22 600 kredinin içinde; müzik ölçülen hız ≈ 750 kredi/dk).  
Seçenek notu: `desk_tense` gişede günün son bölümünde çalar (sık duyulur); `ending_*` oyunda bir kez duyulur, en düşük öncelik.

`AudioManager.blip_stream()` kodla üretilmiş sentezdir (lisans sorunu yok).

## Yeniden üretim

`python3 tools/make_sfx.py --account` (yalnız sayılar), `--estimate`, `desk_tense ending_warm ...` (kredi harcar, `CREDIT_BUDGET` tavanı), `--process` (harcamaz). Bkz. `docs/AUDIO.md`.
