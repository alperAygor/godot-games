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
| `GameManager` | Faz, sahne kaydı, arka plan sahne ön yüklemesi (`ResourceLoader.load_threaded_request`), geri tuşu | `goto_scene(key)`, `preload_scene(key)`, `start_level(id)`, `selected_level_id`, `finish_run(result)`, `reload_scene()`, `back_requested` |
| `AudioService` | SFX havuzu, ortam, müzik, ayar (ses/müzik) | `play(ad)`, `play_pitched`, `play_variant`, `play_music`, `set_sound_enabled` |
| `AdManager` | Ödüllü/geçiş reklamı orkestrasyonu, limitler, zaman aşımı | `can_offer(p)`, `show_rewarded(p)`, `show_interstitial()`, `interstitial_pacing()`, `rewarded_config()`, `rewarded_finished`, `ad_failed` (yerleşimler: `HINT`, `SKIP`, `INTERSTITIAL`) |
| `GameData` | `res://data/*.json` tabloları | `table(ad)`, `value(tablo, anahtar, varsayilan)` |
| `Progress` | Kayıt: ayar, bayrak, modül verisi (seviye kayıtları "levels" bölümünde), "reklamları kaldır" | `module_value()`, `set_module_value()`, `module_section()`, `remove_ads_owned()`, `persist` |

`Progress.persist=false` iken diske hiç yazılmaz (araçlar/testler ilk iş bunu kapatır).

## Sahne akışı

```
Boot --(0.4 sn: dil, satın alma servisi, ön yükleme, bağlantı kapısı)--> Home --Seviyeler--> Map
                                                                         |  \                |
                                                                       Play   +--(karo)-------+
                                                                         v                    v
                                                                       Game (LevelSession) -- ResultSheet --Sonraki--> Game (sıradaki seviye)
                                                                         |                        |--Seviyeler--> Map
                                                                         +--duraklat: Map / Home  +--Tekrar--> aynı seviye
```

`GameManager.start_level(id)` seviye kimliğini `selected_level_id`ye yazar ve Game'e geçer; `last_result` son çözümün sonucudur.

## Seviye oturumu (kabuk <-> saha)

`Game` (scripts/ui/game.gd) sahaya YALNIZ `LevelSession` (scripts/game/level_session.gd) ile konuşur: `load_level`, `undo`,
`restart`, `show_hint`, `set_input_enabled`; sinyaller `move_count_changed`, `can_undo_changed`, `solved`, `hint_finished`.
Oturum tek yerde kurulur: `Game._create_session()` (`# KANCA: gerçek saha görünümü (YardSession) burada bağlanır`).
Şimdi `StubSession` döner (scripts/game/stub_session.gd: her dokunuş bir hamle, par hamlede çözülür). Gerçek görünüm gelince
yalnız o fonksiyonun gövdesi `return YardSession.new()` olur.

## Seviye ilerlemesi

`LevelProgress` (saf, `scripts/core/level_progress.gd`) kaydı `Progress.set_module_value("levels", seviye_id, {best, stars, solved, skipped})`
ile tutar; yıldız hesabı, kilit ve "devam" hedefi (ilk tamamlanmamış seviye) burada. Sıra `LevelCatalog.entries()`ten gelir.

## Reklam akışı

`Game` -> `RunFlow` (Game'in alt düğümü: ödüllü akış, geçiş kararı) -> `AdManager` -> `AdsProvider` (Mock / NoAds / AdMob).
İpucu ve atla ödüllüdür; ödül YALNIZ sağlayıcı `rewarded` verince; hazır değilse ya da 3 sn içinde gelmezse düğme nedenini söyler
ve akış sürer. Geçiş reklamı kararı saf `AdPacing` (sıra, en az aralık, kaldırıldı mı, ödüllü izlendi mi). Ayrıntı: `MONETIZATION.md`.
Sağlayıcı seçimi: AdMob native tekil nesneleri varsa AdMob; yoksa debug'da Mock; release'te NoAds (sahte ödül gerçek oyuncuya verilmez).

## Satın alma

`IapService` (Boot kurar, autoload değil) -> `IapProvider` (Mock / "mağaza yok"; gerçek Play Billing kancası `make_default_provider`).
Sahiplik `Progress.remove_ads_owned()`; UI yalnız `UiShopRow`.

## Yeni içerik eklerken

1. Denge sayısı -> `data/*.json`
2. Kural -> `scripts/core/` (saf sınıf) + `tests/unit/test_*.gd`
3. Görsel -> `scenes/` + `scripts/ui/`
4. Ses -> dosyayı `assets/audio/sfx/` altına koy (ya da `tools/make_sfx.py`), `data/sounds.json`'a yaz
5. Metin -> `data/i18n/strings.csv` sonuna 3 dilde ekle
6. Yeni sahne -> `GameManager.SCENES`'e satır
