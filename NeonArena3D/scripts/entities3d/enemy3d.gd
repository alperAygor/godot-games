extends Node3D
## 3B düşman: 13 tür (7 temel + C2'nin 6 yeni davranışı), türe özel davranış. Mantık 2B, görüntü 3B.
## Yeni türler (veri: data/balance/enemies.json): charger (çizgi uyarılı hücum), shielder (önü zırhlı), medic (iyileştirme
## darbesi), minelayer (gecikmeli mayın), blinker (ışınlan + yer halkası), brooder (yavrulayan ana gemi).
## Dünyaya dokunan eylemler (mayın, iyileştirme, ışınlanma, yavrulama) burada YAPILMAZ: düşman `action` alanını ayarlar,
## Spawner.tick_enemies tüketir (ctx gerektiren her şey orada). Kare başına bellek ayırma yoktur.

const MODELS := {
	"chaser": "res://assets/models/chaser.glb",
	"shooter": "res://assets/models/shooter.glb",
	"tank": "res://assets/models/tank.glb",
	"swarmer": "res://assets/models/swarmer.glb",
	"bomber": "res://assets/models/bomber.glb",
	"sniper": "res://assets/models/sniper.glb",
	"orbiter": "res://assets/models/orbiter.glb",
	"charger": "res://assets/models/charger.glb",
	"shielder": "res://assets/models/shielder.glb",
	"medic": "res://assets/models/medic.glb",
	"minelayer": "res://assets/models/minelayer.glb",
	"blinker": "res://assets/models/blinker.glb",
	"brooder": "res://assets/models/brooder.glb",
}
const SCALES := {"chaser": 1.2, "shooter": 1.25, "tank": 1.15, "swarmer": 1.15, "bomber": 1.2, "sniper": 1.2, "orbiter": 1.2,
	"charger": 1.0, "shielder": 1.2, "medic": 1.2, "minelayer": 1.2, "blinker": 1.2, "brooder": 1.15}

## Spawner'ın tükettiği eylemler (bir karede en çok bir tane).
const ACT_NONE := 0
const ACT_MINE := 1          ## mayıncı: oyuncunun önüne gecikmeli mayın bırak
const ACT_PULSE_START := 2   ## onarıcı: şarj başladı (Spawner uygun hedef yoksa cancel_charge çağırır)
const ACT_PULSE := 3         ## onarıcı: iyileştirme darbesi
const ACT_BLINK_START := 4   ## sıçrayıcı: kaybolma uyarısı başladı (eski konumda küçülen halka)
const ACT_BLINK_LAND := 5    ## sıçrayıcı: indi (action_pos = eski konum); yer halkası burada başlar
const ACT_HATCH_START := 6   ## kuluçka: şişme uyarısı
const ACT_HATCH := 7         ## kuluçka: yavrular çıkar

## Durum makinesi sabitleri (tür başına `state`).
const CH_APPROACH := 0
const CH_WINDUP := 1
const CH_DASH := 2
const CH_RECOVER := 3
const CH_STATES := ["approach", "windup", "dash", "recover"]
const MD_IDLE := 0
const MD_CHARGE := 1
const BL_ROAM := 0
const BL_FADE := 1
const BL_STRIKE := 2
const BR_IDLE := 0
const BR_SWELL := 1

static var _laser_mesh: BoxMesh
static var _laser_mat: StandardMaterial3D
static var _tele_mesh: BoxMesh
static var _tele_mat: StandardMaterial3D
static var _block_mat: StandardMaterial3D
static var _halo_mesh: TorusMesh
static var _prefix_overlay: Dictionary = {}
static var _prefix_halo: Dictionary = {}

var kind := "chaser"
var stats: Dictionary = {}
var pos2 := Vector2.ZERO
var velocity2 := Vector2.ZERO
var knock2 := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var radius := 14.0
var damage_value := 10.0
var speed_value := 120.0
var spawn_delay := 0.5
var touch_cd := 0.0
var fire_cd := 0.0
var charge := 0.0
var fuse := -1.0
var fuse_started := false
var explode_now := false
var dead := false
var elite := false
var strafe := 1.0
var dash_hit := 0.0
var hp_shown := 0.0

# --- C2: yeni davranışlar ve elit ön ekleri ---
var prefix := ""                    ## elit ön eki kimliği ("" = düz elit / elit değil)
var prefix_color := Color(1.0, 0.72, 0.18)
var prefix_points_mult := 0.0       ## 0 = genel elit çarpanı
var take_mult := 1.0                ## alınan hasar çarpanı (zırhlı ön ek, hücumcunun yorgun anı)
var lifesteal := 0.0                ## emici ön ek: temas vuruşunda maks canın bu oranı kadar iyileşir
var split_count := 0                ## bölünen ön ek: ölünce kaç parça
var split_hp_frac := 0.5
var split_delay := 0.6
var bonus_pickups := 0              ## ön ekin ek ödülü
var action := ACT_NONE
var action_pos := Vector2.ZERO
var state := 0
var state_t := 0.0
var cool := 0.0
var aim := Vector2.ZERO
var hatched := 0
var shield_angle := 0.0
var from_split := false
var blocked_hits := 0               ## kalkanın engellediği vuruş sayısı (probe/ölçüm)
var model: MeshInstance3D
var tele: MeshInstance3D
var halo: MeshInstance3D
var laser: MeshInstance3D
var _time := 0.0
var _bob_offset := 0.0
var _flash := 0.0
var _spawn_total := 0.5
var _base_scale := 1.0
var _color := Color(1, 0.3, 0.5)
var _base_damage := 10.0
var _shield_cos := 0.0
var _shield_ready := false
var _last_touch := 0.0
var _block_t := 0.0
var _vis := 1.0                     ## görünür ölçek çarpanı (sıçrayıcı kaybolma, kuluçka şişmesi)
var _gated := false
var _force_vel := false
var _face := Vector2.ZERO

func setup(kind_name: String, data: Dictionary, hp_scale := 1.0, dmg_scale := 1.0, speed_scale := 1.0, elite_def: Dictionary = {}) -> void:
	kind = kind_name
	stats = data
	elite = not elite_def.is_empty()
	max_hp = float(data.get("hp", 20.0)) * hp_scale
	radius = float(data.get("radius", 15.0))
	damage_value = float(data.get("damage", 10.0)) * dmg_scale
	speed_value = float(data.get("speed", 120.0)) * speed_scale
	_base_scale = float(SCALES.get(kind, 1.0))
	if elite:
		max_hp *= float(elite_def.get("hp_mult", 3.0))
		damage_value *= float(elite_def.get("damage_mult", 1.3))
		var s := float(elite_def.get("scale", 1.3))
		radius *= s
		_base_scale *= s
		prefix = str(elite_def.get("prefix", ""))
		if prefix != "":
			speed_value *= float(elite_def.get("speed_mult", 1.0))
			take_mult = float(elite_def.get("damage_taken_mult", 1.0))
			lifesteal = float(elite_def.get("lifesteal_frac", 0.0))
			split_count = int(elite_def.get("split_count", 0))
			split_hp_frac = float(elite_def.get("split_hp_frac", 0.5))
			split_delay = float(elite_def.get("split_delay", 0.6))
			bonus_pickups = int(elite_def.get("bonus_pickups", 0))
			prefix_points_mult = float(elite_def.get("points_mult", 0.0))
			prefix_color = Color.from_string(str(elite_def.get("color", "#ffb82e")), prefix_color)
	_base_damage = damage_value
	hp = max_hp
	spawn_delay = float(data.get("spawn_delay", 0.5))
	_spawn_total = maxf(0.05, spawn_delay)
	fire_cd = randf_range(0.6, 1.6)
	strafe = 1.0 if randf() < 0.5 else -1.0
	_bob_offset = randf() * TAU
	_color = Color.from_string(str(stats.get("color", "#ff3d6e")), Color(1, 0.3, 0.5))
	match kind:   # yeni türlerin başlangıç sayaçları (eski türlerin rastgele akışı değişmez)
		"charger":
			cool = randf_range(0.4, 1.2)
		"shielder":
			_shield_cos = cos(deg_to_rad(float(stats.get("shield_arc", 130.0))) * 0.5)
		"medic":
			cool = randf_range(1.0, float(stats.get("pulse_interval", 3.4)))
		"minelayer":
			cool = randf_range(0.8, float(stats.get("mine_interval", 3.2)))
		"blinker":
			cool = randf_range(1.5, float(stats.get("blink_interval", 4.6)))
		"brooder":
			cool = randf_range(1.2, float(stats.get("hatch_interval", 3.8)))

func _ready() -> void:
	var path: String = MODELS.get(kind, "")
	model = ModelCache.instance(path, 0.01)
	add_child(model)
	if elite:
		model.material_overlay = _overlay()
		_make_halo()
	if kind == "charger":
		_make_tele()
	if kind == "sniper":
		if _laser_mesh == null:
			_laser_mesh = BoxMesh.new()
			_laser_mesh.size = Vector3(1.0, 1.0, 1.0)
			_laser_mat = StandardMaterial3D.new()
			_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_laser_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_laser_mat.albedo_color = Color(0.3, 1.8, 1.1, 0.75)
			_laser_mesh.material = _laser_mat
		laser = MeshInstance3D.new()
		laser.mesh = _laser_mesh
		laser.visible = false
		laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(laser)

func color() -> Color:
	return _color

func points() -> int:
	## Not: CombatSystem.reap elitte sabit `elite.points_mult` ile çarpar; ön ek çarpanı burada oranlanır.
	var base := int(stats.get("points", 10))
	if elite and prefix_points_mult > 0.0:
		return int(round(float(base) * prefix_points_mult / maxf(0.01, GameData.number("elite.points_mult", 3.0))))
	return base

func is_spawning() -> bool:
	return spawn_delay > 0.0

func hp_ratio() -> float:
	return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)

func shield_blocks(push: Vector2, amount: float) -> bool:
	## Kalkancı: yönlü (itmeli) ve ağır olmayan vuruş ön yaydan geliyorsa engellenir. Zincir şimşeği (itme yok), yan/arka
	## vuruş ve `shield_pierce_damage` üstü (nova, raylı top) delip geçer.
	if kind != "shielder" or push == Vector2.ZERO or amount >= float(stats.get("shield_pierce_damage", 40.0)):
		return false
	return (-push).normalized().dot(Vector2.from_angle(shield_angle)) > _shield_cos

func take_damage(amount: float, push := Vector2.ZERO) -> void:
	if dead:
		return
	var dmg := amount * take_mult
	if kind == "charger" and state == CH_RECOVER:
		dmg *= float(stats.get("recover_taken_mult", 1.5))   # yorgun anında açık hedef
	if shield_blocks(push, amount):
		dmg *= float(stats.get("shield_block", 0.12))
		_block_t = 1.0
		blocked_hits += 1
		knock2 += push * 0.3
	else:
		_flash = 1.0
		knock2 += push
	hp -= dmg
	hp_shown = 2.2
	if hp <= 0.0:
		dead = true

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	hp_shown = 1.4

func shrink(hp_frac: float, size: float) -> void:
	## Bölünen parçalar: daha az can, daha küçük gövde.
	max_hp *= hp_frac
	hp = max_hp
	radius *= size
	_base_scale *= size

func cancel_charge() -> void:
	## Onarıcı: darbeye uygun yaralı müttefik yok → şarjı iptal et, kısa süre sonra yeniden dene.
	if kind == "medic":
		state = MD_IDLE
		cool = float(stats.get("retry_delay", 0.8))

func contact_enabled() -> bool:
	## Temas hasarı açık mı? Hücumcu: yalnız yaklaşırken ve atılırken; uyarı + yorgunlukta kapalı.
	if kind == "charger":
		return state == CH_APPROACH or state == CH_DASH
	if kind == "blinker":
		return state == BL_ROAM
	return true

func state_name() -> String:
	if kind == "charger":
		return CH_STATES[state]
	return str(state)

func tick(delta: float, target: Vector2) -> bool:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 9.0)
	_block_t = maxf(0.0, _block_t - delta * 6.0)
	if lifesteal > 0.0 and touch_cd > _last_touch + 0.0001 and not is_spawning():
		heal(max_hp * lifesteal)   # emici: temas vuruşu iyileştirir (CombatSystem touch_cd'yi vuruşta kurar)
		_flash = 1.0
	touch_cd = maxf(0.0, touch_cd - delta)
	dash_hit = maxf(0.0, dash_hit - delta)
	hp_shown = maxf(0.0, hp_shown - delta)
	if is_spawning():
		spawn_delay -= delta
		var grow := 1.0 - clampf(spawn_delay / _spawn_total, 0.0, 1.0)
		position = ArenaSpace.to_world(pos2, 0.3 + 0.55 * grow)
		rotation.y += delta * 9.0 * (1.0 - grow)
		_apply_visual(grow * grow)
		return false

	var to_target := target - pos2
	var dist := to_target.length()
	var dir := to_target.normalized()
	var desired := dir
	var wants_fire := false
	var face_target := false
	_force_vel = false
	_face = Vector2.ZERO
	match kind:
		"shooter":
			var keep := float(stats.get("keep_distance", 280.0))
			if dist < keep - 50.0:
				desired = -dir
			elif dist > keep + 50.0:
				desired = dir
			else:
				desired = Vector2(-dir.y, dir.x) * strafe
			fire_cd -= delta
			if dist < 640.0 and fire_cd <= 0.0:
				fire_cd = float(stats.get("fire_interval", 1.9)) * randf_range(0.85, 1.2)
				wants_fire = true
		"orbiter":
			var orbit := float(stats.get("orbit_radius", 240.0))
			var tangent := Vector2(-dir.y, dir.x) * strafe
			var radial := (dist - orbit) / maxf(1.0, orbit)
			desired = (tangent + dir * clampf(radial, -1.0, 1.0) * 1.4).normalized()
			fire_cd -= delta
			if fire_cd <= 0.0 and dist < 700.0:
				fire_cd = float(stats.get("fire_interval", 1.6))
				wants_fire = true
		"sniper":
			var keep_s := float(stats.get("keep_distance", 470.0))
			if dist > keep_s + 60.0:
				desired = dir
			elif dist < keep_s - 120.0:
				desired = -dir
			else:
				desired = Vector2(-dir.y, dir.x) * strafe * 0.35
			if dist < 760.0:
				charge += delta
				face_target = true
				if charge >= float(stats.get("charge_time", 1.1)):
					charge = -float(stats.get("fire_interval", 2.8)) * 0.35
					wants_fire = true
			else:
				charge = minf(charge, 0.0)
		"bomber":
			desired = dir * 1.25
			if fuse < 0.0 and dist < float(stats.get("fuse_range", 105.0)):
				fuse = float(stats.get("fuse_time", 0.55))
			if fuse >= 0.0:
				desired = dir * 0.35
				fuse -= delta
				_flash = maxf(_flash, 0.5 + 0.5 * sin(_time * 40.0))
				if fuse <= 0.0:
					explode_now = true
		"charger":
			desired = _tick_charger(delta, dir, dist)
		"shielder":
			desired = dir
			if not _shield_ready:
				_shield_ready = true
				shield_angle = dir.angle()
			var diff := wrapf(dir.angle() - shield_angle, -PI, PI)
			var step := float(stats.get("shield_turn", 1.4)) * delta
			shield_angle += clampf(diff, -step, step)
			_face = Vector2.from_angle(shield_angle)
		"medic":
			desired = _tick_medic(delta, dir, dist)
		"minelayer":
			var orbit_m := float(stats.get("orbit_radius", 390.0))
			var tangent_m := Vector2(-dir.y, dir.x) * strafe
			desired = (tangent_m + dir * clampf((dist - orbit_m) / maxf(1.0, orbit_m), -1.0, 1.0) * 1.4).normalized()
			cool -= delta
			if cool <= 0.0 and action == ACT_NONE and dist < 900.0:
				cool = float(stats.get("mine_interval", 3.2))
				action = ACT_MINE
		"blinker":
			desired = _tick_blinker(delta, dir, dist, target)
		"brooder":
			desired = _tick_brooder(delta, dir, dist)
		_:
			desired = dir

	var turn := float(stats.get("turn", 3.0))
	if not _force_vel:
		velocity2 = velocity2.lerp(desired * speed_value, clampf(turn * delta, 0.0, 1.0))
	if not contact_enabled():
		touch_cd = maxf(touch_cd, 0.25)   # uyarı/yorgunluk anında temas hasarı yok (CombatSystem touch_cd'ye bakar)
		_gated = true
	elif _gated:
		_gated = false
		touch_cd = 0.0                    # temas yeniden açılır açılmaz (atılma anı) hasar verebilir
	_last_touch = touch_cd
	knock2 = knock2.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	pos2 += (velocity2 + knock2) * delta
	var hover := 0.85 + sin(_time * 2.6 + _bob_offset) * 0.09
	position = ArenaSpace.to_world(pos2, hover)
	var facing := dir if face_target else velocity2
	if _face != Vector2.ZERO:
		facing = _face
	if facing.length() > 0.5:
		var want := atan2(-facing.x, -facing.y)
		rotation = Vector3(0.0, lerp_angle(rotation.y, want, clampf(delta * 10.0, 0.0, 1.0)), 0.0)
	if laser != null:
		var ratio := clampf(charge / maxf(0.01, float(stats.get("charge_time", 1.1))), 0.0, 1.0)
		laser.visible = ratio > 0.02
		if laser.visible:
			var length := dist / ArenaSpace.SCALE
			var width := 0.015 + 0.05 * ratio * ratio
			laser.scale = Vector3(width, width, length)
			laser.position = Vector3(0, 0.15, -length * 0.5)
	_apply_visual(1.0)
	return wants_fire

func _apply_visual(grow: float) -> void:
	if model == null:
		return
	var flash := clampf(_flash, 0.0, 1.0)
	model.scale = Vector3.ONE * _base_scale * maxf(0.02, grow) * _vis * (1.0 + 0.14 * flash)
	if flash > 0.45:
		model.material_overlay = ModelCache.flash_material()
	elif _block_t > 0.4:
		model.material_overlay = _block_material()
	else:
		model.material_overlay = _overlay() if elite else null
	if halo != null:
		halo.rotation.y = _time * 1.4
		halo.visible = grow > 0.95

# --- C2: tür davranışları -----------------------------------------------------------------
func _kite(dir: Vector2, dist: float, keep: float) -> Vector2:
	if dist < keep - 60.0:
		return -dir
	if dist > keep + 80.0:
		return dir
	return Vector2(-dir.y, dir.x) * strafe

func _tick_charger(delta: float, dir: Vector2, dist: float) -> Vector2:
	## Yaklaş → (uyarı çizgisi, yönü kilitli) → atılma → yorgunluk. Temas hasarı yalnız yaklaşırken ve atılırken.
	var desired := dir
	match state:
		CH_APPROACH:
			cool -= delta
			if cool <= 0.0 and dist < float(stats.get("trigger_range", 440.0)) and dist > float(stats.get("min_range", 140.0)):
				state = CH_WINDUP
				state_t = float(stats.get("windup", 0.9))
				aim = dir
				rotation.y = atan2(-aim.x, -aim.y)
		CH_WINDUP:
			state_t -= delta
			_force_vel = true
			velocity2 = Vector2.ZERO
			_face = aim
			desired = Vector2.ZERO
			if state_t <= 0.0:
				state = CH_DASH
				state_t = float(stats.get("dash_time", 0.42))
				damage_value = _base_damage * float(stats.get("dash_damage_mult", 1.6))
		CH_DASH:
			state_t -= delta
			_force_vel = true
			velocity2 = aim * float(stats.get("dash_speed", 780.0))
			_face = aim
			if state_t <= 0.0:
				state = CH_RECOVER
				state_t = float(stats.get("recover", 1.3))
				damage_value = _base_damage
				velocity2 = Vector2.ZERO
		_:
			state_t -= delta
			_force_vel = true
			velocity2 = Vector2.ZERO
			desired = Vector2.ZERO
			if state_t <= 0.0:
				state = CH_APPROACH
				cool = float(stats.get("cooldown", 1.4))
	if tele != null:
		var show := state == CH_WINDUP
		tele.visible = show
		if show:
			var total := maxf(0.05, float(stats.get("windup", 0.9)))
			var k := 1.0 - clampf(state_t / total, 0.0, 1.0)
			var length := float(stats.get("dash_speed", 780.0)) * float(stats.get("dash_time", 0.42)) / ArenaSpace.SCALE
			var width := float(stats.get("tele_width", 38.0)) / ArenaSpace.SCALE * (0.35 + 0.65 * k)
			var off := radius / ArenaSpace.SCALE
			tele.scale = Vector3(width, 0.05, length)
			tele.position = Vector3(0.0, -0.74, -(length * 0.5 + off))
	return desired

func _tick_medic(delta: float, dir: Vector2, dist: float) -> Vector2:
	var desired := _kite(dir, dist, float(stats.get("keep_distance", 340.0)))
	if state == MD_CHARGE:
		state_t -= delta
		desired *= 0.25
		_vis = 1.0 + 0.12 * sin(_time * 18.0)
		if state_t <= 0.0 and action == ACT_NONE:
			state = MD_IDLE
			_vis = 1.0
			cool = float(stats.get("pulse_interval", 3.4))
			action = ACT_PULSE
	else:
		cool -= delta
		if cool <= 0.0 and action == ACT_NONE:
			state = MD_CHARGE
			state_t = float(stats.get("pulse_charge", 0.85))
			action = ACT_PULSE_START
	return desired

func _tick_blinker(delta: float, dir: Vector2, _dist: float, target: Vector2) -> Vector2:
	match state:
		BL_ROAM:
			cool -= delta
			if cool <= 0.0 and action == ACT_NONE:
				state = BL_FADE
				state_t = float(stats.get("blink_windup", 0.7))
				action = ACT_BLINK_START
			return dir
		BL_FADE:
			state_t -= delta
			_force_vel = true
			velocity2 = Vector2.ZERO
			var total := maxf(0.05, float(stats.get("blink_windup", 0.7)))
			_vis = maxf(0.1, state_t / total) * (0.8 + 0.2 * sin(_time * 40.0))
			if state_t <= 0.0 and action == ACT_NONE:
				action_pos = pos2
				pos2 = target + Vector2.from_angle(randf() * TAU) * float(stats.get("land_dist", 120.0))
				state = BL_STRIKE
				state_t = float(stats.get("strike_delay", 0.9)) + 0.2
				action = ACT_BLINK_LAND
		_:
			state_t -= delta
			_force_vel = true
			velocity2 = Vector2.ZERO
			_vis = minf(1.0, _vis + delta * 6.0)
			if state_t <= 0.0:
				state = BL_ROAM
				_vis = 1.0
				cool = float(stats.get("blink_interval", 4.6))
	return Vector2.ZERO

func _tick_brooder(delta: float, dir: Vector2, dist: float) -> Vector2:
	var desired := _kite(dir, dist, float(stats.get("keep_distance", 470.0)))
	if state == BR_SWELL:
		state_t -= delta
		desired *= 0.2
		var total := maxf(0.05, float(stats.get("hatch_charge", 0.9)))
		_vis = 1.0 + 0.3 * (1.0 - clampf(state_t / total, 0.0, 1.0))
		if state_t <= 0.0 and action == ACT_NONE:
			state = BR_IDLE
			_vis = 1.0
			hatched += 1
			cool = float(stats.get("hatch_interval", 3.8))
			action = ACT_HATCH
	elif hatched < int(stats.get("max_hatches", 4)):
		cool -= delta
		if cool <= 0.0 and action == ACT_NONE:
			state = BR_SWELL
			state_t = float(stats.get("hatch_charge", 0.9))
			action = ACT_HATCH_START
	return desired

# --- C2: görsel yardımcılar (paylaşılan mesh/malzeme; düşman başına yalnız düğüm) ------------------
func _make_tele() -> void:
	if _tele_mesh == null:
		_tele_mesh = BoxMesh.new()
		_tele_mesh.size = Vector3.ONE
		_tele_mat = StandardMaterial3D.new()
		_tele_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tele_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tele_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tele_mat.albedo_color = Color(1.0, 0.85, 0.15, 0.6)
		_tele_mesh.material = _tele_mat
	tele = MeshInstance3D.new()
	tele.mesh = _tele_mesh
	tele.visible = false
	tele.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tele)

func _make_halo() -> void:
	if prefix == "":
		return
	if _halo_mesh == null:
		_halo_mesh = TorusMesh.new()
		_halo_mesh.inner_radius = 0.9
		_halo_mesh.outer_radius = 1.0
		_halo_mesh.rings = 36
		_halo_mesh.ring_segments = 4
	if not _prefix_halo.has(prefix):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(prefix_color.r, prefix_color.g, prefix_color.b, 0.85)
		_prefix_halo[prefix] = m
	halo = MeshInstance3D.new()
	halo.mesh = _halo_mesh
	halo.material_override = _prefix_halo[prefix]
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := radius / ArenaSpace.SCALE * 1.5
	halo.scale = Vector3(r, r, r)
	halo.position = Vector3(0.0, -0.72, 0.0)
	add_child(halo)

func _overlay() -> Material:
	## Elit işareti: ön ekli elitte ön ek renginde, düz elitte altın ışıltı.
	if prefix == "":
		return ModelCache.elite_material()
	if not _prefix_overlay.has(prefix):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(prefix_color.r, prefix_color.g, prefix_color.b, 0.5)
		_prefix_overlay[prefix] = m
	return _prefix_overlay[prefix]

static func _block_material() -> StandardMaterial3D:
	if _block_mat == null:
		_block_mat = StandardMaterial3D.new()
		_block_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_block_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_block_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_block_mat.albedo_color = Color(0.25, 0.6, 1.0, 0.7)
	return _block_mat
