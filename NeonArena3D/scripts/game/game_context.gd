extends RefCounted
class_name GameContext
## Bir oyun sahnesinin paylaşılan durumu: sahne düğümleri, koşu mantığı, varlık listeleri ve modüller.
##
## Modüller (scripts/game/*.gd) birbirini ve durumu yalnız buradan görür; `game3d.gd` bunu kurar ve kare sırasını
## yönetir. Varlık listeleri (enemies, pickups…) yerinde değiştirilir: dışarıdan alınan başvuru hep günceldir.
## Sahiplik: alanı kim YAZAR → yorumda. Okumak herkese serbest.

const PlayerScript = preload("res://scripts/entities3d/player3d.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const MenusScript = preload("res://scripts/ui/menus.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")
const SparksScript = preload("res://scripts/world/sparks.gd")
const BulletFieldScript = preload("res://scripts/world/bullet_field.gd")

## Oyun alanı (düzlem pikselleri). Kamera, sınır, doğma noktaları buna göre.
const ARENA := Rect2(40.0, 40.0, 2560.0, 1600.0)

var host: Node3D                    ## game3d düğümü: add_child / create_tween / get_tree / get_viewport
var events := GameEvents.new()      ## dinlenebilir oyun olayları (reklam/görev/juice kancaları)
var options := LaunchOptions.new()  ## komut satırı / araç bayrakları
var tuning: GameTuning              ## combat.json sabitleri (GameData.tuning)

# Koşu mantığı (saf, testli çekirdek)
var run: RunState
var loadout: Loadout

# Sahne düğümleri (game3d kurar)
var hud: HudScript
var menus: MenusScript
var touch: TouchScript
var world: MapBuilder               ## RunFlow.build_map yazar
var sparks: SparksScript
var field: BulletFieldScript
var player: PlayerScript
var entities: Node3D
var boss: Boss3D                    ## BossEvents yazar

# Varlıklar
var enemies: Array = []             ## Spawner ekler, Spawner/RunFlow çıkarır
var pickups: Array = []
var drones: Array = []              ## WeaponSystem
var obstacles: Array[Dictionary] = []
var hazards: Array = []             ## BossEvents
var aftershocks: Array = []         ## CombatSystem

# Koşu değerleri
var state := "menu"                 ## "menu" | "playing" | "dead" — RunFlow yazar
var map_index := 0
var elapsed := 0.0
var nova := 0.0
var rerolls := 2
var weapon: Dictionary = {}

# Modüller
var flow: RunFlow
var control: PlayerControl
var autopilot: Autopilot
var combat: CombatSystem
var weapons: WeaponSystem
var spawner: Spawner
var bosses: BossEvents
var cards: CardsFlow
var effects: CardEffects            ## C3 kart etkileri + kart ekranı eklentileri (yasaklama, evrim ipucu)
var feedback: Feedback
var camera: CameraRig
var hud_bridge: HudBridge
var hooks: MonetizationHooks        ## reklam akışı (C8): teklifler, duraklatma, geçiş; olayları dinler
