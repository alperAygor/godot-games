extends Node3D
class_name Boss3D
## Üç boss türü, her biri iki fazlı:
##   sentinel — radyal dalga, nişanlı üçlü, uyarılı hücum, (faz 2) sarmal yaylım
##   titan    — yer uyarı daireleri, boşluklu şok dalgası, alev yelpazesi, (faz 2) oyuncuya sıçrama
##   frost    — dönen lazer ışınları, buz kristali yelpazesi, ışınlanma, (faz 2) dörtlü sarmal
## Boss yalnızca "ne zaman, nereye" kararını verir; mermi/hasar game3d.gd'de.

signal radial_wave(count: int)
signal aimed_shot(direction: Vector2)
signal summon(kind: String, count: int)
signal phase_changed(phase: int)
signal charge_warn(direction: Vector2, duration: float)
signal charge_started(direction: Vector2)
signal spiral_shot(angle: float, arms: int)
signal zone_marked(at: Vector2, radius: float, delay: float, burst: int)
signal ring_burst(count: int, gap: int, speed: float)
signal fan_shot(direction: Vector2, count: int, arc: float, speed: float)
signal leap_started(to: Vector2, duration: float)
signal blink_warn(to: Vector2, delay: float)
signal blinked(from: Vector2, to: Vector2)
signal beam_warned

const BEAM_IDLE := 0
const BEAM_WARN := 1
const BEAM_FIRE := 2

var kind := "sentinel"
var stats: Dictionary = {}
var display_name := "BOSS"
var tint := Color(1, 0.2, 0.4)
var pos2 := Vector2.ZERO
var hp := 1.0
var max_hp := 1.0
var radius := 60.0
var damage_value := 30.0
var phase := 1
var alive := true
var dying := 0.0
var intro := 1.2
var height := 1.9
var model: MeshInstance3D
var glow_light: OmniLight3D

## Lazer durumu (frost): game3d her kare okur, çizer ve çarpışmayı denetler.
var beam_state := BEAM_IDLE
var beam_angles: Array[float] = []
var beam_length := 620.0
var beam_width := 24.0

var _time := 0.0
var _flash := 0.0
var _target := Vector2.ZERO
var _t: Dictionary = {}
# sentinel
var _windup := 0.0
var _charge_left := 0.0
var _charge_dir := Vector2.ZERO
var _spiral_left := 0
var _spiral_tick := 0.0
var _spiral_angle := 0.0
# titan
var _fan_left := 0
var _fan_tick := 0.0
var _leap_from := Vector2.ZERO
var _leap_to := Vector2.ZERO
var _leap_time := 0.0
var _leap_total := 0.0
# frost
var _beam_timer := 0.0
var _beam_dir := 1.0
var _blink_to := Vector2.ZERO
var _blink_left := 0.0

func setup(data: Dictionary, hp_scale := 1.0, dmg_scale := 1.0, boss_name := "", boss_color := "", boss_kind := "sentinel") -> void:
	kind = boss_kind
	stats = data
	max_hp = float(data.get("hp", 1600.0)) * float(data.get("hp_mult", 1.0)) * hp_scale
	hp = max_hp
	radius = float(data.get("radius", 62.0))
	damage_value = float(data.get("damage", 30.0)) * dmg_scale
	display_name = boss_name if boss_name != "" else str(data.get("name", "BOSS"))
	tint = Color.from_string(boss_color if boss_color != "" else str(data.get("color", "#ff2d70")), Color(1, 0.2, 0.4))
	beam_length = float(data.get("beam_length", 620.0))
	beam_width = float(data.get("beam_width", 24.0))
	height = 1.5 if kind == "titan" else 1.9
	match kind:
		"titan":
			_t = {"slam": 2.0, "wave": 4.0, "fan": 1.4, "leap": 5.0, "summon": 8.0}
		"frost":
			_t = {"beam": 2.5, "shard": 1.4, "blink": 6.0, "spiral": 3.0, "summon": 9.0}
		_:
			_t = {"radial": 3.2, "summon": 6.0, "charge": 5.0, "aim": 1.4, "spiral": float(data.get("spiral_interval", 5.5))}

func _ready() -> void:
	model = ModelCache.instance(str(stats.get("model", "res://assets/models/boss.glb")), 0.01)
	add_child(model)
	glow_light = OmniLight3D.new()
	glow_light.light_color = tint
	glow_light.light_energy = 3.0
	glow_light.omni_range = 11.0
	glow_light.position = Vector3(0, 0.6, 0)
	glow_light.shadow_enabled = false
	add_child(glow_light)

func color() -> Color:
	return tint

func points() -> int:
	return int(stats.get("points", 600))

func is_charging() -> bool:
	return _charge_left > 0.0 or (_leap_total > 0.0 and _leap_time < _leap_total)

func is_airborne() -> bool:
	return _leap_total > 0.0 and _leap_time < _leap_total

func take_damage(amount: float) -> void:
	if not alive or intro > 0.0:
		return
	hp -= amount
	_flash = 1.0
	if phase == 1 and hp <= max_hp * float(stats.get("phase2_at", 0.5)):
		phase = 2
		_t["spiral"] = 1.5
		_t["charge"] = 2.6
		_t["leap"] = 1.2
		_t["beam"] = minf(float(_t.get("beam", 1.0)), 1.5)
		phase_changed.emit(2)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		dying = 1.25
		beam_state = BEAM_IDLE

func _tick_timer(key: String, delta: float) -> bool:
	_t[key] = float(_t.get(key, 0.0)) - delta
	return float(_t[key]) <= 0.0

func _num(key: String, fallback: float) -> float:
	return float(stats.get(key, fallback))

func tick(delta: float, target: Vector2) -> void:
	_time += delta
	_target = target
	_flash = maxf(0.0, _flash - delta * 9.0)
	if intro > 0.0:
		intro -= delta
		var grow := 1.0 - clampf(intro / 1.2, 0.0, 1.0)
		position = ArenaSpace.to_world(pos2, 6.0 - (6.0 - height) * (1.0 - pow(1.0 - grow, 3.0)))
		_visual(delta, grow)
		return
	if not alive:
		dying -= delta
		position = ArenaSpace.to_world(pos2, height) + Vector3(randf_range(-0.12, 0.12), randf_range(-0.05, 0.05), randf_range(-0.12, 0.12))
		_flash = 0.5 + 0.5 * sin(_time * 50.0)
		_visual(delta, 1.0 + (1.25 - dying) * 0.12)
		return
	match kind:
		"titan":
			_tick_titan(delta)
		"frost":
			_tick_frost(delta)
		_:
			_tick_sentinel(delta)
	_visual(delta, 1.0)

# --- SENTİNEL ------------------------------------------------------------------
func _tick_sentinel(delta: float) -> void:
	var dir := (_target - pos2).normalized()
	var speed := _num("speed", 82.0) * (1.3 if phase == 2 else 1.0)
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_charge_left = _num("charge_time", 0.5)
			charge_started.emit(_charge_dir)
	elif _charge_left > 0.0:
		_charge_left -= delta
		pos2 += _charge_dir * _num("charge_speed", 760.0) * delta
	else:
		pos2 += dir * speed * delta
	var busy := _windup > 0.0 or _charge_left > 0.0
	if _tick_timer("radial", delta) and not busy:
		_t["radial"] = _num("radial_interval", 2.9) * (0.75 if phase == 2 else 1.0)
		radial_wave.emit(int(_num("radial_count", 14)) + (5 if phase == 2 else 0))
	if _tick_timer("summon", delta):
		_t["summon"] = _num("summon_interval", 7.0)
		summon.emit("swarmer" if phase == 1 else "chaser", 3 if phase == 1 else 4)
	if _tick_timer("aim", delta) and not busy:
		_t["aim"] = 1.15 if phase == 1 else 0.9
		aimed_shot.emit(dir)
	if _tick_timer("charge", delta) and not busy:
		_t["charge"] = _num("charge_interval", 6.0) * (1.25 if phase == 1 else 0.8)
		_windup = _num("charge_windup", 0.75)
		_charge_dir = dir
		charge_warn.emit(dir, _windup)
	if phase == 2:
		_tick_spiral(delta, busy, 3, 0.42, 0.075, int(_num("spiral_shots", 22)))
	var jitter := Vector3.ZERO
	if _windup > 0.0:
		jitter = Vector3(randf_range(-0.07, 0.07), 0.0, randf_range(-0.07, 0.07))
	position = ArenaSpace.to_world(pos2, height + sin(_time * 1.6) * 0.16) + jitter

func _tick_spiral(delta: float, busy: bool, arms: int, step: float, every: float, shots: int) -> void:
	if _tick_timer("spiral", delta) and _spiral_left <= 0 and not busy:
		_t["spiral"] = _num("spiral_interval", 5.5)
		_spiral_left = shots
		_spiral_angle = randf() * TAU
	if _spiral_left > 0:
		_spiral_tick -= delta
		if _spiral_tick <= 0.0:
			_spiral_tick = every
			_spiral_left -= 1
			_spiral_angle += step
			spiral_shot.emit(_spiral_angle, arms)

# --- KIZIL DEV -------------------------------------------------------------------
func _tick_titan(delta: float) -> void:
	if is_airborne():
		_leap_time += delta
		var k := clampf(_leap_time / _leap_total, 0.0, 1.0)
		pos2 = _leap_from.lerp(_leap_to, k * k * (3.0 - 2.0 * k))
		position = ArenaSpace.to_world(pos2, height + sin(k * PI) * 7.0)
		return
	var dir := (_target - pos2).normalized()
	var dist := pos2.distance_to(_target)
	var speed := _num("speed", 60.0) * (1.25 if phase == 2 else 1.0)
	if dist > radius + 40.0:
		pos2 += dir * speed * delta
	if _tick_timer("slam", delta):
		_t["slam"] = _num("slam_interval", 3.4) * (0.8 if phase == 2 else 1.0)
		var zones := int(_num("slam_zones", 3)) + (2 if phase == 2 else 0)
		var r := _num("slam_radius", 95.0)
		zone_marked.emit(_target, r, _num("slam_delay", 1.05), 8 if phase == 2 else 0)
		for i in zones - 1:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(r * 1.3, r * 2.6)
			zone_marked.emit(_target + off, r * randf_range(0.8, 1.1), _num("slam_delay", 1.05) + 0.12 * float(i + 1), 0)
	if _tick_timer("wave", delta):
		_t["wave"] = _num("wave_interval", 4.2) * (0.8 if phase == 2 else 1.0)
		ring_burst.emit(int(_num("wave_count", 26)), int(_num("wave_gap", 4)), _num("wave_speed", 230.0))
	if _tick_timer("fan", delta) and _fan_left <= 0:
		_t["fan"] = _num("fan_interval", 2.6)
		_fan_left = 3 if phase == 2 else 2
	if _fan_left > 0:
		_fan_tick -= delta
		if _fan_tick <= 0.0:
			_fan_tick = 0.2
			_fan_left -= 1
			fan_shot.emit(dir, int(_num("fan_count", 7)), _num("fan_arc", 0.9), _num("fan_speed", 420.0))
	if phase == 2:
		if _tick_timer("leap", delta):
			_t["leap"] = _num("leap_interval", 7.0)
			_leap_from = pos2
			_leap_to = _target
			_leap_time = 0.0
			_leap_total = _num("leap_time", 1.0)
			leap_started.emit(_leap_to, _leap_total)
		if _tick_timer("summon", delta):
			_t["summon"] = _num("summon_interval", 7.0) * 1.4
			summon.emit("bomber", 2)
	position = ArenaSpace.to_world(pos2, height + absf(sin(_time * 3.2)) * 0.12)

# --- BUZ HÜKÜMDARI ---------------------------------------------------------------
func _tick_frost(delta: float) -> void:
	var to := _target - pos2
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			var from := pos2
			pos2 = _blink_to
			blinked.emit(from, _blink_to)
		position = ArenaSpace.to_world(pos2, height)
		return
	match beam_state:
		BEAM_WARN:
			_beam_timer -= delta
			if _beam_timer <= 0.0:
				beam_state = BEAM_FIRE
				_beam_timer = _num("beam_time", 3.0)
		BEAM_FIRE:
			_beam_timer -= delta
			var turn := _num("beam_turn", 0.85) * (1.25 if phase == 2 else 1.0) * _beam_dir
			for i in beam_angles.size():
				beam_angles[i] += turn * delta
			if _beam_timer <= 0.0:
				beam_state = BEAM_IDLE
				beam_angles.clear()
				_t["beam"] = _num("beam_interval", 6.5) * (0.75 if phase == 2 else 1.0)
		_:
			# Oyuncunun etrafında mesafeli süzülür.
			var keep := 300.0
			var tangent := Vector2(-dir.y, dir.x)
			var radial := clampf((dist - keep) / keep, -1.0, 1.0)
			pos2 += (dir * radial + tangent * 0.55).normalized() * _num("speed", 70.0) * delta
			if _tick_timer("beam", delta):
				beam_state = BEAM_WARN
				_beam_timer = _num("beam_warn", 0.9)
				_beam_dir = 1.0 if randf() < 0.5 else -1.0
				beam_angles.clear()
				var count := int(_num("beam_count", 2)) + (1 if phase == 2 else 0)
				var base := dir.angle() + 0.5 * _beam_dir
				for i in count:
					beam_angles.append(base + TAU * float(i) / float(count))
				beam_warned.emit()
			elif _tick_timer("blink", delta):
				_t["blink"] = _num("blink_interval", 7.5) * (0.8 if phase == 2 else 1.0)
				_blink_to = _target + Vector2.from_angle(randf() * TAU) * randf_range(300.0, 380.0)
				_blink_left = _num("blink_warn", 0.7)
				blink_warn.emit(_blink_to, _blink_left)
	if beam_state == BEAM_IDLE and _tick_timer("shard", delta):
		_t["shard"] = _num("shard_interval", 2.2) * (0.8 if phase == 2 else 1.0)
		fan_shot.emit(dir, int(_num("shard_count", 5)) + (2 if phase == 2 else 0), _num("shard_arc", 0.55), _num("shard_speed", 300.0))
	if phase == 2:
		_tick_spiral(delta, beam_state == BEAM_WARN, int(_num("spiral_arms", 4)), 0.3, 0.11, 18)
		if _tick_timer("summon", delta):
			_t["summon"] = _num("summon_interval", 7.0) * 1.3
			summon.emit("orbiter", 2)
	position = ArenaSpace.to_world(pos2, height + sin(_time * 1.3) * 0.22)

func set_blink_target(to: Vector2) -> void:
	## game3d engel/arena sınırına göre ışınlanma noktasını düzeltebilir.
	_blink_to = to

# --- Görsel -------------------------------------------------------------------------
func _visual(delta: float, grow: float) -> void:
	if model == null:
		return
	var flash := clampf(_flash, 0.0, 1.0)
	var pulse := 0.0
	match kind:
		"titan":
			var want := atan2(-(_target - pos2).x, -(_target - pos2).y)
			model.rotation.y = lerp_angle(model.rotation.y, want, clampf(delta * 4.0, 0.0, 1.0))
			if is_airborne():
				model.rotation.x = -0.35 * sin(clampf(_leap_time / maxf(_leap_total, 0.01), 0.0, 1.0) * PI)
			else:
				model.rotation.x = lerpf(model.rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		"frost":
			model.rotation.y += delta * (0.6 if beam_state == BEAM_IDLE else 0.15) * (1.6 if phase == 2 else 1.0)
			if beam_state == BEAM_WARN:
				pulse = 0.08 * sin(_time * 40.0)
		_:
			model.rotation.y += delta * (0.9 if phase == 1 else 1.9) * (3.0 if _windup > 0.0 else 1.0)
			if _windup > 0.0:
				pulse = 0.08 * sin(_time * 30.0)
	var base_scale := float(stats.get("scale", 1.0))
	model.scale = Vector3.ONE * maxf(0.02, grow) * base_scale * (1.0 + 0.05 * flash + pulse)
	model.material_overlay = ModelCache.flash_material_soft() if flash > 0.6 else null
	if glow_light != null:
		glow_light.light_energy = (2.0 if phase == 1 else 3.2) + flash * 1.5 + (2.5 if _windup > 0.0 or beam_state == BEAM_WARN else 0.0)
