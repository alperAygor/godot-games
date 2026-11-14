# ARCHITECTURE — Priz kabuğu

Bu belge oyundan bağımsız **uygulama kabuğunu** anlatır (Boot → Home → Game → sonuç sayfası, kayıt, ses, reklam, dil,
arayüz takımı). Oyunun kuralları ayrı katmandadır (çekirdek: `scripts/core/`, `docs/CORE_API.md`; diorama: sahne tarafı).

## Katmanlar

```
UI (Control)            -> sunum, giriş (scripts/ui)
Autoload servisleri     -> akış, ses, reklam, veri, kayıt (scripts/autoload)
Shell (RefCounted)      -> kabuğun saf mantığı, sahnesiz, birim testli (scripts/shell)
Services (AdsProvider)  -> dış SDK sınırı (scripts/services)
Net (OnlineGate)        -> bağlantı kapısı (scripts/net)
Core (RefCounted)       -> OYUN kuralları (scripts/core; başka işçinin alanı, kabuk ona dokunmaz)
```

Bağımlılık yukarıdan aşağı; `shell` hiçbir katmanı tanımaz (autoload'a yalnız düğüm yoluyla, `Loc`/`Haptics` gibi savunmacı).
`scripts/shell/` içeriği: `Loc`, `AdPacing`, `ProgressData`, `AnalyticsLog`, `Motion`, `Juice`, `Icons`, `Quantity`,
`Haptics`, `PlaceholderRun`. Testleri `tests/unit/test_shell_*.gd`.

## Autoload'lar (sıra korunur)

| Servis | Sorumluluk | API |
|---|---|---|
| `GameManager` | Faz, sahne kaydı, arka plan sahne ön yüklemesi (`ResourceLoader.load_threaded_request`), geri tuşu | `goto_scene(key)`, `preload_scene(key)`, `start_game()`, `finish_run(result)`, `reload_scene()`, `back_requested` |
| `AudioService` | SFX havuzu, ortam, müzik, ayar (ses/müzik) | `play(ad)`, `play_pitched`, `play_variant`, `play_music`, `set_sound_enabled` |
| `AdManager` | Ödüllü/geçiş reklamı orkestrasyonu, banner politikası, limitler, zaman aşımı | `can_offer(p)`, `show_rewarded(p)`, `show_interstitial()`, `should_show_interstitial(seviye, odullu_izlendi)`, `set_banner_visible(ekran)`, `is_offer_allowed(seviye)`, `rewarded_finished` |
| `GameData` | `res://data/*.json` tabloları | `table(ad)`, `value(tablo, anahtar, varsayilan)` |
| `Progress` | Kayıt: seviye, yıldız, jeton, seri, ayar, bayrak, modül verisi, "reklamları kaldır" | `level()`, `coins()`, `complete_level(yildiz)`, `record_loss()`, `stars_for(n)`, `win_streak()`, `is_quiet_period()`, `quality_tier()`, `module_value()`, `persist` |

`Progress.persist=false` iken diske hiç yazılmaz (araçlar/testler ilk iş bunu kapatır).
Sigorta hakları **seviye başınadır ve KAYDEDİLMEZ**: `Progress.begin_level_fuses()`, `lose_fuse()`, `grant_extra_fuse()`, `fuses_left()`.

## Sahne akışı

```
Boot --(0.4 sn, dil + ön yükleme + bağlantı kapısı)--> Home --(Oyna)--> Game --(kazan/kaybet)--> ResultSheet
                                                         ^                                              |
                                                         +---------(duraklat > ana ekran)---------------+
```

`GameManager.last_result` son turun sonucudur (`finish_run`). Home = "mahalle" ekranı (banner burada; `neighbourhood`).

## Game ↔ kabuk sözleşmesi (KÜÇÜK TUTULUR)

Gerçek diorama sahnesi `scenes/Game.tscn`'in yerine geçerken `scripts/ui/game.gd`'nin "YER TUTUCU" bölümlerini değiştirir;
aşağıdaki çağrılar aynı kalır. Oyun sahnesi `RunFlow` (alt düğüm) ve `GameHud` ile konuşur, kabuğun geri kalanına dokunmaz.

| Ne zaman | Çağrı | Sonuç |
|---|---|---|
| Sahne açılışı | `GameManager.set_phase(GameManager.Phase.GAME)`; `add_child(RunFlow.new())`; `add_child(GameHud.new())` | HUD: duraklat, seviye noktaları, jeton simgeleri |
| Seviye başı (ilk tur, tekrar, devam) | `Progress.begin_level_fuses()` ve `flow.on_level_start(seviye)` (seviye = `Progress.level()`) | sigorta hakkı kurulur, ödüllü sınırlar sıfırlanır, **banner gizlenir** (`game` ekranı), analitik |
| Seviye numarası | `Progress.level()` (1 tabanlı); HUD için `hud.set_level(n)` | numara ASLA yazılmaz, yalnız noktalar |
| Sigorta atar | `Progress.lose_fuse()` → kalan hak (0 ise seviye kaybedilir) | |
| **Kazandı** | `var r := flow.on_win(seviye, yildiz)`; `GameManager.finish_run(r + {"won": true})`; `ResultSheet.win(self, r["coins"], flow.can_watch(AdManager.Placement.DOUBLE_COINS), r["stars"])` | jeton + yıldız + seri + seviye kaydedilir; `r = {coins, level, finished_level, stars, streak}` |
| Jeton (ödül) | `r["coins"]` (bu seviyenin kazancı, `balance.json win_coins`); ek jeton: `Progress.add_coins(n)` | miktar simgelerle gösterilir (`UiChip`/`Quantity`) |
| **Kaybetti** | `flow.on_lose(seviye)`; `GameManager.finish_run({"won": false})`; `ResultSheet.lose(self, flow.can_watch(AdManager.Placement.EXTRA_FUSE))` | seri biter |
| Ödüllü reklam | `flow.can_watch(placement)` (hazır + sınır + sessiz dönem değil) → `flow.watch(placement, on_success, on_failure)` | ödül YALNIZ `on_success`te verilir |
| Seviye geçişi | `flow.maybe_interstitial(BİTİRİLEN_seviye, then)` | politika `AdPacing`de; reklam yoksa `then` hemen çalışır |
| Ana ekran / tekrar | `GameManager.goto_scene(&"home")`, `reload_scene()` | |

Ödüllü yerleşimler (`AdManager.Placement`): `EXTRA_FUSE` (sigortalar bitince +1 hak), `DOUBLE_COINS`, `HINT`, `DAY_PREVIEW`,
`RENOVATION_EARLY`. Titreşim: `Haptics.tick()/thud()/success()` (fiş oturunca `thud`).
Sahne dili değişince `GameManager.reload_scene()` sahneyi baştan kurar; oyun sahnesi bunu kaldırabilmelidir.

## Ekranda rakam yok

Hiçbir etiket rakam göstermez: `strings.csv` değerleri rakamsızdır (`test_shell_no_digits`), çalışma anı denetimi
`tools/digit_probe.gd` (Home, Game, tüm sayfalar, üç dil). Miktarlar görsel gösterilir:
- **Jeton:** bir sıra jeton simgesi (`UiChip` + `Quantity.coin_layout`); `balance.json coin_display`: `per_icon` miktar = 1 simge,
  en çok `max_icons` simge, `pile_from` ve üstünde "çok" yığını simgesi eklenir.
- **Seviye / ilerleme:** `UiPips` noktaları; blok (varsayılan 5) = 4 normal + 1 zor (yıldız şekli). `Quantity.level_pips`.
- **Yıldız:** 3 noktalı `UiPips` (sonuç sayfası). **Sigorta hakkı:** `UiPips` (yer tutucu oyunda).
Oyun sahnesi de aynı kurala uyar (CLAUDE.md değişmez kural 2). Yeni bir miktar göstergesi gerekiyorsa sayı değil simge/nokta/dolu tüp çizilir.

## Reklam akışı

`RunFlow` (Game'in alt düğümü) → `AdManager` → `AdsProvider` (Mock / NoAds / AdMob). Ödül YALNIZ sağlayıcı `rewarded`
verince; reklam hazır değilse ya da 3 sn içinde gelmezse akış sessizce sürer. Politika (geçiş reklamı, banner, sessiz dönem)
saf `AdPacing` + `data/ads.json`: ayrıntı `docs/MONETIZATION.md`.
Sağlayıcı seçimi: AdMob native tekil nesneleri varsa AdMob; yoksa debug'da Mock; release'te NoAds.

## Yeni içerik eklerken

1. Denge sayısı → `data/*.json`
2. Kural → `scripts/shell/` (kabuk) ya da `scripts/core/` (oyun) saf sınıf + `tests/unit/test_*.gd`
3. Görsel → `scenes/` + `scripts/ui/`
4. Ses → dosyayı `assets/audio/sfx/` altına koy (ya da `tools/make_sfx.py`), `data/sounds.json`'a yaz
5. Metin → `data/i18n/strings.csv` sonuna 3 dilde ekle (RAKAMSIZ)
6. Yeni sahne → `GameManager.SCENES`'e satır
