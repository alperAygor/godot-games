# Ses: sıralama, üretim, seviye

Tarih: 2026-11-15 · İş: T-A1 (kritik seslerin ücretli planda yeniden üretimi). Lisans kaydı: `docs/AUDIO_LICENSE.md`; üretim kaydı: `assets/audio/PROVENANCE.md`; kayıt defteri: `data/sounds.json`.

## 1. Kritiklik sıralaması (38 dosya)

Ölçüt: kaç kez duyulur (müşteri / gün / oyun başına), hissin merkezinde mi, süre/maliyet. Sıra = üretim sırası. Kod çağrıları `Feel.sfx` (scripts/ui) ve `AudioManager` üzerindendir.

| # | ad | yeniden üretildi | süre sn (üretim) | sıklık / not |
|---:|---|---|---:|---|
| 1 | `stamp` | evet | 0.6 | her karar (müşteri başına 1) + not onayı; imza ses |
| 2 | `ink_press` | evet | 0.6 | her kararda damganın 50 ms altında katman |
| 3 | `note_drop` | evet | 0.6 | müşteri başına 2-4 (para/belge bırakma) |
| 4 | `paper_slide` | evet | 0.8 | her sürükle-bırak + belge kayması |
| 5 | `bell` | evet | 1.0 | müşteri gelişi (4'ün 3'ü) |
| 6 | `coin` | evet | 0.8 | her doğru kararda |
| 7 | `error` | evet | 0.6 | her hatada |
| 8 | `calc_key` | evet | 0.5 | hesap makinesi tuşu: oyundaki en sık ses |
| 9 | `footsteps` | evet | 1.8 | her müşteri gelişi |
| 10 | `page` | evet | 0.8 | kural kitabı sayfası, öğretici |
| 11 | `drawer` | evet | 1.0 | doğru 'tamamla' kararı |
| 12 | `chime_win` | evet | 1.6 | gün sonu (iyi), her gün |
| 13 | `chime_fail` | evet | 1.6 | gün sonu (kötü) / oyun kaybı |
| 14 | `door_buzz` | evet | 1.3 | her 4. müşteri gelişi |
| 15 | `crumple` | evet | 0.8 | el koyma kararı |
| 16 | `siren` | evet | 1.5 | polis kararı |
| 17 | `pen_scratch` | evet | 1.0 | not sayfası imzası |
| 18 | `lens` | evet | 0.8 | mercek aracı |
| 19 | `uv_on` | evet | 1.2 | UV lambası aracı |
| 20 | `clock_tick` | evet | 2.0 | günün son dakikalarında her 2 sn |
| 21 | `flicker` | evet | 1.4 | rastgele (~20-35 sn'de bir) |
| 22 | `phone` | evet | 2.0 | ofis aramaları, gün başına birkaç |
| 23 | `tube` | evet | 1.6 | ofis notları, gün başına birkaç |
| 24 | `stinger_win` | evet | 6.0 | oyun sonu (iyi), oyunda bir kez |
| 25 | `ambient` | evet | 12.0 | her ekranda sürekli (kısık) |
| 26 | `desk_calm` | evet | 75.0 | gişe müziği: oyun süresinin çoğu |
| 27 | `theme_main` | evet | 75.0 | ana menü, her açılış |
| 28 | `morning` | evet | 45.0 | her gün başı |
| 29 | `evening` | evet | 60.0 | her gün sonu |
| 30 | `desk_tense` | **hayır** | 75.0 | günün son bölümü |
| 31 | `stinger_fail` | evet | 6.0 | çağrılmıyor (kodda kullanılmıyor) |
| 32 | `buzzer` | evet | 0.7 | çağrılmıyor |
| 33 | `typewriter` | evet | 2.0 | çağrılmıyor (daktilo etkisi kodla bip) |
| 34 | `cash_slide` | evet | 0.9 | çağrılmıyor |
| 35 | `coins_pile` | evet | 1.2 | çağrılmıyor |
| 36 | `ending_warm` | **hayır** | 40.0 | oyun sonu, oyunda bir kez |
| 37 | `ending_dark` | **hayır** | 40.0 | oyun sonu, oyunda bir kez |
| 38 | `ending_escape` | **hayır** | 40.0 | oyun sonu, oyunda bir kez |

Yeniden üretilenler en kritik 34'tür: tüm tek-atımlık efektler ve arayüz sesleri, iki müzik vuruşu, ambient ve dört müzik (`desk_calm` gişe döngüsü, `theme_main` menü, `morning`, `evening`). Müzik yaklaşık 750 kredi/dk olduğundan kalan dört parça bütçeye sığmadı: `desk_tense` (75 sn), `ending_warm/dark/escape` (40 sn). Hiç çağrılmayan efektler (`buzzer`, `typewriter`, `cash_slide`, `coins_pile`, `stinger_fail`) ucuz olduğu için lisans temizliği adına yine de yeniden üretildi.

## 2. Seviye kuralları

Ses yöneticisi bus kazançları sabittir (değiştirilmedi): SFX 0 dB, müzik parçası −5 dB, ambient −13 dB (Music bus). Hedefler buna göre seçildi (`LEVELS`, tools/make_sfx.py):

- **Kısa olaylar** (efektler): ölçü = 150 Hz üstü en yüksek 100 ms RMS ("olay yüksekliği", `ev100`); LUFS-I 0,4 sn bloklarla ölçüldüğü için darbeli seslerde (damga) yanıltıcıdır. Hedefler: damga/mürekkep (hero) −15,5; oyun sesleri (core) −19,5; arayüz −23,5; ara sıra (spot) −22,5; gün sonu (stinger/chime) −19 dBFS. Tepe tavanı (gerçek tepe) −1,5…−4 dB; tavan hedefe izin vermezse kategoriye göre en çok +9/+6/+4 dB ek kazanç hızlı sınırlayıcıyla (alimiter 0,5 ms/8 ms) verilir, hedef yinelemeli aranır. Sonuç: **damga tek başına en yüksek olay (ev100 −16,6; sonraki en yüksek −19,4)**.
- **Ambient / müzik / 6 sn vuruşlar:** LUFS-I. Müzik −18 (tepe ≤ −1,5), ambient −24, stinger −19 (tepe ≤ −2).
- Efektlerde 70 Hz altı ve 9,5 kHz üstü yumuşatıldı (telefon hoparlörü, hışırtı); ambient 8 kHz üstü. Baş sessizlik ≈ 3 ms, kuyruk doğal sönümün ~120 ms'i + 50 ms fade.
- Döngüler (ambient 1,5 sn, müzik 3 sn): kuyruk başa eşit güçlü çapraz geçişle bağlandı; dikiş ölçüsü aşağıda (`jump_ratio` < 4 ise tık riski yok). Godot döngüsü kodda (`stream.loop = true`); `.import` dosyaları değişmedi.
- Henüz yeniden üretilmeyen 4 müzik yalnız kazançla LUFS −18'e eşitlendi (içerik değişmedi).
- Yığın testi (`audio_check.py --stack`: gişe müziği + ambient + 6 efekt aynı anda, bus kazançlarıyla): LUFS-I −22,1, gerçek tepe −2,9 dBTP (kırpma yok).
- Not: MP3'te kodlayıcı gecikmesi Godot'ta ~25 ms ek gecikme olabilir (ffmpeg gecikme bilgisini yok sayar); ad/yol/API değişmesin diye biçim mp3 kaldı.

## 3. Ölçüm tablosu (38 ses)

`ev100` = olay yüksekliği (dBFS), LUFS-I kısa seslerde ≥0,5 sn'ye sessizlikle tamamlanarak ölçüldü, TP = gerçek tepe dBTP. "önce" = ücretsiz plan özgünü (git HEAD).

| ad | yeni | süre sn | LUFS-I | ev100 | TP dBTP | önce LUFS-I / ev100 / TP | baş/son ms | dikiş (jump_ratio) |
|---|---|---:|---:|---:|---:|---|---|---|
| `stamp` | evet | 0.50 | -22.1 | -16.6 | -2.2 | -63.9 / -60.3 / -46.3 | 2 / 75 |  |
| `ink_press` | evet | 0.43 | -25.3 | -22.0 | -2.5 | -36.8 / -31.9 / -12.8 | 3 / 48 |  |
| `note_drop` | evet | 0.53 | -21.8 | -19.8 | -6.0 | -35.7 / -32.5 / -16.2 | 3 / 41 |  |
| `paper_slide` | evet | 0.80 | -18.7 | -19.8 | -8.6 | -22.4 / -21.7 / -13.9 | 3 / 30 |  |
| `bell` | evet | 0.96 | -26.1 | -20.0 | -3.4 | -51.5 / -45.9 / -34.5 | 3 / 132 |  |
| `coin` | evet | 0.63 | -22.9 | -20.1 | -3.0 | -14.6 / -9.2 / 1.4 | 0 / 118 |  |
| `error` | evet | 0.60 | -18.2 | -19.9 | -9.4 | -9.9 / -11.9 / -0.4 | 2 / 36 |  |
| `calc_key` | evet | 0.33 | -27.2 | -23.8 | -4.6 | -27.1 / -26.4 / -6.3 | 3 / 144 |  |
| `footsteps` | evet | 1.66 | -28.1 | -20.1 | -3.4 | -22.2 / -15.5 / -2.2 | 3 / 62 |  |
| `page` | evet | 0.68 | -24.7 | -20.1 | -3.4 | -11.8 / -7.7 / 0.1 | 3 / 34 |  |
| `drawer` | evet | 0.98 | -25.1 | -19.9 | -7.4 | -14.3 / -11.3 / -1.4 | 3 / 172 |  |
| `chime_win` | evet | 1.60 | -21.4 | -19.5 | -4.6 | -21.2 / -12.3 / -5.6 | 0 / 146 |  |
| `chime_fail` | evet | 1.58 | -28.8 | -19.4 | -7.8 | -10.4 / -11.2 / -0.3 | 3 / 78 |  |
| `door_buzz` | evet | 1.28 | -19.6 | -19.9 | -6.8 | -6.9 / -8.8 / 1.2 | 5 / 82 |  |
| `crumple` | evet | 0.80 | -20.9 | -20.0 | -3.3 | -37.2 / -35.8 / -21.6 | 1 / 33 |  |
| `siren` | evet | 1.48 | -24.5 | -22.9 | -13.8 | -6.3 / -4.8 / -2.5 | 0 / 33 |  |
| `pen_scratch` | evet | 0.99 | -29.6 | -24.0 | -8.6 | -14.2 / -8.5 / 0.2 | 5 / 50 |  |
| `lens` | evet | 0.75 | -27.0 | -23.9 | -13.5 | -9.8 / -5.1 / -0.3 | 3 / 136 |  |
| `uv_on` | evet | 0.39 | -28.0 | -24.8 | -4.4 | -29.6 / -26.9 / -6.7 | 3 / 174 |  |
| `clock_tick` | evet | 1.27 | -28.6 | -22.9 | -7.8 | -20.1 / -16.3 / -0.8 | 2 / 128 |  |
| `flicker` | evet | 1.27 | -22.5 | -22.9 | -11.3 | -12.9 / -19.5 / -6.0 | 3 / 25 |  |
| `phone` | evet | 1.25 | -26.9 | -23.0 | -4.6 | -7.6 / -9.0 / -0.2 | 3 / 273 |  |
| `tube` | evet | 0.83 | -26.1 | -23.0 | -8.8 | -17.3 / -10.7 / -0.3 | 3 / 249 |  |
| `stinger_win` | evet | 5.71 | -20.0 | -11.5 | -2.5 | -12.2 / -10.3 / -1.5 | 2 / 151 |  |
| `ambient` | evet | 10.50 | -24.4 | -23.2 | -10.0 | -39.0 / -40.7 / -26.1 | 0 / 0 | 0.48 |
| `desk_calm` | evet | 72.02 | -18.5 | -15.6 | -5.1 | -13.3 / -10.2 / -1.4 | 0 / 0 | 0.13 |
| `theme_main` | evet | 72.02 | -18.5 | -11.1 | -5.4 | -15.4 / -11.1 / -4.9 | 0 / 0 | 0.69 |
| `morning` | evet | 42.02 | -18.9 | -13.8 | -2.0 | -29.6 / -19.9 / -13.6 | 0 / 0 | 0.37 |
| `evening` | evet | 57.02 | -18.5 | -13.5 | -3.6 | -12.6 / -5.3 / -1.0 | 0 / 0 | 2.64 |
| `desk_tense` | hayır | 75.05 | -17.4 | -12.5 | -1.5 | -17.4 / -12.5 / -1.5 | 35 / 19 | 0.0 |
| `stinger_fail` | evet | 6.08 | -21.3 | -12.2 | -2.5 | -13.4 / -12.2 / -1.5 | 3 / 271 |  |
| `buzzer` | evet | 0.56 | -21.0 | -19.9 | -5.8 | -4.7 / -5.0 / 0.9 | 1 / 123 |  |
| `typewriter` | evet | 1.09 | -29.6 | -24.0 | -5.3 | -15.2 / -13.8 / -2.2 | 3 / 244 |  |
| `cash_slide` | evet | 0.79 | -27.0 | -20.1 | -3.3 | -23.0 / -19.0 / -5.5 | 3 / 14 |  |
| `coins_pile` | evet | 0.97 | -25.0 | -19.9 | -4.3 | -16.3 / -13.3 / 0.1 | 3 / 121 |  |
| `ending_warm` | hayır | 40.07 | -18.5 | -12.8 | -4.6 | -14.8 / -9.1 / -1.0 | 33 / 2895 |  |
| `ending_dark` | hayır | 40.02 | -18.2 | -12.1 | -4.3 | -18.2 / -12.1 / -4.3 | 1024 / 5427 |  |
| `ending_escape` | hayır | 40.07 | -18.5 | -14.0 | -7.9 | -12.5 / -8.0 / -2.0 | 557 / 4946 |  |

Toplam ses boyutu: 7480 KB (≈ 7.3 MB; hedef ≤ 9 MB). Eski: 7 924 KB.

## 4. Dürüst notlar: insan kulağı gerekenler

Hiçbir ses dinlenmedi; yalnız ölçüldü. Önce dinlenmesi gerekenler:
1. **`stamp` ve `ink_press`**: +9 dB'ye varan hızlı sınırlayıcı kullanıldı (ham dosya tepesi ≥ +1,7 dBTP, yani zaten kırpık geliyordu); tok "thunk" mu, yoksa sıkışmış/cızırtılı mı? `ink_press` hedefe varamadı (−22): damganın altında yumuşak katman olarak yeterli mi?
2. **Müzik döngü dikişleri** (`desk_calm`, `theme_main`, `morning`, `evening`): ölçü temiz ama müzikal olarak (ritim/ölçü sınırı) kulakla doğrulanmalı; `theme_main` dikişinde 200 ms RMS farkı 7,9 dB (ölçü sınırı yakınında olabilir). Parçalar "tense bureaucratic" tonuna uyuyor mu; `desk_calm` 72 sn döngüde yorucu mu?
3. **`ambient`** (10,5 sn döngü): tekrarı fark ediliyor mu, floresan uğultusu rahatsız eder mi?
4. **Arayüz sesleri** (`calc_key` en sık, `flicker`, `siren`, `error`): telefon hoparlöründe sert mi; hepsi "1980'ler ofis" tonunda mı, çizgi film gibi mi?
5. Üretilen içerik tarifle uyuşuyor mu (ör. `footsteps` üç adım mı, `clock_tick` dört tik mi, `chime_win` üç yükselen nota mı) — bunlar ölçülemez.
6. Gerçek cihazda ses seviyesi dengesi (müzik vs efekt) ve MP3 başlangıç gecikmesi.

## 5. Araçlar

- `tools/make_sfx.py`: üretim + işleme + kayıtlar (`--account`, `--estimate`, `--process`, `--retry`). `tools/audio_check.py`: ölçüm tablosu (`--stack`). `tools/audio_lib.py`: ölçüm yardımcıları (ffmpeg + numpy). Anahtar `.env.local`'den python-dotenv ile okunur, hiçbir yere yazdırılmaz. `tools/make_music.py` (eski, ücretsiz plan) bu iş için kullanılmadı.
- Test: `tests/unit/test_audio_assets.gd` (kayıt = disk, her ses yüklenir, SHA-256 eşleşir, yeniden üretilen her ses lisans/üretim kaydında).
