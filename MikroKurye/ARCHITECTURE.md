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

`data/upgrades.json` — kategori → seviyeler (Faz 4):

```json
{ "chassis": { "max_level": 5, "levels": [ { "cost": {"gold": 100, "scrap": 5}, "mods": {"sway_damping": 0.08} } ] },
  "wheels":  { "max_level": 5, "levels": [] },
  "battery": { "max_level": 5, "levels": [ { "cost": {"gold": 80, "scrap": 3}, "mods": {"battery_capacity": 15.0} } ] } }
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
