# ARCHITECTURE — Switchyard

## Katmanlar

```
UI (Control)            -> sunum, giriş (scripts/ui)
Autoload servisleri     -> akış, ses, reklam, veri, kayıt (scripts/autoload)
Core (RefCounted)       -> saf mantık, sahnesiz, birim testli (scripts/core)
Services (AdsProvider)  -> dış SDK sınırı (scripts/services)
Net (OnlineGate)        -> bağlantı kapısı (scripts/net)
```

Bağımlılık yukarıdan aşağı; `core` hiçbir katmanı tanımaz (autoload'a yalnız düğüm yoluyla, `Loc` gibi savunmacı).

## Autoload'lar (sıra korunur)

| Servis | Sorumluluk | API |
|---|---|---|
| `GameManager` | Faz, sahne kaydı, arka plan sahne ön yüklemesi (`ResourceLoader.load_threaded_request`), geri tuşu | `goto_scene(key)`, `preload_scene(key)`, `start_game()`, `finish_run(result)`, `reload_scene()`, `back_requested` |
| `AudioService` | SFX havuzu, ortam, müzik, ayar (ses/müzik) | `play(ad)`, `play_pitched`, `play_variant`, `play_music`, `set_sound_enabled` |
| `AdManager` | Ödüllü/geçiş reklamı orkestrasyonu, limitler, zaman aşımı | `can_offer(p)`, `show_rewarded(p)`, `show_interstitial()`, `interstitial_pacing()`, `rewarded_finished` |
| `GameData` | `res://data/*.json` tabloları | `table(ad)`, `value(tablo, anahtar, varsayilan)` |
| `Progress` | Kayıt: seviye, jeton, ayar, bayrak, modül verisi, "reklamları kaldır" | `level()`, `coins()`, `complete_level()`, `module_value()`, `persist` |

`Progress.persist=false` iken diske hiç yazılmaz (araçlar/testler ilk iş bunu kapatır).

## Sahne akışı

```
Boot --(0.4 sn, dil + ön yükleme + bağlantı kapısı)--> Home --(Seviye N)--> Game --(kazan/kaybet)--> ResultSheet
                                                         ^                                              |
                                                         +---------(duraklat > ana ekran)---------------+
```

`GameManager.last_result` son turun sonucudur (`finish_run`).

## Reklam akışı

`RunFlow` (Game'in alt düğümü) → `AdManager` → `AdsProvider` (Mock / NoAds / AdMob). Ödül YALNIZ sağlayıcı `rewarded`
verince; reklam hazır değilse ya da 3 sn içinde gelmezse akış sessizce sürer. Geçiş reklamı kararı saf `AdPacing`.
Sağlayıcı seçimi: AdMob native tekil nesneleri varsa AdMob; yoksa debug'da Mock; release'te NoAds (sahte ödül gerçek oyuncuya verilmez).

## Yeni içerik eklerken

1. Denge sayısı → `data/*.json`
2. Kural → `scripts/core/` (saf sınıf) + `tests/unit/test_*.gd`
3. Görsel → `scenes/` + `scripts/ui/`
4. Ses → dosyayı `assets/audio/sfx/` altına koy (ya da `tools/make_sfx.py`), `data/sounds.json`'a yaz
5. Metin → `data/i18n/strings.csv` sonuna 3 dilde ekle
6. Yeni sahne → `GameManager.SCENES`'e satır
