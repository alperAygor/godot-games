class_name KeyboardKey
extends AnimatableBody3D

## Tuşun basma başlangıcı; ses olayı bu sinyale bağlanır (ARCHITECTURE.md §5.6).
signal pressed()

## Stil A toon yüzeyi; GLB'nin krem tuşları/koyu içi korunur, tehlike rengi yalnız
## parlak (tuş kapağı) yüzeylerde `base_color`/emisyon ile sürülür. Davranış ve
## zamanlama değişmez; yalnız renk görseli hedeflenir (CLAUDE.md §8 "PBR yok").
const TOON_SHADER_PATH: String = "res://assets/shaders/toon.gdshader"
const OUTLINE_PATH: String = "res://assets/materials/outline.tres"
const SHADOW_COLOR: Color = Color("44446b")
## Bu eşiğin üstü parlaklık "tuş kapağı" sayılır; koyu gövde/girinti değişmez.
## Tehlike tuşlarının (V1 #ED7A00, palet #F7B801) da kapak sayılması için eşik
## düşük tutulur; koyu iç/gövde (#2B2F3A) bunun altında kalır.
const KEYCAP_LUMINANCE: float = 0.4
## Normal hâlde tüm tuş kapakları kremdir; tehlike rengi yalnız telegraph/press anında.
const KEYCAP_IDLE_COLOR: Color = Color("f2e8d5")
const TELEGRAPH_EMISSION: float = 1.4

@export var phase_offset_seconds: float = 0.0

var _parameters: Dictionary[String, Variant] = {}
var _period: float = 0.0
var _warning_seconds: float = 0.0
var _press_seconds: float = 0.0
var _hold_seconds: float = 0.0
var _release_seconds: float = 0.0
var _press_depth: float = 0.0
var _warning_start: float = 0.0
var _press_start: float = 0.0
var _phase: float = 0.0
var _rest_position: Vector3 = Vector3.ZERO
var _telegraphing: bool = false
var _pressed: bool = false
var _was_pressed: bool = false
var _warning_color: Color = Color.YELLOW
var _pressed_color: Color = Color.RED
var _outline_material: ShaderMaterial = null
var _toon_cache: Dictionary[String, ShaderMaterial] = {}
var _keycap_materials: Array[ShaderMaterial] = []
var _keycap_idle_colors: Array[Color] = []


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("keyboard_key")
	var data: Node = get_node_or_null("/root/GameData")
	if data != null:
		var found: Variant = data.call("value", "balance", "hazards", null)
		if found is Dictionary:
			_parameters.assign(found)
	_warning_seconds = maxf(_parameter("key_warn_seconds", 0.65), 0.5)
	_press_seconds = maxf(_parameter("key_press_seconds", 0.12), 0.001)
	_hold_seconds = maxf(_parameter("key_hold_seconds", 0.4), 0.0)
	_release_seconds = maxf(_parameter("key_release_seconds", 0.25), 0.001)
	_period = maxf(_parameter("key_period_seconds", 4.0),
		_warning_seconds + _press_seconds + _hold_seconds + _release_seconds)
	_press_depth = maxf(_parameter("key_press_depth", 0.28), 0.0)
	_warning_color = Color.from_string(String(_parameters.get("key_warn_color", "f7b801")), Color.YELLOW)
	_pressed_color = Color.from_string(String(_parameters.get("key_pressed_color", "ff4d4d")), Color.RED)
	_rest_position = position
	_press_start = _period - _press_seconds - _hold_seconds - _release_seconds
	_warning_start = _press_start - _warning_seconds
	_phase = fposmod(phase_offset_seconds, _period)
	sync_to_physics = true
	_outline_material = load(OUTLINE_PATH) as ShaderMaterial
	var visual: Node = get_node_or_null("Visual")
	if visual != null:
		_override_visual_material(visual)
	_update_phase()
	# İlk karede basılı başlayan tuş, sahne kurulurken yanlışlıkla "basıldı"
	# olayı üretmesin; kenar yalnızca sonraki geçişlerde algılanır.
	_was_pressed = _pressed


func is_telegraphing() -> bool:
	return _telegraphing


func is_pressed() -> bool:
	return _pressed


func _physics_process(delta: float) -> void:
	_phase = fposmod(_phase + delta, _period)
	_update_phase()
	if _pressed and not _was_pressed:
		pressed.emit()
		AudioService.play("key_press")
	_was_pressed = _pressed


func _update_phase() -> void:
	_telegraphing = _phase >= _warning_start and _phase < _press_start
	_pressed = _phase >= _press_start and _phase < _press_start + _press_seconds + _hold_seconds
	var depth_fraction: float = 0.0
	if _pressed:
		depth_fraction = clampf((_phase - _press_start) / _press_seconds, 0.0, 1.0)
	elif _phase >= _press_start + _press_seconds + _hold_seconds:
		depth_fraction = 1.0 - clampf(
			(_phase - _press_start - _press_seconds - _hold_seconds) / _release_seconds, 0.0, 1.0)
	position = _rest_position + Vector3.DOWN * (_press_depth * depth_fraction)
	# Telegraph rengi yalnız parlak tuş kapaklarında parlar; koyu iç korunur.
	if _telegraphing:
		_set_visual_color(_warning_color, true)
	elif _pressed:
		_set_visual_color(_pressed_color, true)
	else:
		_restore_visual_color()


func _set_visual_color(color: Color, glow: bool) -> void:
	for material: ShaderMaterial in _keycap_materials:
		material.set_shader_parameter("base_color", color)
		material.set_shader_parameter("emissive_color", color)
		material.set_shader_parameter("emissive_energy", TELEGRAPH_EMISSION if glow else 0.0)


func _restore_visual_color() -> void:
	for i: int in range(_keycap_materials.size()):
		_keycap_materials[i].set_shader_parameter("base_color", _keycap_idle_colors[i])
		_keycap_materials[i].set_shader_parameter("emissive_color", _keycap_idle_colors[i])
		_keycap_materials[i].set_shader_parameter("emissive_energy", 0.0)


func _override_visual_material(node: Node) -> void:
	# Imported GLBs can nest their mesh below multiple transform nodes.
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		_restyle_keyboard_mesh(mesh_instance)
	for child: Node in node.get_children():
		_override_visual_material(child)


func _restyle_keyboard_mesh(mesh_instance: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return
	for surface: int in range(mesh.get_surface_count()):
		var source: Material = mesh.surface_get_material(surface)
		if not (source is StandardMaterial3D):
			continue
		var albedo: Color = (source as StandardMaterial3D).albedo_color
		var is_keycap: bool = albedo.get_luminance() >= KEYCAP_LUMINANCE
		# Normal hâlde kapak kremdir; koyu iç/gövde kendi albedosunu korur.
		var base: Color = KEYCAP_IDLE_COLOR if is_keycap else albedo
		var toon: ShaderMaterial = _toon_material(base)
		mesh_instance.set_surface_override_material(surface, toon)
		if is_keycap:
			_keycap_materials.append(toon)
			_keycap_idle_colors.append(KEYCAP_IDLE_COLOR)


func _toon_material(base: Color) -> ShaderMaterial:
	# Renk başına tek malzeme: krem tuşlar/koyu iç/gövde paylaşılır, draw call artmaz.
	var key: String = base.to_html(false)
	if _toon_cache.has(key):
		return _toon_cache[key]
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(TOON_SHADER_PATH) as Shader
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("shadow_color", SHADOW_COLOR)
	if _outline_material != null:
		material.next_pass = _outline_material
	_toon_cache[key] = material
	return material


func _parameter(key: String, fallback: float) -> float:
	return float(_parameters.get(key, fallback))
