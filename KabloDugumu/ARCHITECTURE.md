# ARCHITECTURE — Kablo Düğümü: Akım Ustası

Doküman durumu: **sözleşme v1**. Kod yazmadan önce bu dosyayı oku.
Değişiklik gerekiyorsa önce burayı güncelle, sonra kodu — **sözleşme koddan önce gelir**.

## 1. Katmanlar

```
UI (Control / HUD)                scripts/ui/*
Gameplay (Node3D, verlet, partikül)  scripts/gameplay/*
Autoload servisleri               scripts/autoload/*
Core (saf, testli)                scripts/core/*
Services (AdsProvider)            scripts/services/*
```

Bağımlılık yönü **yukarıdan aşağıya**: `ui → gameplay → core`; `core` hiçbir katmanı tanımaz.

## 2. Sorumluluk ve dosya sahipliği

| Sahip | Klasör/dosyalar |
|---|---|
| **Lead** | `project.godot`, `scripts/autoload/GameManager.gd`, sözleşme dosyaları, entegrasyon |
| **forge-core** | `scripts/core/*.gd`, `data/levels.json`, `data/balance.json`, `tests/unit/test_core_*.gd` |
| **volt-rope** | `scripts/gameplay/cable_rope.gd`, `cable_node.gd`, `contact_scanner.gd`, `spark_burst.gd` |
| **panel-world** | `scripts/gameplay/game.gd`, `level_controller.gd`, `board_builder.gd`, `socket_node.gd`, `camera_rig.gd`, `voltmeter.gd`, `scenes/Game.tscn`, `assets/shaders/*` |
| **panel-ui** | `scripts/ui/*.gd`, `scenes/Boot.tscn`, `Menu.tscn`, `LevelSelect.tscn`, `Result.tscn`, `HUD.tscn`, `data/theme.json`, `assets/theme/*`, `data/icons.json` |
| **signal-qa** | `scripts/autoload/AdManager.gd`, `scripts/autoload/AudioService.gd`, `scripts/services/*`, `data/sfx_recipes.json`, `data/sounds.json`, `data/ads.json`, `assets/audio/*`, `tools/*`, `tests/run_tests.gd`, kök dokümanlar |
| **panel-world + Lead** | `scenes/HUD.tscn` iskeleti Lead'den, içerik panel-ui |

### v0.2 ("ASMR redesign") sahiplik

| Sahip | Dosyalar |
|---|---|
| **Lead** | `project.godot`, `scripts/autoload/Loc.gd`, `scripts/autoload/GameManager.gd`, `data/i18n/*` (ilk tablo), `scripts/autoload/Loc.gd`, `tools/perf_probe.gd`, `tests/unit/test_i18n.gd`, kök dokümanlar, entegrasyon |
| **craft-ui** | `scenes/{Boot,Menu,LevelSelect,Result,HUD}.tscn`, `scripts/ui/**`, `data/theme.json`, `assets/theme/**`, `assets/fonts/title_font.tres`; anahtar eklemek için `data/i18n/{en,tr}.json` (parite zorunlu) |
| **live-world** | `scripts/gameplay/{board_builder,camera_rig,cable_rope,ambient_backdrop}.gd`, `scenes/Game.tscn`, `scenes/AmbientBackdrop.tscn`, `assets/shaders/**`, `assets/materials/**` |
| **level-forge** | `scripts/core/{knot_level,cable_spec,socket_spec}.gd`, `data/{levels,balance}.json`, `scripts/gameplay/{game,level_controller,contact_monitor,input_controller,socket_node,obstacle_cable}.gd`, `tests/unit/test_core_levels.gd`, `tests/unit/test_modifiers.gd` |
| **audio-mood** | `scripts/autoload/AudioService.gd`, `data/{sfx_recipes,sounds}.json`, `assets/audio/**`, `tools/make_sfx.py` |

Aynı dosyaya iki sahip yazmaz. Sözleşme dışı API eklemek gerekiyorsa **önce mesaj at**.

## 3. Autoload sözleşmesi

Sıra korunur: `GameManager → AudioService → AdManager → GameData`.

### GameManager (Lead, dondurulmuş API)

```gdscript
enum Phase { BOOT, MENU, LEVELS, GAME, RESULT }
const SCENES := { &"boot": ..., &"menu": ..., &"levels": ..., &"game": ..., &"result": ... }

var phase: Phase
var level_index: int                # 1..12, aktif bölüm
var last_result: Dictionary         # Result sahnesi okur
var profile: PlayerProfile          # kalıcı yıldız/süre

signal phase_changed(from: Phase, to: Phase)
signal back_requested()

func goto_scene(key: StringName) -> void
func start_level(level_number: int) -> void     # level_index ata, limits sıfırla, GAME sahnesi
func complete_level(result: Dictionary) -> void # profile.record + save, last_result, RESULT
func replay_level() -> void
func next_playable_level() -> int               # profile.highest_unlocked()
```

### AdManager (signal-qa)

```gdscript
enum Placement { FUSE_RESCUE, GOLDEN_CUTTER, INSULATION_SPRAY }
signal ad_started(placement: Placement)
signal rewarded_finished(placement: Placement, success: bool)
signal ad_failed(placement: Placement, reason: String)
func can_offer(placement: Placement) -> bool
func show_rewarded(placement: Placement) -> void
func reset_run_limits() -> void
```

### AudioService (signal-qa)

```gdscript
func play(sound_name: String, pitch_variance: float = 0.0) -> void
func has_sound(sound_name: String) -> bool
func set_muted(muted: bool) -> void
```

## 4. Core sözleşmesi (saf, testli)

### CableSpec — `scripts/core/cable_spec.gd`
```gdscript
class_name CableSpec extends RefCounted
var index: int              # 0..n-1
var color_id: StringName    # &"red" | &"blue" | &"yellow" | &"green" | &"purple"
var color: Color            # render rengi
var voltage: int            # 220 / 110 / 50 / 24 / 12
var source: Vector3         # üst terminal (pano düzleminde)
var socket: Vector3         # kendi prizinin merkezi
var socket_index: int       # priz sırası
var plug_rest: Vector3      # bölüm başındaki fiş konumu
var points: PackedVector3Array  # başlangıç halat eğrisi (kaynaktan fişe)
var length: float           # halatın toplam uzunluğu
```

### SocketSpec — `scripts/core/socket_spec.gd`
```gdscript
class_name SocketSpec extends RefCounted
var index: int
var color_id: StringName
var color: Color
var voltage: int
var position: Vector3
```

### KnotLevel — `scripts/core/knot_level.gd`
```gdscript
class_name KnotLevel extends RefCounted
var level_index: int
var level_name: String
var par_seconds: float
var hint: String
var seed: int
var cables: Array[CableSpec]     # sıra = kaynak sırası
var sockets: Array[SocketSpec]   # sıra = alttaki priz sırası
static func from_config(config: Dictionary, colors_table: Dictionary, layout: Dictionary = {}) -> KnotLevel
static func build(config: Dictionary, colors_table: Dictionary, layout: Dictionary = {}) -> KnotLevel   # alias
func source_points() -> Array[Vector3]
```

### OverloadModel — `scripts/core/overload_model.gd`
```gdscript
class_name OverloadModel extends RefCounted
var value: float            # 0..1
var peak: float             # bölümdeki tepe
var blown: bool
var shield_left: float      # sn
var contact_count: int
func configure(fill_per_second: float, drain_per_second: float, extra_per_contact: float) -> void
func add_load(amount: float) -> void      # yanlis priz cezasi; kalkan engeller
func add_shield(seconds: float) -> void
func reset() -> void
func tick(delta: float, contacts: int) -> void
func is_shielded() -> bool
```

### SnapRule — `scripts/core/snap_rule.gd`
```gdscript
class_name SnapRule extends RefCounted
enum Result { NONE, SNAP, WRONG_COLOR }
static func nearest_socket(plug_pos: Vector3, sockets: Array[SocketSpec], free_sockets: Array[int], radius: float) -> int
static func evaluate(plug_pos: Vector3, sockets: Array[SocketSpec], free_sockets: Array[int], cable_index: int, cables: Array[CableSpec], radius: float) -> Dictionary
# -> {"result": Result, "socket_index": int, "distance": float}
```

### CableMath — `scripts/core/cable_math.gd`
```gdscript
class_name CableMath extends RefCounted
static func segment_distance(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float
static func polyline_distance(a: PackedVector3Array, b: PackedVector3Array) -> float
static func polyline_length(points: PackedVector3Array) -> float
static func resample(points: PackedVector3Array, count: int) -> PackedVector3Array
```

### LevelScoring — `scripts/core/level_scoring.gd`
```gdscript
class_name LevelScoring extends RefCounted
static func stars(elapsed: float, par_seconds: float, shorts: int, peak_overload: float) -> int
static func compute(elapsed: float, par_seconds: float, shorts: int, peak_overload: float) -> Dictionary
# -> {"stars": int, "score": int, "time_bonus": int, "elapsed": float, "shorts": int, "peak": float}
```

### PlayerProfile — `scripts/core/profile_save.gd`
```gdscript
class_name PlayerProfile extends RefCounted
const SAVE_PATH := "user://profile.save"
var best_stars: Dictionary     # level:int -> stars
var best_times: Dictionary     # level:int -> float
func load_save() -> void
func save() -> void
func stars(level: int) -> int
func best_time(level: int) -> float
func record(level: int, stars: int, elapsed: float) -> void
func is_unlocked(level: int) -> bool
func highest_unlocked() -> int
func total_stars() -> int
```

## 5. Gameplay sözleşmesi (volt-rope)

### CableRope — `scripts/gameplay/cable_rope.gd` (`class_name CableRope extends Node3D`)
```gdscript
func setup(points: PackedVector3Array, length: float, color: Color, voltage: int) -> void
func reset_shape(points: PackedVector3Array) -> void
func begin_drag(target: Vector3) -> void        # son nokta kinematik
func update_drag(target: Vector3) -> void
func end_drag(locked: bool) -> void             # false: fiş mıknatısla asılı kalır
func snap_to(target: Vector3) -> void          # prize oturma animasyonu
func set_shielded(active: bool) -> void
func segments() -> PackedVector3Array            # temas taraması için (dünya uzayı, 9–12 örnek)
func is_dragging() -> bool
func taut_ratio() -> float                       # 0..1 gerilme göstergesi
```
Rope: 16–20 nokta, 6 kenarlı tüp mesh, 60 Hz PBD; zemine (z>=board) ve board düzlemine clamps.
Fizik yalnızca `_physics_process` içinde; mesh güncellemesi kare başına bir kez.

### CableNode — `scripts/gameplay/cable_node.gd` (`class_name CableNode extends Node3D`)
Fiş görseli + `CableRope` + durum. Sinyaller:
```gdscript
signal grabbed(cable_index: int)
signal released(cable_index: int, plug_position: Vector3)
signal snapped(cable_index: int, socket_index: int)
signal wrong_socket(cable_index: int)
var index: int
var spec: CableSpec
var state: int   # IDLE=0, DRAGGING=1, CONNECTED=2
func setup(spec: CableSpec) -> void
func plug_position() -> Vector3
func socket_position() -> Vector3
func highlight(on: bool) -> void
func force_snap_animation(target: Vector3) -> void   # altın yan keski
# --- game.gd için proxy'ler (CableNode, CableRope'a delege eder; Lead onayladı) ---
func begin_drag(target: Vector3) -> void
func update_drag(target: Vector3) -> void
func end_drag(locked: bool) -> void
func bounce_up(height: float) -> void          # yanlış priz: fiş 0.25 m yukarı seker
func snap_to(target: Vector3) -> void
func set_shielded(active: bool) -> void
func is_dragging() -> bool
func is_linked() -> bool   # NOT: is_connected() Object metoduyla çakışır! (CableNode.linked alsın)
```

### ContactScanner — `scripts/gameplay/contact_scanner.gd` (`class_name ContactScanner extends RefCounted`)
```gdscript
func scan(cables: Array[CableNode], contact_distance: float) -> Array[Dictionary]
# her öğe: {"a": int, "b": int, "point": Vector3, "distance": float}
```

### SparkBurst — `scripts/gameplay/spark_burst.gd` (`class_name SparkBurst extends Node3D`)
```gdscript
func burst(world_position: Vector3, color: Color, strength: float) -> void
```

## 6. Gameplay sözleşmesi (panel-world)

### Game.tscn ağacı (zorunlu düğüm adları)
```
Game (Node3D, script: scripts/gameplay/game.gd)
├── WorldEnvironment
├── CameraRig (Node3D) └── Camera3D
├── Lights
├── Board (Node3D)            # board_builder ile kurulur
├── CableRoot (Node3D)        # CableNode'lar buraya
├── Sparks (Node3D)
├── PostFX (CanvasLayer)      # tam ekran renk düzeltme shader
└── HUD (CanvasLayer, instance: scenes/HUD.tscn)
```

### game.gd genel API (QA bunu kullanır)
```gdscript
func setup_level(level: int) -> void   # _ready içinde çağrılır
func force_snap(cable_index: int) -> bool   # QA: kablo indexini anında prize bağlar
func force_contact(cable_index_a: int, cable_index_b: int) -> void  # QA: kısa devre tetikler
func debug_state() -> Dictionary            # {"connected": int, "total": int, "overload": float, "level": int}
```
HUD bağı: `$HUD` (`class_name GameHUD`) — API bölüm 7.

## 7. UI sözleşmesi (panel-ui)

### HUD.tscn (CanvasLayer + Control, script `scripts/ui/hud.gd`, `class_name GameHUD`)
```gdscript
signal cutter_pressed
signal spray_pressed
signal revive_pressed
signal retry_pressed
signal menu_pressed
signal pause_pressed
signal resume_pressed

func setup(level_index: int, level_name: String, total_cables: int, par_seconds: float) -> void
func set_timer(seconds: float) -> void
func set_connected(done: int, total: int) -> void
func set_overload(value: float) -> void
func set_voltage(volts: int) -> void
func set_shield(seconds_left: float) -> void
func set_hint(text: String) -> void
func toast(text: String) -> void
func set_ad_buttons(can_cutter: bool, can_spray: bool) -> void
func show_fail(reason: String, can_revive: bool) -> void
func hide_fail() -> void
func show_ad_overlay(visible: bool) -> void
func show_pause(visible: bool) -> void
func celebrate(stars: int) -> void
```

### Ekranlar ve buton adları (QA akışı)
| Sahne | Düğüm adları |
|---|---|
| `Boot.tscn` | kendisi menüye geçer |
| `Menu.tscn` | `PlayButton`, `LevelsButton`, `SettingsButton` |
| `LevelSelect.tscn` | `Level1Button`..`Level12Button`, `BackButton` |
| `Result.tscn` | `NextButton`, `RetryButton`, `MenuButton`, `%Stars` |
| `HUD.tscn` | `CutterButton`, `SprayButton`, `ReviveButton`, `RetryButton`, `FailMenuButton`, `PauseButton`, `ResumeButton`, `MenuButton` |

## 8. Data sözleşmesi

- `data/levels.json`: `{ "colors": {id: {hex, voltage}}, "levels": [{id,name,cables,colors,seed,par_seconds,hint}] }`
- `data/balance.json`: pano ölçüleri + aşırı yük + snap + kablo uzunluğu parametreleri.
- `data/ads.json`, `data/sounds.json`, `data/theme.json`, `data/icons.json` şablonla aynı.
- `GameData.value("balance", "overload_fill_per_second", 0.55)` ile okunur.

## 9. Entegrasyon sırası

1. Sözleşme dosyaları + GameManager + HUD iskeleti (Lead) — verify yeşil.
2. Core (forge-core) + rope (volt-rope) + UI iskeleti (panel-ui) + ses/reklam (signal-qa) paralel.
3. Pano + Game sahnesi (panel-world) core/rope/UI'a bağlanır.
4. Entegrasyon: Lead + panel-world; QA: signal-qa akış + ekran görüntüsü.
5. Cila: denge, ses, partikül, doküman, final verify.

## 10. Yerelleştirme (i18n) sözleşmesi — v0.2

- **Kural:** Kullanıcıya görünen hiçbir metin koda gömülmez. Hepsi `Loc.t("anahtar", değerler)`.
- `Loc` autoload sırası: `GameManager → AudioService → AdManager → GameData → Loc`.
- Tablolar: `data/i18n/en.json` (varsayılan) ve `data/i18n/tr.json`. **İki dosya aynı anahtar
  kümesine sahip olmalı** (verify'da parite testi vardır).
- Verme biçimi: `Loc.t("hud.overload", {"pct": 42}) -> "OVERLOAD 42%"`. Anahtar yoksa anahtar
  döner ve `push_warning` basar.
- Dil: `Loc.set_locale("tr" | "en")`, `Loc.toggle_locale()`, `Loc.locale`,
  `Loc.language_changed` sinyali. Seçim `user://settings.cfg`'de kalıcı; ilk açılışta
  `OS.get_locale()` Türkçe ise `tr`, değilse `en`.
- Bölüm adları/ipuçları anahtarla: `level.<n>.name`, `level.<n>.hint`.
- Oyun adı İngilizce kimlikle sabit: **Cable Knot: Current Master** (`game.title` /
  `game.subtitle` anahtarları TR'de de yerelleştirilmiş adı gösterir).

## 11. Ayarlar sözleşmesi

- Tek dosya: `user://settings.cfg` (`ConfigFile`). Bölüm `ui`: `locale`, `sound`.
- Yazan: `Loc` (dil) ve `AudioService` (ses aç/kapa). Okuyan: ilgili servis `_ready`'de.
- Ayarlar ekranı `craft-ui`'de; servis API'leri: `Loc.set_locale`, `AudioService.set_muted`.

## 12. Bölüm modifier sözleşmesi — v0.2

`data/levels.json` her bölümde `"modifiers": Array[String]` taşır (boş olabilir). Geçerli değerler:

| Modifier | İlk bölüm | Anlam |
|---|---|---|
| `sway` | 5 | Panoda yavaşça salınan canlı hatlar (obstacle); temas kısa devre sayılır |
| `locked_socket` | 7 | Bazı prizler kapaklı: fiş priz yanında 0.6 sn tutulursa kapak açılır |
| `blackout` | 9 | Pano ışıkları yumuşakça söner/yanar (görsel zorluk; drag engellenmez) |
| `fast_overload` | 10 | Bar dolum hızı `overload.fill_per_second * 1.5` |

`KnotLevel` alanı: `var modifiers: Array[StringName]`. gameplay modifier davranışını
`LevelController` üzerinden yönetir; modifier yoksa eski davranış aynen korunur (geri uyum).

## 13. Ambient backdrop sözleşmesi — v0.2

- `scenes/AmbientBackdrop.tscn`: `Node3D` + `scripts/gameplay/ambient_backdrop.gd`
  (`class_name AmbientBackdrop extends Node3D`), kendi kamerası/ortamı **yok** (çağıran sahneler
  kurar) VEYA kendi SubViewport'u için kamera içerir — karar `live-world`'de, ama:
  - API: `func setup(kind: int) -> void` (`KIND_MENU`, `KIND_GAME`), `func set_intensity(value: float) -> void`.
  - Gölge yok, `cast_shadow = OFF`, düşük poligon, toplam ≤ 40 düğüm; menüde SubViewport
    çözünürlüğü ≤ 540×960 ve `render_target_update_mode = UPDATE_ALWAYS`.
- Menüde: `Menu.tscn` içinde `SubViewportContainer` → `SubViewport` → instance. Pano/oyun
  arkasında: `Game.tscn`'de `Backdrop` düğümü olarak.
- Animasyonlar ASMR diline uyar: yavaş (`period ≥ 2 sn`), kesintisiz, döngüsel.

## 13.1 AmbientBackdrop teslimi (uygulandı)

`scenes/AmbientBackdrop.tscn` + `class_name AmbientBackdrop` teslim edildi:
`setup(kind)` (`KIND_MENU=0`, `KIND_GAME=1`), `set_intensity(0..1)`, `menu_camera()`,
`menu_environment()`. Oyun içinde yalnızca panonun sol/sağ kenar boşlukları görünür; üst HUD
bandı ve alt eylem şeridi temiz tutulur. ≤40 düğüm, gölge yok, 30 Hz döngüsel animasyon,
2 statik batch (~9 draw call). Menüde `SubViewport` (540×960) içinde çalışır.

## 14. Performans bütçesi — v0.2

- Hedef: masaüstünde 60 fps sabit; düşük segment Android'de ≥ 30 fps.
- **Kare süresi p95 < 16.7 ms** (M4, 540×960 pencere) ve drag sırasında da korunur.
- Halat mesh'i: yalnızca noktalar değiştiğinde yeniden kurulur; hareketli kablo ≤ 1/kare,
  sabit kablolar 30 Hz'de bir. Alt örnekleme katsayısı idle'da düşürülebilir.
- Tam ekran ekstra render yok (postfx screen-texture shader'ı kaldırılabilir; statik vinyet
  dokusu tercih edilir). MSAA kapalı.
- Ölçüm: `godot --path . -s res://tools/perf_probe.gd` → `BUILD/perf.json` + konsol raporu.
- 2274 nesne / 19k primitive mevcut tabandır; ideal hedef < 120 draw call.
- **Uygulanan optimizasyonlar (ölçüldü):** halat mesh'i olay-tabanlı + yeniden kullanılabilir
  PackedArray (SurfaceTool kaldırıldı), 30 kare hareketsizlikte fizik uykusu, idle'da 51 halka;
  `SparkBurst` `_ready`'de görünmez ısıtma (ilk kıvılcım shader compile hitch'i 118.9 ms → 0);
  BoardBuilder statik pano 2 vertex-renkli batch (~27 → 10 draw); tam ekran screen-texture
  postfx kaldırıldı, statik vinyet dokusu kullanıldı; kamera sarsıntısı yumuşatıldı.
  Sonuç (M4, 540×960, bölüm 12): menu p95 2.78 ms / draw 39; game p95 6.06 ms / draw 158;
  drag p95 6.94 ms / max 10.66 ms / hitch yok / min_fps 93.8. Kalan tek hedef socket
  birleştirmesi (42 → 21 draw, ~+21 kazanç).

## 15. UI tasarım token'ları — v0.2

- **Sade, ikon-öncelikli, nazik.** Ekran başına en fazla 3 ana eylem; buton metni 1–2 kelime.
- Buton yüksekliği **88–100 tasarım px** (1080 taban), dokunma alanı ≥ 88. Birincil buton
  genişliği içerik kadar (tam genişlik değil), ekran kenar boşluğu 48 px.
- Tipografi: **Manrope** (OFL). Başlık `FontVariation` wght 800 (veya büyük punto + sıkı
  aralık); gövde 30–34, etiket 24–28. Maks 2 satır.
- 8 px grid; köşe yarıçapı 20–28; gölge yok, yumuşak kontrast; palet: koyu sıcak-gri zemin,
  mint birincil, amber vurgu, yumuşak mercan tehlike.
- HUD panoyu **örtmez**: üst bar ≤ 180 px, alt eylem şeridi ≤ 140 px (1080 tabanında).
- Dil değiştirici her ekranda erişilebilir (menü üst köşe + ayarlar).

## 16. ASMR / rahatlatıcı yönergeleri — v0.2

- **Hissiyat:** gerilim var ama panik yok; hareketler yavaş, yumuşak, nefes alan.
- Görsel: warm-koyu palet, düşük kontrast, yumuşak bloom; sert beyaz/kırmızı flaş yok;
  kısa devrede sıcak amber vinyet + yumuşak kamera sarsıntısı; kablolar yavaş sallanır.
- Arka plan: canlı ama sakin — dönen fan, salınan lamba, yavaş konveyör, toz partikülleri.
- Ses: yumuşak, tok, düşük frekanslı; crackle kısık; clack ahşap-tok; ambient hum + pad
  sürekli ve kısık; ani yüksek ses yok. `AudioService` ambient loop API kullanılır.
- Animasyon: easing `TRANS_SINE/EASE_OUT`, süreler 0.25–0.6 sn; kutlama sakin parıltı.

