extends Node3D
## 3B oyuncu gemisi. Mantık 2B (pos2), görüntü 3B.

signal shot(origin: Vector2, direction: Vector2)
signal dashed_at(at: Vector2, direction: Vector2)
signal hurt(amount: float)
signal shield_broken

var pos2 := Vector2(640, 360)
var velocity2 := Vector2.ZERO
var aim2 := Vector2.RIGHT
var move_dir := Vector2.RIGHT
var max_hp := 100.0
var hp := 100.0
var speed := 330.0
var radius := 13.0
var invuln := 0.0
var dash_left := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var fire_cd := 0.0
var overdrive := 0.0
var shield := 0
var alive := true
var autopilot := false
var fire_rate_mult := 1.0
var dash_cd_mult := 1.0
var weapon_interval := 0.135
var ship_color := Color(0.35, 0.9, 1.0)
var _ship_model := ""
var _flame_mat: StandardMaterial3D
var bounds := Rect2(40, 40, 1200, 640)

var model: MeshInstance3D
var engine_light: OmniLight3D
var flame: MeshInstance3D
var bubble: MeshInstance3D
var _bubble_mat: ShaderMaterial
var _time := 0.0
var _bank := 0.0
var _thrust := 0.0
var _dash_flash := 0.0
var _hurt_blink := 0.0
var _recoil := 0.0

func _ready() -> void:
	model = ModelCache.instance("res://assets/models/ship.glb", 1.15)
	_ship_model = "res://assets/models/ship.glb"
	add_child(model)
	engine_light = OmniLight3D.new()
	engine_light.position = Vector3(0, 0.3, 0.6)
	engine_light.light_color = Color(0.35, 0.9, 1.0)
	engine_light.light_energy = 1.4
	engine_light.omni_range = 5.5
	engine_light.shadow_enabled = false
	add_child(engine_light)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.17
	cone.height = 1.0
	cone.radial_segments = 8
	cone.rings = 1
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.albedo_color = Color(0.5, 1.6, 2.2, 0.85)
	flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = flame_mat
	_flame_mat = flame_mat
	flame = MeshInstance3D.new()
	flame.mesh = cone
	flame.rotation.x = PI * 0.5
	flame.position = Vector3(0, 0.02, 1.25)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)

	var sphere := SphereMesh.new()
	sphere.radius = 1.25
	sphere.height = 2.5
	sphere.radial_segments = 20
	sphere.rings = 10
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = load("res://assets/shaders/shield.gdshader")
	sphere.material = _bubble_mat
	bubble = MeshInstance3D.new()
	bubble.mesh = sphere
	bubble.visible = false
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bubble)

func set_ship(def: Dictionary) -> void:
	## Gemi modelini, motor rengini ve silah aralığını seçilen gemiye göre ayarlar.
	var path := str(def.get("model", "res://assets/models/ship.glb"))
	if path != _ship_model and model != null:
		model.mesh = ModelCache.mesh(path)
		_ship_model = path
	ship_color = Color.from_string(str(def.get("color", "#5ce1ff")), Color(0.35, 0.9, 1.0))
	weapon_interval = float((def.get("weapon", {}) as Dictionary).get("interval", 0.135))
	if engine_light != null:
		engine_light.light_color = ship_color
	if _flame_mat != null:
		var c := ship_color.lerp(Color(1, 1, 1), 0.25)
		_flame_mat.albedo_color = Color(c.r * 1.8, c.g * 1.8, c.b * 1.8, 0.85)

func reset(start: Vector2, keep_state := false) -> void:
	pos2 = start
	velocity2 = Vector2.ZERO
	alive = true
	invuln = 1.0
	dash_left = 0.0
	dash_cd = 0.0
	fire_cd = 0.0
	visible = true
	if not keep_state:
		hp = max_hp
		overdrive = 0.0
		shield = 0
	position = ArenaSpace.to_world(pos2, 1.0)
	if model != null:
		model.visible = true

func dash_ready() -> bool:
	return dash_cd <= 0.0 and dash_left <= 0.0

func dash_ratio() -> float:
	var total := float(GameData.number("player.dash_cooldown", 1.05)) * dash_cd_mult
	return 1.0 - clampf(dash_cd / maxf(0.01, total), 0.0, 1.0)

func is_dashing() -> bool:
	return dash_left > 0.0

func fire_interval() -> float:
	return weapon_interval * (0.5 if overdrive > 0.0 else 1.0) / maxf(0.2, fire_rate_mult)

func tick(delta: float, move_input: Vector2, aim_target: Vector2, want_fire: bool, want_dash: bool) -> void:
	if not alive:
		return
	_time += delta
	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	overdrive = maxf(0.0, overdrive - delta)
	_dash_flash = maxf(0.0, _dash_flash - delta * 2.5)
	_hurt_blink = maxf(0.0, _hurt_blink - delta)
	_recoil = maxf(0.0, _recoil - delta * 9.0)
	if aim_target.distance_to(pos2) > 4.0:
		aim2 = (aim_target - pos2).normalized()
	if move_input.length() > 0.15:
		move_dir = move_input.normalized()

	if want_dash and dash_ready():
		# Hareket yoksa nişan yönüne atıl: dokunmatikte tek dokunuşla kaçış.
		dash_dir = move_input.normalized() if move_input.length() > 0.15 else aim2
		dash_left = float(GameData.number("player.dash_time", 0.15))
		dash_cd = float(GameData.number("player.dash_cooldown", 1.05)) * dash_cd_mult
		invuln = maxf(invuln, dash_left + 0.1)
		_dash_flash = 1.0
		dashed_at.emit(pos2, dash_dir)

	if dash_left > 0.0:
		dash_left -= delta
		velocity2 = dash_dir * float(GameData.number("player.dash_speed", 1250.0))
	else:
		velocity2 = velocity2.lerp(move_input * speed, clampf(12.0 * delta, 0.0, 1.0))

	pos2 += velocity2 * delta
	pos2.x = clampf(pos2.x, bounds.position.x + radius, bounds.end.x - radius)
	pos2.y = clampf(pos2.y, bounds.position.y + radius, bounds.end.y - radius)
	_thrust = lerpf(_thrust, clampf(velocity2.length() / maxf(1.0, speed), 0.0, 1.6), clampf(delta * 8.0, 0.0, 1.0))

	fire_cd -= delta
	if want_fire and fire_cd <= 0.0 and dash_left <= 0.0:
		fire_cd = fire_interval()
		_recoil = 1.0
		shot.emit(pos2 + aim2 * 24.0, aim2)
	update_visual(delta)

func update_visual(delta: float) -> void:
	var hover := 1.0 + sin(_time * 2.2) * 0.06
	position = ArenaSpace.to_world(pos2, hover)
	_face(aim2)
	var side := velocity2.dot(Vector2(-aim2.y, aim2.x)) / maxf(1.0, speed)
	_bank = lerpf(_bank, -side * 0.5, clampf(delta * 7.0, 0.0, 1.0))
	if model != null:
		model.rotation.z = _bank
		model.rotation.x = lerpf(model.rotation.x, -_thrust * 0.1, clampf(delta * 5.0, 0.0, 1.0))
		model.position.z = _recoil * 0.1
		# Hasar sonrası dokunulmazlıkta yanıp sönme.
		model.visible = _hurt_blink <= 0.0 or int(_hurt_blink * 22.0) % 2 == 0
		model.material_overlay = ModelCache.flash_material() if (_dash_flash > 0.55 or overdrive > 0.0 and int(_time * 10.0) % 3 == 0) else null
	if flame != null:
		var power := clampf(_thrust, 0.0, 1.6) + _dash_flash * 1.5
		var flicker := 0.85 + 0.15 * sin(_time * 47.0)
		flame.scale = Vector3(0.7 + power * 0.5, (0.25 + power * 1.25) * flicker, 0.7 + power * 0.5)
		flame.position.z = 1.0 + flame.scale.y * 0.5
		flame.visible = power > 0.06
	if engine_light != null:
		engine_light.light_energy = 1.2 + 1.8 * _thrust + _dash_flash * 3.0
	if bubble != null:
		bubble.visible = shield > 0
		if shield > 0:
			_bubble_mat.set_shader_parameter("power", 0.75 + 0.25 * sin(_time * 3.0))

func idle_visual(delta: float, at: Vector2, yaw: float, height: float) -> void:
	## Menüde süzülen gemi.
	_time += delta
	pos2 = at
	position = ArenaSpace.to_world(at, height)
	rotation = Vector3(0.0, yaw, 0.0)
	_thrust = lerpf(_thrust, 0.55, clampf(delta * 3.0, 0.0, 1.0))
	if model != null:
		model.visible = true
		model.material_overlay = null
		model.rotation.z = sin(_time * 0.9) * 0.22
		model.rotation.x = -0.05
	if flame != null:
		var flicker := 0.85 + 0.15 * sin(_time * 47.0)
		flame.scale = Vector3(0.95, 0.9 * flicker, 0.95)
		flame.position.z = 1.0 + flame.scale.y * 0.5
		flame.visible = true
	if bubble != null:
		bubble.visible = false
	if engine_light != null:
		engine_light.light_energy = 0.8

func _face(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	rotation = Vector3(0.0, atan2(-direction.x, -direction.y), 0.0)

func take_damage(amount: float, from: Vector2) -> bool:
	if not alive or invuln > 0.0:
		return false
	var push := (pos2 - from).normalized()
	if push == Vector2.ZERO:
		push = Vector2.UP
	if shield > 0:
		shield -= 1
		invuln = 0.75
		velocity2 += push * 140.0
		shield_broken.emit()
		return false
	hp -= amount
	invuln = float(GameData.number("player.hurt_invuln", 0.7))
	_hurt_blink = invuln
	velocity2 += push * 200.0
	if hp <= 0.0:
		hp = 0.0
		alive = false
	hurt.emit(amount)
	return true

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
