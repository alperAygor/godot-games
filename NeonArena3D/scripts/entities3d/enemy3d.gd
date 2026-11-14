extends Node3D
## 3B düşman: 7 tür, türe özel davranış. Mantık 2B, görüntü 3B.

const MODELS := {
	"chaser": "res://assets/models/chaser.glb",
	"shooter": "res://assets/models/shooter.glb",
	"tank": "res://assets/models/tank.glb",
	"swarmer": "res://assets/models/swarmer.glb",
	"bomber": "res://assets/models/bomber.glb",
	"sniper": "res://assets/models/sniper.glb",
	"orbiter": "res://assets/models/orbiter.glb",
}
const SCALES := {"chaser": 1.2, "shooter": 1.25, "tank": 1.15, "swarmer": 1.15, "bomber": 1.2, "sniper": 1.2, "orbiter": 1.2}

static var _laser_mesh: BoxMesh
static var _laser_mat: StandardMaterial3D

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

var model: MeshInstance3D
var laser: MeshInstance3D
var _time := 0.0
var _bob_offset := 0.0
var _flash := 0.0
var _spawn_total := 0.5
var _base_scale := 1.0
var _color := Color(1, 0.3, 0.5)

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
	hp = max_hp
	spawn_delay = float(data.get("spawn_delay", 0.5))
	_spawn_total = maxf(0.05, spawn_delay)
	fire_cd = randf_range(0.6, 1.6)
	strafe = 1.0 if randf() < 0.5 else -1.0
	_bob_offset = randf() * TAU
	_color = Color.from_string(str(stats.get("color", "#ff3d6e")), Color(1, 0.3, 0.5))

func _ready() -> void:
	var path: String = MODELS.get(kind, "")
	model = ModelCache.instance(path, 0.01)
	add_child(model)
	if elite:
		model.material_overlay = ModelCache.elite_material()
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
	return int(stats.get("points", 10))

func is_spawning() -> bool:
	return spawn_delay > 0.0

func hp_ratio() -> float:
	return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)

func take_damage(amount: float, push := Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	_flash = 1.0
	hp_shown = 2.2
	knock2 += push
	if hp <= 0.0:
		dead = true

func tick(delta: float, target: Vector2) -> bool:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 9.0)
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
		_:
			desired = dir

	var turn := float(stats.get("turn", 3.0))
	velocity2 = velocity2.lerp(desired * speed_value, clampf(turn * delta, 0.0, 1.0))
	knock2 = knock2.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	pos2 += (velocity2 + knock2) * delta
	var hover := 0.85 + sin(_time * 2.6 + _bob_offset) * 0.09
	position = ArenaSpace.to_world(pos2, hover)
	var facing := dir if face_target else velocity2
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
	model.scale = Vector3.ONE * _base_scale * maxf(0.02, grow) * (1.0 + 0.14 * flash)
	if flash > 0.45:
		model.material_overlay = ModelCache.flash_material()
	else:
		model.material_overlay = ModelCache.elite_material() if elite else null
