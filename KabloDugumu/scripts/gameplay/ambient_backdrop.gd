class_name AmbientBackdrop
extends Node3D

## Menü ve oyun arkasında canlı atölye (ARCHITECTURE §13 — v0.2).
##
## Sahne bilinçli olarak minimal tutulur (yalnızca script); geometri BoardBuilder
## desenindeki gibi kodla kurulur. Bu sayede:
##   * <= 40 düğüm, gölge yok, düşük poligon (mobil bütçesi),
##   * statik parçalar malzeme başına TEK mesh'te birleşir (draw call bütçesi),
##   * animasyonlar ucuz sinüs/rotasyon, 30 Hz güncellenir ve döngüseldir (>= 2 sn).
##
## Kullanım:
##   * Menü: SubViewport (<= 540x960) içine instance et. KIND_MENU'da kendi
##     Camera3D'sini ve WorldEnvironment'ını kurar (SubViewport dünyası boştur).
##     Çağıran yalnızca SubViewport'u kurar:
##     render_target_update_mode = UPDATE_ALWAYS.
##   * Oyun: Game.tscn içinde "Backdrop" düğümü olarak panonun arkasına kurulur
##     (kind = KIND_GAME). Çağıranın kamerası/ortamı kullanılır.
##
## KADRAJ KURALI (oyun): üst HUD bandı ve alt buton şeridi backdrop öğesi
## İÇERMEZ. Oyun kompozisyonu yalnızca panonun SOL/SAĞ kenar boşluklarında
## görünür: fan/levha/borular yan üstte, dişli + dikey bobin hattı yanda,
## buhar yan ortada. Asma lamba oyunda panonun arkasına gizlenir; yalnızca
## salınan sıcak ışığı panoya vurur (Lead görsel QA geri bildirimi).
##
## API: setup(kind: int), set_intensity(value: float). Ek olarak menü
## entegrasyonu için salt okunur yardımcılar: menu_camera(), menu_environment().

const KIND_MENU: int = 0
const KIND_GAME: int = 1

## Animasyon güncelleme hızı: yavaş hareketler için 30 Hz fazlasıyla yeterli.
const ANIMATION_HZ: float = 30.0
## Doku arkasına yerleşim düzlemi (pano z~0; kamera +Z'de).
const WALL_Z: float = -2.4
const WALL_SIZE: Vector2 = Vector2(9.0, 12.0)
const WALL_CENTER_Y: float = 0.5

# --- ASMR paleti (ARCHITECTURE §16: sıcak-koyu, düşük kontrast) ----------
const WARM: Color = Color(1.0, 0.72, 0.42)
const MINT: Color = Color(0.32, 0.88, 0.74)
const METAL: Color = Color(0.235, 0.250, 0.285)
const METAL_DARK: Color = Color(0.105, 0.115, 0.135)
const WALL_BASE: Color = Color(0.052, 0.050, 0.058)
## Tek neon batch'in taban emission enerjisi (blackout/nefes buna ölçek uygular).
const NEON_ENERGY: float = 0.50

# --- menü kompozisyonu (HUD yok; zengin sahne) ---------------------------
const MENU_FAN_CENTER: Vector3 = Vector3(-1.50, 0.55, -2.05)
const MENU_GEAR_CENTER: Vector3 = Vector3(1.55, 0.20, -2.10)
## Menüde lamba sol üst marja yakın durur: başlığın/butonların arkasına denk gelmez.
const MENU_LAMP_PIVOT: Vector3 = Vector3(-1.42, 3.20, -1.45)
const MENU_CONVEYOR_CENTER: Vector3 = Vector3(0.0, -2.48, -1.45)
const MENU_CONVEYOR_LENGTH: float = 3.30

# --- oyun kompozisyonu (yalnızca sol/sağ kenar boşlukları) ---------------
const GAME_FAN_CENTER: Vector3 = Vector3(-1.48, 1.18, -2.00)
const GAME_GEAR_CENTER: Vector3 = Vector3(1.52, 0.95, -2.05)
## Oyunda lamba gövdesi panonun arkasına gizlenir; ışık panonun önüne taşınır.
const GAME_LAMP_LIGHT_POSITION: Vector3 = Vector3(0.0, 0.55, 0.60)
const GAME_BOBBIN_CENTER: Vector3 = Vector3(1.46, -1.02, -1.50)
const GAME_BOBBIN_TRAVEL: float = 0.46
const GAME_STEAM_RIGHT: Vector3 = Vector3(1.46, -0.35, -1.45)

const FAN_RADIUS: float = 0.30
const FAN_BLADE_SIZE: Vector3 = Vector3(0.52, 0.075, 0.022)
## Fan devri: period ~10 sn (ASMR: yavaş).
const FAN_SPEED: float = 0.62
const GEAR_RADIUS: float = 0.30
const GEAR_SPEED: float = -0.34
const LAMP_ARM: float = 1.12
## Sarkaç salınımı: period ~11.4 sn, genlik ~3.2 derece.
const LAMP_SWING: float = 0.056
const LAMP_SWING_SPEED: float = 0.55
const CONVEYOR_SPEED: float = 0.55
const MENU_BOBBIN_TRAVEL: float = 0.85
const BOBBIN_SPEED: float = 0.30
const STEAM_AMOUNT: int = 18

## @export: Game.tscn "Backdrop" düğümü kind = KIND_GAME verir; menü instance'ı
## varsayılan KIND_MENU ile gelir.
@export var kind: int = KIND_MENU
@export var intensity: float = 1.0

var _setup_done: bool = false
var _time: float = 0.0
var _anim_accum: float = 0.0
var _intensity: float = 1.0

var _matte_ops: Array[Dictionary] = []
var _neon_ops: Array[Dictionary] = []
var _matte_material: ShaderMaterial = null
var _neon_material: ShaderMaterial = null

var _fan_pivot: Node3D = null
var _gear_pivot: Node3D = null
var _lamp_pivot: Node3D = null
var _lamp_light: OmniLight3D = null
var _lamp_light_base_position: Vector3 = Vector3.ZERO
var _lamp_base_energy: float = 1.35
var _lamp_light_game: bool = false
var _rollers: Array[Node3D] = []
var _bobbins: Array[Node3D] = []
var _bobbin_bases: PackedVector3Array = PackedVector3Array()
var _bobbins_vertical: bool = false
var _steam: Array[GPUParticles3D] = []

var _menu_camera: Camera3D = null
var _menu_environment: WorldEnvironment = null
var _menu_light: OmniLight3D = null


func _ready() -> void:
	if not _setup_done:
		setup(kind)


## Sahneyi kurar. Aynı örnek için idempotenttir.
func setup(scene_kind: int) -> void:
	if _setup_done:
		return
	_setup_done = true
	kind = scene_kind if scene_kind == KIND_MENU or scene_kind == KIND_GAME else KIND_MENU
	_intensity = clampf(intensity, 0.0, 1.0)
	_build_materials()
	_build_wall()
	_build_static_shop()
	_build_wall_details()
	_build_fan()
	_build_gear()
	_build_lamp()
	_build_conveyor()
	_build_steam()
	_commit_batches()
	if kind == KIND_MENU:
		_build_menu_view()
	_apply_intensity()
	set_process(true)


## 0 = normal, 1 = tam parlak. Blackout/atmosfer yoğunluğu için ölçekler
## (lamba ışığı, emissive paneller, buhar miktarı).
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	intensity = _intensity
	_apply_intensity()


func get_intensity() -> float:
	return _intensity


func is_setup_done() -> bool:
	return _setup_done


## Menüye gömüldüğünde kamerayı özelleştirmek isteyen çağıran için.
func menu_camera() -> Camera3D:
	return _menu_camera


func menu_environment() -> Environment:
	if _menu_environment == null:
		return null
	return _menu_environment.environment


func _is_menu() -> bool:
	return kind == KIND_MENU


func _fan_center() -> Vector3:
	return MENU_FAN_CENTER if _is_menu() else GAME_FAN_CENTER


func _gear_center() -> Vector3:
	return MENU_GEAR_CENTER if _is_menu() else GAME_GEAR_CENTER


func _process(delta: float) -> void:
	if not _setup_done:
		return
	_time += delta
	_anim_accum += delta
	var interval: float = 1.0 / ANIMATION_HZ
	if _anim_accum < interval:
		return
	_anim_accum = 0.0
	_animate(_time)
	if kind == KIND_MENU:
		_animate_menu_camera(_time)


func node_count() -> int:
	return count_nodes(self)


static func count_nodes(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += count_nodes(child)
	return total


# --- animasyon ------------------------------------------------------------

func _animate(time: float) -> void:
	if _fan_pivot != null:
		_fan_pivot.rotation.z = -time * FAN_SPEED
	if _gear_pivot != null:
		_gear_pivot.rotation.z = time * GEAR_SPEED
	if _lamp_pivot != null and _is_menu():
		_lamp_pivot.rotation.z = sin(time * LAMP_SWING_SPEED) * LAMP_SWING
	if _lamp_light != null:
		var swing: float = sin(time * LAMP_SWING_SPEED + 0.7) * 0.12
		_lamp_light.light_energy = _lamp_base_energy * _intensity * (1.0 + swing)
		if _lamp_light_game:
			# Işık kaynağı yavaşça salınır: panoda gezinen sıcak havuz (ASMR).
			_lamp_light.position = _lamp_light_base_position + Vector3(
				sin(time * LAMP_SWING_SPEED) * 0.05,
				sin(time * LAMP_SWING_SPEED * 0.7 + 1.1) * 0.03,
				0.0)
	for roller: Node3D in _rollers:
		roller.rotation.z = time * CONVEYOR_SPEED
	for i: int in _bobbins.size():
		var bobbin: Node3D = _bobbins[i]
		var base: Vector3 = _bobbin_bases[i]
		var phase: float = PI * float(i)
		if _bobbins_vertical:
			bobbin.position = Vector3(
				base.x,
				base.y + sin(time * BOBBIN_SPEED + phase) * GAME_BOBBIN_TRAVEL,
				base.z)
			bobbin.rotation.y = sin(time * 0.18 + phase) * 0.4
		else:
			bobbin.position = Vector3(
				base.x + sin(time * BOBBIN_SPEED + phase) * MENU_BOBBIN_TRAVEL,
				base.y,
				base.z)
			bobbin.rotation.y = time * 0.22 + phase
	if _neon_material != null:
		var neons_breath: float = 0.78 + 0.22 * sin(time * 0.42)
		_neon_material.set_shader_parameter("emission_energy",
			NEON_ENERGY * _intensity * neons_breath)


func _animate_menu_camera(time: float) -> void:
	if _menu_camera == null:
		return
	# Menüde kamera nefes alır: çok yavaş yatay kayma + dikey salınım (period >= 8 sn).
	_menu_camera.position = Vector3(
		sin(time * 0.11) * 0.10,
		0.22 + sin(time * 0.07 + 1.2) * 0.045,
		5.25)
	_menu_camera.rotation = Vector3(-0.015 + sin(time * 0.09) * 0.004, 0.0, 0.0)


func _apply_intensity() -> void:
	if _lamp_light != null:
		_lamp_light.light_energy = _lamp_base_energy * _intensity
	if _menu_light != null:
		_menu_light.light_energy = 0.35 * _intensity
	if _neon_material != null:
		_neon_material.set_shader_parameter("emission_energy", NEON_ENERGY * _intensity)
	for particles: GPUParticles3D in _steam:
		particles.amount_ratio = clampf(0.25 + 0.75 * _intensity, 0.0, 1.0)
		particles.emitting = _intensity > 0.02


# --- malzemeler -----------------------------------------------------------

func _build_materials() -> void:
	_matte_material = _shader_material("res://assets/shaders/batched_matte.gdshader")
	if _matte_material != null:
		_matte_material.set_shader_parameter("roughness", 0.45)
		_matte_material.set_shader_parameter("metallic_scale", 1.0)
	_neon_material = _shader_material("res://assets/shaders/batched_neon.gdshader")
	if _neon_material != null:
		_neon_material.set_shader_parameter("albedo_scale", 0.35)
		_neon_material.set_shader_parameter("emission_energy", NEON_ENERGY)


func _shader_material(path: String) -> ShaderMaterial:
	var shader: Shader = load(path) as Shader
	if shader == null:
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


func _wall_material() -> Material:
	var shader: Shader = load("res://assets/shaders/workshop_wall.gdshader") as Shader
	if shader == null:
		var fallback: StandardMaterial3D = StandardMaterial3D.new()
		fallback.albedo_color = WALL_BASE
		fallback.roughness = 0.85
		return fallback
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color",
		Vector4(WALL_BASE.r, WALL_BASE.g, WALL_BASE.b, 1.0))
	material.set_shader_parameter("warm_color", Vector4(0.30, 0.19, 0.10, 1.0))
	return material


## Yalnızca menüdeki lamba parçaları (rim/bulb) için tek malzeme.
func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color * 0.35
	material.metallic = 0.1
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


# --- geometri biriktirme: iki vertex-renkli batch (matte + neon) ----------
## Tüm statik parçalar 2 draw call'a iner (ARCHITECTURE §14).

func _add_prim(key: String, mesh: PrimitiveMesh, xform: Transform3D) -> void:
	match key:
		"mint":
			_neon_ops.append({"mesh": mesh, "xform": xform, "color": _linear(MINT)})
		"warm":
			_neon_ops.append({"mesh": mesh, "xform": xform, "color": _linear(WARM)})
		"metal_dark":
			_matte_ops.append({"mesh": mesh, "xform": xform,
				"color": _matte_color(METAL_DARK, 0.35)})
		_:
			_matte_ops.append({"mesh": mesh, "xform": xform,
				"color": _matte_color(METAL, 0.55)})


func _commit_batches() -> void:
	if not _matte_ops.is_empty():
		add_child(_batch_instance("StaticMatte", _matte_ops, _matte_material))
	if not _neon_ops.is_empty():
		add_child(_batch_instance("StaticNeon", _neon_ops, _neon_material))


func _batch_instance(node_name: String, ops: Array[Dictionary],
		material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _merged_colored_mesh(ops)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return instance


## Dönen parçalar (fan/gear/bobbin/roller) için tek parça renkli mesh.
func _single_instance(node_name: String, ops: Array, key: String) -> MeshInstance3D:
	var neon: bool = key == "mint" or key == "warm"
	var color: Color = _linear(MINT) if key == "mint" else _linear(WARM)
	if not neon:
		color = _matte_color(METAL, 0.55) if key != "metal_dark" 			else _matte_color(METAL_DARK, 0.35)
	var colored: Array[Dictionary] = []
	for op: Dictionary in ops:
		colored.append({"mesh": op["mesh"], "xform": op["xform"], "color": color})
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _merged_colored_mesh(colored)
	instance.material_override = _neon_material if neon else _matte_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Vertex-renkli birleşik mesh (tek yüzey).
func _merged_colored_mesh(ops: Array[Dictionary]) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var offset: int = 0
	for op: Dictionary in ops:
		var mesh: PrimitiveMesh = op["mesh"] as PrimitiveMesh
		if mesh == null:
			continue
		var xform: Transform3D = op["xform"] as Transform3D
		var color: Color = op["color"] as Color
		var arrays: Array = mesh.get_mesh_arrays()
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i: int in source_vertices.size():
			vertices.append(xform * source_vertices[i])
			if i < source_normals.size():
				normals.append((xform.basis * source_normals[i]).normalized())
			else:
				normals.append(Vector3.UP)
			colors.append(color)
		if arrays[Mesh.ARRAY_INDEX] == null:
			for i: int in source_vertices.size():
				indices.append(offset + i)
		else:
			for index: int in (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array):
				indices.append(offset + index)
		offset += source_vertices.size()
	var mesh_out: ArrayMesh = ArrayMesh.new()
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = vertices
	arrays_out[Mesh.ARRAY_NORMAL] = normals
	arrays_out[Mesh.ARRAY_COLOR] = colors
	arrays_out[Mesh.ARRAY_INDEX] = indices
	mesh_out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
	return mesh_out


func _linear(color: Color) -> Color:
	return color.srgb_to_linear()


func _matte_color(base_color: Color, metallic: float) -> Color:
	var color: Color = base_color.srgb_to_linear()
	color.a = clampf(metallic, 0.0, 1.0)
	return color


func _xform(position: Vector3, rotation_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	var basis: Basis = Basis.from_euler(rotation_deg * (PI / 180.0))
	return Transform3D(basis, position)


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder_mesh(radius: float, height: float, segments: int = 10) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _cone_mesh(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


# --- duvar ----------------------------------------------------------------

func _build_wall() -> void:
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.name = "Wall"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = WALL_SIZE
	plane.orientation = PlaneMesh.FACE_Z
	wall.mesh = plane
	wall.position = Vector3(0.0, WALL_CENTER_Y, WALL_Z)
	wall.material_override = _wall_material()
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(wall)
	# Menüde duvara asılı devre şeması levhası (oyunda pano arkasında kalır: draw yok).
	if not _is_menu():
		return
	var shader: Shader = load("res://assets/shaders/pano_grid.gdshader") as Shader
	if shader == null:
		return
	var blueprint: MeshInstance3D = MeshInstance3D.new()
	blueprint.name = "WallBlueprint"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.34, 1.80)
	blueprint.mesh = quad
	blueprint.position = Vector3(0.0, 0.52, WALL_Z + 0.012)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grid_intensity", 0.05)
	material.set_shader_parameter("trace_intensity", 0.20)
	material.set_shader_parameter("scan_speed", 0.03)
	blueprint.material_override = material
	blueprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blueprint)


# --- statik atölye parçaları ---------------------------------------------

func _build_static_shop() -> void:
	var menu: bool = _is_menu()
	# Tavan kirişleri: yalnızca menüde (oyunda üst HUD bandına girer).
	if menu:
		for i: int in 2:
			_add_prim("metal_dark", _box_mesh(Vector3(9.0, 0.10, 0.26)),
				_xform(Vector3(0.0, 2.55 + float(i) * 0.42, -2.2)))
	# Duvar panelleri: sol/sağ şeritlerde endüstriyel plakalar
	var plate_positions: Array[Vector3] = [
		Vector3(-1.62, 1.55, -2.32), Vector3(-1.72, 0.55, -2.32),
		Vector3(-1.66, -0.75, -2.32), Vector3(1.68, 1.30, -2.32),
		Vector3(1.62, -1.05, -2.32),
	]
	for i: int in plate_positions.size():
		var position: Vector3 = plate_positions[i]
		_add_prim("metal", _box_mesh(Vector3(0.44, 0.58, 0.045)), _xform(position))
		_add_prim("metal_dark", _box_mesh(Vector3(0.34, 0.48, 0.02)),
			_xform(position + Vector3(0.0, 0.0, 0.035)))
		var accent_key: String = "warm" if i % 2 == 0 else "mint"
		_add_prim(accent_key, _box_mesh(Vector3(0.06, 0.22, 0.012)),
			_xform(position + Vector3(0.0, 0.10, 0.052)))
	# Dikey borular (kenar şeritleri): oyunda üst HUD bandına girmesin diye kısa.
	var pipe_height: float = 4.4 if menu else 3.0
	var pipe_center_y: float = 0.15 if menu else 0.30
	for side: float in [-1.0, 1.0]:
		_add_prim("metal", _cylinder_mesh(0.075, pipe_height, 10),
			_xform(Vector3(side * 1.86, pipe_center_y, -2.28)))
		for i: int in 3:
			_add_prim("metal_dark", _box_mesh(Vector3(0.16, 0.05, 0.10)),
				_xform(Vector3(side * 1.86, pipe_center_y - 1.35 + float(i) * 1.35, -2.24)))
	# Duvardaki küçük bağlantı kutuları
	if menu:
		_add_prim("metal_dark", _box_mesh(Vector3(0.20, 0.14, 0.10)),
			_xform(Vector3(-1.30, 2.55, -2.30)))
		_add_prim("mint", _box_mesh(Vector3(0.03, 0.05, 0.012)),
			_xform(Vector3(-1.30, 2.60, -2.24)))
		_add_prim("metal_dark", _box_mesh(Vector3(0.20, 0.14, 0.10)),
			_xform(Vector3(1.45, 2.42, -2.30)))
		_add_prim("warm", _box_mesh(Vector3(0.03, 0.05, 0.012)),
			_xform(Vector3(1.45, 2.47, -2.24)))
	else:
		# Oyunda aynı kutular yan şeridin üst kısmında (HUD bandı altında) kalır.
		_add_prim("metal_dark", _box_mesh(Vector3(0.20, 0.14, 0.10)),
			_xform(Vector3(-1.72, 1.86, -2.30)))
		_add_prim("mint", _box_mesh(Vector3(0.03, 0.05, 0.012)),
			_xform(Vector3(-1.72, 1.90, -2.24)))


## Duvarın yan şeritlerine yerleşen küçük endüstriyel detaylar (statik, batch'li).
func _build_wall_details() -> void:
	var menu: bool = _is_menu()
	# Köşe ışık şeritleri: kenarlarda çok hafif mint/amber sızıntısı (nefes alır).
	var strip_height: float = 3.20 if menu else 2.40
	var strip_center_y: float = 0.40 if menu else 0.30
	for side: float in [-1.0, 1.0]:
		var key: String = "mint" if side < 0.0 else "warm"
		_add_prim(key, _box_mesh(Vector3(0.018, strip_height, 0.012)),
			_xform(Vector3(side * 1.94, strip_center_y, -2.33)))
		_add_prim("metal_dark", _box_mesh(Vector3(0.24, 0.03, 0.02)),
			_xform(Vector3(side * 1.64, 0.05, -2.32)))
	# Menüde üst bantta havalandırma ızgaraları; oyunda HUD bandına girmemeli.
	if menu:
		for side: float in [-1.0, 1.0]:
			for i: int in 4:
				_add_prim("metal_dark", _box_mesh(Vector3(0.36, 0.020, 0.030)),
					_xform(Vector3(side * 1.36, 2.32 - float(i) * 0.075, -2.31)))
	# Orta arka duvara asılı alet panosu (menü kompozisyonuna derinlik).
	_add_prim("metal_dark", _box_mesh(Vector3(1.06, 0.64, 0.04)),
		_xform(Vector3(0.0, -0.62, -2.33)))
	_add_prim("metal", _box_mesh(Vector3(0.94, 0.52, 0.02)),
		_xform(Vector3(0.0, -0.62, -2.30)))
	for i: int in 3:
		_add_prim("metal_dark", _box_mesh(Vector3(0.030, 0.38, 0.030)),
			_xform(Vector3(-0.30 + float(i) * 0.30, -0.62, -2.27)))


# --- fan ------------------------------------------------------------------

func _build_fan() -> void:
	var center: Vector3 = _fan_center()
	_fan_pivot = Node3D.new()
	_fan_pivot.name = "Fan"
	_fan_pivot.position = center
	add_child(_fan_pivot)
	var ops: Array = []
	for i: int in 3:
		var angle: float = TAU * float(i) / 3.0
		var blade_basis: Basis = Basis(Vector3.BACK, angle)
		ops.append({"mesh": _box_mesh(FAN_BLADE_SIZE),
			"xform": Transform3D(blade_basis,
				blade_basis * Vector3(FAN_RADIUS * 0.52, 0.0, 0.0))})
	ops.append({"mesh": _cylinder_mesh(0.075, 0.10, 10),
		"xform": _xform(Vector3.ZERO, Vector3(90.0, 0.0, 0.0))})
	_fan_pivot.add_child(_single_instance("FanBlades", ops, "metal"))
	# Koruma teli: statik, fanın hemen önünde (dönmez)
	_add_prim("metal_dark", _cylinder_mesh(0.045, 0.10, 8),
		_xform(center + Vector3(0.0, 0.0, 0.10), Vector3(90.0, 0.0, 0.0)))
	for i: int in 4:
		var bar_angle: float = PI * float(i) / 4.0
		_add_prim("metal", _box_mesh(Vector3(FAN_RADIUS * 2.05, 0.018, 0.018)),
			_xform(center + Vector3(0.0, 0.0, 0.10), Vector3(0.0, 0.0, bar_angle)))


# --- dişli ----------------------------------------------------------------

func _build_gear() -> void:
	var center: Vector3 = _gear_center()
	_gear_pivot = Node3D.new()
	_gear_pivot.name = "Gear"
	_gear_pivot.position = center
	add_child(_gear_pivot)
	var ops: Array = []
	ops.append({"mesh": _cylinder_mesh(GEAR_RADIUS * 0.72, 0.05, 12),
		"xform": _xform(Vector3.ZERO, Vector3(90.0, 0.0, 0.0))})
	for i: int in 7:
		var angle: float = TAU * float(i) / 7.0
		var offset: Vector3 = Basis(Vector3.BACK, angle) * Vector3(GEAR_RADIUS * 0.9, 0.0, 0.0)
		ops.append({"mesh": _box_mesh(Vector3(0.10, 0.08, 0.05)),
			"xform": Transform3D(Basis(Vector3.BACK, angle), offset)})
	_gear_pivot.add_child(_single_instance("GearTeeth", ops, "metal"))


# --- asma lamba -----------------------------------------------------------

func _build_lamp() -> void:
	if _is_menu():
		_lamp_pivot = Node3D.new()
		_lamp_pivot.name = "Lamp"
		_lamp_pivot.position = MENU_LAMP_PIVOT
		add_child(_lamp_pivot)
		var ops: Array = []
		ops.append({"mesh": _cylinder_mesh(0.012, LAMP_ARM, 6),
			"xform": _xform(Vector3(0.0, -LAMP_ARM * 0.5, 0.0))})
		ops.append({"mesh": _cone_mesh(0.055, 0.235, 0.20),
			"xform": _xform(Vector3(0.0, -LAMP_ARM - 0.02, 0.0))})
		_lamp_pivot.add_child(_single_instance("LampArm", ops, "metal_dark"))
		# Abajurun alt kenarı: sıcak, yumuşak parlayan halka (tek draw).
		var rim: MeshInstance3D = MeshInstance3D.new()
		rim.name = "LampRim"
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.222
		torus.outer_radius = 0.248
		torus.rings = 16
		torus.ring_segments = 6
		rim.mesh = torus
		rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		rim.position = Vector3(0.0, -LAMP_ARM - 0.115, 0.0)
		rim.material_override = _emissive(WARM, 0.85)
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lamp_pivot.add_child(rim)
		var bulb: MeshInstance3D = MeshInstance3D.new()
		bulb.name = "Bulb"
		bulb.mesh = _sphere_mesh(0.055)
		bulb.material_override = _emissive(WARM, 1.1)
		bulb.position = Vector3(0.0, -LAMP_ARM - 0.10, 0.0)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lamp_pivot.add_child(bulb)
		_lamp_light = OmniLight3D.new()
		_lamp_light.name = "LampLight"
		_lamp_light.position = Vector3(0.0, -LAMP_ARM - 0.12, 0.0)
		_lamp_pivot.add_child(_lamp_light)
		_lamp_light_game = false
	else:
		# Oyun: gövde görünmez, yalnızca panonun önünde salınan sıcak ışık kalır.
		_lamp_pivot = Node3D.new()
		_lamp_pivot.name = "LampHidden"
		_lamp_pivot.visible = false
		add_child(_lamp_pivot)
		_lamp_light = OmniLight3D.new()
		_lamp_light.name = "LampSwing"
		_lamp_light.position = GAME_LAMP_LIGHT_POSITION
		add_child(_lamp_light)
		_lamp_light_game = true
		_lamp_light_base_position = GAME_LAMP_LIGHT_POSITION
	_lamp_light.light_color = WARM
	_lamp_light.light_energy = _lamp_base_energy
	_lamp_light.omni_range = 4.6
	_lamp_light.omni_attenuation = 1.35
	_lamp_light.shadow_enabled = false


# --- konveyör + bobinler --------------------------------------------------

func _build_conveyor() -> void:
	if _is_menu():
		_build_menu_conveyor()
	else:
		_build_game_bobbin_lift()


func _build_menu_conveyor() -> void:
	_add_prim("metal_dark", _box_mesh(Vector3(MENU_CONVEYOR_LENGTH, 0.14, 0.46)),
		_xform(MENU_CONVEYOR_CENTER))
	for side: float in [-1.0, 1.0]:
		_add_prim("metal", _box_mesh(Vector3(MENU_CONVEYOR_LENGTH, 0.09, 0.05)),
			_xform(MENU_CONVEYOR_CENTER + Vector3(0.0, 0.07, side * 0.235)))
		_add_prim("metal_dark", _box_mesh(Vector3(0.10, 0.42, 0.10)),
			_xform(MENU_CONVEYOR_CENTER + Vector3(side * MENU_CONVEYOR_LENGTH * 0.5, -0.22, 0.0)))
	for i: int in 3:
		var roller: Node3D = Node3D.new()
		roller.name = "Roller%d" % i
		roller.position = MENU_CONVEYOR_CENTER + Vector3(-1.05 + 1.05 * float(i), 0.02, 0.0)
		add_child(roller)
		var ops: Array = []
		ops.append({"mesh": _cylinder_mesh(0.075, 0.40, 8),
			"xform": _xform(Vector3.ZERO, Vector3(90.0, 0.0, 0.0))})
		ops.append({"mesh": _box_mesh(Vector3(0.05, 0.05, 0.42)),
			"xform": Transform3D.IDENTITY})
		roller.add_child(_single_instance("RollerMesh", ops, "metal"))
		_rollers.append(roller)
	_bobbins_vertical = false
	for i: int in 2:
		_create_bobbin(MENU_CONVEYOR_CENTER + Vector3(-0.45 + 0.95 * float(i), 0.16, 0.0),
			"Bobbin%d" % i)


## Oyun: yanda dikey bobin hattı (üst/alt HUD bantlarına girmez, yavaş salınır).
func _build_game_bobbin_lift() -> void:
	var center: Vector3 = GAME_BOBBIN_CENTER
	for side: float in [-1.0, 1.0]:
		_add_prim("metal", _box_mesh(Vector3(0.05, 1.70, 0.05)),
			_xform(center + Vector3(side * 0.18, 0.0, 0.0)))
		_add_prim("metal_dark", _box_mesh(Vector3(0.05, 0.02, 0.24)),
			_xform(center + Vector3(side * 0.18, 0.86, 0.0)))
	_add_prim("metal_dark", _box_mesh(Vector3(0.26, 0.05, 0.22)), _xform(center))
	_bobbins_vertical = true
	for i: int in 2:
		_create_bobbin(center + Vector3(0.0, -0.30 + 0.60 * float(i), 0.0),
			"BobbinLift%d" % i)


func _create_bobbin(base: Vector3, node_name: String) -> void:
	var bobbin: Node3D = Node3D.new()
	bobbin.name = node_name
	bobbin.position = base
	add_child(bobbin)
	var ops: Array = []
	ops.append({"mesh": _cylinder_mesh(0.115, 0.17, 10), "xform": _xform(Vector3.ZERO)})
	ops.append({"mesh": _cylinder_mesh(0.135, 0.02, 10),
		"xform": _xform(Vector3(0.0, 0.09, 0.0))})
	ops.append({"mesh": _cylinder_mesh(0.135, 0.02, 10),
		"xform": _xform(Vector3(0.0, -0.09, 0.0))})
	bobbin.add_child(_single_instance("BobbinMesh", ops, "metal"))
	_bobbins.append(bobbin)
	_bobbin_bases.append(base)


# --- buhar ----------------------------------------------------------------

func _build_steam() -> void:
	var positions: Array[Vector3] = []
	if _is_menu():
		positions = [
			MENU_CONVEYOR_CENTER + Vector3(-1.15, 0.30, -0.05),
			MENU_CONVEYOR_CENTER + Vector3(1.15, 0.30, -0.05),
		]
	else:
		# Oyunda tek buhar kaynağı yeter (draw call bütçesi); sol/orta konumda.
		positions = [GAME_STEAM_RIGHT]
	for i: int in positions.size():
		var particles: GPUParticles3D = GPUParticles3D.new()
		particles.name = "Steam%d" % i
		particles.position = positions[i]
		particles.amount = STEAM_AMOUNT
		particles.lifetime = 4.2
		particles.preprocess = 2.0
		particles.one_shot = false
		particles.local_coords = false
		particles.fixed_fps = 30
		particles.visibility_aabb = AABB(Vector3(-0.6, -0.4, -0.6), Vector3(1.2, 1.6, 1.2))
		particles.emitting = true
		var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
		process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_material.emission_box_extents = Vector3(0.12, 0.02, 0.05)
		process_material.direction = Vector3(0.0, 1.0, 0.0)
		process_material.spread = 24.0
		process_material.initial_velocity_min = 0.04
		process_material.initial_velocity_max = 0.12
		process_material.gravity = Vector3(0.0, 0.03, 0.0)
		process_material.damping_min = 0.02
		process_material.damping_max = 0.05
		process_material.scale_min = 0.5
		process_material.scale_max = 1.6
		process_material.color = Color(0.95, 0.90, 0.84, 0.10)
		particles.process_material = process_material
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.13, 0.13)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = Color(1.0, 1.0, 1.0, 0.38)
		quad.material = material
		particles.draw_pass_1 = quad
		add_child(particles)
		_steam.append(particles)


# --- menü görünümü (kamera + ortam) ---------------------------------------

func _build_menu_view() -> void:
	_menu_camera = Camera3D.new()
	_menu_camera.name = "MenuCamera"
	_menu_camera.position = Vector3(0.0, 0.22, 5.25)
	_menu_camera.rotation = Vector3(-0.015, 0.0, 0.0)
	_menu_camera.fov = 46.0
	_menu_camera.near = 0.05
	_menu_camera.far = 40.0
	_menu_camera.current = true
	add_child(_menu_camera)

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = WALL_BASE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.52, 0.44)
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.58
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.09
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 1.12
	environment.set("glow_levels/1", true)
	environment.set("glow_levels/2", true)
	environment.set("glow_levels/3", true)
	environment.set("glow_levels/4", false)

	_menu_environment = WorldEnvironment.new()
	_menu_environment.name = "MenuEnvironment"
	_menu_environment.environment = environment
	add_child(_menu_environment)

	# Menü ışıkları: sıcak anahtar + mint dolgu (oyun sahnesindeki dengeyle uyumlu).
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "MenuKeyLight"
	key_light.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	key_light.light_color = Color(1.0, 0.87, 0.73)
	key_light.light_energy = 0.55
	key_light.shadow_enabled = false
	add_child(key_light)

	_menu_light = OmniLight3D.new()
	_menu_light.name = "MenuFill"
	_menu_light.position = Vector3(-2.1, -1.2, 1.7)
	_menu_light.light_color = MINT
	_menu_light.light_energy = 0.35
	_menu_light.omni_range = 5.5
	_menu_light.shadow_enabled = false
	add_child(_menu_light)

	var warm_fill: OmniLight3D = OmniLight3D.new()
	warm_fill.name = "MenuWarmFill"
	warm_fill.position = Vector3(2.3, 1.7, 1.2)
	warm_fill.light_color = WARM
	warm_fill.light_energy = 0.30
	warm_fill.omni_range = 5.0
	warm_fill.shadow_enabled = false
	add_child(warm_fill)
