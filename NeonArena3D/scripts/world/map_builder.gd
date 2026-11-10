extends Node3D
class_name MapBuilder
## Temaya göre büyük arena kurar: zemin, güç alanı duvarları, ufuk çizgisi, engeller ve ışıklar.

const MODELS := {
	"pillar": "res://assets/models/pillar.glb",
	"crate": "res://assets/models/crate.glb",
	"crystal": "res://assets/models/crystal.glb",
	"obelisk": "res://assets/models/obelisk.glb",
	"barrier": "res://assets/models/barrier.glb",
	"dais": "res://assets/models/dais.glb",
}
const OBSTACLE_RADIUS := {
	"crate": 0.85,
	"crystal": 1.0,
	"obelisk": 0.95,
	"barrier": 1.35,
	"pillar": 0.9,
}
const LIGHT_ENERGY := 7.0

var obstacles: Array[Dictionary] = []
var theme: Dictionary = {}
var theme_index := 0
var rng := RandomNumberGenerator.new()
var env: Environment
var sun: DirectionalLight3D
var color_a := Color.CYAN
var color_b := Color.MAGENTA

var _lights: Array[OmniLight3D] = []
var _light_colors: Array[Color] = []
var _light_base: Array[float] = []
var _pulse := 0.0
var _pulse_t := 1.0
var _pulse_origin := Vector2.ZERO
var _danger := 0.0
var _danger_target := 0.0
var _wall_flash := 0.0
var _floor_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _motes: CPUParticles3D
var _quality := 2

func build(index: int, theme_data: Dictionary) -> void:
	theme_index = index
	theme = theme_data
	rng.seed = 90210 + index * 137
	color_a = _color("light_a", "#33ccff")
	color_b = _color("light_b", "#cc33ff")
	_clear()
	_build_environment()
	_build_floor()
	_build_rails()
	_build_walls()
	_build_field()
	_build_center()
	_build_props()
	_build_perimeter()
	_build_motes()
	apply_quality(_quality)

func _clear() -> void:
	for child in get_children():
		child.queue_free()
	obstacles.clear()
	_lights.clear()
	_light_colors.clear()
	_light_base.clear()

func flash_pulse(origin := Vector3.ZERO, amount := 1.0) -> void:
	## Zeminde yayılan dalga halkası + ışıkların kısa parlaması.
	_pulse = maxf(_pulse, amount)
	_pulse_t = 0.0
	_pulse_origin = Vector2(origin.x, origin.z)

func set_danger(on: bool) -> void:
	_danger_target = 1.0 if on else 0.0

func hit_wall() -> void:
	_wall_flash = 1.0

func apply_quality(q: int) -> void:
	_quality = q
	if sun != null:
		sun.shadow_enabled = q >= 1
	if _motes != null:
		_motes.emitting = q >= 1
		_motes.visible = q >= 1
	if env != null:
		env.glow_enabled = true
		env.set_glow_level(1, 0.0)
		env.set_glow_level(2, 1.0)
		env.set_glow_level(3, 0.9 if q >= 1 else 0.0)
		env.set_glow_level(4, 0.6 if q >= 1 else 0.8)
		env.set_glow_level(5, 0.5 if q >= 2 else 0.0)
		env.set_glow_level(6, 0.0)

func tick(delta: float, player_world := Vector3.ZERO) -> void:
	_pulse = maxf(0.0, _pulse - delta * 1.6)
	_pulse_t = minf(1.0, _pulse_t + delta * 0.85)
	_danger = move_toward(_danger, _danger_target, delta * 0.8)
	_wall_flash = maxf(0.0, _wall_flash - delta * 3.0)
	var danger_color := Color(1.0, 0.16, 0.3)
	for i in _lights.size():
		_lights[i].light_energy = _light_base[i] * (1.0 + _pulse * 0.9)
		_lights[i].light_color = _light_colors[i].lerp(danger_color, _danger * 0.42)
	var pp := Vector2(player_world.x, player_world.z)
	if _floor_mat != null:
		_floor_mat.set_shader_parameter("player_pos", pp)
		_floor_mat.set_shader_parameter("pulse", _pulse_t if _pulse_t < 1.0 else 0.0)
		_floor_mat.set_shader_parameter("pulse_origin", _pulse_origin)
		_floor_mat.set_shader_parameter("danger", _danger)
	if _wall_mat != null:
		_wall_mat.set_shader_parameter("player_pos", pp)
		_wall_mat.set_shader_parameter("flash", _wall_flash + _pulse * 0.5)

func _color(key: String, fallback: String) -> Color:
	return Color.from_string(str(theme.get(key, fallback)), Color.WHITE)

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _color("floor_base", "#02050c").darkened(0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = color_a.lerp(Color(0.5, 0.6, 0.8), 0.45).darkened(0.45)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.95
	env.glow_strength = 1.05
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_hdr_scale = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = _color("fog", "#0a1424").lerp(color_a, 0.08)
	env.fog_density = 0.0075
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.18
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-42.0), 0.0)
	sun.light_color = _color("sun", "#8fb4ff")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.8
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 62.0
	add_child(sun)

	var half := ArenaSpace.HALF_EXTENT
	var spots := [
		[Vector3(-half.x * 0.55, 4.0, -half.y * 0.55), color_a],
		[Vector3(half.x * 0.55, 4.0, -half.y * 0.55), color_b],
		[Vector3(-half.x * 0.55, 4.0, half.y * 0.55), color_b],
		[Vector3(half.x * 0.55, 4.0, half.y * 0.55), color_a],
		[Vector3(0, 4.5, 0), color_a.lerp(color_b, 0.35)],
	]
	for entry in spots:
		var light := OmniLight3D.new()
		light.position = entry[0]
		light.light_color = entry[1]
		# Beyaza yakın ışıklar sahneyi yakar: parlaklığa göre güç düşür.
		var c: Color = entry[1]
		var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var energy := LIGHT_ENERGY * clampf(0.5 / maxf(lum, 0.05), 0.5, 1.0)
		light.light_energy = energy
		_light_base.append(energy)
		light.omni_range = 27.0
		light.omni_attenuation = 1.3
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)
		_light_colors.append(entry[1])

func _build_floor() -> void:
	var half := ArenaSpace.HALF_EXTENT
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = half * 2.0
	floor_mesh.mesh = plane
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = load("res://assets/shaders/floor_grid.gdshader")
	_floor_mat.set_shader_parameter("base_color", _color("floor_base", "#02050c"))
	_floor_mat.set_shader_parameter("line_color", _color("floor_line", "#1a6f9c"))
	_floor_mat.set_shader_parameter("accent_color", color_b.darkened(clampf((0.2126 * color_b.r + 0.7152 * color_b.g + 0.0722 * color_b.b) - 0.45, 0.0, 0.5)))
	_floor_mat.set_shader_parameter("cell", 1.0)
	_floor_mat.set_shader_parameter("glow", 0.5)
	floor_mesh.material_override = _floor_mat
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)

	var outer := MeshInstance3D.new()
	var outer_plane := PlaneMesh.new()
	outer_plane.size = Vector2(190.0, 190.0)
	outer.mesh = outer_plane
	outer.position.y = -0.04
	var outer_mat := ShaderMaterial.new()
	outer_mat.shader = load("res://assets/shaders/floor_grid.gdshader")
	outer_mat.set_shader_parameter("base_color", _color("floor_base", "#02050c").darkened(0.45))
	outer_mat.set_shader_parameter("line_color", _color("floor_line", "#1a6f9c").darkened(0.35))
	outer_mat.set_shader_parameter("accent_color", color_b.darkened(0.3))
	outer_mat.set_shader_parameter("cell", 2.0)
	outer_mat.set_shader_parameter("glow", 0.22)
	outer_mat.set_shader_parameter("outer", 1.0)
	outer.material_override = outer_mat
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer)

func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color * energy
	return mat

func _build_rails() -> void:
	var glow := _glow_material(color_a, 1.35)
	var half := ArenaSpace.HALF_EXTENT
	var thickness := 0.14
	var segments := [
		[Vector3(0, 0.08, -half.y - 0.1), Vector3(half.x * 2.0 + 0.5, 0.12, thickness)],
		[Vector3(0, 0.08, half.y + 0.1), Vector3(half.x * 2.0 + 0.5, 0.12, thickness)],
		[Vector3(-half.x - 0.1, 0.08, 0), Vector3(thickness, 0.12, half.y * 2.0 + 0.5)],
		[Vector3(half.x + 0.1, 0.08, 0), Vector3(thickness, 0.12, half.y * 2.0 + 0.5)],
	]
	for seg in segments:
		var rail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = seg[1]
		rail.mesh = box
		rail.position = seg[0]
		rail.material_override = glow
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rail)

func _build_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = _color("floor_base", "#02050c").lightened(0.12)
	wall_mat.roughness = 0.6
	wall_mat.metallic = 0.2
	var trim := _glow_material(color_a, 1.25)
	var trim_b := _glow_material(color_b, 1.2)
	var half := ArenaSpace.HALF_EXTENT
	var t := 0.5
	var h := 0.8
	var walls := [
		[Vector3(0, h * 0.5, -half.y - 0.8), Vector3(half.x * 2.0 + 2.1, h, t)],
		[Vector3(0, h * 0.5, half.y + 0.8), Vector3(half.x * 2.0 + 2.1, h, t)],
		[Vector3(-half.x - 0.8, h * 0.5, 0), Vector3(t, h, half.y * 2.0 + 2.1)],
		[Vector3(half.x + 0.8, h * 0.5, 0), Vector3(t, h, half.y * 2.0 + 2.1)],
	]
	for entry in walls:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = entry[1]
		wall.mesh = box
		wall.position = entry[0]
		wall.material_override = wall_mat
		add_child(wall)
		var strip := MeshInstance3D.new()
		var strip_box := BoxMesh.new()
		strip_box.size = Vector3(entry[1].x + 0.04, 0.05, entry[1].z + 0.04)
		strip.mesh = strip_box
		strip.position = entry[0] + Vector3(0, h * 0.5 + 0.02, 0)
		strip.material_override = trim
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(strip)
	# Köşe direkleri: arenayı çerçeveler.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector3(sx * (half.x + 0.8), 0.0, sz * (half.y + 0.8))
			var post := MeshInstance3D.new()
			var post_box := BoxMesh.new()
			post_box.size = Vector3(0.9, 3.4, 0.9)
			post.mesh = post_box
			post.position = corner + Vector3(0, 1.7, 0)
			post.material_override = wall_mat
			add_child(post)
			var cap := MeshInstance3D.new()
			var cap_box := BoxMesh.new()
			cap_box.size = Vector3(1.0, 0.12, 1.0)
			cap.mesh = cap_box
			cap.position = corner + Vector3(0, 3.46, 0)
			cap.material_override = trim_b if sx * sz > 0.0 else trim
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cap)
			for k in 2:
				var band := MeshInstance3D.new()
				var band_box := BoxMesh.new()
				band_box.size = Vector3(0.96, 0.06, 0.96)
				band.mesh = band_box
				band.position = corner + Vector3(0, 1.1 + float(k) * 1.1, 0)
				band.material_override = trim
				band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(band)

func _build_field() -> void:
	## Sınır boyunca yarı saydam güç alanı; oyuncu yaklaşınca parlar.
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = load("res://assets/shaders/field_wall.gdshader")
	_wall_mat.set_shader_parameter("color", color_a)
	var half := ArenaSpace.HALF_EXTENT
	var height := 3.2
	var sides := [
		[Vector3(0, height * 0.5, -half.y - 0.12), half.x * 2.0, 0.0],
		[Vector3(0, height * 0.5, half.y + 0.12), half.x * 2.0, PI],
		[Vector3(-half.x - 0.12, height * 0.5, 0), half.y * 2.0, PI * 0.5],
		[Vector3(half.x + 0.12, height * 0.5, 0), half.y * 2.0, -PI * 0.5],
	]
	for entry in sides:
		var quad := QuadMesh.new()
		quad.size = Vector2(entry[1], height)
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.position = entry[0]
		node.rotation.y = entry[2]
		node.material_override = _wall_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func _build_center() -> void:
	var mesh := ModelCache.mesh(MODELS["dais"])
	if mesh != null:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func _spawn_model(key: String, at: Vector3, yaw: float, scale_factor: float, shadows := true) -> void:
	var path: String = MODELS.get(key, "")
	var mesh := ModelCache.mesh(path) if path != "" else null
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_factor
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _build_props() -> void:
	var half := ArenaSpace.HALF_EXTENT
	var counts: Dictionary = theme.get("props", {})
	# Dışarıdaki dekor
	for key in counts:
		var count := int(counts[key])
		if key == "barrier":
			count = mini(count, 10)
		for i in count:
			var side := rng.randi() % 4
			var pos := Vector3.ZERO
			if side == 0:
				pos = Vector3(rng.randf_range(-half.x, half.x), 0, -half.y - rng.randf_range(2.6, 6.0))
			elif side == 1:
				pos = Vector3(rng.randf_range(-half.x, half.x), 0, half.y + rng.randf_range(2.6, 6.0))
			elif side == 2:
				pos = Vector3(-half.x - rng.randf_range(2.6, 6.0), 0, rng.randf_range(-half.y, half.y))
			else:
				pos = Vector3(half.x + rng.randf_range(2.6, 6.0), 0, rng.randf_range(-half.y, half.y))
			_spawn_model(key, pos, rng.randf() * TAU, rng.randf_range(0.9, 1.4), false)
	# İçerideki engeller (çarpışmalı)
	_place_obstacles(counts)

func _place_obstacles(counts: Dictionary) -> void:
	var kinds: Array[String] = []
	for key in counts:
		if key == "pillar":
			continue
		var amount := int(counts[key])
		for i in mini(amount, 6):
			kinds.append(key)
	if kinds.is_empty():
		kinds = ["crate", "crate", "crystal"]
	var half := ArenaSpace.HALF_EXTENT
	var placed := 0
	var guard := 0
	while placed < 11 and guard < 300:
		guard += 1
		var world := Vector3(rng.randf_range(-half.x + 5.0, half.x - 5.0), 0.0, rng.randf_range(-half.y + 5.0, half.y - 5.0))
		if Vector2(world.x, world.z).length() < 11.0:
			continue
		var ok := true
		for other in obstacles:
			var other_world: Vector3 = other["world"]
			if other_world.distance_to(world) < 9.0:
				ok = false
				break
		if not ok:
			continue
		var kind: String = kinds[rng.randi() % kinds.size()]
		var scale_factor := rng.randf_range(0.9, 1.2)
		var yaw := rng.randf() * TAU
		_spawn_model(kind, world, yaw, scale_factor)
		obstacles.append({
			"pos2": ArenaSpace.to_plane(world),
			"world": world,
			"kind": kind,
			"radius": float(OBSTACLE_RADIUS.get(kind, 1.0)) * scale_factor * ArenaSpace.SCALE,
			"color": color_a if placed % 2 == 0 else color_b,
		})
		placed += 1

func _build_perimeter() -> void:
	## Ufuk çizgisi: tek MultiMesh, pencereler shader'da.
	var half := ArenaSpace.HALF_EXTENT
	var count := 84
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/tower.gdshader")
	mat.set_shader_parameter("body", _color("floor_base", "#02050c").lightened(0.1))
	mat.set_shader_parameter("lit_a", _color("perimeter_cap", "#1a9bd8"))
	mat.set_shader_parameter("lit_b", _color("perimeter_warm", "#e0409a"))
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = box
	mm.instance_count = count
	for i in count:
		var far_row := i % 2 == 1
		var angle := TAU * float(i) / float(count) + rng.randf_range(-0.03, 0.03)
		var radius := rng.randf_range(half.y + 13.0, half.y + 19.0) + (11.0 if far_row else 0.0)
		var height := rng.randf_range(4.0, 10.0) * (1.7 if far_row else 1.0)
		var width := rng.randf_range(1.8, 3.4) * (1.3 if far_row else 1.0)
		var pos := Vector3(cos(angle) * radius * 1.45, height * 0.5 - 0.1, sin(angle) * radius)
		var basis := Basis(Vector3.UP, -angle).scaled(Vector3(width, height, width))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		mm.set_instance_custom_data(i, Color(rng.randf(), 0.0, 0.0, 0.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _build_motes() -> void:
	## Havada süzülen ışık zerreleri: derinlik hissi verir.
	var half := ArenaSpace.HALF_EXTENT
	_motes = CPUParticles3D.new()
	_motes.amount = 70
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(half.x, 0.3, half.y)
	_motes.position = Vector3(0, 0.6, 0)
	_motes.direction = Vector3.UP
	_motes.spread = 25.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = 0.25
	_motes.initial_velocity_max = 0.7
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color_a.r, color_a.g, color_a.b, 0.0))
	ramp.add_point(0.25, Color(color_a.r, color_a.g, color_a.b, 0.8))
	ramp.add_point(0.7, Color(color_b.r, color_b.g, color_b.b, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(color_b.r, color_b.g, color_b.b, 0.0))
	_motes.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = soft
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = dot
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(2.0, 2.0, 2.0, 1.0)
	quad.material = mat
	_motes.mesh = quad
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)
