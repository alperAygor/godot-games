class_name EndlessLevel
extends LevelRoot
## Sonsuz mod seviyesi: level planını (LevelProgression) parçalardan kurar, robotun
## ilerisini önceden üretir, gerideki parçaları siler ve uzak parçaları gizler.
## Sözleşme: PROJECT_SPEC §14. Teslimat noktası (`DeliveryZone`) her level'da ileri taşınır.
## Oyun mantığı (ödül, hasar, batarya) GameController'dadır; bu sınıf yalnız dünyayı kurar.

## Yeni bir kontrol noktası eklendiğinde (konum dünyadadır).
signal checkpoint_added(position: Vector3)
## Robot yeni bir bölgenin ilk level'ına geçtiğinde (bölge adı, sıra).
signal zone_changed(zone_name: String, zone_index: int)

const TABLE_NAME: String = "segments"
const ZONE_TABLE_NAME: String = "zones"
const ZONE_BLEND_SECONDS: float = 1.4
## Dolgu ışığı: gölge atmaz; kenar/arka ışığı gibi siluet çıkarır (ucuz).
## Bölge eşyaları: modeller +Z'ye bakar; kameraya dönük durmaları için yarım tur.
const ZONE_PROP_DIR: String = "res://assets/models/v3/zone/"
const ZONE_PROP_FACING_YAW: float = 180.0
const ZONE_PROP_POP_SECONDS: float = 0.7
const ZONE_PROP_HIDE_SECONDS: float = 0.35
## Masa temalı (bölge 0) arka plan eşyaları; diğer bölgelerde yerlerini bölge eşyaları alır.
const DESK_DECOR_NODES: Array[String] = ["BgMonitor", "BgLamp", "BgPlant", "BgBooks", "BgHeadphones"]
const SWAY_SCRIPT_PATH: String = "res://scripts/gameplay/ambient/sway.gd"
const FILL_YAW_OFFSET: float = 180.0
const FILL_PITCH_DEGREES: float = -25.0
const WOOD_MATERIAL_PATH: String = "res://assets/materials/wood.tres"
const WOOD_EDGE_MATERIAL_PATH: String = "res://assets/materials/wood_edge.tres"
const DEFAULT_SEED: int = 20261113
## Robotun ilerisinde en az bu kadar yol hazır tutulur (sis ~130 m'de bitiyor).
const BUILD_HORIZON: float = 150.0
## Bu kadar geride kalan parçalar silinir.
const KEEP_BEHIND: float = 30.0
const ACTIVE_BEHIND: float = 25.0
const ACTIVE_AHEAD: float = 120.0
const CHECKPOINT_SPACING: float = 40.0
const CHECKPOINT_MIN_TAIL: float = 10.0
const CHECKPOINT_HEIGHT: float = 0.58
const PAD_HEIGHT: float = 1.0
## Parça güncellemesi her kare gerekmez.
const UPDATE_EVERY_FRAMES: int = 6

@export var seed_value: int = DEFAULT_SEED

var current_level: int = 1

var _library: Array = []
var _scenes: Dictionary[String, PackedScene] = {}
var _live: Array[Segment] = []
var _level_end: Dictionary[int, float] = {}
var _built_level: int = 0
var _built_end_z: float = 0.0
var _frame: int = 0
var _checkpoints: Array[Vector3] = []
var _zones: Array = []
var _zone_materials: Dictionary[int, Array] = {}
var _zone_index: int = 0
var _zone_tween: Tween = null
var _sky_material: ProceduralSkyMaterial = null
var _environment: Environment = null

@onready var _segments_root: Node3D = $Segments
@onready var _pad: Area3D = $DeliveryZone
@onready var _backdrop: Node3D = $Backdrop
@onready var _style: StyleA = $StyleA as StyleA
@onready var _sun: DirectionalLight3D = $Sun as DirectionalLight3D
@onready var _world_environment: WorldEnvironment = $WorldEnvironment as WorldEnvironment
var _fill: DirectionalLight3D = null
## Bölge sırası -> o bölgenin arka plan eşya düğümleri ve her düğümün asıl ölçeği.
var _decor: Dictionary[int, Array] = {}
var _decor_scale: Dictionary[int, Array] = {}
var _decor_tween: Tween = null
var _decor_visible: int = -1


func _ready() -> void:
	super._ready()
	_load_library()
	_load_zones()
	_build_next_level()
	_place_pad()


func is_endless() -> bool:
	return true


## Mevcut level'ın bitiş çizgisinin dünya z'si (negatif).
func level_end_z() -> float:
	return float(_level_end.get(current_level, _built_end_z))


## Level tamamlandı: sonraki level'a geçer, teslimat noktasını ileri taşır.
func advance() -> void:
	current_level += 1
	while _built_level < current_level:
		_build_next_level()
	_place_pad()
	_enter_zone_if_new()


## GameController her fizik karesinde çağırır; maliyet düşük tutulur.
func update_world(robot_z: float) -> void:
	_backdrop.position.z = robot_z
	_frame += 1
	if _frame % UPDATE_EVERY_FRAMES != 0:
		return
	while _built_end_z > robot_z - BUILD_HORIZON:
		_build_next_level()
	for segment: Segment in _live.duplicate():
		var near_z: float = segment.position.z
		var far_z: float = near_z - segment.length
		if far_z > robot_z + KEEP_BEHIND:
			_live.erase(segment)
			segment.queue_free()
			continue
		var active: bool = near_z > robot_z - ACTIVE_AHEAD and far_z < robot_z + ACTIVE_BEHIND
		segment.set_active(active)


## Şimdiye kadar üretilen ara kontrol noktaları (GameController bağlanmadan önce de oluşur).
func checkpoint_positions() -> Array[Vector3]:
	return _checkpoints


## Araç/önizleme: seçilen bölgenin paletini ve zemini hemen uygular (oyun akışında kullanılmaz).
func preview_zone(index: int) -> void:
	if _zones.is_empty():
		return
	var clamped: int = clampi(index, 0, _zones.size() - 1)
	_apply_zone_instantly(clamped)
	_show_decor(clamped, false)
	var pair: Array = _materials_for_zone(clamped)
	for segment: Segment in _live:
		segment.apply_floor(pair[0] as Material, pair[1] as Material)


## Mevcut level'ın bölge sırası (0'dan).
func zone_index() -> int:
	return _zone_index


func segment_count() -> int:
	return _live.size()


func _load_library() -> void:
	var data: Node = get_node_or_null("/root/GameData")
	if data == null:
		return
	var table: Variant = data.call("table", TABLE_NAME)
	if table is Dictionary:
		var entries: Variant = (table as Dictionary).get("segments", [])
		if entries is Array:
			_library = entries as Array


func _build_next_level() -> void:
	var level: int = _built_level + 1
	var plan: Array[Dictionary] = LevelProgression.plan(level, seed_value, _library)
	var start_z: float = _built_end_z
	for entry: Dictionary in plan:
		var segment: Segment = _instantiate_segment(String(entry["id"]))
		if segment == null:
			continue
		segment.position = Vector3(0.0, 0.0, start_z - float(entry["offset"]))
		_segments_root.add_child(segment)
		segment.apply_level(level)
		if _style != null:
			_style.restyle(segment)
		_theme_segment(segment, level)
		_live.append(segment)
	var length: float = LevelProgression.plan_length(plan)
	if plan.is_empty():
		length = LevelProgression.length_for(level)
	_built_end_z = start_z - length
	_level_end[level] = _built_end_z
	_built_level = level
	var marker_offset: float = CHECKPOINT_SPACING
	while marker_offset < length - CHECKPOINT_MIN_TAIL:
		var position_3d: Vector3 = Vector3(0.0, CHECKPOINT_HEIGHT, start_z - marker_offset)
		_checkpoints.append(position_3d)
		checkpoint_added.emit(position_3d)
		marker_offset += CHECKPOINT_SPACING


func _instantiate_segment(segment_id: String) -> Segment:
	var packed: PackedScene = _scenes.get(segment_id)
	if packed == null:
		for entry_raw: Variant in _library:
			var entry: Dictionary = entry_raw as Dictionary
			if String(entry.get("id", "")) == segment_id:
				packed = load(String(entry.get("scene", ""))) as PackedScene
				break
		if packed == null:
			push_warning("EndlessLevel: parça sahnesi yüklenemedi: %s" % segment_id)
			return null
		_scenes[segment_id] = packed
	return packed.instantiate() as Segment


func _place_pad() -> void:
	_pad.global_position = Vector3(0.0, PAD_HEIGHT, level_end_z())


func _load_zones() -> void:
	var data: Node = get_node_or_null("/root/GameData")
	if data == null:
		return
	var table: Variant = data.call("table", ZONE_TABLE_NAME)
	if table is Dictionary:
		var entries: Variant = (table as Dictionary).get("zones", [])
		if entries is Array:
			_zones = entries as Array
	if _world_environment != null:
		_environment = _world_environment.environment
		if _environment != null and _environment.sky != null:
			_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
	_create_fill_light()
	_collect_desk_decor()
	_apply_zone_instantly(0)
	_show_decor(0, false)


func _create_fill_light() -> void:
	_fill = DirectionalLight3D.new()
	_fill.name = "Fill"
	_fill.shadow_enabled = false
	add_child(_fill)


func _collect_desk_decor() -> void:
	var nodes: Array = []
	var scales: Array = []
	for node_name: String in DESK_DECOR_NODES:
		var node: Node3D = _backdrop.get_node_or_null(node_name) as Node3D
		if node != null:
			nodes.append(node)
			scales.append(node.scale)
	_decor[0] = nodes
	_decor_scale[0] = scales


## Bölgenin eşya düğümlerini ilk ihtiyaçta kurar (modeller yüklenir, stil uygulanır).
func _build_decor(index: int) -> void:
	var nodes: Array = []
	var scales: Array = []
	var zone: Dictionary = _zones[index] as Dictionary
	var props: Variant = zone.get("props", [])
	if props is Array:
		for entry: Variant in props as Array:
			if not entry is Dictionary:
				continue
			var spec: Dictionary = entry as Dictionary
			var scene: PackedScene = load(ZONE_PROP_DIR + String(spec.get("model", "")) + ".glb") as PackedScene
			if scene == null:
				continue
			var node: Node3D = scene.instantiate() as Node3D
			var pos: Array = spec.get("pos", [0.0, 0.0, 0.0]) as Array
			var size: float = float(spec.get("scale", 1.0))
			node.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			node.rotation_degrees.y = ZONE_PROP_FACING_YAW + float(spec.get("yaw", 0.0))
			node.scale = Vector3.ONE * size
			node.visible = false
			if bool(spec.get("sway", false)):
				node.set_script(load(SWAY_SCRIPT_PATH))
			_backdrop.add_child(node)
			var style: StyleA = get_node_or_null("StyleA") as StyleA
			if style != null:
				style.restyle(node)
			nodes.append(node)
			scales.append(node.scale)
	_decor[index] = nodes
	_decor_scale[index] = scales


## Seçili bölgenin eşyaları görünür olur, öncekiler küçülüp kaybolur.
func _show_decor(index: int, animated: bool) -> void:
	if _zones.is_empty() or index == _decor_visible:
		return
	if not _decor.has(index):
		_build_decor(index)
	if _decor_tween != null:
		_decor_tween.kill()
	var old_index: int = _decor_visible
	_decor_visible = index
	if animated:
		_decor_tween = create_tween().set_parallel(true)
	if old_index >= 0 and _decor.has(old_index):
		_retire_decor(old_index, animated)
	var nodes: Array = _decor[index]
	var scales: Array = _decor_scale[index]
	for i: int in range(nodes.size()):
		var node: Node3D = nodes[i] as Node3D
		var full: Vector3 = scales[i] as Vector3
		node.visible = true
		if animated:
			node.scale = Vector3.ONE * 0.001
			_decor_tween.tween_property(node, "scale", full, ZONE_PROP_POP_SECONDS)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12 * float(i))
		else:
			node.scale = full


func _retire_decor(index: int, animated: bool) -> void:
	var nodes: Array = _decor[index]
	for node_variant: Variant in nodes:
		var node: Node3D = node_variant as Node3D
		if animated:
			_decor_tween.tween_property(node, "scale", Vector3.ONE * 0.001, ZONE_PROP_HIDE_SECONDS)
			_decor_tween.tween_callback(node.hide).set_delay(ZONE_PROP_HIDE_SECONDS)
		else:
			node.visible = false


## Parçanın zemini, ait olduğu level'ın bölge paletiyle boyanır (önceden üretilen
## parçalar, robot oraya varmadan yeni bölgenin zeminini gösterir).
func _theme_segment(segment: Segment, level: int) -> void:
	if _zones.is_empty():
		return
	var index: int = ZoneCycle.zone_for(level, _zones.size())
	var pair: Array = _materials_for_zone(index)
	if pair.size() == 2:
		segment.apply_floor(pair[0] as Material, pair[1] as Material)


func _materials_for_zone(index: int) -> Array:
	if _zone_materials.has(index):
		return _zone_materials[index]
	var zone: Dictionary = _zones[index] as Dictionary
	var surface: ShaderMaterial = (load(WOOD_MATERIAL_PATH) as ShaderMaterial).duplicate() as ShaderMaterial
	surface.set_shader_parameter("base_color", Color.html(String(zone.get("floor_base", "BFA07B"))))
	surface.set_shader_parameter("wood_dark", Color.html(String(zone.get("floor_dark", "B07A45"))))
	surface.set_shader_parameter("shadow_color", Color.html(String(zone.get("floor_shadow", "8F6B61"))))
	var apron: ShaderMaterial = (load(WOOD_EDGE_MATERIAL_PATH) as ShaderMaterial).duplicate() as ShaderMaterial
	apron.set_shader_parameter("base_color", Color.html(String(zone.get("apron_base", "8C592E"))))
	apron.set_shader_parameter("wood_dark", Color.html(String(zone.get("apron_dark", "6B421F"))))
	apron.set_shader_parameter("shadow_color", Color.html(String(zone.get("floor_shadow", "8F6B61"))))
	var pair: Array = [surface, apron]
	_zone_materials[index] = pair
	return pair


func _enter_zone_if_new() -> void:
	if _zones.is_empty():
		return
	var index: int = ZoneCycle.zone_for(current_level, _zones.size())
	if index == _zone_index:
		return
	_zone_index = index
	_blend_environment(_zones[index] as Dictionary)
	_show_decor(index, true)
	zone_changed.emit(String((_zones[index] as Dictionary).get("name", "")), index)


func _apply_zone_instantly(index: int) -> void:
	_zone_index = index
	if _zones.is_empty():
		return
	_set_environment_palette(_palette_of(_zones[index] as Dictionary))


## Gökyüzü/sis/ışık renkleri bölge değişiminde yumuşakça geçer.
func _blend_environment(zone: Dictionary) -> void:
	if _zone_tween != null:
		_zone_tween.kill()
	var from_palette: Dictionary = _current_palette()
	var to_palette: Dictionary = _palette_of(zone)
	_zone_tween = create_tween()
	_zone_tween.tween_method(func(weight: float) -> void: _set_environment_palette(_mix_palettes(from_palette, to_palette, weight)),
		0.0, 1.0, ZONE_BLEND_SECONDS)


func _palette_of(zone: Dictionary) -> Dictionary:
	return {
		"sky_top": Color.html(String(zone.get("sky_top", "F4E4CE"))),
		"sky_horizon": Color.html(String(zone.get("sky_horizon", "FFECD5"))),
		"ground_bottom": Color.html(String(zone.get("ground_bottom", "EDD9C0"))),
		"ground_horizon": Color.html(String(zone.get("ground_horizon", "FFECD5"))),
		"fog": Color.html(String(zone.get("fog", "FFE6C2"))),
		"sun": Color.html(String(zone.get("sun", "FFF0D3"))),
		"ambient": Color.html(String(zone.get("ambient", "DBDBCC"))),
		"sun_energy": float(zone.get("sun_energy", 1.0)),
		"sun_pitch": float(zone.get("sun_pitch", -55.0)),
		"sun_yaw": float(zone.get("sun_yaw", -25.0)),
		"ambient_energy": float(zone.get("ambient_energy", 0.35)),
		"fill": Color.html(String(zone.get("fill", "B9C9E6"))),
		"fill_energy": float(zone.get("fill_energy", 0.16)),
		"glow_intensity": float(zone.get("glow_intensity", 0.05)),
		"glow_threshold": float(zone.get("glow_threshold", 1.1)),
	}


func _current_palette() -> Dictionary:
	var palette: Dictionary = {}
	if _sky_material != null:
		palette["sky_top"] = _sky_material.sky_top_color
		palette["sky_horizon"] = _sky_material.sky_horizon_color
		palette["ground_bottom"] = _sky_material.ground_bottom_color
		palette["ground_horizon"] = _sky_material.ground_horizon_color
	if _environment != null:
		palette["fog"] = _environment.fog_light_color
		palette["ambient"] = _environment.ambient_light_color
		palette["ambient_energy"] = _environment.ambient_light_energy
		palette["glow_intensity"] = _environment.glow_intensity
		palette["glow_threshold"] = _environment.glow_hdr_threshold
	if _sun != null:
		palette["sun"] = _sun.light_color
		palette["sun_energy"] = _sun.light_energy
		palette["sun_pitch"] = _sun.rotation_degrees.x
		palette["sun_yaw"] = _sun.rotation_degrees.y
	if _fill != null:
		palette["fill"] = _fill.light_color
		palette["fill_energy"] = _fill.light_energy
	return palette


func _mix_palettes(from_palette: Dictionary, to_palette: Dictionary, weight: float) -> Dictionary:
	var mixed: Dictionary = {}
	for key: Variant in to_palette.keys():
		var target: Variant = to_palette[key]
		var start: Variant = from_palette.get(key, target)
		if target is Color:
			mixed[key] = (start as Color).lerp(target as Color, weight)
		else:
			mixed[key] = lerpf(float(start), float(target), weight)
	return mixed


func _set_environment_palette(palette: Dictionary) -> void:
	if _sky_material != null:
		_sky_material.sky_top_color = palette.get("sky_top", _sky_material.sky_top_color)
		_sky_material.sky_horizon_color = palette.get("sky_horizon", _sky_material.sky_horizon_color)
		_sky_material.ground_bottom_color = palette.get("ground_bottom", _sky_material.ground_bottom_color)
		_sky_material.ground_horizon_color = palette.get("ground_horizon", _sky_material.ground_horizon_color)
	if _environment != null:
		_environment.fog_light_color = palette.get("fog", _environment.fog_light_color)
		_environment.ambient_light_color = palette.get("ambient", _environment.ambient_light_color)
		_environment.ambient_light_energy = float(palette.get("ambient_energy", _environment.ambient_light_energy))
		_environment.glow_intensity = float(palette.get("glow_intensity", _environment.glow_intensity))
		_environment.glow_hdr_threshold = float(palette.get("glow_threshold", _environment.glow_hdr_threshold))
	if _sun != null:
		_sun.light_color = palette.get("sun", _sun.light_color)
		_sun.light_energy = float(palette.get("sun_energy", _sun.light_energy))
		var pitch: float = float(palette.get("sun_pitch", _sun.rotation_degrees.x))
		var yaw: float = float(palette.get("sun_yaw", _sun.rotation_degrees.y))
		_sun.rotation_degrees = Vector3(pitch, yaw, 0.0)
		if _fill != null:
			_fill.rotation_degrees = Vector3(FILL_PITCH_DEGREES, yaw + FILL_YAW_OFFSET, 0.0)
			_fill.light_color = palette.get("fill", _fill.light_color)
			_fill.light_energy = float(palette.get("fill_energy", _fill.light_energy))
