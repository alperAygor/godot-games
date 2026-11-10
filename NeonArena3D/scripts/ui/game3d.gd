extends Node3D
## NEON ARENA 3D — ana döngü: koşu durumu, kartlar, boss, haritalar, çarpışmalar, kamera ve girdi.

const PlayerScript = preload("res://scripts/entities3d/player3d.gd")
const EnemyScript = preload("res://scripts/entities3d/enemy3d.gd")
const PickupScript = preload("res://scripts/entities3d/pickup3d.gd")
const BossScript = preload("res://scripts/entities3d/boss3d.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const MenusScript = preload("res://scripts/ui/menus.gd")
const TouchScript = preload("res://scripts/ui/touch_controls.gd")
const MapBuilderScript = preload("res://scripts/world/map_builder.gd")
const SparksScript = preload("res://scripts/world/sparks.gd")
const BulletFieldScript = preload("res://scripts/world/bullet_field.gd")
const RunStateScript = preload("res://scripts/core/run_state.gd")
const LoadoutScript = preload("res://scripts/core/loadout.gd")
const KIT = preload("res://scripts/ui/ui_kit.gd")

const ARENA := Rect2(40.0, 40.0, 2560.0, 1600.0)
const CAM_OFFSET := Vector3(0.0, 19.5, 13.0)
const NOVA_MAX := 100.0

var run: RunStateScript
var loadout: LoadoutScript
var hud: HudScript
var menus: MenusScript
var touch: TouchScript
var world: MapBuilderScript
var sparks: SparksScript
var field: BulletFieldScript
var player: PlayerScript
var boss: BossScript
var camera: Camera3D
var camera_rig: Node3D
var aim_marker: MeshInstance3D
var vignette_rect: ColorRect
var vignette_mat: ShaderMaterial
var entities: Node3D
var enemies: Array = []
var pickups: Array = []
var drones: Array = []
var obstacles: Array[Dictionary] = []

var state := "menu"
var map_index := 0
var demo := false
var start_wave := 1
var debug_hp := 0.0
var debug_die := 0.0
var debug_map := 0
var debug_screen := ""
var debug_nova := false
var show_cards_demo := false
var dead_timer := 0.0
var elapsed := 0.0
var nova := 0.0
var rerolls := 2
var weapon: Dictionary = {}
var debug_ship := ""
var debug_boss := ""
var debug_give: Array = []
var hazards: Array = []
var _aftershocks: Array = []
var _overheal := 0.0

var _cards_open := false
var _pending_card_open := false
var _current_cards: Array = []
var _rng := RandomNumberGenerator.new()
var _boss_ofs := 0.0
var _boss_landed := false
var _boss_dying := false
var _boss_pop := 0.0
var _wave_time := 0.0
var _hunt_timer := 0.0
var _target: Variant = null
var _target_timer := 0.0
var _cam_lead := Vector2.ZERO
var _cam_basis := Basis.IDENTITY
var _zoom := 1.0
var _hurt_fx := 0.0
var _tint_fx := 0.0
var _heartbeat := 0.0
var _shield_timer := 0.0
var _revives_used := 0
var _milestone_index := 0
var _nova_was_ready := false
var _hint_time := 0.0
var _layout_size := Vector2.ZERO
var _over_shown := false
var _record := false
var _cores_earned := 0

func _ready() -> void:
	randomize()
	_rng.randomize()
	_parse_args()
	_build_scene()
	run = RunStateScript.new(GameData.balance, 0)
	run.wave_started.connect(_on_wave_started)
	run.spawn_due.connect(_on_spawn_due)
	run.boss_due.connect(_on_boss_due)
	run.wave_cleared.connect(_on_wave_cleared)
	run.map_cleared.connect(_on_map_cleared)
	run.map_changed.connect(_on_map_changed)
	run.level_up.connect(_on_level_up)
	loadout = LoadoutScript.new(GameData.cards)
	_build_map(0)
	_apply_quality()
	if demo:
		_start_game()
	else:
		_enter_menu()
		if debug_screen == "settings" or debug_screen == "howto":
			menus.open_sub(debug_screen, "main")

func _parse_args() -> void:
	demo = "--demo" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wave="):
			start_wave = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--hp="):
			debug_hp = float(arg.get_slice("=", 1))
		elif arg.begins_with("--die="):
			debug_die = float(arg.get_slice("=", 1))
		elif arg == "--cards":
			show_cards_demo = true
		elif arg == "--nova":
			debug_nova = true
		elif arg.begins_with("--map="):
			debug_map = maxi(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--give="):
			debug_give = Array(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--boss="):
			debug_boss = arg.get_slice("=", 1)
		elif arg.begins_with("--ship="):
			debug_ship = arg.get_slice("=", 1)
		elif arg.begins_with("--screen="):
			debug_screen = arg.get_slice("=", 1)

# --- Kurulum --------------------------------------------------------------------
func _build_scene() -> void:
	sparks = SparksScript.new()
	add_child(sparks)
	field = BulletFieldScript.new()
	add_child(field)
	entities = Node3D.new()
	add_child(entities)
	player = PlayerScript.new()
	player.bounds = ARENA
	add_child(player)
	player.shot.connect(_on_player_shot)
	player.dashed_at.connect(_on_player_dash)
	player.hurt.connect(_on_player_hurt)
	player.shield_broken.connect(_on_shield_broken)
	camera_rig = Node3D.new()
	_cam_basis = Basis.looking_at(Vector3(0.0, 0.0, 0.8) - CAM_OFFSET, Vector3.UP)
	camera_rig.position = ArenaSpace.to_world(ARENA.get_center(), 0.0) + CAM_OFFSET
	camera_rig.basis = _cam_basis
	add_child(camera_rig)
	camera = Camera3D.new()
	camera.fov = 46.0
	camera.near = 0.3
	camera.far = 260.0
	camera_rig.add_child(camera)
	camera.current = true
	aim_marker = _make_aim_marker()
	add_child(aim_marker)
	aim_marker.visible = false

	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = load("res://assets/shaders/vignette.gdshader")
	vignette_rect.material = vignette_mat
	layer.add_child(vignette_rect)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = HudScript.new()
	hud.camera = camera
	hud_layer.add_child(hud)
	touch = TouchScript.new()
	hud_layer.add_child(touch)
	touch.set_enabled(false)
	touch.pause_pressed.connect(_pause)
	menus = MenusScript.new()
	hud_layer.add_child(menus)
	menus.play_pressed.connect(_start_game)
	menus.resume_pressed.connect(_resume)
	menus.restart_pressed.connect(_start_game)
	menus.menu_pressed.connect(_enter_menu)
	menus.pause_requested.connect(_pause)
	menus.card_picked.connect(_on_card_picked)
	menus.reroll_pressed.connect(_on_reroll)
	menus.quality_changed.connect(_apply_quality)
	menus.ship_preview.connect(func(id: String): player.set_ship(Settings.meta.ship_def(id)))

func _make_aim_marker() -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.44
	torus.rings = 24
	torus.ring_segments = 4
	var node := MeshInstance3D.new()
	node.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.9, 1.5, 1.7, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _update_layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp == _layout_size:
		return
	_layout_size = vp
	var m := Vector4(28, 20, 28, 20)
	if Settings.touch:
		m = Vector4(40, 22, 40, 24)
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if win.x > 0.0 and win.y > 0.0 and safe.size.x > 0:
			var sx := vp.x / win.x
			var sy := vp.y / win.y
			m.x = maxf(m.x, float(safe.position.x) * sx + 14.0)
			m.y = maxf(m.y, float(safe.position.y) * sy + 10.0)
			m.z = maxf(m.z, (win.x - float(safe.end.x)) * sx + 14.0)
			m.w = maxf(m.w, (win.y - float(safe.end.y)) * sy + 10.0)
	hud.set_margins(m)
	touch.set_margins(m)
	menus.set_margins(m)
	vignette_mat.set_shader_parameter("resolution", vp)

func _apply_quality() -> void:
	var q := Settings.quality
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	var mobile := OS.has_feature("mobile")
	vp.scaling_3d_scale = [0.67, 0.82, 1.0][q] if mobile else [0.75, 1.0, 1.0][q]
	sparks.budget = [0.5, 0.8, 1.0][q]
	if world != null and is_instance_valid(world):
		world.apply_quality(q)

func _build_map(index: int) -> void:
	if world != null and is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	_clear_entities()
	world = MapBuilderScript.new()
	add_child(world)
	world.build(index, GameData.map_theme(index))
	world.apply_quality(Settings.quality)
	obstacles = world.obstacles
	map_index = index

func _clear_entities() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	_boss_dying = false
	_target = null
	enemies.clear()
	pickups.clear()
	hazards.clear()
	_aftershocks.clear()
	field.clear_all()
	sparks.clear_all()

# --- Akış: menü / oyun / duraklat ------------------------------------------------
func _enter_menu() -> void:
	get_tree().paused = false
	Fx.reset()
	state = "menu"
	_cards_open = false
	_pending_card_open = false
	_clear_entities()
	if world == null or world.theme_index != 0:
		_build_map(0)
	loadout.reset()
	_sync_drones()
	player.set_ship(Settings.meta.current_ship())
	player.max_hp = GameData.number("player.max_health", 100.0)
	player.reset(ARENA.get_center())
	hud.active = false
	hud.dimmed = false
	touch.set_enabled(false)
	aim_marker.visible = false
	world.set_danger(false)
	menus.in_game = false
	menus.show_main()
	Sound.music("menu")
	Sound.set_muffled(false)

func _start_game() -> void:
	get_tree().paused = false
	Fx.reset()
	get_viewport().gui_release_focus()
	menus.hide_all()
	menus.in_game = true
	if world == null or world.theme_index != debug_map:
		_build_map(debug_map)
	else:
		_clear_entities()
	map_index = debug_map
	world.set_danger(false)
	loadout.reset()
	loadout.apply_effects(Settings.meta.effects())
	var ship_def: Dictionary = Settings.meta.current_ship()
	if debug_ship != "" and not Settings.meta.ship_def(debug_ship).is_empty():
		ship_def = Settings.meta.ship_def(debug_ship)
	weapon = ship_def.get("weapon", {})
	loadout.apply_effects(ship_def.get("effect", {}))
	player.set_ship(ship_def)
	for id in debug_give:
		var card := GameData.card_by_id(str(id))
		if not card.is_empty():
			loadout.apply(card)
	_sync_drones()
	player.autopilot = demo
	player.max_hp = GameData.number("player.max_health", 100.0)
	player.reset(ARENA.get_center())
	_apply_loadout()
	if loadout.i("start_shield") > 0:
		player.shield = 1
	nova = NOVA_MAX if debug_nova else clampf(loadout.m("nova_start"), 0.0, NOVA_MAX)
	rerolls = 2 + loadout.i("rerolls")
	_cores_earned = 0
	_overheal = 0.0
	_revives_used = 0
	_milestone_index = 0
	_nova_was_ready = false
	_shield_timer = 0.0
	_hurt_fx = 0.0
	_tint_fx = 0.0
	_cam_lead = Vector2.ZERO
	state = "playing"
	hud.active = true
	hud.dimmed = false
	hud.reset()
	touch.set_enabled(Settings.touch and not demo)
	elapsed = 0.0
	dead_timer = 0.0
	_over_shown = false
	_cards_open = false
	_pending_card_open = false
	Sound.set_muffled(false)
	Sound.music("battle")
	run.begin()
	run.xp_mult = loadout.m("xp_mult")
	if start_wave > 1:
		run.jump_to(start_wave)
	if debug_hp > 0.0:
		player.hp = minf(debug_hp, player.max_hp)
	if show_cards_demo:
		run.add_xp(run.xp_next)
	if not Settings.tutorial_done and not demo:
		_hint_time = 9.0
		hud.hint = tr("SOL: HAREKET   ·   SAĞ: NİŞAN   ·   ATIL ile mermilerden kaç") if Settings.touch else tr("WASD hareket   ·   FARE nişan + ateş   ·   BOŞLUK atıl   ·   Q nova")

func _pause() -> void:
	if state != "playing" or get_tree().paused:
		return
	get_tree().paused = true
	touch.release_all()
	hud.dimmed = true
	Sound.set_muffled(true)
	Sound.play("ui_click")
	menus.show_pause(run.wave, run.level, run.score, loadout.summary())

func _resume() -> void:
	if _cards_open:
		return
	menus.hide_all()
	hud.dimmed = false
	get_tree().paused = false
	Sound.set_muffled(false)

func _apply_loadout() -> void:
	var base_hp: float = GameData.number("player.max_health", 100.0)
	var new_max: float = base_hp + loadout.m("max_hp_bonus")
	if new_max > player.max_hp + 0.01:
		player.hp += new_max - player.max_hp
	player.max_hp = new_max
	player.hp = clampf(player.hp, 0.0, player.max_hp)
	player.speed = GameData.number("player.speed", 360.0) * loadout.m("speed_mult")
	player.fire_rate_mult = loadout.m("fire_rate_mult")
	player.dash_cd_mult = loadout.m("dash_cd_mult")
	_sync_drones()

# --- Ana döngü -------------------------------------------------------------------
func _process(delta: float) -> void:
	elapsed += delta
	Fx.tick(delta)
	_update_layout()
	if Input.is_action_just_pressed("mute"):
		Sound.toggle_mute()
	if state == "menu":
		_idle_player(delta)
	elif state == "playing":
		if _pending_card_open and not _cards_open:
			_pending_card_open = false
			_open_cards()
			if _cards_open:
				return
		if debug_die > 0.0 and elapsed > debug_die and player.alive:
			debug_die = 0.0
			player.invuln = 0.0
			player.shield = 0
			player.take_damage(99999.0, player.pos2 + Vector2.UP)
		_tick_game(delta)
	elif state == "dead":
		dead_timer += delta
		_tick_effects_only(delta)
		if dead_timer > 1.5 and not _over_shown:
			_over_shown = true
			hud.active = false
			menus.show_gameover({
				"score": run.score, "best": Settings.best, "record": _record, "wave": run.wave,
				"level": run.level, "kills": run.kills, "combo": run.max_combo, "time": run.time,
				"cores": _cores_earned, "total_cores": Settings.meta.cores,
			}, loadout.summary())
	_render_frame(delta)
	_update_camera(delta)
	_update_hud()

func _render_frame(delta: float) -> void:
	## Dünya efektleri: zemin, ışık diskleri, mermiler, kıvılcımlar, vinyet.
	if world != null and is_instance_valid(world):
		world.tick(delta, player.position)
	sparks.glow_begin()
	if player.visible:
		var menu_mode := state == "menu"
		sparks.glow_add(player.position.x, player.position.z, 1.7 if menu_mode else 2.6, Color(player.ship_color.r, player.ship_color.g, player.ship_color.b, 0.16 if menu_mode else 0.28))
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			var c: Color = e.color()
			sparks.glow_add(e.position.x, e.position.z, e.radius / ArenaSpace.SCALE * 2.8, Color(c.r, c.g, c.b, 0.22 if not e.is_spawning() else 0.12))
	if boss != null and is_instance_valid(boss):
		var bc: Color = boss.color()
		sparks.glow_add(boss.position.x, boss.position.z, 6.5, Color(bc.r, bc.g, bc.b, 0.4))
	for p in pickups:
		if is_instance_valid(p):
			var pc: Color = p.color()
			sparks.glow_add(p.position.x, p.position.z, 1.5, Color(pc.r, pc.g, pc.b, 0.4))
	for o in obstacles:
		var ow: Vector3 = o["world"]
		var oc: Color = o["color"]
		sparks.glow_add(ow.x, ow.z, float(o["radius"]) / ArenaSpace.SCALE * 2.3, Color(oc.r, oc.g, oc.b, 0.13))
	field.render(sparks, elapsed)
	sparks.tick(delta)
	_hurt_fx = maxf(0.0, _hurt_fx - delta * 1.8)
	_tint_fx = maxf(0.0, _tint_fx - delta * 2.2)
	var low := 0.0
	if state == "playing" and player.alive and player.hp / maxf(1.0, player.max_hp) < 0.3:
		low = 1.0
	vignette_mat.set_shader_parameter("hurt", _hurt_fx)
	vignette_mat.set_shader_parameter("low_hp", low)
	vignette_mat.set_shader_parameter("tint", _tint_fx)

func _idle_player(delta: float) -> void:
	var center := ARENA.get_center()
	var at := center + Vector2(sin(elapsed * 0.5) * 22.0, cos(elapsed * 0.4) * 14.0)
	player.idle_visual(delta, at, elapsed * 0.35 + 0.6, 1.25 + sin(elapsed * 1.3) * 0.14)
	if int(elapsed * 30.0) % 2 == 0:
		var back: Vector3 = player.global_transform.basis.z
		sparks.trail(player.position + back * 1.3, -back, player.ship_color)

func _update_camera(delta: float) -> void:
	var shake := Fx.offset()
	if state == "menu":
		var ship: Vector3 = player.position
		var ang := elapsed * 0.14 + 0.5
		var want := ship + Vector3(sin(ang) * 9.0, 3.4 + sin(elapsed * 0.3) * 0.5, cos(ang) * 9.0)
		camera_rig.position = camera_rig.position.lerp(want, clampf(delta * 2.5, 0.0, 1.0))
		var right: Vector3 = camera_rig.global_transform.basis.x
		var look := Basis.looking_at((ship - right * 2.9 + Vector3(0, 0.5, 0)) - camera_rig.position, Vector3.UP)
		camera_rig.basis = camera_rig.basis.orthonormalized().slerp(look, clampf(delta * 4.0, 0.0, 1.0))
		camera.fov = lerpf(camera.fov, 50.0, clampf(delta * 3.0, 0.0, 1.0))
		camera.position = Vector3.ZERO
		return
	var lead: Vector2 = player.aim2 * 44.0 + player.velocity2 * 0.13
	_cam_lead = _cam_lead.lerp(lead, clampf(delta * 2.4, 0.0, 1.0))
	var focus2: Vector2 = player.pos2 + _cam_lead
	var zoom_target := 1.0
	if boss != null and is_instance_valid(boss) and boss.alive:
		zoom_target = 1.13
		if boss.pos2.distance_to(player.pos2) < 900.0:
			focus2 = focus2.lerp(boss.pos2, 0.16)
	_zoom = lerpf(_zoom, zoom_target, clampf(delta * 1.4, 0.0, 1.0))
	var margin := Vector2(380.0, 290.0)
	focus2.x = clampf(focus2.x, ARENA.position.x + margin.x, ARENA.end.x - margin.x)
	focus2.y = clampf(focus2.y, ARENA.position.y + margin.y, ARENA.end.y - margin.y)
	var focus := ArenaSpace.to_world(focus2, 0.0)
	camera_rig.position = camera_rig.position.lerp(focus + CAM_OFFSET * _zoom, clampf(delta * 6.0, 0.0, 1.0))
	camera_rig.basis = camera_rig.basis.orthonormalized().slerp(_cam_basis, clampf(delta * 5.0, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 46.0, clampf(delta * 3.0, 0.0, 1.0))
	camera.position = Vector3(shake.x, shake.y, 0.0) * 0.013

func _mouse_aim() -> Vector2:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var plane := Plane(Vector3.UP, 1.0)
	var hit: Variant = plane.intersects_ray(origin, normal)
	if hit == null:
		return player.pos2 + player.aim2 * 200.0
	return ArenaSpace.to_plane(hit)

func _tick_effects_only(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if not is_instance_valid(e):
			enemies.remove_at(i)
			continue
		e.tick(delta, player.pos2)
	field.tick(delta)
	if boss != null and is_instance_valid(boss):
		boss.tick(delta, player.pos2)

# --- Otomatik nişan ---------------------------------------------------------------
func _line_blocked(a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 1.0:
		return false
	for o in obstacles:
		var c: Vector2 = o["pos2"]
		var t := clampf((c - a).dot(ab) / len_sq, 0.0, 1.0)
		if (a + ab * t).distance_to(c) < float(o["radius"]) - 4.0:
			return true
	return false

func _pick_target() -> Variant:
	var limit: float = GameData.number("player.auto_aim_range", 760.0)
	var best: Variant = null
	var best_score := 1e12
	for e in enemies:
		if not is_instance_valid(e) or e.dead or e.is_spawning():
			continue
		var d: float = e.pos2.distance_to(player.pos2)
		if d > limit:
			continue
		var score := d
		if e == _target:
			score *= 0.8
		if e.kind == "bomber" or e.kind == "sniper":
			score *= 0.85
		if _line_blocked(player.pos2, e.pos2):
			score *= 2.2
		if score < best_score:
			best_score = score
			best = e
	if boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0:
		var db: float = maxf(0.0, boss.pos2.distance_to(player.pos2) - boss.radius)
		if db < limit * 1.25 and db * 1.15 < best_score:
			best = boss
	return best

func _target_valid(t: Variant) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if t == boss:
		return boss.alive
	return not t.dead

func _auto_aim(delta: float) -> Variant:
	## Hedefi saniyede ~8 kez yeniden seçer; arada mevcut hedefi izler.
	_target_timer -= delta
	if _target_timer <= 0.0 or not _target_valid(_target):
		_target_timer = 0.12
		_target = _pick_target()
	return _target if _target_valid(_target) else null

func _lead_point(t: Variant) -> Vector2:
	var speed: float = GameData.number("player.bullet_speed", 980.0)
	var tpos: Vector2 = t.pos2
	if t == boss:
		return tpos
	var tvel: Vector2 = t.velocity2
	return tpos + tvel * (tpos.distance_to(player.pos2) / speed)

# --- Oyun adımı -------------------------------------------------------------------
func _tick_game(delta: float) -> void:
	run.step(delta)
	_wave_time += delta
	_hunt_timer -= delta
	if _hunt_timer <= 0.0 and _wave_time > 35.0 and run.phase in [RunStateScript.PHASE_BATTLE, RunStateScript.PHASE_BOSS]:
		_hunt_timer = 15.0
		_hunt_stragglers()
	if _hint_time > 0.0:
		_hint_time -= delta
		if _hint_time <= 0.0:
			hud.hint = ""
			Settings.tutorial_done = true
			Settings.save()

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var aim_target: Vector2 = player.pos2 + player.aim2 * 200.0
	var fire := false
	var dash := Input.is_action_just_pressed("dash")
	var want_nova := Input.is_action_just_pressed("nova")
	var locked: Variant = null
	if player.autopilot:
		var plan := _autopilot()
		input = plan["move"]
		aim_target = plan["aim"]
		fire = plan["fire"]
		dash = plan["dash"]
		want_nova = plan["nova"]
	elif Settings.touch:
		if touch.move.length() > 0.01:
			input = touch.move
		dash = dash or touch.take_dash()
		want_nova = want_nova or touch.take_nova()
		if touch.aiming:
			aim_target = player.pos2 + touch.aim * 320.0
			fire = true
		else:
			locked = _auto_aim(delta)
			if locked != null:
				aim_target = _lead_point(locked)
				fire = Settings.auto_fire
			elif input.length() > 0.2:
				aim_target = player.pos2 + input.normalized() * 200.0
	else:
		aim_target = _mouse_aim()
		fire = Input.is_action_pressed("fire") or Settings.auto_fire
	_update_aim_marker(delta, locked, aim_target)

	var before: Vector2 = player.pos2
	player.tick(delta, input, aim_target, fire, dash)
	if (player.pos2 - before).length() > 0.5:
		var edge := player.radius + 1.0
		if player.pos2.x <= ARENA.position.x + edge or player.pos2.x >= ARENA.end.x - edge or player.pos2.y <= ARENA.position.y + edge or player.pos2.y >= ARENA.end.y - edge:
			world.hit_wall()
	var fixed := _push_out(player.pos2, player.radius)
	if fixed != player.pos2:
		player.pos2 = fixed
		player.position = ArenaSpace.to_world(fixed, player.position.y)
	var regen: float = loadout.m("regen")
	if regen > 0.0 and player.alive:
		_heal(regen * delta, false)
	if loadout.i("shield_regen") > 0 and player.shield <= 0:
		_shield_timer += delta
		if _shield_timer >= GameData.number("player.shield_regen_time", 18.0):
			_shield_timer = 0.0
			_give_shield()
	if want_nova:
		_try_nova()
	var nova_ready := nova >= NOVA_MAX
	if nova_ready and not _nova_was_ready:
		Sound.play("nova_ready")
		hud.toast(tr("NOVA HAZIR"), KIT.MAGENTA, 1.4)
	_nova_was_ready = nova_ready
	if player.velocity2.length() > 40.0 and player.alive:
		var back: Vector3 = player.global_transform.basis.z
		sparks.trail(player.position + back * 1.25, -back, Color(1.0, 0.85, 0.3) if player.overdrive > 0.0 else player.ship_color, 2.0 if player.is_dashing() else 1.5)
		if player.is_dashing():
			sparks.trail(player.position + back * 0.4, -back, Color(0.7, 1.0, 1.0), 2.4)

	# Düşmanlar
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if not is_instance_valid(e):
			enemies.remove_at(i)
			continue
		if e.dead:
			enemies.remove_at(i)
			_reap(e)
			continue
		var wants_fire: bool = e.tick(delta, player.pos2)
		if not e.is_spawning():
			e.pos2 += _avoid_obstacles(e.pos2, e.radius) * 90.0 * delta
			e.pos2 = _push_out(e.pos2, e.radius)
		e.pos2.x = clampf(e.pos2.x, ARENA.position.x + e.radius, ARENA.end.x - e.radius)
		e.pos2.y = clampf(e.pos2.y, ARENA.position.y + e.radius, ARENA.end.y - e.radius)
		if e.fuse >= 0.0 and not e.fuse_started:
			e.fuse_started = true
			var blast_r: float = float(e.stats.get("explode_radius", 120.0)) / ArenaSpace.SCALE
			sparks.ring(e.position, Color(1.0, 0.3, 0.12, 0.9), blast_r, blast_r, float(e.stats.get("fuse_time", 0.55)), 0.1, 1.0)
			Sound.play("bomb_beep")
		if wants_fire:
			_fire_enemy_bullet(e)
		if e.explode_now:
			e.dead = true

	# Boss
	if boss != null and is_instance_valid(boss):
		boss.tick(delta, player.pos2)
		boss.pos2.x = clampf(boss.pos2.x, ARENA.position.x + boss.radius, ARENA.end.x - boss.radius)
		boss.pos2.y = clampf(boss.pos2.y, ARENA.position.y + boss.radius, ARENA.end.y - boss.radius)
		if not _boss_landed and boss.intro <= 0.0:
			_boss_landed = true
			sparks.ring(boss.position, boss.color(), 1.0, 13.0, 0.7, 0.2)
			sparks.burst(boss.position, boss.color(), 50, 13.0, 0.8, 1.6)
			Sound.play("explode_big", -2.0, 0.8)
			Fx.shake(20.0)
			Fx.vibrate(80)
			world.flash_pulse(boss.position, 1.0)
		if not boss.alive:
			if not _boss_dying:
				_on_boss_dying()
			_boss_pop -= delta
			if _boss_pop <= 0.0:
				_boss_pop = 0.11
				var off := Vector3(randf_range(-1.6, 1.6), randf_range(-0.4, 1.2), randf_range(-1.6, 1.6))
				sparks.burst(boss.position + off, boss.color() if randf() < 0.5 else Color(1, 0.9, 0.6), 14, 9.0, 0.5, 1.3)
				sparks.flash(boss.position + off, boss.color(), 5.0, 8.0, 0.2)
				Sound.play("explode", -4.0, randf_range(0.8, 1.3))
				Fx.shake(6.0)
			if boss.dying <= 0.0:
				_on_boss_killed()

	_tick_hazards(delta)
	_tick_aftershocks(delta)
	_tick_beams()
	_steer_rockets(delta)
	field.tick(delta)
	var pull: float = 135.0 * loadout.m("magnet")
	for i in range(pickups.size() - 1, -1, -1):
		var p = pickups[i]
		if not is_instance_valid(p) or not p.tick(delta, player.pos2, pull):
			if is_instance_valid(p):
				p.queue_free()
			pickups.remove_at(i)
	_tick_drones(delta)
	_separate_enemies()
	_resolve_collisions()

	var ratio: float = player.hp / maxf(1.0, player.max_hp)
	if player.alive and ratio < 0.3:
		_heartbeat -= delta
		if _heartbeat <= 0.0:
			_heartbeat = 0.95
			Sound.play("low_hp")
	if not player.alive and state == "playing":
		_on_player_died()

func _update_aim_marker(delta: float, locked: Variant, aim_target: Vector2) -> void:
	if demo:
		aim_marker.visible = false
		return
	aim_marker.rotation.y += delta * 2.5
	if Settings.touch:
		if locked != null:
			var lp: Vector2 = locked.pos2
			var lr: float = locked.radius
			aim_marker.visible = true
			aim_marker.position = ArenaSpace.to_world(lp, 0.12)
			var k := lr / ArenaSpace.SCALE * 2.9 * (1.0 + 0.08 * sin(elapsed * 9.0))
			aim_marker.scale = Vector3(k, 1.0, k)
		else:
			aim_marker.visible = false
	else:
		aim_marker.visible = true
		aim_marker.scale = Vector3.ONE
		aim_marker.position = ArenaSpace.to_world(aim_target, 0.06)

func _push_out(pos: Vector2, radius: float) -> Vector2:
	for o in obstacles:
		var center: Vector2 = o["pos2"]
		var min_dist: float = radius + float(o["radius"])
		var diff := pos - center
		var dist := diff.length()
		if dist < min_dist:
			if dist < 0.001:
				diff = Vector2.RIGHT
				dist = 1.0
			pos = center + diff / dist * min_dist
	return pos

func _avoid_obstacles(pos: Vector2, radius: float) -> Vector2:
	var push := Vector2.ZERO
	for o in obstacles:
		var diff: Vector2 = pos - o["pos2"]
		var dist := diff.length()
		var limit: float = float(o["radius"]) + radius + 70.0
		if dist < limit and dist > 0.01:
			# Engelin çevresinden dolan: itme + teğet bileşeni.
			var away := diff / dist
			push += (away + Vector2(-away.y, away.x) * 0.6) * (1.0 - dist / limit)
	return push.normalized() if push.length() > 1.0 else push

func _hunt_stragglers() -> void:
	## Uzun süren dalgada kalan düşmanlar oyuncuya ışınlanır: soft-lock olmaz.
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		sparks.burst(e.position, e.color(), 10, 5.0, 0.4, 0.9)
		e.pos2 = _spawn_point()
		e.position = ArenaSpace.to_world(e.pos2, 0.9)
		sparks.burst(e.position, e.color(), 12, 6.0, 0.45, 1.0)
	if not enemies.is_empty():
		hud.toast(tr("AV MODU — kalan düşmanlar yaklaşıyor"), KIT.RED, 1.8)
		Sound.play("elite", -4.0, 1.2)

func _point_blocked(pos: Vector2, radius: float) -> bool:
	for o in obstacles:
		var r: float = radius + float(o["radius"])
		if pos.distance_squared_to(o["pos2"]) < r * r:
			return true
	return false

func _separate_enemies() -> void:
	for i in enemies.size():
		var a = enemies[i]
		if not is_instance_valid(a) or a.dead or a.is_spawning():
			continue
		for j in range(i + 1, enemies.size()):
			var b = enemies[j]
			if not is_instance_valid(b) or b.dead or b.is_spawning():
				continue
			var diff: Vector2 = b.pos2 - a.pos2
			var min_dist: float = a.radius + b.radius + 2.0
			var dist_sq := diff.length_squared()
			if dist_sq > 0.0001 and dist_sq < min_dist * min_dist:
				var dist := sqrt(dist_sq)
				var push: Vector2 = diff / dist * (min_dist - dist) * 0.5
				a.pos2 -= push
				b.pos2 += push

# --- Çarpışmalar ------------------------------------------------------------------
func _resolve_collisions() -> void:
	var boss_hittable: bool = boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0
	for b in field.bullets:
		if b.dead:
			continue
		if b.friendly:
			for e in enemies:
				if e.dead or e.is_spawning():
					continue
				var rr: float = e.radius + b.radius
				if b.pos2.distance_squared_to(e.pos2) < rr * rr:
					if not b.hits.is_empty() and b.hits.has(e.get_instance_id()):
						continue
					_hit_enemy(e, b)
					if b.blast > 0.0:
						_rocket_blast(b)
						b.dead = true
						break
					if b.pierce > 0:
						b.pierce -= 1
						b.hits.append(e.get_instance_id())
					else:
						b.dead = true
					break
			if b.dead:
				continue
			if boss_hittable:
				var br: float = boss.radius + b.radius
				if b.pos2.distance_squared_to(boss.pos2) < br * br:
					boss.take_damage(b.damage)
					if b.blast > 0.0:
						_rocket_blast(b)
					var at := ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT)
					sparks.spray(at, -ArenaSpace.dir_to_world(b.velocity2), Color(1.0, 0.7, 0.8), 6, 8.0, 0.3, 1.0)
					_damage_number(at, b.damage, b.crit)
					Sound.play("crit" if b.crit else "hit", -1.0, 0.85)
					b.dead = true
					continue
		else:
			if player.alive and player.invuln <= 0.0:
				var pr: float = player.radius + b.radius + 1.0
				if b.pos2.distance_squared_to(player.pos2) < pr * pr:
					player.take_damage(b.damage, b.pos2 - b.velocity2 * 0.01)
					b.dead = true
					continue
		if _point_blocked(b.pos2, b.radius):
			if b.blast > 0.0:
				_rocket_blast(b)
			sparks.spray(ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT), -ArenaSpace.dir_to_world(b.velocity2), b.color, 4, 5.0, 0.22, 0.8)
			b.dead = true

	var dash_damage: float = loadout.m("dash_damage")
	if player.alive and player.is_dashing() and dash_damage > 0.0:
		for e in enemies:
			if e.dead or e.is_spawning() or e.dash_hit > 0.0:
				continue
			if e.pos2.distance_to(player.pos2) < e.radius + player.radius + 22.0:
				e.dash_hit = 0.4
				var dash_hit: float = dash_damage * loadout.m("damage_mult") * (2.0 if loadout.i("blitz") > 0 else 1.0)
				e.take_damage(dash_hit, player.dash_dir * 260.0)
				sparks.lightning(player.position, e.position, Color(0.6, 1.0, 1.0), 0.08, 0.18)
				sparks.burst(e.position, Color(0.6, 1.0, 1.0), 8, 7.0, 0.3, 1.0)
				_damage_number(e.position, dash_hit, false)
				Sound.play("chain")
				if e.dead and loadout.i("blitz") > 0:
					player.dash_cd = 0.0
					sparks.ring(player.position, Color(0.6, 1.0, 1.0), 0.3, 2.2, 0.25, 0.25)
	if player.invuln <= 0.0 and player.alive:
		for e in enemies:
			if e.dead or e.is_spawning() or e.touch_cd > 0.0:
				continue
			if e.pos2.distance_to(player.pos2) < e.radius + player.radius:
				e.touch_cd = 0.6
				player.take_damage(e.damage_value, e.pos2)
				var thorns: float = loadout.m("thorns") * (3.0 if loadout.i("fortress") > 0 else 1.0)
				if thorns > 0.0:
					e.take_damage(thorns, (e.pos2 - player.pos2).normalized() * 220.0)
					_damage_number(e.position, thorns, false)
				break
	if boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0 and not boss.is_airborne() and player.invuln <= 0.0 and player.alive:
		if boss.pos2.distance_to(player.pos2) < boss.radius + player.radius:
			player.take_damage(boss.damage_value * (1.4 if boss.is_charging() else 1.0), boss.pos2)
	for pi in range(pickups.size() - 1, -1, -1):
		var p = pickups[pi]
		if is_instance_valid(p) and p.pos2.distance_to(player.pos2) < 34.0 and player.alive:
			_apply_pickup(p)
			p.queue_free()
			pickups.remove_at(pi)

func _heal(amount: float, show := true) -> void:
	## Tüm iyileşmeler buradan geçer; Kan Hasadı taşan canı kalkana çevirir.
	var room := player.max_hp - player.hp
	player.heal(amount)
	if loadout.i("harvest") <= 0:
		return
	_overheal += maxf(0.0, amount - room)
	if _overheal >= 50.0 and player.shield <= 0:
		_overheal = 0.0
		_give_shield()
		if show:
			hud.toast(tr("KAN HASADI — kalkan"), KIT.RED, 1.0)

func _tick_aftershocks(delta: float) -> void:
	for i in range(_aftershocks.size() - 1, -1, -1):
		var a: Dictionary = _aftershocks[i]
		a["t"] = float(a["t"]) - delta
		if float(a["t"]) > 0.0:
			continue
		_aftershocks.remove_at(i)
		var at: Vector2 = a["pos2"]
		var w := ArenaSpace.to_world(at, 0.6)
		sparks.burst(w, Color(1.0, 0.45, 0.85), 22, 11.0, 0.5, 1.3)
		sparks.ring(w, Color(1.0, 0.45, 0.85), 0.4, 4.0, 0.35, 0.25, 1.0)
		sparks.flash(w, Color(1.0, 0.4, 0.8), 6.0, 9.0, 0.2)
		Sound.play("explode", -2.0, 0.8)
		Fx.shake(6.0)
		_area_damage(at, 150.0, float(a["dmg"]))

func _damage_number(at: Vector3, amount: float, crit: bool) -> void:
	hud.float_text(at, str(int(round(amount))), KIT.GOLD if crit else Color(0.92, 0.97, 1.0), 26 if crit else 17, 0.75 if crit else 0.55)

func _hit_enemy(e, b) -> void:
	var dir: Vector2 = b.velocity2.normalized()
	var push := dir * (26.0 if e.kind == "tank" or e.elite else 90.0)
	e.take_damage(b.damage, push)
	var at := ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT)
	sparks.spray(at, -ArenaSpace.dir_to_world(dir), Color(1.0, 0.85, 0.45) if b.crit else e.color().lerp(Color(1, 1, 1), 0.45), 7 if b.crit else 4, 8.0, 0.28, 1.0 if b.crit else 0.8)
	_damage_number(e.position, b.damage, b.crit)
	Sound.play("crit" if b.crit else "hit")
	var chain: int = loadout.i("chain")
	var storm: bool = b.crit and loadout.i("storm") > 0
	if storm:
		chain += 2
	if chain > 0 and b.chain == 0:
		_chain_from(e, b.damage * (1.0 if storm else 0.5), chain)

func _chain_from(source, damage: float, jumps: int) -> void:
	var visited: Array = [source]
	var current = source
	for n in jumps:
		var next = null
		var best := 240.0
		for e in enemies:
			if e.dead or e.is_spawning() or visited.has(e):
				continue
			var d: float = e.pos2.distance_to(current.pos2)
			if d < best:
				best = d
				next = e
		if next == null:
			break
		sparks.lightning(current.position, next.position, Color(0.75, 0.6, 1.0), 0.07, 0.17)
		sparks.burst(next.position, Color(0.8, 0.7, 1.0), 5, 5.0, 0.25, 0.8)
		next.take_damage(damage)
		_damage_number(next.position, damage, false)
		visited.append(next)
		current = next
	if visited.size() > 1:
		Sound.play("chain")

func _area_damage(center: Vector2, radius: float, damage: float, skip = null) -> void:
	for other in enemies:
		if other == skip or other.dead or other.is_spawning():
			continue
		var d: float = other.pos2.distance_to(center)
		if d < radius + other.radius:
			other.take_damage(damage, (other.pos2 - center).normalized() * 240.0)
	if boss != null and is_instance_valid(boss) and boss.alive and boss.pos2.distance_to(center) < radius + boss.radius:
		boss.take_damage(damage)

func _bomber_blast(e) -> void:
	var radius := float(e.stats.get("explode_radius", 120.0))
	var world_r := radius / ArenaSpace.SCALE
	sparks.burst(e.position, Color(1.0, 0.4, 0.15), 44, 13.0, 0.7, 1.5)
	sparks.ring(e.position, Color(1.0, 0.45, 0.15), 0.5, world_r * 1.15, 0.45, 0.22, 1.0)
	sparks.flash(e.position, Color(1.0, 0.5, 0.2), 9.0, 12.0, 0.3)
	Sound.play("explode_big", -3.0, 1.15)
	Fx.shake(13.0)
	if player.alive and player.pos2.distance_to(e.pos2) < radius:
		player.take_damage(e.damage_value, e.pos2)
	_area_damage(e.pos2, radius, e.damage_value * 1.6, e)

func _apply_pickup(p) -> void:
	match p.kind:
		"heal":
			var amount: float = GameData.number("pickups.heal_amount", 22.0)
			_heal(amount)
			hud.toast(tr("+%d CAN") % int(amount), KIT.GREEN)
			hud.float_text(player.position, "+%d" % int(amount), KIT.GREEN, 22, 0.9)
			Sound.play("pickup_heal")
		"shield":
			_give_shield()
			hud.toast(tr("KALKAN"), Color(0.55, 0.8, 1.0))
		_:
			player.overdrive = GameData.number("pickups.overdrive_time", 6.0)
			hud.toast(tr("AŞIRI YÜK — ateş hızı ×2"), KIT.GOLD)
			Sound.play("pickup_power")
	sparks.burst(p.position, p.color(), 18, 8.0, 0.55, 1.1)
	sparks.ring(player.position, p.color(), 0.4, 3.2, 0.4, 0.2)
	_tint_fx = maxf(_tint_fx, 0.35)
	vignette_mat.set_shader_parameter("tint_color", p.color())
	Fx.vibrate(15)

func _give_shield() -> void:
	player.shield = 1
	Sound.play("shield_up")
	sparks.ring(player.position, Color(0.5, 0.8, 1.0), 3.0, 1.2, 0.4, 0.2)

# --- Nova -------------------------------------------------------------------------
func _try_nova() -> void:
	if nova < NOVA_MAX or not player.alive:
		if player.alive:
			Sound.play("deny")
		return
	nova = 0.0
	var radius: float = GameData.number("player.nova_radius", 340.0)
	var damage: float = GameData.number("player.nova_damage", 70.0) * loadout.m("damage_mult") * (1.0 + 0.12 * float(run.wave - 1))
	if loadout.i("doom_nova") > 0:
		radius *= 1.5
		for k in 3:
			var at: Vector2 = player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(radius * 0.35, radius * 0.8)
			_aftershocks.append({"pos2": at, "t": 0.35 + 0.3 * float(k), "dmg": damage * 0.6})
	_blast(radius, damage, Color(1.0, 0.4, 0.85))
	player.invuln = maxf(player.invuln, 0.6)
	Sound.play("nova")
	hud.show_banner(tr("NOVA"), "", 0.7, KIT.MAGENTA)

func _blast(radius: float, damage: float, color: Color) -> void:
	var world_r := radius / ArenaSpace.SCALE
	for at in field.clear_hostile(player.pos2, radius * 1.3):
		sparks.burst(ArenaSpace.to_world(at, 1.0), Color(1.0, 0.5, 0.8), 3, 4.0, 0.3, 0.8)
	_area_damage(player.pos2, radius, damage)
	sparks.ring(player.position, color, 0.6, world_r, 0.5, 0.2, 1.0)
	sparks.ring(player.position, Color(1, 1, 1, 0.9), 0.3, world_r * 0.8, 0.38, 0.1)
	sparks.ring(player.position, color, 0.2, world_r * 1.35, 0.75, 0.06)
	sparks.burst(player.position, color, 60, 18.0, 0.7, 1.6, 0.4)
	sparks.burst(player.position, Color(1, 1, 1), 24, 12.0, 0.5, 1.2, 0.4)
	sparks.flash(player.position, color, 14.0, 20.0, 0.4)
	world.flash_pulse(player.position, 1.0)
	_tint_fx = 1.0
	vignette_mat.set_shader_parameter("tint_color", color)
	Fx.shake(22.0)
	Fx.hitstop(0.07, 0.1)
	Fx.vibrate(70)

# --- Otopilot (demo / test) ---------------------------------------------------------
func _autopilot() -> Dictionary:
	var nearest = null
	var nearest_dist := 1e9
	var close := 0
	for e in enemies:
		if e.dead:
			continue
		var d: float = e.pos2.distance_to(player.pos2)
		if d < 300.0:
			close += 1
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	var aim_target: Vector2 = player.pos2 + player.aim2 * 200.0
	var move := Vector2.ZERO
	if nearest != null:
		aim_target = nearest.pos2 + nearest.velocity2 * 0.12
		var away: Vector2 = (player.pos2 - nearest.pos2).normalized()
		var side := Vector2(-away.y, away.x)
		move = (side * 0.9 + away * 0.45).normalized()
		if str(weapon.get("type", "")) == "scatter" and nearest_dist > 230.0:
			# Kısa menzilli silah: yaklaş ve yan yan dolaş.
			move = (side * 0.7 - away * 0.8).normalized()
		elif nearest_dist < 150.0:
			move = away
	var boss_near := false
	if boss != null and is_instance_valid(boss) and boss.alive:
		aim_target = boss.pos2
		var away_b: Vector2 = (player.pos2 - boss.pos2).normalized()
		var dist_b: float = player.pos2.distance_to(boss.pos2)
		boss_near = dist_b < 330.0
		if dist_b < 300.0:
			move = away_b
		elif nearest == null:
			move = Vector2(-away_b.y, away_b.x)
	for b in field.bullets:
		if b.friendly or b.dead:
			continue
		var to_player: Vector2 = player.pos2 - b.pos2
		var d2: float = to_player.length()
		if d2 < 170.0 and b.velocity2.dot(to_player) > 0.0:
			move += Vector2(-b.velocity2.y, b.velocity2.x).normalized() * 0.8
	for h in hazards:
		var to_h: Vector2 = player.pos2 - h["pos2"]
		var lim: float = float(h["radius"]) + 70.0
		if to_h.length() < lim:
			move += to_h.normalized() * 2.5
	var beam_close := false
	if boss != null and is_instance_valid(boss) and boss.beam_state != BossScript.BEAM_IDLE:
		for angle in boss.beam_angles:
			var bd := Vector2.from_angle(angle)
			var rel: Vector2 = player.pos2 - boss.pos2
			var along := rel.dot(bd)
			if along > 0.0 and along < boss.beam_length:
				var side_v := rel - bd * along
				if side_v.length() < 140.0:
					move += side_v.normalized() * 2.0 + Vector2(-bd.y, bd.x) * 0.5
				if boss.beam_state == BossScript.BEAM_FIRE and side_v.length() < 70.0:
					beam_close = true
	for o in obstacles:
		var to_obs: Vector2 = player.pos2 - o["pos2"]
		var dist_o := to_obs.length()
		var guard: float = float(o["radius"]) + 80.0
		if dist_o < guard and dist_o > 0.01:
			move += to_obs / dist_o * (1.0 - dist_o / guard) * 1.8
	if player.pos2.x < ARENA.position.x + 160.0:
		move.x += 1.4
	if player.pos2.x > ARENA.end.x - 160.0:
		move.x -= 1.4
	if player.pos2.y < ARENA.position.y + 160.0:
		move.y += 1.4
	if player.pos2.y > ARENA.end.y - 160.0:
		move.y -= 1.4
	move = move.normalized() if move.length() > 0.001 else Vector2.ZERO
	return {
		"move": move,
		"aim": aim_target,
		"fire": true,
		"dash": (nearest_dist < 120.0 or beam_close) and player.dash_ready(),
		"nova": nova >= NOVA_MAX and (close >= 4 or boss_near),
	}

# --- Atışlar ----------------------------------------------------------------------
func _fire_one(origin: Vector2, dir: Vector2, speed: float, damage: float, life: float, size: float, style: int, tint: Color):
	var crit: bool = randf() < loadout.m("crit")
	var b = field.spawn(origin, dir, speed, true, damage * (2.0 if crit else 1.0), life, size, crit, Color(0, 0, 0, 0) if crit else tint)
	b.style = style
	b.pierce = loadout.i("pierce")
	return b

func _on_player_shot(origin: Vector2, direction: Vector2) -> void:
	var w: Dictionary = weapon
	var kind := str(w.get("type", "blaster"))
	var damage: float = GameData.number("player.damage", 12.0) * loadout.m("damage_mult") * float(w.get("damage", 1.0))
	var speed := float(w.get("speed", 980.0))
	var life := float(w.get("life", 0.85))
	var spread := float(w.get("spread", 0.035))
	var size: float = loadout.m("bullet_size") * float(w.get("size", 1.0))
	var extra: int = loadout.i("projectiles") - 1
	var tint: Color = player.ship_color.lerp(Color(1, 1, 1), 0.3)
	var muzzle := ArenaSpace.to_world(origin, 1.05)
	var dir3 := ArenaSpace.dir_to_world(direction)
	match kind:
		"scatter":
			var pellets := int(w.get("pellets", 6)) + extra * 2
			var arc := float(w.get("arc", 0.6)) + float(extra) * 0.1
			for i in pellets:
				var t := float(i) / float(maxi(1, pellets - 1)) - 0.5
				var dir := direction.rotated(t * arc + randf_range(-spread, spread))
				_fire_one(origin, dir, speed * randf_range(0.88, 1.08), damage, life * randf_range(0.85, 1.1), size, BulletFieldScript.STYLE_PELLET, tint)
			sparks.spray(muzzle, dir3, tint, 9, 12.0, 0.16, 0.9, 0.45)
			Sound.play("shoot_scatter")
			player.velocity2 -= direction * 120.0
			Fx.punch(-direction, 2.6)
			Fx.shake(1.6)
		"rail":
			var side := Vector2(-direction.y, direction.x)
			for i in extra + 1:
				var off := (float(i) - float(extra) * 0.5) * 18.0
				var b = _fire_one(origin + side * off, direction, speed, damage, life, size, BulletFieldScript.STYLE_RAIL, tint)
				b.pierce += int(w.get("pierce", 4))
				var start := ArenaSpace.to_world(origin + side * off, 1.05)
				sparks.beam(start, start + dir3 * 9.0, tint, 0.1 * size, 0.1)
			sparks.spray(muzzle, dir3, Color(1, 1, 1), 6, 14.0, 0.14, 0.8, 0.25)
			Sound.play("shoot_rail")
			player.velocity2 -= direction * 160.0
			Fx.punch(-direction, 3.4)
			Fx.shake(2.4)
		"rocket":
			for i in extra + 1:
				var off := (float(i) - float(extra) * 0.5) * 0.42
				var b = _fire_one(origin, direction.rotated(off + randf_range(-spread, spread)), speed, damage, life, size, BulletFieldScript.STYLE_ROCKET, Color(1.0, 0.75, 0.4))
				b.homing = float(w.get("homing", 6.0))
				b.blast = float(w.get("blast", 72.0))
				b.accel = float(w.get("accel", 1400.0))
				b.max_speed = float(w.get("max_speed", 980.0))
				b.pierce = 0
			sparks.spray(muzzle, dir3, Color(1.0, 0.7, 0.35), 5, 7.0, 0.22, 1.0, 0.5)
			Sound.play("shoot_rocket")
			Fx.punch(-direction, 1.4)
		_:
			var count := extra + 1
			for i in count:
				var offset := 0.0
				if count > 1:
					offset = (float(i) - float(count - 1) * 0.5) * 0.10
				_fire_one(origin, direction.rotated(offset + randf_range(-spread, spread)), speed, damage, life, size, BulletFieldScript.STYLE_BLASTER, Color(0, 0, 0, 0))
			sparks.spray(muzzle, dir3, Color(0.6, 0.95, 1.0), 3, 9.0, 0.14, 0.7, 0.3)
			Sound.play("shoot", randf_range(-2.0, 0.0), 1.18 if player.overdrive > 0.0 else 1.0)
			player.velocity2 -= direction * GameData.number("player.knockback", 90.0) * 0.3
			Fx.punch(-direction, 0.9)

func _nearest_hostile(from: Vector2, radius: float, heading: Vector2) -> Object:
	var best: Object = null
	var best_score := 1e12
	var fwd := heading.normalized()
	for e in enemies:
		if e.dead or e.is_spawning():
			continue
		var to: Vector2 = e.pos2 - from
		var d := to.length()
		if d > radius:
			continue
		var score := d * (1.0 + maxf(0.0, -fwd.dot(to / maxf(d, 0.001))) * 1.5)
		if score < best_score:
			best_score = score
			best = e
	if boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0:
		var db: float = boss.pos2.distance_to(from) - boss.radius
		if db < radius and db < best_score:
			best = boss
	return best

func _steer_rockets(delta: float) -> void:
	for b in field.bullets:
		if b.dead or not b.friendly or b.homing <= 0.0:
			continue
		b.retarget -= delta
		if b.retarget <= 0.0 or not _target_valid(b.target):
			b.retarget = 0.15
			b.target = _nearest_hostile(b.pos2, 600.0, b.velocity2)
		if _target_valid(b.target):
			var tp: Vector2 = b.target.pos2
			var diff := wrapf((tp - b.pos2).angle() - b.velocity2.angle(), -PI, PI)
			b.velocity2 = b.velocity2.rotated(clampf(diff, -b.homing * delta, b.homing * delta))
		if randf() < 0.7:
			var fwd := ArenaSpace.dir_to_world(b.velocity2)
			sparks.trail(ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT) - fwd * 0.45, fwd, Color(1.0, 0.55, 0.25), 1.2)

func _rocket_blast(b) -> void:
	var at := ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT)
	sparks.burst(at, Color(1.0, 0.6, 0.25), 14, 9.0, 0.4, 1.1)
	sparks.ring(at, Color(1.0, 0.55, 0.2), 0.3, b.blast / ArenaSpace.SCALE * 1.1, 0.3, 0.25, 1.0)
	sparks.flash(at, Color(1.0, 0.55, 0.2), 4.0, 7.0, 0.16)
	Sound.play("explode", -6.0, 1.35)
	Fx.shake(2.5)
	_area_damage(b.pos2, b.blast, b.damage * 0.6)

func _fire_enemy_bullet(e) -> void:
	var dir: Vector2 = (player.pos2 - e.pos2).normalized()
	var speed := float(e.stats.get("bullet_speed", 330.0))
	var sniper: bool = e.kind == "sniper"
	var tint: Color = e.color().lerp(Color(1.0, 0.25, 0.55), 0.35)
	field.spawn(e.pos2 + dir * (e.radius + 6.0), dir, speed, false, e.damage_value * 0.8, 3.2, 1.25 if sniper else 1.0, false, Color(tint.r, tint.g, tint.b, 1.0))
	sparks.spray(e.position, ArenaSpace.dir_to_world(dir), e.color(), 4, 5.0, 0.2, 0.8)
	Sound.play("shoot_sniper" if sniper else "shoot_enemy", -4.0 if sniper else 0.0)

func _spawn_boss_bullet(at: Vector2, dir: Vector2, speed: float, damage: float) -> void:
	var c: Color = boss.color().lerp(Color(1, 0.3, 0.6), 0.3) if boss != null else Color(1, 0.3, 0.6)
	field.spawn(at, dir, speed, false, damage, 4.2, 1.45, false, Color(c.r, c.g, c.b, 1.0))

func _on_boss_radial(count: int) -> void:
	if boss == null:
		return
	_boss_ofs += 0.19
	for i in count:
		var dir := Vector2.from_angle(TAU * float(i) / float(count) + _boss_ofs)
		_spawn_boss_bullet(boss.pos2 + dir * (boss.radius + 10.0), dir, 250.0, boss.damage_value * 0.5)
	sparks.ring(boss.position, boss.color(), 1.5, 4.5, 0.3, 0.15)
	Sound.play("shoot_enemy", 3.0, 0.6)

func _on_boss_aimed(dir: Vector2) -> void:
	if boss == null:
		return
	for i in 3:
		var offset := (float(i) - 1.0) * 0.13
		_spawn_boss_bullet(boss.pos2 + dir.rotated(offset) * (boss.radius + 8.0), dir.rotated(offset), 470.0, boss.damage_value * 0.6)
	Sound.play("shoot_enemy", 1.0, 0.8)

func _on_boss_spiral(angle: float, arms: int) -> void:
	if boss == null:
		return
	for k in arms:
		var dir := Vector2.from_angle(angle + TAU * float(k) / float(arms))
		_spawn_boss_bullet(boss.pos2 + dir * (boss.radius + 8.0), dir, 235.0, boss.damage_value * 0.45)
	Sound.play("shoot_enemy", -3.0, 1.3)

func _on_boss_summon(kind: String, count: int) -> void:
	if boss == null:
		return
	for i in count:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(boss.radius + 20.0, boss.radius + 90.0)
		_spawn_enemy(kind, boss.pos2 + offset, 0.35)
		run.add_alive(1)

func _on_boss_charge_warn(dir: Vector2, duration: float) -> void:
	if boss == null:
		return
	var reach: float = float(boss.stats.get("charge_speed", 760.0)) * float(boss.stats.get("charge_time", 0.5))
	var from := ArenaSpace.to_world(boss.pos2, 0.15)
	var to := ArenaSpace.to_world(boss.pos2 + dir * (reach + boss.radius), 0.15)
	sparks.beam(from, to, Color(1.0, 0.2, 0.25, 0.55), boss.radius / ArenaSpace.SCALE * 1.7, duration)
	sparks.ring(boss.position, Color(1.0, 0.3, 0.3), 5.0, 1.6, duration, 0.14)
	Sound.play("bomb_beep", 3.0, 0.7)
	Sound.play("elite", -5.0, 1.5)

func _on_boss_charge(_dir: Vector2) -> void:
	Sound.play("dash", 4.0, 0.55)
	Fx.shake(9.0)

func _on_boss_phase(_phase: int) -> void:
	if boss == null:
		return
	hud.show_banner(tr("ÖFKE FAZI"), tr("saldırılar hızlanıyor"), 1.8, KIT.RED)
	Sound.play("boss_phase")
	sparks.ring(boss.position, boss.color(), 1.0, 16.0, 0.8, 0.14, 1.0)
	sparks.burst(boss.position, boss.color(), 60, 15.0, 0.9, 1.6)
	sparks.flash(boss.position, boss.color(), 12.0, 18.0, 0.5)
	for at in field.clear_hostile(boss.pos2, 99999.0):
		sparks.burst(ArenaSpace.to_world(at, 1.0), boss.color(), 2, 3.0, 0.3, 0.8)
	Fx.shake(18.0)
	Fx.hitstop(0.1, 0.1)
	Fx.vibrate(90)

func _on_boss_due() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	var theme: Dictionary = GameData.map_theme(map_index)
	var lap := map_index / maxi(1, GameData.maps.size())
	var kind := str(theme.get("boss", "sentinel"))
	if debug_boss != "":
		kind = debug_boss
	var b: BossScript = BossScript.new()
	var display := tr(str(theme.get("boss_name", "BOSS")))
	if lap > 0:
		display += " MK-%d" % (lap + 1)
	b.setup(GameData.boss_stats(kind), run.hp_scale() * (1.0 + 0.25 * float(lap)), run.damage_scale(), display, str(theme.get("boss_color", "")), kind)
	b.pos2 = _boss_spawn_point()
	b.position = ArenaSpace.to_world(b.pos2, 6.0)
	add_child(b)
	boss = b
	_boss_landed = false
	_boss_dying = false
	b.radial_wave.connect(_on_boss_radial)
	b.aimed_shot.connect(_on_boss_aimed)
	b.summon.connect(_on_boss_summon)
	b.phase_changed.connect(_on_boss_phase)
	b.charge_warn.connect(_on_boss_charge_warn)
	b.charge_started.connect(_on_boss_charge)
	b.spiral_shot.connect(_on_boss_spiral)
	b.zone_marked.connect(_on_boss_zone)
	b.ring_burst.connect(_on_boss_ring)
	b.fan_shot.connect(_on_boss_fan)
	b.leap_started.connect(_on_boss_leap)
	b.blink_warn.connect(_on_boss_blink_warn)
	b.blinked.connect(_on_boss_blinked)
	b.beam_warned.connect(func(): Sound.play("laser_charge"))
	hud.show_banner(b.display_name, tr("BOSS YAKLAŞIYOR"), 2.6, b.color())
	sparks.ring(ArenaSpace.to_world(b.pos2, 0.0), b.color(), 9.0, 1.5, 1.2, 0.1, 1.0)
	Sound.play("boss_warn")
	Sound.music("boss", 1.2)
	world.set_danger(true)
	Fx.vibrate(120)

# --- Boss saldırıları: tehlike bölgeleri, dalgalar, ışınlar ---------------------------
func _on_boss_zone(at: Vector2, radius: float, delay: float, burst: int) -> void:
	at = at.clamp(ARENA.position + Vector2(40, 40), ARENA.end - Vector2(40, 40))
	var dmg: float = boss.damage_value * 0.9 if boss != null else 25.0
	hazards.append({"pos2": at, "radius": radius, "t": delay, "max": delay, "dmg": dmg, "burst": burst, "kind": "slam"})
	var w := ArenaSpace.to_world(at, 0.0)
	var c := Color(1.0, 0.32, 0.12)
	sparks.ring(w, Color(c, 0.9), radius / ArenaSpace.SCALE, radius / ArenaSpace.SCALE, delay, 0.07, 0.6)
	sparks.ring(w, Color(c, 0.7), 0.1, radius / ArenaSpace.SCALE, delay, 0.9, 0.0)
	Sound.play("bomb_beep", -2.0, 0.8)

func _tick_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		h["t"] = float(h["t"]) - delta
		if float(h["t"]) > 0.0:
			continue
		hazards.remove_at(i)
		var at: Vector2 = h["pos2"]
		var r: float = h["radius"]
		var w := ArenaSpace.to_world(at, 0.2)
		var c := Color(1.0, 0.4, 0.12) if str(h["kind"]) != "leap" else (boss.color() if boss != null else Color(1, 0.4, 0.1))
		sparks.burst(w, c, 26, 11.0, 0.55, 1.3, 0.6)
		sparks.ring(w, c, r / ArenaSpace.SCALE * 0.4, r / ArenaSpace.SCALE * 1.15, 0.35, 0.25, 1.0)
		sparks.flash(w, c, 6.0, 9.0, 0.2)
		Sound.play("slam", -2.0 if str(h["kind"]) == "slam" else 2.0)
		Fx.shake(9.0 if str(h["kind"]) == "slam" else 18.0)
		if player.alive and player.pos2.distance_to(at) < r + player.radius * 0.5:
			player.take_damage(float(h["dmg"]), at)
		var burst := int(h["burst"])
		for k in burst:
			var dir := Vector2.from_angle(TAU * float(k) / float(burst) + randf() * 0.3)
			_spawn_boss_bullet(at + dir * 10.0, dir, 210.0, float(h["dmg"]) * 0.45)

func _on_boss_ring(count: int, gap: int, speed: float) -> void:
	if boss == null:
		return
	var start := randi() % count
	for i in count:
		if posmod(i - start, count) < gap:
			continue
		var dir := Vector2.from_angle(TAU * float(i) / float(count))
		_spawn_boss_bullet(boss.pos2 + dir * (boss.radius + 10.0), dir, speed, boss.damage_value * 0.5)
	sparks.ring(boss.position, boss.color(), 1.5, 6.0, 0.35, 0.18, 0.4)
	Sound.play("slam", -6.0, 1.3)
	Fx.shake(6.0)

func _on_boss_fan(dir: Vector2, count: int, arc: float, speed: float) -> void:
	if boss == null:
		return
	for i in count:
		var t := float(i) / float(maxi(1, count - 1)) - 0.5
		var d := dir.rotated(t * arc)
		_spawn_boss_bullet(boss.pos2 + d * (boss.radius + 6.0), d, speed * randf_range(0.95, 1.05), boss.damage_value * 0.45)
	Sound.play("shoot_enemy", 2.0, 0.65 if boss.kind == "titan" else 1.25)

func _on_boss_leap(to: Vector2, duration: float) -> void:
	if boss == null:
		return
	to = to.clamp(ARENA.position + Vector2(boss.radius, boss.radius), ARENA.end - Vector2(boss.radius, boss.radius))
	boss._leap_to = to
	var r := float(boss.stats.get("leap_radius", 150.0))
	hazards.append({"pos2": to, "radius": r, "t": duration, "max": duration, "dmg": boss.damage_value * 1.2, "burst": 14, "kind": "leap"})
	var w := ArenaSpace.to_world(to, 0.0)
	sparks.ring(w, Color(1.0, 0.2, 0.15, 0.95), r / ArenaSpace.SCALE, r / ArenaSpace.SCALE, duration, 0.06, 0.8)
	sparks.ring(w, Color(1.0, 0.3, 0.15, 0.8), 0.2, r / ArenaSpace.SCALE, duration, 0.9, 0.0)
	Sound.play("leap")
	hud.toast(tr("SIÇRAMA — dairenin dışına çık!"), KIT.RED, 1.0)

func _on_boss_blink_warn(to: Vector2, delay: float) -> void:
	if boss == null:
		return
	var fixed: Vector2 = to.clamp(ARENA.position + Vector2(140, 140), ARENA.end - Vector2(140, 140))
	for i in 8:
		if not _point_blocked(fixed, boss.radius + 20.0):
			break
		fixed = (fixed + (ARENA.get_center() - fixed).normalized() * 80.0)
	boss.set_blink_target(fixed)
	var w := ArenaSpace.to_world(fixed, 0.0)
	sparks.ring(w, Color(0.6, 0.9, 1.0), 5.0, 1.6, delay, 0.12, 0.5)
	sparks.burst(boss.position, boss.color(), 18, 7.0, 0.5, 1.0)
	Sound.play("teleport", -4.0, 0.8)

func _on_boss_blinked(from: Vector2, to: Vector2) -> void:
	if boss == null:
		return
	sparks.burst(ArenaSpace.to_world(from, 1.5), Color(0.75, 0.95, 1.0), 26, 10.0, 0.5, 1.2)
	sparks.burst(ArenaSpace.to_world(to, 1.5), Color(0.75, 0.95, 1.0), 30, 10.0, 0.6, 1.3)
	sparks.ring(ArenaSpace.to_world(to, 0.0), boss.color(), 1.0, 7.0, 0.4, 0.15)
	sparks.lightning(ArenaSpace.to_world(from, 1.5), ArenaSpace.to_world(to, 1.5), Color(0.7, 0.95, 1.0), 0.09, 0.25)
	for k in 10:
		var dir := Vector2.from_angle(TAU * float(k) / 10.0)
		_spawn_boss_bullet(from + dir * 20.0, dir, 180.0, boss.damage_value * 0.4)
	Sound.play("teleport")
	Fx.shake(6.0)

func _tick_beams() -> void:
	## Buz Hükümdarı lazerleri: uyarıda ince çizgi, ateşte kalın ışın + çarpışma.
	if boss == null or not is_instance_valid(boss) or not boss.alive or boss.beam_state == BossScript.BEAM_IDLE:
		return
	var origin: Vector2 = boss.pos2
	var from3 := ArenaSpace.to_world(origin, 1.0)
	var firing: bool = boss.beam_state == BossScript.BEAM_FIRE
	for angle in boss.beam_angles:
		var dir := Vector2.from_angle(angle)
		var end: Vector2 = origin + dir * boss.beam_length
		var to3 := ArenaSpace.to_world(end, 1.0)
		if firing:
			var flicker := 0.85 + 0.15 * sin(elapsed * 60.0)
			sparks.beam(from3, to3, Color(0.4, 0.85, 1.0, 0.7), boss.beam_width / ArenaSpace.SCALE * 1.4 * flicker, 0.035)
			sparks.beam(from3, to3, Color(0.95, 1.0, 1.0, 0.95), boss.beam_width / ArenaSpace.SCALE * 0.45, 0.035)
			if randf() < 0.5:
				sparks.spray(to3, -ArenaSpace.dir_to_world(dir), Color(0.7, 0.95, 1.0), 2, 6.0, 0.25, 0.8)
			if player.alive:
				var ab := end - origin
				var t := clampf((player.pos2 - origin).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if (origin + ab * t).distance_to(player.pos2) < boss.beam_width + player.radius:
					player.take_damage(boss.damage_value * float(boss.stats.get("beam_damage", 0.5)), origin + ab * t)
		else:
			sparks.beam(from3, to3, Color(1.0, 0.3, 0.4, 0.35 + 0.25 * sin(elapsed * 30.0)), 0.05, 0.035)
	if firing and fmod(elapsed, 0.25) < get_process_delta_time():
		Sound.play("laser", -6.0)

func _on_boss_dying() -> void:
	_boss_dying = true
	_boss_pop = 0.0
	for at in field.clear_hostile(boss.pos2, 99999.0):
		sparks.burst(ArenaSpace.to_world(at, 1.0), boss.color(), 2, 3.0, 0.3, 0.8)
	run.pending.clear()
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			e.dead = true
	Sound.play("boss_die")
	Fx.hitstop(0.25, 0.25)

func _on_boss_killed() -> void:
	if boss == null:
		return
	var at: Vector3 = boss.position
	sparks.burst(at, boss.color(), 90, 20.0, 1.4, 2.0)
	sparks.burst(at, Color(1, 1, 1), 40, 14.0, 0.9, 1.4)
	sparks.ring(at, boss.color(), 1.0, 22.0, 0.9, 0.16, 1.0)
	sparks.ring(at, Color(1, 1, 1), 0.5, 15.0, 0.6, 0.08)
	sparks.flash(at, boss.color(), 16.0, 26.0, 0.6)
	Sound.play("explode_big", 3.0, 0.7)
	Fx.shake(28.0)
	Fx.vibrate(200)
	world.flash_pulse(at, 1.0)
	menus.flash(Color(1, 1, 1), 0.35, 0.6)
	hud.float_text(at, "+%d" % boss.points(), KIT.GOLD, 34, 1.4)
	var drop_at: Vector2 = boss.pos2
	for kind in ["heal", "shield", "overdrive"]:
		_spawn_pickup(drop_at + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0), kind)
	nova = minf(NOVA_MAX, nova + 50.0)
	var dying: Node3D = boss
	boss = null
	_boss_dying = false
	dying.queue_free()
	world.set_danger(false)
	Sound.music("battle", 1.5)
	run.boss_died()

# --- Kartlar ----------------------------------------------------------------------
func _on_level_up(_level: int) -> void:
	_pending_card_open = true

func _card_counts() -> Dictionary:
	var counts := {}
	for id in loadout.taken:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

func _open_cards(play_sound := true) -> void:
	var count := int(GameData.number("leveling.cards", 3))
	_current_cards = loadout.roll(count, _rng)
	if _current_cards.is_empty():
		run.consume_level()
		return
	_cards_open = true
	get_tree().paused = true
	touch.release_all()
	hud.dimmed = true
	if play_sound:
		Sound.play("level_up")
	Sound.set_muffled(true)
	menus.show_cards(_current_cards, run.level - run.pending_levels + 1, rerolls, _card_counts())
	if demo and not show_cards_demo:
		_on_card_picked(randi() % _current_cards.size())

func _on_reroll() -> void:
	if not _cards_open or rerolls <= 0:
		return
	rerolls -= 1
	_open_cards(false)

func _on_card_picked(index: int) -> void:
	if not _cards_open or index < 0 or index >= _current_cards.size():
		return
	var card: Dictionary = _current_cards[index]
	loadout.apply(card)
	_apply_loadout()
	run.consume_level()
	_cards_open = false
	Sound.play("card_pick")
	if run.pending_levels > 0:
		_open_cards(false)
		return
	menus.hide_all()
	hud.dimmed = false
	get_tree().paused = false
	Sound.set_muffled(false)
	var accent: Color = KIT.TIER_COLOR.get(str(card.get("tier", "common")), KIT.CYAN)
	if str(card.get("tier", "")) == "synergy":
		hud.show_banner(tr("SİNERJİ"), tr(str(card.get("name", ""))), 2.0, accent)
		sparks.ring(player.position, accent, 0.4, 9.0, 0.7, 0.14, 1.0)
		Sound.play("synergy")
	else:
		hud.toast(tr(str(card.get("name", ""))), accent, 1.6)
	sparks.ring(player.position, accent, 0.4, 4.0, 0.5, 0.18)
	player.invuln = maxf(player.invuln, 0.8)

func _sync_drones() -> void:
	while drones.size() < loadout.i("drones"):
		var node := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		ball.radial_segments = 10
		ball.rings = 5
		node.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.6, 1.9, 2.2)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		drones.append({"node": node, "angle": 0.0, "cd": 0.0})
	while drones.size() > loadout.i("drones"):
		var drone = drones.pop_back()
		if is_instance_valid(drone["node"]):
			drone["node"].queue_free()

func _tick_drones(delta: float) -> void:
	if drones.is_empty():
		return
	var count := drones.size()
	for i in count:
		var drone: Dictionary = drones[i]
		drone["angle"] = float(drone["angle"]) + delta * 2.4
		var offset := Vector2.from_angle(float(drone["angle"]) + TAU * float(i) / float(count)) * 80.0
		var at: Vector2 = player.pos2 + offset
		var node: MeshInstance3D = drone["node"]
		if is_instance_valid(node):
			node.position = ArenaSpace.to_world(at, 1.35)
			node.visible = player.alive
			sparks.glow_add(node.position.x, node.position.z, 0.9, Color(0.6, 0.9, 1.0, 0.3))
		drone["cd"] = float(drone["cd"]) - delta
		if float(drone["cd"]) <= 0.0 and player.alive:
			var target_pos: Variant = null
			var best := 700.0
			for e in enemies:
				if e.dead or e.is_spawning():
					continue
				var d: float = e.pos2.distance_to(at)
				if d < best:
					best = d
					target_pos = e.pos2
			if target_pos == null and boss != null and is_instance_valid(boss) and boss.alive and boss.pos2.distance_to(at) < 800.0:
				target_pos = boss.pos2
			if target_pos != null:
				drone["cd"] = 0.28 if loadout.i("hive") > 0 else 0.55
				var dir: Vector2 = ((target_pos as Vector2) - at).normalized()
				var b = field.spawn(at, dir, 900.0, true, GameData.number("player.damage", 12.0) * loadout.m("damage_mult") * 0.55, 0.75, 0.8)
				b.chain = 1

# --- Oyuncu olayları ---------------------------------------------------------------
func _on_player_dash(at: Vector2, direction: Vector2) -> void:
	Sound.play("dash")
	var world_at := ArenaSpace.to_world(at, 1.0)
	sparks.spray(world_at, -ArenaSpace.dir_to_world(direction), Color(0.6, 1.0, 1.0), 16, 12.0, 0.4, 1.1, 0.5)
	sparks.ring(world_at, Color(0.5, 1.0, 1.0), 0.4, 2.6, 0.3, 0.2)
	Fx.punch(direction, 4.0)
	Fx.vibrate(12)

func _on_player_hurt(amount: float) -> void:
	Sound.play("hurt")
	if loadout.i("fortress") > 0 and player.alive:
		var dmg: float = GameData.number("player.damage", 12.0) * loadout.m("damage_mult") * 1.4
		for k in 12:
			var dir := Vector2.from_angle(TAU * float(k) / 12.0)
			var fb = field.spawn(player.pos2 + dir * 20.0, dir, 760.0, true, dmg, 0.55, 1.1, false, Color(1.0, 0.75, 0.3))
			fb.pierce = 1
		sparks.ring(player.position, Color(1.0, 0.75, 0.3), 0.5, 4.0, 0.3, 0.2)
	hud.flash_damage()
	hud.float_text(player.position, "-%d" % int(round(amount)), KIT.RED, 22, 0.8)
	_hurt_fx = 1.0
	Fx.shake(12.0)
	Fx.hitstop(0.06, 0.15)
	Fx.vibrate(45)
	sparks.burst(player.position, Color(1.0, 0.4, 0.5), 20, 8.0, 0.6, 1.2)
	sparks.flash(player.position, Color(1.0, 0.25, 0.35), 6.0, 9.0, 0.25)

func _on_shield_broken() -> void:
	Sound.play("shield_break")
	sparks.burst(player.position, Color(0.55, 0.8, 1.0), 26, 10.0, 0.5, 1.2)
	sparks.ring(player.position, Color(0.55, 0.8, 1.0), 1.0, 4.5, 0.4, 0.14)
	hud.toast(tr("KALKAN KIRILDI"), Color(0.55, 0.8, 1.0), 1.0)
	_shield_timer = 0.0
	Fx.shake(7.0)
	Fx.vibrate(30)

func _on_player_died() -> void:
	if loadout.i("revive") > _revives_used:
		_revives_used += 1
		player.alive = true
		player.hp = player.max_hp * 0.5
		player.invuln = 2.2
		_blast(420.0, 80.0 * loadout.m("damage_mult") * (1.0 + 0.12 * float(run.wave - 1)), KIT.GOLD)
		Sound.play("revive")
		hud.show_banner(tr("İKİNCİ ŞANS"), tr("yarı canla geri döndün"), 1.8, KIT.GOLD)
		return
	state = "dead"
	player.visible = false
	aim_marker.visible = false
	touch.set_enabled(false)
	hud.hint = ""
	run.end_run()
	_cores_earned = MetaProgress.run_reward(run.score, run.wave, run.bosses, loadout.m("core_mult"))
	_record = Settings.record_run(run.score, run.wave, run.kills, _cores_earned)
	Sound.play("game_over")
	Sound.play("explode_big", 0.0, 0.9)
	Sound.set_muffled(true, 0.8)
	world.set_danger(false)
	Fx.shake(22.0)
	Fx.vibrate(250)
	_hurt_fx = 1.0
	Engine.time_scale = 0.3
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_interval(0.9)
	tween.tween_callback(func(): Engine.time_scale = 1.0)
	sparks.burst(player.position, Color(0.6, 0.95, 1.0), 70, 15.0, 1.3, 1.7)
	sparks.burst(player.position, Color(1.0, 0.85, 0.5), 30, 10.0, 0.9, 1.3)
	sparks.ring(player.position, Color(0.6, 0.95, 1.0), 0.5, 11.0, 0.8, 0.14, 1.0)
	sparks.flash(player.position, Color(0.6, 0.9, 1.0), 12.0, 16.0, 0.5)

# --- Düşman olayları ---------------------------------------------------------------
func _reap(e) -> void:
	var elite: bool = e.elite
	var points: int = e.points() * (int(GameData.number("elite.points_mult", 3.0)) if elite else 1)
	var before: int = run.score
	run.enemy_died(points)
	var color: Color = e.color()
	var big: bool = e.kind == "tank" or elite
	sparks.burst(e.position, color, 26 if big else 16, 11.0 if big else 9.0, 0.6, 1.4 if big else 1.15)
	sparks.burst(e.position, Color(1, 1, 1), 6, 6.0, 0.3, 0.9)
	sparks.ring(e.position, color, 0.3, 4.2 if big else 2.6, 0.38, 0.2)
	sparks.flash(e.position, color, 4.0 if big else 2.5, 7.0, 0.18)
	hud.float_text(e.position + Vector3(0, 0.6, 0), "+%d" % (run.score - before), KIT.GOLD if elite else Color(0.75, 0.95, 1.0, 0.9), 22 if elite else 15, 0.8)
	Sound.play("explode_big" if big else "explode", -6.0 if big else 0.0)
	Fx.shake(8.0 if big else 3.5)
	if big:
		Fx.hitstop(0.04, 0.2)
	nova = minf(NOVA_MAX, nova + GameData.number("player.nova_per_kill", 4.5) * loadout.m("nova_rate_mult") * (3.0 if elite else 1.0))
	var vampire: float = loadout.m("vampire")
	if vampire > 0.0:
		_heal(vampire)
	if e.kind == "tank" and state == "playing" and not _boss_dying:
		for i in 2:
			var offset := Vector2.from_angle(randf() * TAU) * 34.0
			_spawn_enemy("chaser", e.pos2 + offset, 0.35, false)
		run.add_alive(2)
	if e.kind == "bomber":
		_bomber_blast(e)
	var explosive: int = loadout.i("explosive")
	if explosive > 0:
		var er := 85.0 + 22.0 * float(explosive)
		sparks.ring(e.position, Color(1.0, 0.6, 0.2), 0.3, er / ArenaSpace.SCALE, 0.3, 0.3, 1.0)
		_area_damage(e.pos2, er, GameData.number("player.damage", 12.0) * loadout.m("damage_mult") * (0.9 + 0.5 * float(explosive)), e)
	if elite or randf() < GameData.number("pickups.drop_chance", 0.14):
		_spawn_pickup(e.pos2, _roll_pickup())
	_check_milestone()
	if e == _target:
		_target = null
	if is_instance_valid(e):
		e.queue_free()

func _roll_pickup() -> String:
	var r := randf()
	var shield_w: float = GameData.number("pickups.shield_weight", 0.16)
	var od_w: float = GameData.number("pickups.overdrive_weight", 0.26)
	if r < shield_w and player.shield <= 0:
		return "shield"
	if r < shield_w + od_w:
		return "overdrive"
	return "heal"

func _check_milestone() -> void:
	var list: Array = GameData.value("scoring.milestones", [10, 25, 50, 100])
	if run.combo < int(list[0]):
		_milestone_index = 0
		return
	if _milestone_index < list.size() and run.combo >= int(list[_milestone_index]):
		var names := [tr("SERİ!"), tr("KATLİAM!"), tr("DURDURULAMAZ!"), tr("EFSANE!")]
		hud.toast(tr("%d KOMBO — %s") % [run.combo, names[mini(_milestone_index, names.size() - 1)]], KIT.GOLD.lerp(KIT.MAGENTA, float(_milestone_index) / 3.0), 1.5)
		Sound.play("combo", 4.0, 1.0 + 0.18 * float(_milestone_index))
		nova = minf(NOVA_MAX, nova + 10.0)
		_milestone_index += 1

func _on_spawn_due(kind: String) -> void:
	_spawn_enemy(kind, _spawn_point(), 0.6)

func _spawn_point(override_min := 0.0, override_max := 0.0) -> Vector2:
	var min_r: float = GameData.number("waves.spawn_radius_min", 620.0) if override_min <= 0.0 else override_min
	var max_r: float = GameData.number("waves.spawn_radius_max", 980.0) if override_max <= 0.0 else override_max
	for i in 30:
		var angle := randf() * TAU
		var dist := randf_range(min_r, max_r)
		var p: Vector2 = player.pos2 + Vector2.from_angle(angle) * dist
		p.x = clampf(p.x, ARENA.position.x + 70.0, ARENA.end.x - 70.0)
		p.y = clampf(p.y, ARENA.position.y + 70.0, ARENA.end.y - 70.0)
		if p.distance_to(player.pos2) > 300.0 and not _point_blocked(p, 50.0):
			return p
	return ARENA.get_center() + Vector2(0, 400)

func _boss_spawn_point() -> Vector2:
	## Boss her zaman ekranın üst tarafında, oyuncunun kuzeyinde doğar.
	for i in 12:
		var offset := Vector2(randf_range(-200.0, 200.0), -randf_range(300.0, 380.0))
		var p: Vector2 = player.pos2 + offset
		p.x = clampf(p.x, ARENA.position.x + 140.0, ARENA.end.x - 140.0)
		p.y = clampf(p.y, ARENA.position.y + 140.0, ARENA.end.y - 140.0)
		if p.distance_to(player.pos2) > 260.0 and not _point_blocked(p, 90.0):
			return p
	return (player.pos2 + Vector2(0, 420)).clamp(ARENA.position + Vector2(140, 140), ARENA.end - Vector2(140, 140))

func _spawn_enemy(kind: String, at: Vector2, delay := 0.5, allow_elite := true) -> void:
	var elite_def: Dictionary = {}
	if allow_elite and kind != "swarmer":
		var def: Dictionary = GameData.elite_def()
		if not def.is_empty() and run.wave >= int(def.get("from_wave", 4)) and not run.is_boss_wave(run.wave):
			var chance := minf(float(def.get("chance_max", 0.16)), float(def.get("chance", 0.05)) + float(def.get("chance_per_wave", 0.006)) * float(run.wave))
			if randf() < chance:
				elite_def = def
	var e = EnemyScript.new()
	var stats: Dictionary = GameData.enemy_stats(kind)
	stats["spawn_delay"] = delay
	e.setup(kind, stats, run.hp_scale(), run.damage_scale(), run.speed_scale(), elite_def)
	e.pos2 = at
	e.position = ArenaSpace.to_world(at, 0.3)
	entities.add_child(e)
	enemies.append(e)
	var c: Color = KIT.GOLD if e.elite else e.color()
	var r: float = e.radius / ArenaSpace.SCALE
	sparks.ring(e.position, c, r * 4.0, r * 1.1, delay, 0.14, 1.0)
	sparks.burst(e.position, c, 6, 4.0, 0.4, 0.8)
	if e.elite:
		Sound.play("elite")
		hud.toast(tr("ELİT DÜŞMAN"), KIT.GOLD, 1.2)
	else:
		Sound.play("spawn")

func _spawn_pickup(at: Vector2, kind: String) -> void:
	var p = PickupScript.new()
	at.x = clampf(at.x, ARENA.position.x + 30.0, ARENA.end.x - 30.0)
	at.y = clampf(at.y, ARENA.position.y + 30.0, ARENA.end.y - 30.0)
	p.setup(kind, _push_out(at, 20.0))
	entities.add_child(p)
	pickups.append(p)

# --- Dalga / harita olayları --------------------------------------------------------
func _on_wave_started(wave: int) -> void:
	_wave_time = 0.0
	_hunt_timer = 35.0
	if world != null and is_instance_valid(world):
		world.flash_pulse(player.position, 1.0)
	if not run.is_boss_wave(wave):
		Sound.play("wave_start")
		hud.show_banner(tr("DALGA %02d") % wave, tr("%d düşman") % run.pending.size(), 1.7)

func _on_wave_cleared(wave: int) -> void:
	_heal(8.0)
	hud.toast(tr("DALGA %02d TEMİZ   +%d") % [wave, int(GameData.number("waves.clear_bonus", 60)) * wave], KIT.GREEN, 1.8)
	Sound.play("wave_clear")

func _on_map_cleared(_index: int) -> void:
	_heal(player.max_hp * 0.25)
	hud.show_banner(tr("SEKTÖR TEMİZLENDİ"), tr("yeni bölgeye geçiliyor"), 2.6, KIT.GOLD)
	Sound.play("wave_clear", 3.0, 0.8)

func _on_map_changed(index: int) -> void:
	_build_map(index)
	player.reset(ARENA.get_center(), true)
	_apply_loadout()
	camera_rig.position = ArenaSpace.to_world(player.pos2, 0.0) + CAM_OFFSET * _zoom
	var theme: Dictionary = GameData.map_theme(index)
	menus.flash(world.color_a.lerp(Color(1, 1, 1), 0.5), 0.9, 0.9)
	hud.show_banner(tr(str(theme.get("name", "YENİ SEKTÖR"))), tr("sektör %d  ·  seviye %d") % [index + 1, run.level], 2.4, world.color_a.lerp(Color(1, 1, 1), 0.2))
	sparks.ring(player.position, world.color_a, 0.5, 14.0, 0.9, 0.12, 1.0)
	Fx.shake(8.0)

# --- HUD ---------------------------------------------------------------------------
func _update_hud() -> void:
	if state == "menu":
		return
	var enemy_positions: Array = []
	var elite_positions: Array = []
	var bars: Array = []
	var pointers: Array = []
	var few: bool = run.enemies_left() <= 5
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.elite:
			elite_positions.append(e.pos2)
		else:
			enemy_positions.append(e.pos2)
		if e.hp_shown > 0.0 and (e.elite or e.max_hp >= 60.0) and not e.is_spawning():
			bars.append([e.position, e.hp_ratio(), e.elite])
		if few or e.elite:
			pointers.append([e.position, KIT.GOLD if e.elite else KIT.RED, 1.0])
	var pickup_positions: Array = []
	for p in pickups:
		if is_instance_valid(p):
			pickup_positions.append(p.pos2)
			pointers.append([p.position, p.color(), 0.8])
	var boss_pos: Variant = null
	var boss_ratio := 0.0
	var boss_on: bool = boss != null and is_instance_valid(boss)
	if boss_on:
		boss_pos = boss.pos2
		boss_ratio = clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
		pointers.append([boss.position, boss.color(), 1.5])
	touch.dash_ratio = player.dash_ratio()
	touch.nova_ratio = nova / NOVA_MAX
	touch.auto_fire = Settings.auto_fire
	hud.update_state({
		"hp": player.hp, "max_hp": player.max_hp, "shield": player.shield, "score": run.score,
		"wave": run.wave, "combo": run.combo, "combo_ratio": run.combo_ratio(), "mult": run.multiplier(),
		"dash_ratio": player.dash_ratio(), "nova_ratio": nova / NOVA_MAX,
		"overdrive": player.overdrive, "left": run.enemies_left(),
		"best": Settings.best, "level": run.level, "xp_ratio": run.hp_ratio_for_next(),
		"map_name": str(GameData.map_theme(map_index).get("name", "")),
		"boss_active": boss_on and boss.alive, "boss_ratio": boss_ratio,
		"boss_name": boss.display_name if boss_on else "", "boss_phase": boss.phase if boss_on else 1,
		"boss_color": boss.color() if boss_on else KIT.RED,
		"in_break": run.phase == RunStateScript.PHASE_BREAK,
		"minimap": {
			"arena": ARENA, "player": player.pos2, "aim": player.aim2, "enemies": enemy_positions,
			"elites": elite_positions, "pickups": pickup_positions, "boss": boss_pos, "obstacles": obstacles,
		},
		"bars": bars, "pointers": pointers,
	})
