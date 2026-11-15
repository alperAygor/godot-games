# Neon Arena 3D — Para kazanma (reklam servisleri)

Durum: **servis katmanı hazır ve test edilmiş; oyun akışına BAĞLANMADI** (bağlama: C8, `game3d.gd` bölünmesi F2 birleştikten sonra).
AdMob eklentisi projede **YOK** (A1 görevi); reklam kodu Android'de yerel tekil nesneler bulunana dek kendiliğinden pasiftir.
Tasarım gerekçesi: `docs/IDEAS.md` (Bölüm C). Bu belge uygulanan kuralları, API'yi ve bağlanacak çağrı noktalarını tanımlar.

## 1. Mimari

```
oyun/menü kodu ──► Ads (cephe, statik)            scripts/services/ads.gd
                     └─► AdManager (autoload)      scripts/autoload/AdManager.gd   limitler, bekleyen istek, zaman aşımı, onay kapısı
                            ├─► AdPacing (saf)     scripts/core/ad_pacing.gd       geçiş reklamı kararı (veri: data/ads.json)
                            ├─► AdConfig           scripts/services/ad_config.gd   ads.json okuma + doğrulama
                            ├─► AdEnvironment      scripts/services/ad_environment.gd, settings_ad_environment.gd
                            │                      (saat, remove-ads, koşu sayacı, günlük tarih; gerçek: Settings bayrakları)
                            └─► AdsProvider        scripts/services/ads_provider.gd (arayüz)
                                   ├─ MockAdsProvider    masaüstü hata ayıklama + testler (ayarlanabilir sonuç)
                                   ├─ NoAdsProvider      yayın sürümünde eklenti yoksa: sessiz, ödül ASLA
                                   └─ AdmobAdsProvider   Android'de yerel tekil nesneler varsa (durum makinesi)
                                          └─ AdmobBridge (taban: "eklenti yok") / PoingAdmobBridge (Poing v5.1.0 bağlantısı)
```
Yerleşim kimlikleri tiplidir: `AdPlacement.Id { REVIVE, DOUBLE_CORES, REROLL, DAILY_BONUS, INTERSTITIAL }` (sıra testle sabit; yeni yerleşim SONA eklenir).
Sağlayıcı seçimi (`AdManager.make_default_provider`): AdMob (yalnız Android + yerel tekil nesneler) → hata ayıklama sürümünde Mock → yayın sürümünde NoAds.
Komut satırı (yalnız hata ayıklama): `--ads=none`, `--ads-outcome=success|dismissed|no_fill|timeout`, `--ads-delay=<sn>`.

## 2. Kurallar (tümü `data/ads.json`'da; kodda sabit sayı yok)

| Konu | Kural |
|---|---|
| REVIVE | Koşu başına en fazla 1 (`placements.REVIVE.per_run`). |
| DOUBLE_CORES | Koşu başına 1. |
| REROLL | Koşu başına en fazla 2; kullanıcı +1 yenileme alır. |
| DAILY_BONUS | Gün başına 1: `Settings.today_key()` ile `flags.daily_bonus_date` karşılaştırılır; ödülle birlikte kaydedilir. Güvenilir saat geri alınmaya karşı korur. |
| Ödül | YALNIZ sağlayıcının `rewarded` geri çağrısında; kapatma/hata/zaman aşımı/geç sinyal = ödül yok. Başarısız istek hak tüketmez. |
| Geçiş (INTERSTITIAL) | Yalnız `moment == "run_end"`; ilk `free_runs` (3) koşuda yok (4. koşudan itibaren olabilir); son geçişten `min_seconds` (180: 179 yok, 180 var); son geçişten bu yana en az `every_n_deaths` (2) ölüm; bu koşuda ödüllü izlendiyse yok; "reklamsız" alındıysa asla; saat geri alındıysa yok. |
| Reklamsız (remove-ads) | Yalnız geçişi kaldırır; ödüllü yerleşimler isteğe bağlı açık kalır. Kaynak: `Settings.has_entitlement("remove_ads")` veya `flags.ads_removed`. |
| Zaman aşımı | Gösterim istenip `show_start_timeout_seconds` (3) içinde ekrana gelmezse ya da ekrandaki reklam `max_ad_seconds` (180) içinde bitmezse akış reklamsız serbest kalır (`then`/`on_fail` çağrılır). |
| Onay | `AdsProvider.request_consent()` çözülmeden `initialize()` çağrılmaz, hiçbir reklam isteği yapılmaz, `can_show` false'tur. Çözülüp `can_request_ads=false` ise oturum reklamsızdır. UMP formu zaman aşımı (8 sn) = "reklam istenemez" (güvenli yön). |
| Gizlilik seçenekleri | İsteğe bağlı yetenek: `Ads.privacy_options_required()` / `Ads.show_privacy_options(on_done)`. Mock ve NoAds: false. AdMob köprüsünde API doğrulanana dek false (A1). |
| Asla | Oyun sırasında/kart seçerken/boss anında reklam; ödüllü gösterilmeden ödül; zorunlu duvar; üretim kimliğiyle test. |

Pacing sayıları değişirse yalnız `data/ads.json` ve `tests/unit/test_ad_pacing.gd` beklentileri güncellenir.

## 3. Cephe API'si (`Ads`, tipli, statik)

```gdscript
Ads.can_show(placement: AdPlacement.Id) -> bool                         # düğme gösterilsin mi (hazır + onay + limit + günlük)
Ads.show_rewarded(placement, on_reward: Callable, on_fail: Callable = Callable()) -> bool
        # on_reward() YALNIZ ödül onaylanınca; on_fail(reason: String) hata/zaman aşımı/uygunsuz; dönüş: başladı mı
Ads.maybe_interstitial(after_run_context: Dictionary, then: Callable) -> bool
        # then() HER DURUMDA tam bir kez (reklam yok / bitti / hata / zaman aşımı); dönüş: reklam başladı mı
        # bağlam: {"died": bool=true, "moment": String="run_end", "runs_completed": int (isteğe bağlı)}
Ads.begin_run()                          # yeni koşu başında: koşu limitleri + "ödüllü izlendi" işareti sıfırlanır
Ads.daily_bonus_available() -> bool
Ads.privacy_options_required() -> bool ; Ads.show_privacy_options(on_done := Callable())
```
Yönetici yoksa/sağlayıcı yoksa hepsi güvenli no-op'tur (`then` yine çağrılır). Ek olarak `AdManager` sinyalleri vardır:
`ad_started`, `rewarded_finished(placement, success)`, `ad_failed(placement, reason)`, `interstitial_finished(success)`, `availability_changed()`.

## 4. Bağlanacak çağrı noktaları (F2 sonrası, C8 görevi)

Kod konumları `game3d.gd` bölünmeden önceki adlarla verilir; F2 sonrası karşılıkları `run_flow.gd` / `cards_flow.gd`.

1. **Koşu başı** — `_start_game()`: ilk satırlarda `Ads.begin_run()`.
2. **REVIVE** — `_on_player_died()`, mevcut `ikincisans` (`loadout.i("revive")`) kontrolünden SONRA, `state = "dead"` öncesi: `Ads.can_show(REVIVE)` ise ölümde "İZLE VE DEVAM ET" seçeneği (HUD/oyun-bitti öncesi kısa karar); `Ads.show_rewarded(REVIVE, _revive_player)`; `_revive_player` = mevcut revive gövdesi (yarı can, 2,2 sn dokunulmazlık). Seçilmezse/başarısızsa normal ölüm akışı sürer.
3. **DOUBLE_CORES** — oyun-bitti ekranı (`menus.show_gameover` sonrası): `Ads.can_show(DOUBLE_CORES)` ise "ÇEKİRDEKLERİ ×2" düğmesi; `Ads.show_rewarded(DOUBLE_CORES, func(): Settings.meta.earn(_cores_earned))` (ek `_cores_earned` kadar; mevcut kazanç `Settings.record_run` içinde zaten eklenmiştir).
4. **REROLL** — `_on_reroll()` (kart ekranı): `rerolls <= 0` iken ve `Ads.can_show(REROLL)` ise "REKLAM İZLE → +1 YENİLE" düğmesi; `Ads.show_rewarded(REROLL, func(): rerolls += 1; menus güncelle)`.
5. **DAILY_BONUS** — ana menü: `Ads.daily_bonus_available()` ise "GÜNLÜK BONUS" girişi; `Ads.show_rewarded(DAILY_BONUS, <bonus ver>)` (tarih kaydı yöneticide yapılır; bonus verme C7'ye ait).
6. **Geçiş** — koşu bitti ekranından "TEKRAR OYNA" / "ANA MENÜ"ye basıldığı an (yani `restart_pressed` / `menu_pressed` işleyicisinde): `Ads.maybe_interstitial({"died": true}, <asıl işlem: _start_game / _enter_menu>)`. **Sıra şartı:** `Settings.record_run` bu çağrıdan ÖNCE çalışmış olmalı (koşu sayacı biten koşuyu içermeli; zaten `_on_player_died` içinde çağrılıyor). Kazanma/zafer koşu sonları için `{"died": false}`.
7. **Ayarlar** — gizlilik satırı: `Ads.privacy_options_required()` ise "Gizlilik seçenekleri" düğmesi → `Ads.show_privacy_options()`.
8. **Düğme görünürlüğü** — `AdManager.availability_changed` / `ad_started` / `rewarded_finished` dinlenerek düğmeler güncellenir; `Ads.can_show` false ise düğme GİZLİDİR (sağlayıcı yok = oyuncu fark etmez).

Süre bayrağı: geçiş gösterilince `Settings.mark_transition()` (yönetici çağırır) `flags.last_transition_time` yazar ve kaydeder.

## 5. Kimlikler ve güvenlik

`data/ads.json` → `admob.mode`: varsayılan `test`; yalnız Google'ın herkese açık TEST kimlikleri vardır. `production` bloğu `REPLACE_*` yer tutucudur — gerçek kimlikler
**sahibine aittir, uydurulmaz**. Üretim kimlikleri YALNIZ yayın sürümünde, `mode=production` ve hiçbir alan `REPLACE_` değilken kullanılır; aksi halde test
kimliğine düşülür (kendi reklamına tıklamak hesap yasağı sebebidir; `tests/unit/test_ad_config.gd` bunu sınar).

## 6. Bilerek YAPILMAYANLAR

- AdMob eklentisi/addon, indirme, Gradle, `export_presets.cfg`/`android/**` değişikliği (A1). `[admob]`/`[editor_plugins]` bölümü eklenmedi.
- Faturalandırma / "reklamları kaldır" satın alma (A2). Yalnız sahiplik okunur (`remove_ads` hakkı veya `ads_removed` bayrağı).
- Çevrimiçi kapısı (şablonun `require_online`'ı) — oyun çevrimdışı.
- Oyun/menü bağlantısı (C8), reklam düğmelerinin arayüzü (F3 yalnız bağlama noktalarını bırakır).
- Poing köprüsünde `privacy_options_required`/`show_privacy_options` ve UMP `canRequestAds` (eklenti kaynağından doğrulanmadı; A1'de cihazda).
- Analitik, banner, çekirdek paketi.

## 7. Cihazda elle test listesi (A1 sonrası; test kimlikleriyle)

- [ ] AAB/APK Gradle ile hatasız; logcat'te `[AdMob] Native plugin ... not found` yok.
- [ ] Onay çözülmeden reklam isteği yok; AB VPN/test cihazında UMP formu çıkar, oyun beklemeden açılır.
- [ ] Ödüllü reklam: ödül yalnız tamamlanınca; erken kapatınca yok; uçak modunda düğme gizli/akış takılmaz (≤3 sn).
- [ ] Geçiş: ilk 3 koşuda yok, 4. koşuda ≥180 sn + 2. ölümde var; revive izlendiyse o koşuda yok; remove-ads sonrası asla.
- [ ] Release: `mode=production` + gerçek kimlikler; pakette test kimliği kalmadı.
