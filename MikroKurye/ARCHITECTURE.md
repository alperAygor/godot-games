# ARCHITECTURE — Micro Courier

Tasarım için `PROJECT_SPEC.md`, iş sırası için `TASKS.md`. Bu belge **modül sözleşmelerini** tanımlar: sınıf adı, dosya, kamu API'si, davranış kuralları.
İşçi ajanlar API imzalarına **birebir** uyar (testler bu imzalara yazılır). İmza değişikliği liderin kararıdır.

## 1. Katmanlar

```
UI (Control)            -> sunum, giriş (HUD, sipariş seçimi, garaj, sonuç)
Gameplay (Node3D)       -> dünya, robot, kargo, tehlikeler, kamera (fizik burada)
Autoload servisleri     -> akış, ses, reklam, veri, kayıt
Core (RefCounted)       -> saf mantık: hasar, batarya, ödül, geliştirme, kontrol noktası (HEADLESS TEST EDİLİR)
Services (AdsProvider)  -> dış SDK sınırı
```

Bağımlılık yukarıdan aşağıya. **`core` hiçbir katmanı tanımaz**: sahne, düğüm, autoload, `Engine` çağırmaz; yalnızca sayı, `Dictionary`, `Array` alır-verir.
Fizik motoru yalnızca **ölçüm** üretir (darbe impulsu, açısal ivme, düşüş yüksekliği); hasar kararını `core` verir (K5).

## 2. Autoload'lar (sıra korunur)

Şablondaki dörtlü: `GameManager` → `AudioService` → `AdManager` → `GameData`. Faz 4'te `SaveService` (en sona) eklenir.

| Servis | Ek sorumluluk (bu oyun) |
|---|---|
| `GameManager` | Faz: BOOT, MENU, GARAGE (Faz 4), GAME, RESULT. `last_result` sözlüğü: `{success, damage, stars, multiplier, gold, scrap, cargo_id, level_id}` |
| `GameData` | Tablolar: `balance`, `cargo`, `upgrades`, `ads`, `sounds`, `theme` |
| `AdManager` | Yerleşim kimlikleri: `CARGO_INSURANCE`, `GOLDEN_BOX`, `TRY_BEFORE_BUY`, `BATTERY_RECHARGE`, `DOUBLE_REWARD` (limitler `data/ads.json`) |

## 3. Veri tabloları (`data/`)

Sihirli sayı yok; ayarlanabilir her değer buradadır.

`data/cargo.json` — kargo profilleri (anahtar = `cargo_id`):

```json
{
  "pencil_battery": { "name_key": "cargo.battery", "difficulty": 1, "mass": 0.05,
    "impact_threshold": 9.0, "impact_scale": 0.02, "slosh_threshold": 999.0, "slosh_scale": 0.0,
    "fall_threshold": 0.45, "fall_scale": 0.6, "reward_gold": 40, "reward_scrap": 2 },
  "sd_card": { "name_key": "cargo.sd_card", "difficulty": 2, "mass": 0.02,
    "impact_threshold": 3.5, "impact_scale": 0.07, "slosh_threshold": 14.0, "slosh_scale": 0.004,
    "fall_threshold": 0.18, "fall_scale": 1.4, "reward_gold": 90, "reward_scrap": 5 },
  "espresso_capsule": { "name_key": "cargo.espresso", "difficulty": 3, "mass": 0.04,
    "impact_threshold": 5.0, "impact_scale": 0.05, "slosh_threshold": 6.0, "slosh_scale": 0.012,
    "fall_threshold": 0.25, "fall_scale": 1.0, "reward_gold": 160, "reward_scrap": 9 }
}
```

(Sayılar başlangıç tahminidir; fizik prototipinde (Faz 2) ölçülerek ayarlanır.)

`data/upgrades.json` — kategori → seviyeler (Faz 4). Seviye N'i satın almanın bedeli `levels[N-1].cost`; sahip olunan tüm seviyelerin `mods`'u toplanır:

```json
{
  "chassis": { "max_level": 5, "levels": [
    { "cost": {"gold": 100, "scrap": 5},  "mods": {"cargo_damping_bonus": 1.0} },
    { "cost": {"gold": 200, "scrap": 10}, "mods": {"cargo_damping_bonus": 1.0} },
    { "cost": {"gold": 350, "scrap": 18}, "mods": {"cargo_damping_bonus": 1.0} },
    { "cost": {"gold": 550, "scrap": 28}, "mods": {"cargo_damping_bonus": 1.0} },
    { "cost": {"gold": 800, "scrap": 40}, "mods": {"cargo_damping_bonus": 1.0} } ] },
  "wheels": { "max_level": 5, "levels": [
    { "cost": {"gold": 80,  "scrap": 4},  "mods": {"wheel_grip_bonus": 0.6} },
    { "cost": {"gold": 160, "scrap": 8},  "mods": {"wheel_grip_bonus": 0.6} },
    { "cost": {"gold": 300, "scrap": 15}, "mods": {"wheel_grip_bonus": 0.6} },
    { "cost": {"gold": 480, "scrap": 24}, "mods": {"wheel_grip_bonus": 0.6} },
    { "cost": {"gold": 700, "scrap": 35}, "mods": {"wheel_grip_bonus": 0.6} } ] },
  "battery": { "max_level": 5, "levels": [
    { "cost": {"gold": 80,  "scrap": 3},  "mods": {"battery_capacity_bonus": 15.0} },
    { "cost": {"gold": 160, "scrap": 7},  "mods": {"battery_capacity_bonus": 15.0} },
    { "cost": {"gold": 300, "scrap": 14}, "mods": {"battery_capacity_bonus": 15.0} },
    { "cost": {"gold": 480, "scrap": 22}, "mods": {"battery_capacity_bonus": 15.0} },
    { "cost": {"gold": 700, "scrap": 32}, "mods": {"battery_capacity_bonus": 15.0} } ] }
}
```

`data/balance.json` — mevcut `base_fee` korunur; fizik ve batarya sabitleri `physics.*`, `battery.*` anahtarlarıyla eklenir (bkz. §5).

## 4. Core modülleri (saf mantık; Faz 1; testler ÖNCE yazılır)

Hepsi `scripts/core/`; `class_name` + `extends RefCounted`; testler `tests/unit/test_<ad>.gd`. (Numaralama sırası belge sırasıdır, ör. 4.7 `Wallet` 4.5'ten önce yazılabilir.)

### 4.1 `DamageModel` — `scripts/core/damage_model.gd` (statik, durumsuz)

Kargo profili = `cargo.json` girdisi (`Dictionary`). Eksik anahtar için aşağıdaki varsayılanlar kullanılır.

```gdscript
static func impact_damage(impulse: float, profile: Dictionary) -> float   # (impulse - impact_threshold) * impact_scale; eşik ve altı 0; negatif impulse = 0
static func slosh_damage(angular_accel: float, dt: float, profile: Dictionary) -> float  # (|a| - slosh_threshold) * slosh_scale * dt; eşik altı 0; dt <= 0 ise 0
static func fall_damage(drop_height: float, profile: Dictionary) -> float  # (h - fall_threshold) * fall_scale; eşik altı / negatif 0
```

Hepsi **>= 0** döner ve tek çağrıda `1.0`'a kırpılır. Varsayılan: eşikler `INF`-benzeri değil `999.0`, ölçekler `0.0` (hasar yok).

### 4.2 `CargoHealth` — `scripts/core/cargo_health.gd` (durumlu)

```gdscript
func _init(profile: Dictionary, jelly_charges: int = 0) -> void
func apply_impact(impulse: float) -> float        # uygulanan hasar (>= 0)
func apply_slosh(angular_accel: float, dt: float) -> float
func apply_fall(drop_height: float) -> float
func damage() -> float                            # birikmiş hasar, 0..1
func integrity() -> float                         # 1 - damage()
func is_broken() -> bool                          # damage() >= 1.0
func jelly_left() -> int                          # Şok Emici Jel: kalan koruma
```

Kural: Hasar bu çağrıda 1.0'a ulaşacakken ve `jelly_left() > 0` ise koruma tüketilir; hasar `max(mevcut, 0.95)` olur ve `jelly_left()` bir azalır (kırılma yok).
Dönüş değeri, **gerçekten eklenen** hasardır (`damage()` farkı; kırpma/jel sonrası). Kırık kargoya hasar eklenmez (dönüş 0.0).

### 4.3 `BatteryModel` — `scripts/core/battery_model.gd` (durumlu)

```gdscript
func _init(capacity: float = 100.0, params: Dictionary = {}) -> void   # params: speed_drain (0.02), empty_speed_factor (0.35), boost_factor (1.25); eksik anahtar = parantezdeki varsayılan
func level() -> float             # 0..1
func drain(amount: float) -> void # >= 0 harcar, 0'ın altına inmez
func drain_for_speed(speed: float, dt: float) -> void  # tüketim = speed_drain * speed^2 * dt (hız 0 ise 0; negatif dt/hız 0 sayılır)
func recharge(amount: float) -> void  # kapasiteyi aşmaz
func refill_full() -> void
func is_empty() -> bool
func speed_factor() -> float      # dolu: 1.0; boş: empty_speed_factor; arada level()'a göre DOĞRUSAL (1.0 -> empty_speed_factor)
func start_boost(seconds: float) -> void
func boost_active() -> bool
func tick(dt: float) -> void      # boost süresini azaltır (0'ın altına inmez); boost sırasında speed_factor() = boost_factor (batarya boş olsa da)
```

### 4.4 `DeliveryReward` — `scripts/core/delivery_reward.gd` (statik)

`RunScoring` (yıldız/ücret çarpanı) **bozulmadan** kullanılır.

```gdscript
static func compute(damage: float, profile: Dictionary, bonus: Dictionary = {}) -> Dictionary
# {damage, stars, multiplier, gold, scrap, success}
# gold  = int(round(profile.reward_gold * RunScoring.multiplier_for_damage(damage_kırpılmış) * (1 + bonus.gold_pct)))
# scrap = int(round(profile.reward_scrap * (1 - damage_kırpılmış)))   (kırık = 0)
# success = damage < 1.0
```

### 4.5 `UpgradeModel` — `scripts/core/upgrade_model.gd` (statik; Faz 4)

```gdscript
static func cost(table: Dictionary, category: String, level: int) -> Dictionary      # level = SATIN ALINACAK seviye (1..max); yoksa {}
static func can_afford(wallet: Dictionary, cost: Dictionary) -> bool                   # {gold, scrap}
static func purchase(table: Dictionary, wallet: Dictionary, levels: Dictionary, category: String) -> Dictionary
# {ok: bool, wallet: Dictionary, levels: Dictionary, reason: String}; girdi sözlüklerini DEĞİŞTİRMEZ (kopya döner)
static func stats(table: Dictionary, levels: Dictionary) -> Dictionary                 # tüm sahip olunan seviyelerin "mods" toplamı
```

### 4.7 `Wallet` — `scripts/core/wallet.gd` (durumlu; para birimi)

İki para birimi: **gold** (Altın) ve **scrap** (Hurda). Negatif bakiye olamaz.

```gdscript
func _init(gold: int = 0, scrap: int = 0) -> void
func gold() -> int
func scrap() -> int
func add(gold: int, scrap: int = 0) -> void        # negatif girdi 0 sayılır (yalnız ekler)
func can_afford(cost: Dictionary) -> bool          # {"gold": int, "scrap": int}; eksik anahtar 0
func spend(cost: Dictionary) -> bool               # yeterliyse düşer ve true; değilse HİÇBİR ŞEY değişmez ve false
func to_dict() -> Dictionary                       # {"gold": int, "scrap": int}
static func from_dict(d: Dictionary) -> Wallet     # eksik/yanlış tip/negatif/küsuratlı -> 0; JSON'dan gelen küsuratsız float (10.0) tamsayı sayılır (GOTCHAS #20)
```

### 4.8 `ProfileData` — `scripts/core/profile_data.gd` (durumlu; kayıt içeriği, Faz 4)

Oyuncu ilerlemesinin saf veri modeli (dosya/IO YOK; `SaveService` sarmalar).

```gdscript
const VERSION: int = 1
func _init() -> void                                   # cüzdan 0/0, seviyeler {chassis:0, wheels:0, battery:0}, istatistik sıfır
func wallet() -> Wallet                                # canlı referans (değişiklikler profile yansır)
func level(category: String) -> int                    # bilinmeyen kategori 0
func set_level(category: String, level: int) -> void   # < 0 -> 0
func levels() -> Dictionary                            # {"chassis": int, "wheels": int, "battery": int} KOPYA
func record_result(result: Dictionary) -> void
# result: {success, gold, scrap, stars, cargo_id}. Başarılıysa gold/scrap cüzdana eklenir (negatif 0), stats.deliveries += 1,
# stats.best_stars[cargo_id] = max(eski, stars); başarısızsa (success=false) yalnız stats.breaks += 1 (para eklenmez).
func stats() -> Dictionary                             # {"deliveries": int, "breaks": int, "best_stars": Dictionary} KOPYA
func to_dict() -> Dictionary                           # {"version": 1, "wallet": {...}, "levels": {...}, "stats": {...}}
static func from_dict(d: Dictionary) -> ProfileData    # eksik/yanlış tip/negatif -> varsayılan; JSON küsuratsız float tamsayı sayılır (GOTCHAS #20); bilinmeyen/yüksek sürüm -> yalnız tanıdığı alanları okur
```

### 4.6 `CheckpointTracker` — `scripts/core/checkpoint_tracker.gd` (durumlu; Faz 2)

```gdscript
func register(id: int, position: Vector3) -> void   # id'ler 0..N, 0 = başlangıç
func reach(id: int) -> bool                         # yalnızca ileri ilerleme sayılır (id > son); doğruysa güncellendi
func last_id() -> int
func last_position() -> Vector3                     # kayıtsızsa Vector3.ZERO
func reset() -> void
```

## 5. Gameplay (Faz 2+; sahne ve fizik)

Bu modüllerin davranışı ağırlıklı **fizik hissine** bağlıdır; birim testi sınırlıdır. Doğrulama: `verify.sh` + proje `tools/game_probe.gd` (headless fizik probu) + `shots.sh` + oyuncu denemesi.

| Düğüm / sınıf | Dosya | Sorumluluk |
|---|---|---|
| `RobotController` (RigidBody3D) | `scripts/gameplay/robot_controller.gd` | Joystick girdisini hedef hız/yöne çevirir, `speed_factor()` uygular, havada denge torku |
| `SuspensionWheel` (Node3D) | `scripts/gameplay/suspension_wheel.gd` | Raycast süspansiyon (yay-sönüm), tutuş; robota kuvvet uygular |
| `CargoBasket` (RigidBody3D + 6DOF yay) | `scripts/gameplay/cargo_basket.gd` | Kargoyu sırtta taşır, sallanır; `impact_reported(impulse)`, `slosh_reported(angular_accel, dt)` |
| `ImpactSensor` | `scripts/gameplay/impact_sensor.gd` | `_integrate_forces` ile darbe impulsunu ölçer; sinyalle bildirir |
| `InputService` (Control/Node) | `scripts/gameplay/input_service.gd` | Sanal joystick, havada kaydırma, modül düğmesi; fare/dokunma |
| `CameraRig` | `scripts/gameplay/camera_rig.gd` | Arkadan-yukarıdan takip, hız bağımlı FOV/sarsıntı |
| `LevelRoot` | `scripts/gameplay/level_root.gd` | Başlangıç, kontrol noktaları, teslimat bölgesi, düşme sınırı |
| `Hazard*` | `scripts/gameplay/hazards/` | `KeyboardKey`, `FanWind`, `RollingPencil` |

Akış: `ImpactSensor/CargoBasket` → sinyal → `GameController` (Game sahnesi) → `CargoHealth.apply_*` → HUD güncellenir; `is_broken()` → revive teklifi (`AdManager`) ya da `GameManager.finish_run`.
Fizik sabitleri (`data/balance.json`, `physics.*`): `gravity_scale`, `robot_mass`, `max_speed`, `accel`, `turn_rate`, `suspension_stiffness`, `suspension_damping`, `cargo_spring`, `cargo_damping`, `cargo_joint_limit_deg`, `air_balance_torque`.

Kurallar: sabit adım 60 Hz; `_physics_process`'te allocation yok (`Array`/`Dictionary`/`PackedVector3Array` yeniden kullanılır); çarpışma şekilleri basit (kutu/kapsül/küre); raycast sayısı robot başına 4.

### 5.1 Fizik prototipi sözleşmesi (Faz 2; `tools/game_probe.gd` bunu denetler)

Bu bölüm bağlayıcıdır; imzalar ve sahne düzeni değişmez. Probe (`tools/game_probe.gd`, KORUMALI) headless çalışır ve sayısal kabul ölçütüdür.

**Sahne:** `res://scenes/Proto.tscn` (kök `Node3D`):
- Zemin: `StaticBody3D`, üst yüzeyi **y = 0**, −Z yönünde en az 60 m, X'te en az 6 m. Yürüyüş yönü **−Z**.
- `Marker3D` adı `RampStart`: zeminde, rampadan ~8 m önce; **−Z'ye bakar**. Rampanın ardında en az 15 m düz zemin (iniş alanı). Rampa tırmanışı ~15–25°, yüksekliği 0.4–1.0 m.
- `Marker3D` adı `RobotStart`: robotun başlangıcı (zeminin biraz üstü, −Z'ye bakar).
- Takip kamerası: `Camera3D` (arkadan-yukarıdan, robotu izler); kök sahnede `CameraRig` düğümü.
- Dış ortam: sahne yalnızca basit düz renkli `StandardMaterial3D` kullanır (low-poly stili).

**Robot** — düğüm grubu `robot`, `class_name RobotController`, `extends RigidBody3D`, `scripts/gameplay/robot_controller.gd`:
```gdscript
func set_move_input(v: Vector2) -> void   # x: sol(-1)/sağ(+1) direksiyon, y: geri(-1)/ileri(+1) gaz; uzunluk 1'e kırpılır
func speed() -> float                      # |düzlemsel hız| (m/s)
func max_speed() -> float                  # hedeflenen azami hız (m/s), balance.physics.max_speed
func is_grounded() -> bool                 # en az bir tekerlek zemine değiyor
```
4 raycast süspansiyon tekerleği (`SuspensionWheel`); `RigidBody3D` kullanılır, `VehicleBody3D` DEĞİL. Girdi klavye (WASD/oklar) ve dokunma/fare joystick'ten gelir, ikisi de `set_move_input`'a düşer.

**Kargo** (Faz 2.2'den itibaren) — grup `cargo`, `class_name CargoBasket`, `extends RigidBody3D`, `scripts/gameplay/cargo_basket.gd`:
```gdscript
func sway_angle_deg() -> float   # sepet "yukarı" ekseni ile robotun "yukarı" ekseni arasındaki açı (derece, >= 0)
func is_attached() -> bool       # robota bağlı mı (sepet–robot mesafesi/açısı sınır içinde)
signal impact_reported(impulse: float)
signal slosh_reported(angular_accel: float, dt: float)
```

**Parametreler:** `balance.json` → `physics.*` (bkz. §5 sabit listesi). Kod, değeri `get_node_or_null("/root/GameData")` ile okur (probe `-s` modunda çalıştığı için autoload'a **kimlikle** değil yolla eriş); düğüm yoksa koddaki makul varsayılanlar kullanılır.

**Probe aşamaları** (`tools/probe_stage.txt`: `robot` ya da `full`; liderin kararıdır):
| Aşama | Ölçüt (60 Hz fizik, kare sayıları) |
|---|---|
| Kurulum | `Proto.tscn` yüklenir; `robot` grubu var; API metotları var; `RobotStart`/`RampStart` var |
| Dinlenme | 180 kare girdisiz: `speed() < 0.1`, `0 < robot.y < 1.0`, değerler sonlu |
| İvmelenme | 180 kare ileri gaz: azami hız ≥ `0.8 * max_speed()`, ≤ `1.3 * max_speed()` |
| Frenleme | 240 kare girdisiz: son hız < `0.15 * max_speed()` |
| Dönüş | 120 kare gaz+sağ direksiyon: yaw değişimi ≥ 30° |
| Rampa | `RampStart`'tan gazla: ≥ 3 ardışık kare havada, sonra tekrar yerde; hız < 40 m/s; y > −2 |
| (full) Kargo | `cargo` var; dinlenmede `sway < 1.5°`; ivmelenmede tepe `sway ≥ 2°` ve `≤ 60°`; frenlemeden 4 sn sonra `sway < 3°`; tüm testlerde `is_attached()` doğru |

### 5.2 Oyun akışı sözleşmesi (Faz 2C; `tools/flow_probe.gd` denetler)

`res://scenes/Game.tscn` gerçek oyun sahnesi olur (şablondaki yer tutucu butonlu sahne YERİNE). Kök `Node3D`, script `scripts/gameplay/game_controller.gd`, `class_name GameController`, düğüm grubu `game_controller`.

**Sahne içeriği:** zemin/rampa içeren test seviyesi (Proto'dan türetilebilir ama Proto.tscn DEĞİŞMEZ), `RobotStart` Marker3D, `Checkpoint_1`, `Checkpoint_2` Marker3D (−Z'de ~10 m ve ~20 m), `DeliveryZone` (Area3D + CollisionShape3D, −Z'de ~30 m, robotun düz gidişinde engelsiz),
robot (grup `robot`), kargo (grup `cargo`), takip kamerası, `HUD` (CanvasLayer: `CargoHealthBar` ProgressBar 0..100, `BatteryBar` ProgressBar 0..100). Seviye düz ve engelsizdir; gerçek harita Faz 3'te gelir.

**GameManager:** `var selected_cargo_id: String = "pencil_battery"` eklenir (ileride sipariş ekranı doldurur). `Game.tscn` açılınca bu kargo profili `GameData.table("cargo")` içinden alınır; yoksa `pencil_battery`.

**GameController API:**
```gdscript
signal finished(result: Dictionary)          # tur bitince BİR KEZ (teslimat ya da kırılma)
func state() -> Dictionary                   # {cargo_id, damage, integrity, battery, checkpoint_id, respawns, delivered, broken, finished, elapsed}
func restart() -> void                       # sağlık, batarya, kontrol noktası, sayaçlar sıfırlanır; robot RobotStart'a döner; finished bayrağı temizlenir
func set_battery_level(level: float) -> void # 0..1 (kırpılır); reklamlı hızlı şarj ve test için; HUD/hız faktörü hemen yansır
```
**Bağlantılar (hepsi `scripts/core/` sınıflarıyla):**
- `cargo.impact_reported(impulse)` → `CargoHealth.apply_impact`; `cargo.slosh_reported(a, dt)` → `apply_slosh`. Kargo profili `GameData.table("cargo")[selected_cargo_id]`.
- Her fizik karesi `BatteryModel.drain_for_speed(robot.speed(), dt)`; `robot.set_speed_factor(battery.speed_factor())` (RobotController'a `set_speed_factor(f: float) -> void` eklenir: hedef hızı f ile çarpar; `max_speed()` DEĞİŞMEZ).
- `CheckpointTracker`: `RobotStart` = id 0, `Checkpoint_N` = id N; robot bir kontrol noktasının 2 m yakınına girince `reach(N)`.
- Düşme: robot `y < balance.game.kill_y` (varsayılan -5) olursa son kontrol noktasına geri döner (hızlar sıfır), `respawns += 1`, ceza olarak `apply_fall(balance.game.respawn_drop_height)` (varsayılan 1.0).
- `DeliveryZone` robota/sepete temas ederse teslimat: `DeliveryReward.compute(damage, profile)`; `is_broken()` olursa başarısız sonuç (aynı fonksiyon, `success=false`).
- Sonuç sözlüğü: `{success, damage, stars, multiplier, gold, scrap, fee (=gold), cargo_id, level_id, time}`. `finished` yayılır, sonra `GameManager.finish_run(result)` **çağrılır** (`get_node_or_null("/root/GameManager")` ile, probe `-s` modunda çalışır).
- HUD çubukları her karede `integrity()*100` ve `battery.level()*100` ile güncellenir.
- Parametreler: `balance.json` → `game.kill_y`, `game.respawn_drop_height`, `game.checkpoint_radius`.

### 5.3 Seviye ve tehlike sözleşmesi (Faz 3; `tools/level_probe.gd` denetler)

**Seviye sahnesi:** `res://scenes/levels/desk_01.tscn` (Çalışma Masası). Kök `Node3D`, `scripts/gameplay/level_root.gd`, `class_name LevelRoot`, `@export var level_id: String = "desk_01"`.
- Tek başına yüklenebilir (Game/GameController olmadan): tehlikeler kendi içinde çalışır.
- Marker3D'ler: `RobotStart`, `Checkpoint_1`, `Checkpoint_2`, `Checkpoint_3`; `DeliveryZone` (Area3D). Hepsi −Z yönünde sıralı (daha büyük numara = daha uzakta). `RobotStart`→`DeliveryZone` uzaklığı ≥ 60 m, genişlik ≥ 8 m. Masa SONLUDUR (kenarlardan düşülebilir; zemin dışında boşluk).
- Zemin y=0 civarı; masa üstü eşyaları (kupa, kitap, cetvel, kalem, klavye) `assets/models/*.glb` modelleri hazırsa onlarla, değilse basit düz renkli kutu/silindirlerle yerleştirilir (model entegrasyonu Görsel V2'de).
- Seçim: `GameManager.selected_level_id` (varsayılan `desk_01`); `Game.tscn` seviyeyi buradan yükler (`scenes/levels/<id>.tscn`).

**Tehlikeler** (`scripts/gameplay/hazards/`, hepsi seviyede yer alır, kendi grubuna ve `hazard` grubuna girer; zamanlama fizik karesi ile **deterministik**, rastgelelik yok ya da sabit tohumlu):
```gdscript
class_name KeyboardKey  # extends AnimatableBody3D, grup "keyboard_key"
func is_telegraphing() -> bool   # bastırmadan ÖNCE uyarı (renk/titreme); en az 0.5 sn (balance.hazards.key_warn_seconds)
func is_pressed() -> bool        # tuş aşağıda (robotu fırlatabilir/sarsabilir)
# Döngü: bekle -> uyar -> bas -> bırak; periyot balance.hazards.key_period_seconds

class_name FanWind      # extends Area3D, grup "fan_wind"
func is_blowing() -> bool
func wind_direction() -> Vector3  # birim vektör
# Alandaki HER RigidBody3D'ye merkezî kuvvet uygular (kütleyle ölçeklenmez: ivme balance.hazards.fan_accel); üflemeli/sakin döngü

class_name RollingPencil # extends RigidBody3D, grup "rolling_pencil"
# Yolu keserek yuvarlanır (periyodik başlatma), bir mesafe sonra başlangıca döner; kenara düşmez
```
Kargo hasarı, tehlikelerin robota/sepete uyguladığı çarpmalardan zaten `impact_reported` ile akar; tehlikelere özel hasar kodu YOK.
Parametreler: `balance.json` → `hazards.*` (`key_period_seconds`, `key_warn_seconds`, `key_press_depth`, `fan_accel`, `fan_cycle_seconds`, `pencil_period_seconds`, `pencil_speed`).

**Probe (headless, 60 Hz kare sayımı):** yapı (marker'lar, uzunluk, ≥1 klavye tuşu, ≥1 fan, ≥1 kalem), klavye uyarı→basma sırası (uyarı ≥ 20 kare önce), fan alanındaki test küresi üflerken ≥0.3 m/s kazanır, kalem 600 karede ≥1 m hareket eder.

### 5.4 Meta akışı sözleşmesi (Faz 4b; `tools/meta_probe.gd` denetler)

**SaveService** (autoload, `GameData`'dan SONRA; `scripts/autoload/SaveService.gd`): `ProfileData`'yı `user://save.json`'a yazar/okur.
```gdscript
func profile() -> ProfileData
func set_save_path(path: String) -> void           # test için; varsayılan "user://save.json"
func load_profile() -> void                         # yok/bozuk dosya -> varsayılan profil (bozuk dosya "<ad>.corrupt" olarak yedeklenir, çökme yok)
func save_profile() -> bool                         # atomik yaz (geçici dosya + yeniden adlandır)
func apply_result(result: Dictionary) -> void       # profile.record_result + save_profile(); AYNI sonuç iki kez uygulanmaz (result["applied"] işareti)
func upgrade_cost(category: String) -> Dictionary   # sıradaki seviyenin bedeli ({} = maksimumda)
func purchase(category: String) -> bool             # UpgradeModel.purchase + save_profile(); yetersiz bakiye/maksimum -> false, DEĞİŞİKLİK YOK
func mods() -> Dictionary                           # UpgradeModel.stats(data/upgrades.json, profile.levels())
```
**GameManager:** `var navigation_enabled: bool = true` (false iken `goto_scene` sahne değiştirmez, hata basmaz; probe için); `SCENES`'e `&"order"` (`OrderSelect.tscn`) ve `&"garage"` (`Garage.tscn`) eklenir; `Phase`'e `GARAGE`. Akış: Menu → (Oyna) OrderSelect → Game → Result → (Tekrar) Game / (Menü) Menu; Menu → Garaj.
**OrderSelect** (`scenes/OrderSelect.tscn`): `data/cargo.json`'daki her kargo için bir kart düğmesi `CargoCard_<cargo_id>` (ad, zorluk, ödül); basınca `GameManager.selected_cargo_id` set edilir ve `start_game()` çağrılır. Geri düğmesi `BackButton`.
**Garage** (`scenes/Garage.tscn`): cüzdan etiketleri `GoldLabel`, `ScrapLabel`; her kategori için `UpgradeButton_<category>` (seviye, maliyet; yetmiyorsa devre dışı) → `SaveService.purchase`; `BackButton`.
**Result:** `SaveService.apply_result(result)` ÇAĞIRIR (bir kez) ve yeni cüzdanı gösterir. **Menü:** "Oyna" → OrderSelect, "Garaj" → Garage; mevcut diğer akış bozulmaz.
**Efektler (`GameController.state()["mods"]`):** başlangıçta `SaveService.mods()` okunur: `cargo_damping_bonus` kargo sönümüne eklenir, `wheel_grip_bonus` tekerlek tutuşuna eklenir, `battery_capacity_bonus` batarya kapasitesine eklenir; uygulanan toplamlar `state()["mods"]` sözlüğünde görünür.
**Probe:** SaveService turu (apply_result → dosyaya yazılır → yeniden yükleme aynı), bozuk dosya toleransı, purchase (bakiye düşer/seviye artar/yetersizse değişmez), mods → `state()["mods"]`, OrderSelect kartı → `selected_cargo_id`, Garage etiketleri.

### 5.5 Reklam sözleşmesi (Faz 5; `tools/ads_probe.gd` denetler)

**AdManager.Placement** (şablon kalıntıları `EXTRA_POCKET`, `TAPE_RESCUE` KALDIRILIR): `CARGO_INSURANCE`, `BATTERY_RECHARGE`, `DOUBLE_REWARD`, `TRY_BEFORE_BUY`, `GOLDEN_BOX`.
`PLACEMENT_KEYS` ve `data/ads.json` bunlara göre: `CARGO_INSURANCE {per_run 1, per_session 5}`, `BATTERY_RECHARGE {1, 5}`, `DOUBLE_REWARD {1, 3}`, `TRY_BEFORE_BUY {1, 3}`, `GOLDEN_BOX {1, 3}`. Mevcut API (`can_offer`, `show_rewarded`, `rewarded_finished(placement, success)`, `reset_run_limits`) korunur.
**MockAdsProvider** (test edilebilirlik): `var instant: bool = false` (true iken `show()` bir sonraki karede bitirir, gecikme yok) ve `var force_result: int = -1` (-1 rastgele/mevcut davranış, 0 başarısız `failed("no_fill")`, 1 başarılı `rewarded`). Probe bunları `AdManager.provider` üzerinde ayarlar.
**Sınırlar:** her tur başlangıcında (`GameController.restart()`/Game açılışı) `AdManager.reset_run_limits()` çağrılır.

**Aşama a — GameController (revive + hızlı şarj):**
```gdscript
signal revive_offered()
func accept_revive() -> void      # reklamı gösterir; başarıyla biterse revive uygulanır
func decline_revive() -> void     # teklifi reddeder: tur kırık olarak BİTER (finished yayılır)
func request_recharge() -> void   # BATTERY_RECHARGE reklamı; başarıyla biterse batarya %100 + boost
# state() yeni anahtarlar: revive_offered (bool), revive_used (bool), recharge_available (bool), boost_active (bool)
```
- **Revive (CARGO_INSURANCE):** kargo KIRILIRSA ve `AdManager.can_offer(CARGO_INSURANCE)` ise tur BİTMEZ: `revive_offered` sinyali + `state().revive_offered=true`; HUD'da `RevivePanel` (içinde `ReviveButton`, `DeclineButton`). `accept_revive()` → reklam başarılıysa: kargo sağlığı SIFIRLANIR (hasar 0.0, kırık değil), robot son kontrol noktasına döner (hızlar sıfır), `revive_used=true`, tur devam eder. Reklam başarısızsa teklif kapanır, tur kırık biter. Tur başına bir kez; ikinci kırılmada teklif YOK (anında biter). Reklam teklif edilemiyorsa (limit/provider) kırılma eskisi gibi hemen biter.
- **Hızlı şarj (BATTERY_RECHARGE):** `battery.level() < balance.game.recharge_threshold` (varsayılan 0.15) ve `can_offer` iken `state().recharge_available=true` ve HUD'da `RechargeButton` görünür. `request_recharge()` → başarıyla biterse `set_battery_level(1.0)` + `BatteryModel.start_boost(balance.game.recharge_boost_seconds)` (varsayılan 10); `state().boost_active`. Tur başına bir kez.
- Düğme metinleri `scripts/ui/strings.gd`'de.

**Aşama b — Sonuç/garaj/seviye:**
- **DOUBLE_REWARD:** `Result.tscn`'de `DoubleRewardButton` (yalnız başarılı sonuçta ve `can_offer`): reklam başarılıysa `SaveService.grant(gold, scrap)` (sonuçtaki değerler kadar ikinci kez) ve düğme gizlenir; `result["doubled"]=true`.
- **SaveService.grant(gold: int, scrap: int) -> void** (cüzdana ekler + kaydeder; negatif 0). `SaveService.set_trial(category: String)`, `SaveService.clear_trial()`, `SaveService.trial() -> String`; `mods()` deneme kategorisinin SONRAKİ seviyesinin `mods`'unu da ekler. `GameController` başlangıçta `mods()`'u okur ve deneme etkisini UYGULADIKTAN sonra `clear_trial()` çağırır (tek koşuluk).
- **TRY_BEFORE_BUY:** Garage'da seviyesi maksimum olmayan her kategori için `TryButton_<category>`: `show_rewarded(TRY_BEFORE_BUY)` başarılıysa `set_trial(category)`.
- **GOLDEN_BOX:** seviyede (`desk_01.tscn`) rotadan ~4–5 m uzakta `GoldenBox` (Area3D, grup `golden_box`, altın renkli parlayan kutu); robot/sepet değerse `state().golden_box_collected=true`. Başarılı teslimde `result["golden_box"]=true`. Result'ta `GoldenBoxButton` (yalnız `golden_box` ise ve `can_offer`): reklam başarılıysa `SaveService.grant(balance.game.golden_box_gold (varsayılan 150), balance.game.golden_box_scrap (varsayılan 10))`, düğme gizlenir. `restart()` kutuyu yeniden açar.

### 5.6 Cila sözleşmesi (Faz 6; `tools/polish_probe.gd` denetler): Şok Jeli, ses, ayarlar, rehber

**Şok Emici Jel (MVP modülü):** `data/upgrades.json`'a kategori `shock_gel` eklenir: `{"max_level": 1, "levels": [{"cost": {"gold": 400, "scrap": 20}, "mods": {"jelly_charges": 1}}]}`.
`GameController` başlangıçta `mods.jelly_charges`'ı (float → tamsayı, GOTCHAS #20) `CargoHealth.new(profile, jelly_charges)`'a verir; `state()` yeni anahtar `jelly_left` (int). Garage'da `UpgradeButton_shock_gel` ve `TryButton_shock_gel` (diğer kategorilerle aynı mantık, kategori listesi `upgrades.json`'dan dinamik).
Davranış (core'da hazır): kargoyu ilk KIRACAK vuruş jel tarafından emilir (hasar 0.95, kırık değil, `jelly_left` 1→0); sonraki kırıcı vuruş kırar (revive teklifi vb. normal akış).

**Ses:** `AudioService`'e `func play_count(sound_name: String) -> int` (başarıyla "çalınan" her `play` için artar; headless'ta sesli çalma yok ama SAYAÇ artar), `func set_muted(muted: bool)`, `func is_muted() -> bool` (muted iken `play` hiçbir şey yapmaz ve sayaç ARTMAZ).
`data/sounds.json` anahtarları ve gerçek `assets/audio/sfx/<ad>.wav` dosyaları: `ui_tap`, `success` (var) + `impact_light`, `impact_heavy`, `key_press`, `delivery`, `break_sound`, `purchase`, `revive`, `boost`. Dosyalar `tools/make_sfx.py --offline` ile (YEDEK SENTEZ; ücretli ElevenLabs API'si ÇAĞRILMAZ) `data/sfx_recipes.json` tariflerinden üretilir.
Olay → ses: `cargo.impact_reported(impulse)`: impulse ≥ `balance.audio.heavy_impulse` (varsayılan 8.0) → `impact_heavy`, ≥ `balance.audio.light_impulse` (varsayılan 2.0) → `impact_light`; klavye tuşu basma başlangıcı (`KeyboardKey` yeni sinyal `pressed()`) → `key_press`; teslimat başarılı → `delivery`; kırılma → `break_sound`; `SaveService.purchase` başarılı → `purchase`; revive başarılı → `revive`; hızlı şarj başarılı → `boost`; her `Button.pressed` (Menu/OrderSelect/Garage/Result/Settings) → `ui_tap` (`scripts/ui/ui_sfx.gd` yardımcı sınıfı ile bağlanır, kodu tek yerde tut).
Sıklık sınırı: aynı ses 80 ms içinde iki kez çalınmaz (çarpma sinyali sağanağı); `balance.audio.min_gap_ms`.

**Ayarlar:** `ProfileData` (core) `settings` kazanır: `func settings() -> Dictionary` (KOPYA; varsayılan `{"sound_on": true, "tutorial_done": false}`), `func set_setting(key: String, value: bool) -> void` (yalnız bilinen anahtarlar), `to_dict/from_dict` içinde `"settings"` (tolerans kuralları aynı; eksik anahtar varsayılan). `SaveService.setting(key: String) -> bool` ve `set_setting(key: String, value: bool)` (kaydeder); açılışta `AudioService.set_muted(not sound_on)`.
`scenes/Settings.tscn`: `SoundToggle` (CheckButton, `button_pressed = sound_on`; değişince `set_setting("sound_on", ...)` + `AudioService.set_muted`), `BackButton`. `Menu.tscn`'e `SettingsButton` (→ `GameManager` sahne anahtarı `settings`).
**Rehber:** `Menu.tscn` `TutorialPanel` (yalnız `tutorial_done == false` iken görünür), 3 sayfa: `TutorialNextButton` ilerletir, son sayfada basınca panel kapanır ve `tutorial_done = true` kaydedilir; `TutorialSkipButton` da kapatır ve işaretler. Metinler `scripts/ui/strings.gd`'de (kısa: sürüş, kargo sallanması/hasar, garaj).

## 6. UI

`HUD` (kargo sağlığı çubuğu, batarya, modül düğmesi), `OrderSelect` (3 kargo kartı), `Garage` (Faz 4), `Result` (mevcut genişletilir). Sunum katmanı yalnızca gösterir; hesap `core`'dadır.

## 7. Test stratejisi

| Katman | Yöntem |
|---|---|
| `core` | Birim test (`tests/unit/`), sınır değerleri, **önce test** |
| Veri | `data/*.json` şema testi (zorunlu anahtarlar, aralıklar) |
| Sahne bütünlüğü | `orchestra/tools/tscn_lint.py` (kabul denetimi içinde) |
| Fizik | `tools/game_probe.gd`: robotu sabit girdiyle sürer, kargo sallanma genliği/hasar eğrisini sayılara döker (regresyon için) |
| His | `shots.sh` + **oyuncu denemesi** (otomatik değil) |
