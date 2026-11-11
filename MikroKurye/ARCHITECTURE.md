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
func _init(capacity: float = 100.0) -> void
func level() -> float             # 0..1
func drain(amount: float) -> void # >= 0 harcar, 0'ın altına inmez
func drain_for_speed(speed: float, dt: float) -> void  # speed^2 orantılı küçük sabit tüketim (katsayı data/balance.json battery.speed_drain)
func recharge(amount: float) -> void  # kapasiteyi aşmaz
func refill_full() -> void
func is_empty() -> bool
func speed_factor() -> float      # dolu: 1.0; boş: battery.empty_speed_factor (varsayılan 0.35); aralıkta doğrusal
func start_boost(seconds: float) -> void
func boost_active() -> bool
func tick(dt: float) -> void      # boost süresini azaltır; boost sırasında speed_factor() = 1.25
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
static func from_dict(d: Dictionary) -> Wallet     # eksik/yanlış tip/negatif -> 0
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
