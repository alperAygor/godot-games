extends Node3D
## NEON ARENA 3D — ince orkestratör: sahneyi kurar, modülleri bağlar ve KARE SIRASINI tek yerde yönetir.
##
## Oynanış scripts/game/ altındaki modüllerde (bkz. docs/ARCHITECTURE.md):
##   RunFlow (durum makinesi, başlat/ölüm/harita) · PlayerControl (girdi, gemi adımı, otomatik nişan) · Autopilot (bot)
##   CombatSystem (çarpışma, hasar, nova, ölüm ödülü) · WeaponSystem (silahlar, roket, dron) · Spawner (doğma, tempo)
##   BossEvents (boss saldırıları, tehlikeler, ışınlar) · CardsFlow (seviye kartları) · CameraRig · Feedback (juice)
##   HudBridge (HUD/dokunmatik durum). Paylaşılan durum: GameContext (`ctx`); olaylar: GameEvents (`events`).
## Kare sırası rastgele akışın sırasını belirler: değiştirmek tohumlu koşuları (scene_probe trace_md5) değiştirir.

const PlayerScript = preload("res://scripts/entities3d/player3d.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const MenusScript = preload("res://scripts/ui/menus.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")
const SparksScript = preload("res://scripts/world/sparks.gd")
const BulletFieldScript = preload("res://scripts/world/bullet_field.gd")
const RunStateScript = preload("res://scripts/core/run_state.gd")
const LoadoutScript = preload("res://scripts/core/loadout.gd")

const ARENA := GameContext.ARENA

var ctx := GameContext.new()
## Koşu tohumu: 0 = rastgele (oyuncu). `--seed=N` ya da sahneye eklenmeden önce `run_seed = N` (bayrak önceliklidir).
## Aynı tohum + `--fixed-fps` ile gerçek sahnedeki bot koşusu kare kare belirlenimli olur (bkz. tools/sim/scene_probe.gd).
var run_seed := 0

# --- Dış arayüz (tools/dev probeları, smoke_test, scene_probe ve sonraki görevler bunları kullanır) -------------
var events: GameEvents:
	get: return ctx.events
var run: RunState:
	get: return ctx.run
var loadout: Loadout:
	get: return ctx.loadout
var player: PlayerScript:
	get: return ctx.player
var boss: Boss3D:
	get: return ctx.boss
var field: BulletFieldScript:
	get: return ctx.field
var hud: HudScript:
	get: return ctx.hud
var menus: MenusScript:
	get: return ctx.menus
var touch: TouchScript:
	get: return ctx.touch
var world: MapBuilder:
	get: return ctx.world
var enemies: Array:
	get: return ctx.enemies
var pickups: Array:
	get: return ctx.pickups
var drones: Array:
	get: return ctx.drones
var state: String:
	get: return ctx.state
var nova: float:
	get: return ctx.nova
	set(v): ctx.nova = v
var rerolls: int:
	get: return ctx.rerolls
var NOVA_MAX: float:
	get: return ctx.tuning.nova_max
var _cores_earned: int:
	get: return ctx.flow.cores_earned
var _aftershocks: Array:
	get: return ctx.aftershocks

func _start_game() -> void:
	ctx.flow.start_game()

func _apply_loadout() -> void:
	ctx.control.apply_loadout()

func _heal(amount: float, show := true) -> void:
	ctx.combat.heal(amount, show)

func _hit_enemy(e, b) -> void:
	ctx.combat.hit_enemy(e, b)

func _resolve_collisions() -> void:
	ctx.combat.resolve_collisions()

func _spawn_enemy(kind: String, at: Vector2, delay := 0.5, allow_elite := true) -> void:
	ctx.spawner.spawn_enemy(kind, at, delay, allow_elite)

func _try_nova() -> void:
	ctx.combat.try_nova()

# --- Kurulum --------------------------------------------------------------------
func _ready() -> void:
	ctx.host = self
	ctx.options.parse(OS.get_cmdline_user_args())
	if ctx.options.run_seed == 0:
		ctx.options.run_seed = run_seed
	run_seed = ctx.options.run_seed
	ctx.tuning = GameData.tuning
	_make_modules()
	if run_seed != 0:
		seed(run_seed)
		ctx.cards.rng.seed = run_seed
	else:
		randomize()
		ctx.cards.rng.randomize()
	_build_scene()
	ctx.run = RunStateScript.new(GameData.balance, run_seed)
	ctx.run.wave_started.connect(ctx.spawner.on_wave_started)
	ctx.run.spawn_due.connect(ctx.spawner.on_spawn_due)
	ctx.run.boss_due.connect(ctx.bosses.on_boss_due)
	ctx.run.wave_cleared.connect(ctx.flow.on_wave_cleared)
	ctx.run.map_cleared.connect(ctx.flow.on_map_cleared)
	ctx.run.map_changed.connect(ctx.flow.on_map_changed)
	ctx.run.level_up.connect(ctx.cards.on_level_up)
	ctx.loadout = LoadoutScript.new(GameData.cards)
	ctx.flow.build_map(0)
	ctx.flow.apply_quality()
	if ctx.options.demo:
		ctx.flow.start_game()
	else:
		ctx.flow.enter_menu()
		if ctx.options.debug_screen == "settings" or ctx.options.debug_screen == "howto":
			ctx.menus.open_sub(ctx.options.debug_screen, "main")

func _make_modules() -> void:
	ctx.flow = _module(RunFlow.new(), "RunFlow")
	ctx.control = _module(PlayerControl.new(), "PlayerControl")
	ctx.autopilot = _module(Autopilot.new(), "Autopilot")
	ctx.combat = _module(CombatSystem.new(), "Combat")
	ctx.weapons = _module(WeaponSystem.new(), "Weapons")
	ctx.spawner = _module(Spawner.new(), "Spawner")
	ctx.bosses = _module(BossEvents.new(), "BossEvents")
	ctx.cards = _module(CardsFlow.new(), "CardsFlow")
	ctx.effects = _module(CardEffects.new(), "CardEffects")
	ctx.hooks = _module(MonetizationHooks.new(), "MonetizationHooks")
	ctx.feedback = _module(Feedback.new(), "Feedback")
	ctx.camera = _module(CameraRig.new(), "CameraRig")
	ctx.hud_bridge = _module(HudBridge.new(), "HudBridge")

func _module(m: GameModule, node_name: String) -> GameModule:
	m.name = node_name
	m.setup(ctx)
	add_child(m)
	return m

func _build_scene() -> void:
	## Düğüm sırası korunur (işleme sırası = rastgele akış sırası): efektler, mermiler, varlıklar, oyuncu,
	## kamera + nişan halkası, vinyet katmanı, HUD katmanı (HUD, dokunmatik, menüler). Harita build_map ile eklenir.
	ctx.sparks = SparksScript.new()
	add_child(ctx.sparks)
	ctx.field = BulletFieldScript.new()
	add_child(ctx.field)
	ctx.entities = Node3D.new()
	add_child(ctx.entities)
	var p: PlayerScript = PlayerScript.new()
	p.bounds = ARENA
	add_child(p)
	ctx.player = p
	p.shot.connect(ctx.weapons.on_player_shot)
	p.dashed_at.connect(ctx.feedback.on_player_dash)
	p.hurt.connect(ctx.combat.on_player_hurt)
	p.shield_broken.connect(ctx.feedback.on_shield_broken)
	p.dashed_at.connect(ctx.effects.on_dash)
	p.shield_broken.connect(ctx.effects.on_shield_broken)
	ctx.camera.build(self)
	ctx.feedback.build(self)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	ctx.hud = HudScript.new()
	ctx.hud.camera = ctx.camera.camera
	hud_layer.add_child(ctx.hud)
	ctx.touch = TouchScript.new()
	hud_layer.add_child(ctx.touch)
	ctx.touch.set_enabled(false)
	ctx.touch.pause_pressed.connect(ctx.hooks.on_pause_requested)
	var m: MenusScript = MenusScript.new()
	ctx.menus = m
	hud_layer.add_child(m)
	# Menü eylemleri reklam akışından (MonetizationHooks) geçer: reklam sürerken yok sayılır; TEKRAR OYNA / ANA MENÜ
	# koşu sonunda önce geçiş reklamı kararını verir (reklam yoksa doğrudan RunFlow'a düşer).
	m.play_pressed.connect(ctx.hooks.on_play)
	m.resume_pressed.connect(ctx.hooks.on_resume)
	m.restart_pressed.connect(ctx.hooks.on_restart)
	m.menu_pressed.connect(ctx.hooks.on_menu)
	m.pause_requested.connect(ctx.hooks.on_pause_requested)
	m.card_picked.connect(ctx.hooks.on_card_picked)
	m.reroll_pressed.connect(ctx.hooks.on_reroll)
	m.quality_changed.connect(ctx.flow.apply_quality)
	m.ship_preview.connect(func(id: String): ctx.player.set_ship(Settings.meta.ship_def(id)))
	ctx.hooks.build(self)
	ctx.effects.build(self)

# --- Kare -------------------------------------------------------------------------
func _process(delta: float) -> void:
	ctx.elapsed += delta
	Fx.tick(delta)
	ctx.hud_bridge.update_layout()
	if Input.is_action_just_pressed("mute"):
		Sound.toggle_mute()
	if ctx.state == "menu":
		ctx.control.idle(delta)
	elif ctx.state == "playing":
		if ctx.cards.tick_pending():
			return
		ctx.flow.tick_debug_die()
		_tick_game(delta)
	elif ctx.state == "dead":
		ctx.flow.tick_dead(delta)
	ctx.feedback.render_frame(delta)
	ctx.camera.update(delta)
	ctx.hud_bridge.update()

func _tick_game(delta: float) -> void:
	## Oyun adımı. Sıra önemlidir (bkz. dosya başı).
	ctx.run.step(delta)
	ctx.spawner.tick_pacing(delta)
	ctx.flow.tick_hint(delta)
	ctx.control.tick(delta)
	ctx.spawner.tick_enemies(delta)
	ctx.bosses.tick(delta)
	ctx.bosses.tick_hazards(delta)
	ctx.combat.tick_aftershocks(delta)
	ctx.bosses.tick_beams()
	ctx.weapons.steer_rockets(delta)
	ctx.field.tick(delta)
	ctx.spawner.tick_pickups(delta)
	ctx.weapons.tick_drones(delta)
	ctx.effects.tick(delta)
	ctx.spawner.separate_enemies()
	ctx.combat.resolve_collisions()
	ctx.feedback.tick_low_hp(delta)
	if not ctx.player.alive and ctx.state == "playing":
		ctx.flow.on_player_died()
