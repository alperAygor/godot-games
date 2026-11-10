# ARCHITECTURE — Çanta Fiziği

Doküman durumu: **v0.1.0 / iskelet**. Bu belge hedef mimariyi tanımlar; dosyalar Faz 1–2'de oluşturulacaktır.
Bugün repoda var olan: `scenes/`, `scripts/autoload/`, `assets/models/`, `assets/audio/` (boş, `.gitkeep` ile).

---

## 1. Katmanlar

```
┌───────────────────────────────────────────────────────┐
│  UI (Control / CanvasLayer)   — sunum, giriş         │
├───────────────────────────────────────────────────────┤
│  Gameplay (Node3D + fizik)    — dünya, çanta, araç   │
├───────────────────────────────────────────────────────┤
│  Autoload servisleri          — akış, ses, reklam    │
├───────────────────────────────────────────────────────┤
│  Core (RefCounted/Resource)   — saf mantık, testli   │
├───────────────────────────────────────────────────────┤
│  Services (AdsProvider)       — dış SDK sınırı       │
└───────────────────────────────────────────────────────┘
```

Bağımlılık yönü **yukarıdan aşağıya**. `core` hiçbir katmanı tanımaz; bu sayede headless test edilebilir.

---

## 2. Autoload'lar

`project.godot` içindeki sıra **anlamlıdır** ve değiştirilmez:

```ini
[autoload]
GameManager="*res://scripts/autoload/GameManager.gd"
AudioService="*res://scripts/autoload/AudioService.gd"
AdManager="*res://scripts/autoload/AdManager.gd"
```

Sıra gerekçesi: `GameManager._ready()` kaydı yüklerken `AudioService`'e ses çaldırabilir; `AdManager` reklam SDK'sını `GameManager`'ın onay/ilk açılış durumuna göre başlatır.

### 2.1 `GameManager` — oyun akışının tek sahibi

Sorumluluklar: durum makinesi, sahne yönlendirme, kayıt (save/load), para & itibar, tur sonucu.

```gdscript
extends Node

enum Phase { BOOT, MENU, PACKING, DRIVING, RESULT, PAUSED }

signal phase_changed(from: Phase, to: Phase)
signal run_started(order: OrderData)
signal run_finished(result: RunResult)
signal currency_changed(amount: int)
signal reputation_changed(stars: int)

var phase: Phase = Phase.BOOT
var run: RunState = null          # aktif tur; menüde null
var profile: PlayerProfile = null
```

| API | Açıklama |
|---|---|
| `start_run(order: OrderData) -> void` | Turu kurar, `Phase.PACKING`'e geçer |
| `begin_driving() -> void` | Paketleme bitti, fizik kilidi açılır |
| `finish_run(result: RunResult) -> void` | Puanlar, parayı işler, kaydeder, `Phase.RESULT` |
| `abandon_run() -> void` | Turu iptal eder, ceza yok |
| `goto_scene(path: String) -> void` | Sahne geçişi (tek yol) |
| `save() -> void` / `load() -> void` | `user://profile.save` |
| `add_currency(amount: int) -> void` | Tek para girişi; sinyal yayar |

Kurallar:
- Durum geçişi **yalnızca** `_set_phase()` üzerinden; dışarıdan doğrudan `phase` atanmaz.
- `Phase.PACKING` dışında paket sürüklenemez.
- `goto_scene` `SceneHost` altındaki çocuğu değiştirir; `change_scene_to_file` kullanılmaz, böylece UI katmanı ve fade korunur.
- Kayıt **atomik**: `user://profile.save.tmp` → `DirAccess.rename`.

### 2.2 `AudioService` — tek ses girişi

Bus'lar: `Master` → `Music`, `SFX`, `UI`. (Bus layout: `assets/audio/default_bus_layout.tres`)

```gdscript
extends Node

enum Bus { MUSIC, SFX, UI }

func play_music(stream: AudioStream, fade_time: float = 0.6) -> void
func stop_music(fade_time: float = 0.6) -> void
func play_sfx(stream: AudioStream, bus: Bus = Bus.SFX, pitch_variance: float = 0.08) -> void
func play_ui(stream: AudioStream) -> void
func set_bus_volume(bus: Bus, linear: float) -> void   # 0.0–1.0, ayarlardan gelir
func set_haptics_enabled(enabled: bool) -> void
```

- SFX havuzu: 8 adet `AudioStreamPlayer` (döngüsel). Aynı anda 8'den fazla ses çalmaz → mobilde kesme yok.
- `pitch_variance` aynı sesin tekrarını maskeler.
- Headless modda (`DisplayServer.get_name() == "headless"`) ses çalınamaz → tüm fonksiyonlar sessizce döner. Testlerde kırılmaz.
- Müzik geçişi `Tween` ile; kesme (pop) yasak.

### 2.3 `AdManager` — ödüllü reklam orkestrasyonu

SDK'yı **bilmez**; `AdsProvider` arayüzüyle konuşur (`scripts/services/ads_provider.gd`).

```gdscript
extends Node

enum Placement { EXTRA_POCKET, TAPE_RESCUE, DOUBLE_REWARD, FREE_UPGRADE }

signal rewarded_finished(placement: Placement, success: bool)
signal ad_failed(placement: Placement, reason: String)

var provider: AdsProvider = null   # varsayılan: MockAdsProvider / NoAdsProvider

func is_ready(placement: Placement) -> bool
func show_rewarded(placement: Placement) -> void
func can_offer(placement: Placement) -> bool     # limit + cooldown + hazırlık
func reset_run_limits() -> void                  # her tur başında
```

Akış:

```
can_offer? ──hayır──► butonu gizle / pasif göster (hata yok)
   │evet
   ▼
show_rewarded ──► provider.show(...) ──► SDK callback
   │                                        │
   │◄──── rewarded_finished(placement, true)┘  (ödül verilir, idempotent)
   │◄──── rewarded_finished(placement, false)─  (kullanıcı kapattı: sessiz)
   │◄──── ad_failed(placement, reason)────────  (yükleme hatası: sessiz geç)
```

Kurallar:
- Ödül veren taraf **her zaman** `rewarded_finished`'i dinler; reklam çağrısı ödülü doğrudan vermez.
- Aynı `placement` için eşzamanlı ikinci istek reddedilir (`_pending: Placement`).
- Süreç geri planda öldürülürse ödül verilmez; tur zaten kaybedilmiş sayılır (kayıp kabul edilebilir, hile değil).
- Limitler `data/ads.json`: `{"EXTRA_POCKET": {"per_run": 1, "per_session": 3}, ...}`.
- **Gerçek SDK yok.** Geliştirme `MockAdsProvider` (1.5 sn bekleyip başarı döner), test `NoAdsProvider` kullanır. AdMob eklentisi Faz 6'da `AdMobProvider` olarak eklenir; başka hiçbir kod değişmez.

### 2.4 Servis sınırı — `AdsProvider`

```gdscript
class_name AdsProvider
extends RefCounted

signal shown()
signal rewarded()
signal dismissed()
signal failed(reason: String)

func initialize() -> void: pass
func is_ready(placement: StringName) -> bool: return false
func show(placement: StringName) -> void: pass
```

Reklam SDK'sı ile ilgili **tek** dosya buranın altındadır. `AdManager` dışında hiçbir script `AdsProvider`'ı import etmez.

---

## 3. Sahne ağacı

### 3.1 Kök sahne: `scenes/main.tscn` (`run/main_scene`)

```
Main (Node)                       scripts/main.gd
├── SceneHost (Node)              ← GameManager.goto_scene() buraya bağlar
├── UILayer (CanvasLayer)         layer = 10
│   ├── Fade (ColorRect)          tam ekran, siyah, mouse_filter = IGNORE
│   ├── SafeArea (MarginContainer) scripts/ui/safe_area.gd
│   ├── HUD (Control)             oyun sırasında görünür
│   └── Popups (Control)          modal pencereler, en üstte
└── Debug (Node)                  yalnızca debug build
```

`SceneHost` altında zamanla **tek** sahne bulunur. UI katmanı sahneden bağımsız olduğu için geçişte HUD yanıp sönmez.

> Not: `GameManager` autoload olarak `/root` altında yaşar; `Main`'in çocuğu değildir.

> **v0.2.0'da kurulan (bu belgedeki hedeften erken sapmalar):** `scenes/Main.tscn` + `scenes/BackpackGrid.tscn`.
> `Main` içinde `WorldEnvironment`, `Sun`/`KeyFill`/`BagFill`/`Rim` ışıkları, `Camera3D`, `Table`,
> `BackpackGrid`, `Packages` ve iki `CanvasLayer` var: `Grade` (renk düzeltme `ColorRect`'i, layer 1) ve
> `UI` (layer 2, renk düzeltmesinden etkilenmez). `SceneHost`/`Fade` autoload'larla birlikte (Faz 1 kalanı) gelecek.
> `GridController` paketleri `draggable` grubundan bulur — nerede durduklarını bilmez, bu yüzden sahne yeniden düzenlense de çalışır.

### 3.2 `scenes/boot.tscn`

```
Boot (Control)                    scripts/ui/boot.gd
└── Logo (TextureRect)
```
Görev: `GameManager.load()`, `AudioService` bus ayarları, `AdManager` ilk yükleme. Sonra `goto_scene("res://scenes/menu.tscn")`. Minimum 0.4 sn gösterilir (flash önlemi).

### 3.3 `scenes/menu.tscn`

```
Menu (Control)
├── Background (TextureRect / Node3D önizleme)
├── SafeArea (MarginContainer)
│   └── VBox
│       ├── Title
│       ├── PlayButton
│       ├── UpgradeButton
│       └── SettingsButton
└── PopupRoot (Control)
```

### 3.4 `scenes/gameplay.tscn` — asıl sahne

```
Gameplay (Node3D)                        scripts/gameplay/gameplay.gd
├── Environment (Node3D)
│   ├── WorldEnvironment                 (gl_compatibility uyumlu ayarlar)
│   ├── Sun (DirectionalLight3D)
│   └── Sky (Sky)
├── Road (Node3D)                        scripts/gameplay/road.gd
│   ├── Segment_00 (road_segment_*.tscn)  → runtime'da sırayla eklenir
│   ├── Segment_01
│   └── Bumps (Node3D)                    tümsek çarpıştırıcıları
├── Truck (Node3D)                       scripts/gameplay/truck.gd
│   ├── Body (MeshInstance3D)
│   ├── Wheels (Node3D)
│   └── BagMount (Node3D)                ← süspansiyon burada
│       └── Bag (Node3D)                 scripts/gameplay/bag.gd
│           ├── InnerWalls (StaticBody3D)  ayrı CollisionShape3D'ler
│           │   ├── Floor / WallLeft / WallRight / WallFront / WallBack
│           ├── Pocket (Node3D)          [opsiyonel, reklam ödülü]
│           ├── PackageSlot (Node3D)     paketlerin ebeveyni
│           └── DamageIndicator (Node3D)
├── Camera (Camera3D)                    scripts/gameplay/camera_rig.gd
│   └── (sarsıntı hedefin kendisine uygulanır)
└── HUD (CanvasLayer = 10)
    └── SafeArea
        ├── DamageBar
        ├── Inclinometer
        ├── Speedometer
        └── AdButtons (ExtraPocketButton, TapeRescueButton)
```

Sahne yükleme sırası ve sahiplik:

| Düğüm | Sahibi (script) | Sorumluluk |
|---|---|---|
| `Gameplay` | `gameplay.gd` | Tur kurulumu, `GameManager` ile köprü |
| `Road` | `road.gd` | Segment havuzu, hız, tümsek üretimi |
| `Truck` | `truck.gd` | İleri hareket, fren, şerit |
| `Bag` | `bag.gd` | Paket listesi, hasar toplama, cep yönetimi |
| `Package` | `package.gd` | `RigidBody3D`, impuls takibi, kırılma |
| `Camera` | `camera_rig.gd` | Takip + sönümlü sarsıntı |
| `HUD` | `hud.gd` | Sadece gösterim; `bag`/`GameManager` sinyallerini dinler |

### 3.5 `scenes/result.tscn`

```
Result (Control)
├── StarsRow (HBoxContainer)
├── PackageReport (VBoxContainer)   paket bazında hasar
├── RewardLabel
├── DoubleRewardButton              → AdManager.Placement.DOUBLE_REWARD
├── RetryButton
└── NextButton
```

---

## 4. Sinyal akışı (tur içi)

```
Package.impacted(package, impulse)
        │
        ▼
Bag._on_package_impacted → DamageModel.apply(...)   [core, saf]
        │
        ├─► bag.damage_changed(total_ratio) ──► HUD (bar)
        └─► bag.package_broken(pkg) ─────────► Gameplay → AdManager.can_offer(TAPE_RESCUE)
                                                   │
                                                   └─► HUD teklif butonu

Gameplay.finished(result) ──► GameManager.finish_run(result)
                                   ├─► currency_changed → Menu/HUD
                                   └─► session fazı RESULT → result.tscn
```

Kural: UI **sadece dinler**. UI'dan gelen tek yönlü çağrılar niyettir (`bag.request_pack(pkg)`), durum değişikliği core'da olur.

---

## 5. Dizin ve dosya planı

```
CantaFizigi/
├── project.godot
├── scenes/
│   ├── main.tscn, boot.tscn, menu.tscn, gameplay.tscn, result.tscn
│   ├── road/road_segment_*.tscn
│   └── ui/package_card.tscn, damage_popup.tscn, settings_popup.tscn
├── scripts/
│   ├── autoload/  GameManager.gd  AudioService.gd  AdManager.gd
│   ├── core/      damage_model.gd  scoring.gd  run_state.gd  player_profile.gd
│   │              package_data.gd  order_data.gd  economy.gd
│   ├── gameplay/  gameplay.gd  bag.gd  package.gd  truck.gd  road.gd  camera_rig.gd
│   ├── ui/        hud.gd  menu.gd  result_screen.gd  boot.gd  safe_area.gd
│   └── services/  ads_provider.gd  mock_ads_provider.gd  no_ads_provider.gd
├── assets/
│   ├── models/    bag_01.glb  package_standard.glb  package_fragile.glb  truck_01.glb
│   ├── audio/     default_bus_layout.tres  music/  sfx/
│   ├── theme/     main_theme.tres
│   └── translations/ strings.csv
├── data/          packages.json  ads.json  balance.json  upgrades.json
├── tests/         test_case.gd  run_tests.gd  unit/test_damage_model.gd ...
└── tools/         verify.sh  screenshot.gd
```

**İsimlendirme:** script ve sahne dosyaları `snake_case`, `class_name` `PascalCase`, düğüm adları `PascalCase` (`Bag`, `Truck`), paket düğümleri `Package_<id>`.

---

## 6. Fizik katmanları ve çarpışma matrisi

| Bit | Ad | Kullanan |
|---|---|---|
| 1 | `world` | Yol, zemin, binalar |
| 2 | `bag_walls` | Çanta iç duvarları |
| 3 | `packages` | Paketler (birbirleriyle çarpışır) |
| 4 | `truck` | Araç gövdesi |
| 5 | `pockets` | Cep duvarları (paket kabul eder, dışarı sızdırmaz) |
| 6 | `triggers` | Alan tetikleyicileri (teslimat noktası, hız bölgesi) |

| | world | bag_walls | packages | truck | pockets | triggers |
|---|---|---|---|---|---|---|
| **packages** | ✔ | ✔ | ✔ | ✔ | ✔ | ✘ |
| **truck** | ✔ | ✘ | ✔ | ✘ | ✘ | ✔ |
| **player ray** | ✔ | ✔ | ✔ | ✘ | ✘ | ✘ |

Paket–paket çarpışmasını kapatmak "paketler birbirini kırmasın" derdi için çözüm **değildir**; oyunun kalbi orada. Performans için paket sayısı ve `sleep` kullanılır.

---

## 7. Veri odaklı yapı

Tüm sayısal denge `data/*.json` içinde; kodda yalnızca `const` varsayılan.

| Dosya | İçerik |
|---|---|
| `packages.json` | Paket tipleri, kütle/boyut/sürtünme/kırılma eşiği/ücret çarpanı |
| `balance.json` | Hız, tümsek etkisi, hasar katsayıları, yıldız eşikleri |
| `ads.json` | Yerleşim limitleri, cooldown, mock süresi |
| `upgrades.json` | Yükseltme seviyeleri ve fiyatları |

`GameData` autoload'u Faz 3'te eklenecek (dosyaları `res://data/`'dan yükler, eksikse hata verir). Bu dosyalar export'a **dahil edilir** (`*.json` filtresi).

---

## 8. Kayıt formatı (`user://profile.save`)

```json
{
  "version": 1,
  "currency": 1250,
  "reputation": 4,
  "upgrades": { "bag_capacity": 2, "suspension": 1, "tape": 1 },
  "stats": { "deliveries": 42, "perfect": 11, "ads_watched": 7 },
  "settings": { "music": 0.7, "sfx": 1.0, "haptics": true, "camera_shake": true }
}
```

- `version` artırılmadan şema değişmez. Değişirse `PlayerProfile._migrate(from: int)` yazılır.
- Bozuk dosya → yedek alınır (`profile.save.bak`), yeni profil başlatılır, oyuncuya tek seferlik bilgi verilir.
- Kayıt yalnızca `GameManager.save()` ile yazılır (tek yazar ilkesi).

---

## 9. Performans bütçesi (orta segment Android)

| Metrik | Bütçe |
|---|---|
| FPS | 60 (min 45) |
| Aktif `RigidBody3D` | ≤ 16 (12 paket + araç) |
| Draw call | ≤ 120 |
| Toplam tris | ≤ 60k |
| Texture bellek | ≤ 120 MB |
| Sahne yükleme | ≤ 1.2 sn |
| `_process` içinde `get_node` | 0 (yollar cache'lenir) |

`gl_compatibility` kısıtları: gelişmiş post-process yok; `SSAO`, `SSR`, `Volumetric Fog` **kullanılmaz**. Gölge: tek `DirectionalLight3D`, 1024 px, yalnızca araç+çanta.

---

## 10. Test stratejisi

```
tests/
├── test_case.gd        assert_true/false/eq/almost_eq, before_each/after_each
├── run_tests.gd        → 0 geçti, 1 başarısız, 2 yüklenemedi
└── unit/
    ├── test_damage_model.gd     impuls → hasar eşlemesi
    ├── test_scoring.gd          hasar → yıldız/ücret
    ├── test_player_profile.gd   save/load/migrate
    └── test_ad_limits.gd        yerleşim limitleri, idempotent ödül
```

Fizik testleri **deterministik tohum** ile; gerçek görsel doğrulama `tools/screenshot.gd` ile (headless ekran görüntüsü üretmez, pencere açar).

Çalıştırma:
```bash
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . --import
```

---

## 11. Genişleme noktaları (bilinçli hazırlanan)

| İhtiyaç | Nerede eklenir | Dokunulmayacak |
|---|---|---|
| Gerçek AdMob | `scripts/services/admob_provider.gd` | `AdManager`, HUD |
| IAP | `scripts/services/iap_provider.gd` + `GameManager.purchase()` | gameplay |
| Yeni paket tipi | `data/packages.json` + model | `package.gd` çekirdeği |
| Yeni yol segmenti | `scenes/road/*.tscn` + `data/roads.json` | `road.gd` |
| iOS | export preset + `AdsProvider` iOS implementasyonu | oyun kodu |

---

## 12. Karar kaydı

| # | Karar | Gerekçe | Tarih |
|---|---|---|---|
| A1 | Renderer `gl_compatibility` | Düşük segment cihaz uyumu ve emülatörde siyah ekran sorununu önlemek | 2026-11-10 |
| A2 | 3D fizik (2D değil) | Paketlerin üst üste dizilmesi ve sarsıntı okunabilirliği 3D'de çok daha güçlü; Blender hattı hazır | 2026-11-10 |
| A3 | Autoload sayısı 3 ile sınırlı | Başlangıçta küçük tutmak, bağımlılık karmaşasını önlemek; `GameData` Faz 3'te | 2026-11-10 |
| A4 | Ödül yalnızca sinyalle | Reklam SDK'sının oyun mantığına sızmasını engellemek | 2026-11-10 |
| A5 | Tek yazar kayıt (`GameManager`) | Kayıt çakışması ve bozulma riski | 2026-11-10 |
| A6 | Renk düzeltme **ekran shader'ı** ile | `adjustment_color_correction` LUT'u `gl_compatibility`'de bozuk örnekliyor (kimlik LUT bile sahneyi kırmızıya boyadı). Tam ekran `screen_texture` shader'ı taşınabilir, aynı sonucu veriyor ve `gl_compatibility`'de çalışıyor | 2026-11-10 |
| A7 | Bloom + SSAO `gl_compatibility`'de açık | Godot 4.7.2'de ikisi de çalışıyor; A/B render + determinizm kontrolü ile doğrulandı (bkz. CHANGELOG) | 2026-11-10 |
| A8 | Paketler şimdilik `Node3D` + tween | Faz 2'nin ilk dilimi görsel; fizik (`RigidBody3D`, kırılma) Faz 3'te devreye girecek | 2026-11-10 |
