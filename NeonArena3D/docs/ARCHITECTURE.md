# Neon Arena 3D — Mimari (F2 sonrası)

Bu belge modül sınırlarını, veri dosyalarını, olay kancalarını ve Faz 1 görevleri için sahiplik haritasını tanımlar.
F2 bir **davranış koruyan** yeniden düzenlemedir: aynı tohumla gerçek sahnedeki bot koşusu, bölmeden önceki kodla
kare kare aynıdır (bkz. §6).

## 1. Katmanlar

```
data/*.json, data/balance/*.json        veri (sayılar, içerik) — kod değiştirmeden ayarlanır
  └─ scripts/autoload/game_data.gd      yükler + doğrular (BalanceData, ContentValidation), GameTuning kurar
scripts/core/                            saf mantık, sahnesiz, testli: RunState, Loadout, MetaProgress, ArenaSpace
scripts/game/                            oynanış modülleri (bu belge) + saf yardımcılar
scripts/entities3d/, scripts/world/      sahne varlıkları (oyuncu, düşman, boss, harita, efekt, mermi alanı)
scripts/ui/game3d.gd                     ince orkestratör: kurulum + kare sırası
scripts/ui/{hud,menus,touch_controls}.gd arayüz (F3 menüleri böler; arayüzleri değişmedi)
```

Kural: modüller birbirine ve duruma yalnız `GameContext` (`ctx`) üzerinden erişir; sahneye özgü olmayan mantık
(geometri, bayrak ayrıştırma, veri doğrulama) saf `RefCounted` sınıfıdır ve `tests/unit/` altında testlidir.

## 2. Modüller (`scripts/game/`)

| Dosya | Sınıf | Sorumluluk | Kendi durumu |
|---|---|---|---|
| `game_context.gd` | `GameContext` | paylaşılan durum: sahne düğümleri, `run`/`loadout`, varlık listeleri, `state`, `nova`, `rerolls`, `weapon`, modül başvuruları, `ARENA` | — |
| `game_events.gd` | `GameEvents` | dinlenebilir olay yolu (§4) | — |
| `game_module.gd` | `GameModule` | modül tabanı (`Node`, `_process` yok; `ctx`, `KIT`, `ARENA`) | — |
| `run_flow.gd` | `RunFlow` | durum makinesi menü/oyun/ölü/duraklat; koşu başlatma + sıfırlama, tohumlama, harita kurulumu ve sektör geçişi, dalga/harita olaylarının oyuncu tarafı, ölüm + İkinci Şans + ödül, kalite ayarı | `cores_earned`, `revives_used`, ölüm sayacı, ipucu süresi |
| `player_control.gd` | `PlayerControl` | girdi (klavye/fare, dokunmatik + otomatik nişan, otopilot) → `player.tick`; duvar/engel, yenilenme, kalkan yenilenmesi, nova isteği, iz; kart etkilerini gemiye uygulama (`apply_loadout`) | otomatik nişan hedefi, kalkan sayacı |
| `autopilot.gd` | `Autopilot` | demo/test botu (`plan()`); smoke, sahne probu ve kalibrasyon kullanır | — |
| `combat.gd` | `CombatSystem` | mermi/temas/atılma çarpışmaları, isabet + zincir + alan hasarı, roket/bombacı patlaması, iyileşme/kalkan, toplanabilir etkisi, nova, oyuncu hasarı (Diken Kalesi), düşman ölümü (puan/XP/düşme/bölünme/kombo eşiği) | taşan iyileşme, kombo eşiği |
| `weapons.gd` | `WeaponSystem` | gemi silahları (atış topu/saçma/ray/roket), roket güdümü, düşman mermisi, refakat dronları | — |
| `spawner.gd` | `Spawner` | düşman/toplanabilir doğurma, doğma noktası, elit şansı, av modu temposu, düşman adımı (engel kaçınma, itme, sınır, bombacı fitili), ayrılma | dalga süresi, av sayacı |
| `boss_events.gd` | `BossEvents` | boss doğma, Boss3D sinyallerinin mermi/tehlike/ışın karşılıkları, yer tehlikeleri, lazerler, ölüm sekansı | iniş/ölüm bayrakları |
| `card_effects.gd` | `CardEffects` | C3 kart etkileri (yeni 25 kart, 6 evrim, lanet bedelleri) — diğer modüller yalnız tek satırlık kanca çağırır (`shot_damage_mult`, `on_hit`, `on_kill`, `on_hurt`, `on_dash`, `on_nova`, `tick` …); kart ekranına yasaklama satırı + evrim ipucu (`cards.add_below_reroll`); lanetli kart için `apply_curse(id)` (C1 kapısı). Sayılar `data/card_rules.json` → `params` | bıçak/taret/iz/statik/füze sayaçları, öldürme sayacı |
| `cards_flow.gd` | `CardsFlow` | seviye kartı aç/yenile/seç, duraklatma, arka arkaya bekleyen seviyeler | açık mı, bekleyen, kart çekiliş RNG |
| `camera_rig.gd` | `CameraRig` | kamera (menü süzülmesi, öne bakış, boss yakınlaştırma, sarsıntı), fare nişanı, nişan halkası | kamera düğümleri, öne bakış, yakınlaştırma |
| `feedback.gd` | `Feedback` | juice: dünya parıltıları, vinyet (hasar/düşük can/ton), hasar sayıları, kalp atışı, atılma/kalkan/hasar efektleri | vinyet değerleri |
| `monetization_hooks.gd` | `MonetizationHooks` | reklam akışı (C8): `events` + menü seam'lerini `Ads` cephesine bağlar; ölümde diriltme teklifi, ×2 çekirdek, +1 yenileme, günlük bonus, gizlilik satırı, TEKRAR OYNA/ANA MENÜ'de geçiş reklamı; reklam sürerken duraklat + sustur + önceki durumu geri getir (bkz. docs/MONETIZATION.md §4) | `ad_active`, koşu bayrakları, düğmeler |
| `hud_bridge.gd` | `HudBridge` | güvenli alan kenar boşlukları, her kare `hud.update_state` + dokunmatik oranları | son görünüm boyutu |
| `arena_geometry.gd` | `ArenaGeometry` (saf) | engel itme/kaçınma, nokta/çizgi engeli | — |
| `launch_options.gd` | `LaunchOptions` (saf) | `--demo --wave --hp --die --cards --nova --map --give --boss --ship --screen --seed` | — |
| `balance_data.gd` | `BalanceData` (saf) | `data/balance/*.json` yükle + birleştir + doğrula | — |
| `game_tuning.gd` | `GameTuning` (saf) | `combat.json` → tipli alanlar (kare başına sözlük yolu yok) | — |
| `content_validation.gd` | `ContentValidation` (saf) | kart/gemi/atölye/harita doğrulaması | — |

`scripts/ui/game3d.gd` (≈225 satır): modülleri kurar, sinyalleri bağlar, kare sırasını yönetir ve araçların
kullandığı dış arayüzü (aşağıda) sağlar. Yeni oynanış kodu buraya değil ilgili modüle girer.

Ek: `scripts/ui/ad_overlay.gd` (`AdOverlay`: teklif + reklam perdesi, menülerin üstünde), `scripts/core/ad_flow.gd` (`AdFlow`: saf kurallar +
`data/ads_flow.json`), `scripts/core/time_scale.gd` (`TimeScale`: oyun hızının tek sahibi; `Fx` autoload'ı `Engine.time_scale`e YALNIZ buradan yazar —
`Fx.hitstop`, `Fx.slow_motion` (ölüm), `Fx.settle_time` (duraklat/devam/reklam/yeni koşu), `Fx.set_base_scale` (araçlar)). Araçlar `Engine.time_scale`e doğrudan yazmaz.

### Kare sırası (`game3d._process` → `_tick_game`)
```
elapsed += dt · Fx.tick · HudBridge.update_layout · sessiz tuşu
menü:  PlayerControl.idle
oyun:  CardsFlow.tick_pending (kart açıldıysa bu kare biter) · RunFlow.tick_debug_die · _tick_game:
         RunState.step → Spawner.tick_pacing → RunFlow.tick_hint → PlayerControl.tick → Spawner.tick_enemies
         → BossEvents.tick → BossEvents.tick_hazards → CombatSystem.tick_aftershocks → BossEvents.tick_beams
         → WeaponSystem.steer_rockets → field.tick → Spawner.tick_pickups → WeaponSystem.tick_drones
         → Spawner.separate_enemies → CombatSystem.resolve_collisions → Feedback.tick_low_hp → ölüm kontrolü
ölü:   RunFlow.tick_dead
her durumda: Feedback.render_frame · CameraRig.update · HudBridge.update
```
Sıra, global `randf()` akışının sırasını belirler. Sırayı ya da bir fonksiyon içindeki `randf` çağrı sırasını
değiştirmek tohumlu koşuyu değiştirir (bu bir hata değildir ama "davranış korundu" iddiasını bozar; bkz. §6).

### Dış arayüz (geriye uyumluluk)
`tools/dev/*_probe.gd`, `tools/smoke_test.gd`, `tools/sim/scene_probe.gd` sahne düğümünden şunları okur; korunmalıdır:
`run, loadout, player, boss, field, hud, menus, touch, world, enemies, pickups, drones, state, nova (yazılabilir),
rerolls, NOVA_MAX, _cores_earned, _aftershocks, events` ve `_start_game() _apply_loadout() _heal() _hit_enemy()
_resolve_collisions() _spawn_enemy() _try_nova()`. Yeni araçlar `scene.ctx` ve `scene.events` kullanmalı.

## 3. Veri

| Dosya | Bölümler | İçerik |
|---|---|---|
| `data/balance/player.json` | `player` | gövde, hareket, atılma, silah tabanı, nova (`nova_cost` = nova üst sınırı) |
| `data/balance/enemies.json` | `enemies`, `elite` | tür istatistikleri (sıra = dalga planı ağırlık sırası), elit ön eki |
| `data/balance/bosses.json` | `boss`, `boss_kinds` | temel boss + türe özel üzerine yazmalar |
| `data/balance/waves.json` | `waves`, `difficulty` | dalga tablosu ve dalga başına ölçekleme |
| `data/balance/scoring.json` | `scoring`, `leveling` | kombo/puan/eşikler, XP eğrisi, kart sayısı |
| `data/balance/pickups.json` | `pickups` | düşme şansı, ağırlıklar, etkiler |
| `data/balance/combat.json` | `combat` | eskiden `game3d.gd`'ye gömülü oynanış sabitleri (nova, diriltme, isabet/zincir/atılma, patlayıcı, tank bölünmesi, Diken Kalesi, dron, silah kalıbı, düşman/boss mermi kalıpları, otomatik nişan, av modu) |
| `data/cards.json`, `ships.json`, `upgrades.json`, `maps.json` | — | içerik (değişmedi) |

- Birleştirme: `BalanceData.load_dir()` dosyaları okur, bölümleri tek sözlükte birleştirir (eski `balance.json` ile
  aynı şekil); `GameData.value("a.b.c")` / `number()` / `enemy_stats()` / `boss_stats()` API'si aynıdır.
- Doğrulama (açılışta, `GameData.load_all`): bölüm iki dosyada → hata; dosya yok/bozuk JSON → dosya adıyla hata;
  zorunlu sayısal alanlar (`BalanceData.REQUIRED`, `ENEMY_FIELDS`), renkler, artan kombo eşikleri, `combat` şeması
  (eksik/negatif/kesirli sayaç/bilinmeyen alan: yazım hatası yakalanır); içerik: kart/gemi/yükseltme etki anahtarı
  `Loadout._defaults()` içinde olmalı, kart tier'ı bilinmeli, sinerji gereksinimleri tanımlı olmalı, silah türü
  bilinmeli, harita boss türü `boss_kinds` içinde olmalı. Her hata `push_error("veri doğrulama: …")` ile basılır →
  `verify.sh` açılış adımı kırmızı olur. Testler: `tests/unit/test_balance.gd`.
- Oynanış kodu `combat`/sık okunan `player` alanlarını `ctx.tuning` (`GameTuning`, açılışta bir kez) üzerinden okur.
- Ekleme tarifleri: **düşman** → `enemies.json`'a tür (+ `enemy3d.gd` davranışı yeni bir `kind` ise); **boss** →
  `bosses.json` `boss_kinds` + `maps.json` `boss`; **kart** → `cards.json` (etki anahtarı yeni ise `Loadout._defaults`
  + etkisini okuyan modül); **gemi** → `ships.json`; **sayı** → ilgili dosya. Kod değişmeyen her ekleme doğrulamadan geçer.
- `tests/sim/run_sim.gd` (denge simülasyonu) aynı yükleyiciyi kullanır ama `combat` formüllerinin KOPYASINI taşır:
  `combat.json`'da sayı değiştiren simülasyonu da güncellemeli (bkz. §7).

## 4. Olaylar ve kancalar (SEAM)

`scene.events` (`GameEvents`): `run_started(ship_id, run_seed)`, `enemy_killed(kind, elite, points)`,
`player_hurt(amount)`, `player_died(revive_card)`, `player_revived(source)`, `boss_spawned(kind)`, `boss_killed(kind)`,
`cards_shown(cards, rerolls)`, `card_picked(card)`, `reward_computed(cores)`, `run_ended(summary)`.
Dinleyici yokken davranış değişmez. Kodda `SEAM(...)` yorumuyla işaretli kanca noktaları; C8'de `MonetizationHooks` ile BAĞLANDI (aşağıdaki "Not" sütunu eski tasarım, güncel akış docs/MONETIZATION.md §4):

| Kanca | Yer | Not |
|---|---|---|
| koşu bitti / geçiş reklamı | `RunFlow.finish_death` sonu → `events.run_ended(summary)` | oyun sonu ekranı 1,5 sn sonra `RunFlow.tick_dead` içinde açılır; geçiş reklamı TEKRAR OYNA/ANA MENÜ basışında (`hooks.on_restart/on_menu`) |
| oyuncu öldü, diriltme mümkün | `RunFlow.on_player_died` → `events.player_died(revive_card)` → kart yoksa `hooks.offer_revive()`; vazgeçilirse `RunFlow.finish_death()`; `RunFlow.revive(source)` | kart diriltmesi `revive("card")` kullanır; reklam akışı ölüm sekansını bekletip `revive("ad")` çağırmalı |
| kart seçimi gösterildi, yenileme mümkün | `CardsFlow.open` → `events.cards_shown(cards, rerolls)`; `CardsFlow.grant_reroll()` + `reroll()` | `rerolls == 0` iken reklamla yenileme |
| koşu sonu ödülü hesaplandı | `RunFlow.on_player_died` → `events.reward_computed(cores)` | ödül `Settings.record_run` ile işlendi; çift çekirdek `Settings.meta` üzerinden eklenir |

C1 (koşu yapısı) ek olayları: `sector_cleared(sector, total)`, `gate_chosen(option_id)`, `run_won(summary)`. `run_ended` özetinde
ayrıca `mode, won, outcome ("death"|"victory"), sectors, sectors_total, gates, reward` vardır. Zaferle biten koşu da `state == "dead"`
(= koşu bitti) olur; `MonetizationHooks` geçiş reklamına `{"died": outcome != "victory"}` verir.

### C1 koşu yapısı (özet)
- Saf çekirdek `RunState` (`scripts/core/run_state.gd`): `set_mode(standard|quick|endless)` → `begin()`; aşamalar `PHASE_GATE`, `PHASE_VICTORY`
  (step bekler); `choose_gate(id)`, `continue_endless()`, `finish_victory()`; ödül `reward(core_mult)`; `snapshot()/restore()`.
  Mod seçilmezse SONSUZ = eski davranış (aynı tohumla aynı akış; kapı seçenekleri ayrı `gate_rng`'den).
- Veri: `data/balance/waves.json` → `run` (modlar, ödül eğrisi, kapı seçenekleri, `sector_mix`). Kayıt: `RunRecords` (`Settings.flags`
  içinde `run_mode`, `rec_<mod>_{best,wave,runs,wins,fastest}`; settings.gd değişmedi).
- Sahne: `RunFlow` (kapı/zafer/mod seçici/hedef göstergesi), ekranlar `scripts/ui/screens/{gate,victory}.gd` (menus.gd'ye dokunmadan
  `menus.modules`'a kaydedilir, `screens_rebuilt`'te yeniden), `scripts/ui/sector_hud.gd` (CanvasLayer 9). Bayraklar: `--mode=`,
  `--after-victory=finish|continue`, `--screen=gate|victory`. Probe: `tools/dev/run_probe.gd` (kapıda). Sim: `--modes`, `--gate-policy`, `--career-mode`.
- Diğer görevler için kancalar (C1+C2+C3 entegrasyonunda bağlandı, aşağıya bkz.): C3 → kapı seçeneğinde `card_tier: "cursed"`;
  C2 → `run.sector_mix[sektör] = {tür: ağırlık çarpanı}` (RunState.unlocked_kinds) ve zorluk için `run.difficulty_wave(n)`.

### C1 × C2 × C3 entegrasyonu
- **Lanetli kapı → C3 lanetli kartı.** Kapı açılınca `RunState.assign_gate_cards(alınmamış lanet kimlikleri)` (`gate_rng` ile) `card_tier:
  "cursed"` seçeneğine bir kart atar (`run.gate_cards`, anlık görüntüde saklanır). Ekran `GateScreen.describe(def, Loadout.curse_info(kart))`
  ile kartın adını, etkisini (artı), bedelini (eksi) ve KARTIN ödülünü seçimden önce gösterir. Seçilince `RunFlow._on_gate_closed` →
  `ctx.effects.apply_curse(id)` (bir kez; ödül `core_mult`'a katlanır). Kartlı seçenekte `RunState.gate_reward_bonus(id) = 0`: kapının kendi
  `reward_mult`'u (+%15) EKLENMEZ — çift sayım yok. Lanetli kart kalmadıysa kapının kendi `effect` + `reward_mult`'u yedek. Bot/sim aynı kural
  (`bot_gate_choice(..., rewards)` kartın gerçek ödülünü tartar). Testler: `test_run_state` (saf), `test_balance_sim` (sim), `run_probe` §5 (sahne).
- **Elit/zorluk ölçeği etkin dalgayla.** `EnemyData.elite_chance(elite, run.difficulty_wave(n), boss_dalgası)` ve `prefix_wave(etkin)`:
  elit eşiği (`from_wave`), şansı ve öneklerin `min_wave`'i hem `Spawner.spawn_enemy`'de hem simde etkin dalgayı kullanır (türlerin
  `unlock`'u zaten `RunState.unlocked_kinds`'te etkin dalgayla). Sonsuz/standartta etkin dalga = n: davranış birebir aynı (tohumlu sim ve
  belirlenimli `scene_probe` iziyle kanıtlandı). `max_alive` dalgaya bağlı değil.
- **Sektör tadı (yalnız veri).** `run.sector_mix`: S1 NEON (öğrenme; seyrek hücumcu), S2 KIZIL (kalkancı+onarıcı, mayıncı, tank), S3 BUZ (sıçrayıcı,
  hücumcu, kuluçka+sürü). Kuluçka `sectors` [0,1] → [0,1,2] (standartta başka türlü hiç görünmezdi). Karışım yalnız sektörlü modlarda ve zafere
  kadar (`RunState.sector_mix`): sonsuz mod ve zafer sonrası devam karışımsız.
- **AŞIRI GERİLİM** düşman can/hasar çarpanı `run.hp_scale()/damage_scale()` içinde: yeni türler, elit önekleri (çarpanlar ölçeğin üstüne),
  bölünen parçalar, kuluçka yavruları, mayın/iniş hasarı (düşmanın ölçekli hasarı) ve boss dahil; simde de aynı (test_balance_sim).
- **Kalkancı hasar sayısı.** `enemy3d.take_damage` gerçek verilen hasarı döner (+ `last_blocked`); `Feedback.enemy_damage_number` gerçek sayıyı
  gösterir (zırhlı ×0,5, yorgun hücumcu ×1,5 dahil), kalkana gelen vuruşta küçük mavi sayı + seyrek "ENGEL" işareti.

Not: roadmap C13'ün `scripts/game/events.gd` dosyası (koşu içi rastgele olaylar) bu olay yolundan ayrıdır.

## 5. Faz 1 sahiplik haritası (modül düzeyinde)

| Görev | Dokunacağı F2 dosyaları | Not |
|---|---|---|
| C1 koşu yapısı | `run_flow.gd`, `data/balance/waves.json` (+ `run_state.gd`) | yeni durumlar (zafer, kapı) RunFlow'a; kare sırası game3d'de |
| C2 düşmanlar | `spawner.gd`, `data/balance/enemies.json` (+ `enemy3d.gd`) | yeni tür davranışı enemy3d; doğma/elit Spawner |
| C3 kartlar/evrim | yeni `card_effects.gd`, `cards.json`, `loadout.gd` | sinerji okumaları şu an `combat.gd`/`weapons.gd`/`player_control.gd` içinde (`loadout.i("storm")` vb.); C3 bunları card_effects'e taşır |
| C4 tehlikeler | yeni `scripts/world/hazards.gd` | boss tehlikeleri `boss_events.gd`'de; çevre tehlikesi ayrı modül + `_tick_game`'e tek satır |
| C5 juice | `feedback.gd` (+ fx/sound/sparks) | savaş içi efekt çağrıları yerinde; taşırken rastgele akış sırası değişir → yeni baseline |
| C8 reklam akışı (yapıldı) | `monetization_hooks.gd` (events dinler) | §4 kancaları; F5 `AdManager`; `tools/dev/ads_probe.gd` kapıda |
| A3 performans | tüm modüller | kare başına `GameData.number()` (dize bölme) çağrıları kaldı: `spawn_point`, `roll_pickup`, `reap`, `try_nova`, `apply_loadout` → GameTuning'e taşınabilir |

`game3d.gd`'ye dokunan görev yalnız kare sırasına satır ekler; aynı anda iki görev ekliyorsa sırayla birleştirilir.

## 6. Belirlenimlilik ve davranış eşdeğerliği

- `--seed=N` (ya da sahneye eklenmeden önce `scene.run_seed = N`): global `randf` akışı, kart çekilişi ve RunState dalga
  planı tohumlanır (`RunFlow.reseed`, her koşu başında). `--seed` yoksa oyun eskisi gibi rastgele.
- `--fixed-fps 60` kare süresini duvar saatinden ayırır. İkisi birlikte: aynı kod = aynı koşu.
- `tools/sim/scene_probe.gd -- --demo --seed=N ...` çıktısındaki `trace_md5`, her örnekte (SABİT kare aralığı: `--sample-frames=6`;
  eskiden duvar saati zamanlayıcısıydı ve iz çalıştırmalar arası kararsızdı) dalga/öldürme/puan/
  seviye/can/konum/canlı/mermi sayısı/durum izinin özetidir. Yeniden düzenleme sonrası aynı `trace_md5` = davranış aynı.
  `--dump=yol` örnek başına iz satırlarını yazar (fark nerede başladı); `--mode=endless|quick|standard` sahnenin moduna geçer.
  ```
  godot --headless --fixed-fps 60 --path . -s res://tools/sim/scene_probe.gd -- --demo --ship=sahin --seed=11 --seconds=60
  ```
- F2 kanıtı: 14 temel koşu (4 gemi × 3 tohum + 2 uzun) + 13 kapsama koşusu (tüm kartlar, 3 boss, dalga 5–25, dokunmatik,
  diriltme, ölüm) bölmeden önceki kodla birebir aynı `trace_md5`; denge simülasyonu raporu bayt bayt aynı.

## 7. Bilinen sınırlar (F2 kapsamı dışında bırakıldı)

- Görsel/juice sabitleri (kıvılcım sayıları, sarsıntı, renkler) ve silah sapma aralıkları kodda; `combat.json` yalnız oynanışı etkileyenleri taşır.
- Çekirdek ödülü C1'den beri `RunState.reward` (eğri `waves.json` → `run.modes.<mod>.reward`); `MetaProgress.run_reward` yalnız mod tanımı yoksa (eski formül).
- `tests/sim/run_sim.gd` savaş formüllerinin kopyası; `combat.json` değerlerini okumuyor.
