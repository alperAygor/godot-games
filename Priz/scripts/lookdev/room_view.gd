class_name RoomView
extends Node3D

## Tek oda dioraması: ortam, güneş, dolgu ışığı, kamera, gün ışığı yöneticisi ve oda modeli.
## Oyun sahnesi bunu örnekler; prizlere, hatlara ve cihaz yerlerine buradan erişir.
##
## Kamu arayüzü:
##   get_socket(id: String) -> Node3D          ("Socket_01"..); yerel +Z duvardan dışarı
##   get_socket_ids() -> PackedStringArray
##   line_of_socket(id: String) -> int        (1..3)
##   get_anchor(name: String) -> Node3D        ("Anchor_Fridge" ... "Anchor_FuseBox")
##   set_line_glow(line: int, glow: float)     — kablo parlaması (0 sönük, 1 akım, 2+ sınırda)
##   set_line_highlight(line: int, v: float)   — dokununca hattın kablo + prizleri parlar
##   set_socket_highlight(id: String, v: float)— tek priz vurgusu (sürüklemede uygun prizler)
##   set_socket_dim(id: String, v: float)      — takılamayan prizler solar
##   set_quality(tier: int)                    — QualityTiers.Tier
##   day_light, camera_rig                     — DayLight / DioramaCamera

const ROOM_SCENE: PackedScene = preload("res://assets/models/room/room_studio.glb")
const BACKDROP_SHADER: Shader = preload("res://assets/shaders/backdrop_sky.gdshader")

const LINE_COLORS: Array[Color] = [Color(0.88, 0.34, 0.29), Color(0.25, 0.56, 0.85), Color(0.91, 0.70, 0.23)]
## Prizin bağlı olduğu hat (tools/blender/make_room.py SOCKETS ile aynı).
const SOCKET_LINES: Dictionary = {
	"Socket_01": 1, "Socket_02": 1, "Socket_03": 2, "Socket_04": 3,
	"Socket_05": 3, "Socket_06": 2, "Socket_07": 2,
}

@export var quality: int = QualityTiers.Tier.HIGH
@export var start_slice: int = DayLight.Slice.NOON

var environment: Environment
var backdrop_material: ShaderMaterial
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var day_light: DayLight
var camera_rig: DioramaCamera
var shafts: LightShafts
var reflection_probe: ReflectionProbe
var room: Node3D
var appliances_root: Node3D

var _sockets: Dictionary = {}       # id -> Node3D (priz yeri; yerel +Z duvardan dışarı)
var _anchors: Dictionary = {}       # ad -> Node3D
var _cable_mat: ShaderMaterial      # tüm hat kabloları tek ağ (Cables_noshadow)
var _marker_mat: ShaderMaterial     # tüm priz işaretleri tek ağ (SocketMarkers)
var _line_glow: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _line_hl: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _line_dim: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _socket_hl: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _socket_dim: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
	_build_environment()
	_build_lights()
	room = ROOM_SCENE.instantiate() as Node3D
	room.name = "Room"
	add_child(room)
	appliances_root = Node3D.new()
	appliances_root.name = "Appliances"
	add_child(appliances_root)
	_index_room(room)
	shafts = LightShafts.new()
	shafts.name = "LightShafts"
	add_child(shafts)
	camera_rig = DioramaCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	_build_reflection_probe()
	day_light = DayLight.new()
	day_light.name = "DayLight"
	add_child(day_light)
	var sky_mat: ShaderMaterial = _setup_window_view()
	day_light.setup(sun, fill, environment, sky_mat, shafts, camera_rig)
	day_light.backdrop = backdrop_material
	var bounce: OmniLight3D = OmniLight3D.new()
	bounce.name = "SunBounce"
	bounce.omni_range = 3.4
	bounce.omni_attenuation = 1.2
	bounce.shadow_enabled = false
	bounce.light_specular = 0.0
	add_child(bounce)
	day_light.bounce = bounce
	_build_interior_lights()
	day_light.set_slice(start_slice, 0.0)
	for mat: ShaderMaterial in [_cable_mat, _marker_mat]:
		if mat != null:
			mat.set_shader_parameter("line_colors", PackedColorArray(LINE_COLORS + [Color(0.6, 0.42, 0.84)]))
	if _cable_mat != null:
		_cable_mat.set_shader_parameter("glow", _line_glow)
		_cable_mat.set_shader_parameter("highlight", _line_hl)
		_cable_mat.set_shader_parameter("dim", _line_dim)
	if _marker_mat != null:
		_marker_mat.set_shader_parameter("highlight", _socket_hl)
		_marker_mat.set_shader_parameter("dim", _socket_dim)
	set_quality(quality)


func set_quality(tier: int) -> void:
	quality = tier
	QualityTiers.apply(tier, self)


func get_socket(id: String) -> Node3D:
	return _sockets.get(id, null) as Node3D


func get_socket_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for k: String in _sockets.keys():
		ids.append(k)
	ids.sort()
	return ids


func line_of_socket(id: String) -> int:
	return int(SOCKET_LINES.get(id, 0))


func get_anchor(anchor_name: String) -> Node3D:
	return _anchors.get(anchor_name, null) as Node3D


func set_line_glow(line: int, glow: float) -> void:
	_set_line_param(_line_glow, "glow", line, glow)


func set_line_highlight(line: int, v: float) -> void:
	_set_line_param(_line_hl, "highlight", line, v)
	for id: String in _sockets.keys():
		if line_of_socket(id) == line:
			set_socket_highlight(id, v)


func set_line_dim(line: int, v: float) -> void:
	_set_line_param(_line_dim, "dim", line, v)


func set_socket_highlight(id: String, v: float) -> void:
	var i: int = _socket_index(id)
	if i < 0 or _marker_mat == null:
		return
	_socket_hl[i] = v
	_marker_mat.set_shader_parameter("highlight", _socket_hl)


func set_socket_dim(id: String, v: float) -> void:
	var i: int = _socket_index(id)
	if i < 0 or _marker_mat == null:
		return
	_socket_dim[i] = v
	_marker_mat.set_shader_parameter("dim", _socket_dim)


func _socket_index(id: String) -> int:
	if not id.begins_with("Socket_"):
		return -1
	var i: int = int(id.substr(7)) - 1
	return i if i >= 0 and i < 8 else -1


func _set_line_param(arr: PackedFloat32Array, param: String, line: int, v: float) -> void:
	if line < 1 or line > 4 or _cable_mat == null:
		return
	arr[line - 1] = v
	_cable_mat.set_shader_parameter(param, arr)


## Bir cihaz sahnesini çapanın dönüşümüyle yerleştirir.
func place_at_anchor(node: Node3D, anchor_name: String) -> void:
	var a: Node3D = get_anchor(anchor_name)
	appliances_root.add_child(node)
	if a != null:
		node.global_transform = a.global_transform


func _index_room(node: Node) -> void:
	var n: String = String(node.name)
	if n.begins_with("Socket_") and node is Node3D:
		_sockets[n] = node
	elif n == "SocketMarkers" and node is MeshInstance3D:
		_marker_mat = _own_shader(node as MeshInstance3D)
	elif n.begins_with("Cables") and node is MeshInstance3D:
		_cable_mat = _own_shader(node as MeshInstance3D)
	elif n.begins_with("Anchor_") or n.begins_with("LightAnchor_"):
		_anchors[n] = node
	for c: Node in node.get_children():
		_index_room(c)


func _own_shader(mi: MeshInstance3D) -> ShaderMaterial:
	var src: ShaderMaterial = mi.mesh.surface_get_material(0) as ShaderMaterial
	if src == null:
		return null
	var copy: ShaderMaterial = src.duplicate() as ShaderMaterial
	mi.set_surface_override_material(0, copy)
	return copy


func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	environment.ambient_light_energy = 0.6
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky: Sky = Sky.new()
	backdrop_material = ShaderMaterial.new()
	backdrop_material.shader = BACKDROP_SHADER
	sky.sky_material = backdrop_material
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.set_glow_level(0, 0.0)
	environment.set_glow_level(1, 1.0)
	environment.set_glow_level(2, 1.0)
	environment.set_glow_level(3, 0.8)
	environment.set_glow_level(4, 0.5)
	environment.set_glow_level(5, 0.2)
	environment.glow_intensity = 0.6
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.glow_hdr_threshold = 0.95
	environment.glow_hdr_scale = 2.0
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.05
	environment.adjustment_saturation = 1.08
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = environment
	add_child(world_env)


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 24.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	sun.light_angular_distance = 1.2
	sun.position = Vector3(2.7, 6.0, -3.0)
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.name = "Fill"
	fill.shadow_enabled = false
	fill.light_specular = 0.25
	fill.rotation_degrees = Vector3(-48.0, 50.0, 0.0)
	add_child(fill)


func _build_reflection_probe() -> void:
	reflection_probe = ReflectionProbe.new()
	reflection_probe.name = "RoomProbe"
	reflection_probe.size = Vector3(5.4, 2.7, 4.4)
	reflection_probe.position = Vector3(2.7, 1.35, 2.2)
	reflection_probe.box_projection = true
	reflection_probe.interior = true
	reflection_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection_probe.intensity = 0.8
	reflection_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(reflection_probe)


func _setup_window_view() -> ShaderMaterial:
	var view: MeshInstance3D = _find_mesh(room, "WindowView_noshadow")
	if view == null:
		push_warning("RoomView: pencere manzarası yok")
		return null
	var mat: ShaderMaterial = (view.mesh.surface_get_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
	view.set_surface_override_material(0, mat)
	mat.set_shader_parameter("uv_scale", Vector2(1.0, 0.8))
	mat.set_shader_parameter("uv_offset", Vector2(0.0, 0.05))
	return mat


func _build_interior_lights() -> void:
	var warm: Color = Color(1.0, 0.74, 0.46)
	# Oda tavanı (görünmez armatür): gece sıcak ışık havuzu
	var ceil: OmniLight3D = OmniLight3D.new()
	ceil.name = "CeilingGlow"
	ceil.light_color = warm
	ceil.omni_range = 4.6
	ceil.omni_attenuation = 1.4
	ceil.shadow_enabled = false
	ceil.position = Vector3(2.9, 2.45, 2.0)
	add_child(ceil)
	day_light.add_interior_light(ceil, 1.4)
	var ka: Node3D = get_anchor("LightAnchor_Kitchen")
	if ka != null:
		var kl: OmniLight3D = OmniLight3D.new()
		kl.name = "KitchenLight"
		kl.light_color = Color(1.0, 0.8, 0.55)
		kl.omni_range = 1.5
		kl.omni_attenuation = 1.6
		kl.shadow_enabled = false
		ka.add_child(kl)
		day_light.add_interior_light(kl, 1.6)
	var ha: Node3D = get_anchor("LightAnchor_Hood")
	if ha != null:
		var hl: SpotLight3D = SpotLight3D.new()
		hl.name = "HoodLight"
		hl.light_color = Color(1.0, 0.85, 0.65)
		hl.spot_range = 1.4
		hl.spot_angle = 50.0
		hl.shadow_enabled = false
		ha.add_child(hl)
		hl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		day_light.add_interior_light(hl, 1.8)
	var strip: MeshInstance3D = _find_mesh(room, "KitchenStrip_noshadow")
	if strip != null:
		var sm: StandardMaterial3D = (strip.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		strip.set_surface_override_material(0, sm)
		day_light.add_interior_emissive(sm, 4.0)


func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if String(node.name) == mesh_name and node is MeshInstance3D:
		return node as MeshInstance3D
	for c: Node in node.get_children():
		var r: MeshInstance3D = _find_mesh(c, mesh_name)
		if r != null:
			return r
	return null
