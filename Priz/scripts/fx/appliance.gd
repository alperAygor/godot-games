class_name Appliance
extends Node3D

## Tüm cihazların ortak tabanı: GLB modelini örnekler, KAPALI/ÇALIŞIYOR durumunu yumuşak
## bir rampa ile sürer ve şebeke gücünü (sigorta atması) uygular.
##
## Kamu arayüzü (oyun işçisi):
##   set_running(on: bool, ramp: float = -1.0)  — ramp < 0 ise cihazın varsayılan rampası
##   is_running() -> bool
##   get_level() -> float                         — 0..1 (rampa sonrası etkin çıktı)
##   set_mains(factor: float)                     — DayLight.blackout() "priz_mains" grubu üzerinden çağırır
##   get_plug_anchor() -> Node3D                  — kablonun cihazdan çıktığı nokta
##   appliance_id: String                         — "fridge", "oven", ...
## Sinyal: running_changed(on)
##
## Alt sınıflar `_on_level(level: float)` (çıktı yoğunluğu) ve `_animate(delta, level)`
## (sürekli hareket) yazar. Model düğümlerine `part("Ad")` ile erişilir.

signal running_changed(on: bool)

@export var model: PackedScene
@export var appliance_id: String = ""
@export var default_ramp: float = 0.6

var running: bool = false
var _target: float = 0.0
var _ramp_level: float = 0.0
var _mains: float = 1.0
var _ramp_time: float = 0.6
var _model_root: Node3D
var _parts: Dictionary = {}


func _ready() -> void:
	add_to_group("priz_mains")
	add_to_group("priz_appliances")
	if model != null and _model_root == null:
		_model_root = model.instantiate() as Node3D
		_model_root.name = "Model"
		add_child(_model_root)
	if _model_root != null:
		_index(_model_root)
	_ramp_time = default_ramp
	_setup()
	_on_level(0.0)


## Alt sınıf kurulumu (malzeme kopyaları, ışıklar, parçacıklar).
func _setup() -> void:
	pass


## Çıktı yoğunluğu değişti (0..1): emisyon, ışık enerjisi vb.
func _on_level(_level: float) -> void:
	pass


## Her karede: dönme, salınım, buhar miktarı.
func _animate(_delta: float, _level: float) -> void:
	pass


## Durum değişiminde bir kez (kol inmesi, düğme dönmesi gibi).
func _on_switch(_on: bool) -> void:
	pass


func set_running(on: bool, ramp: float = -1.0) -> void:
	_ramp_time = default_ramp if ramp < 0.0 else ramp
	if on == running:
		return
	running = on
	_target = 1.0 if on else 0.0
	_on_switch(on)
	running_changed.emit(on)


func is_running() -> bool:
	return running


func get_level() -> float:
	return _ramp_level * _mains


func set_mains(factor: float) -> void:
	_mains = clampf(factor, 0.0, 1.0)
	_on_level(get_level())


func get_plug_anchor() -> Node3D:
	return part("PlugAnchor")


func part(part_name: String) -> Node3D:
	return _parts.get(part_name, null) as Node3D


func mesh_part(part_name: String) -> MeshInstance3D:
	return _parts.get(part_name, null) as MeshInstance3D


func _process(delta: float) -> void:
	if not is_equal_approx(_ramp_level, _target):
		var step: float = delta / maxf(_ramp_time, 0.01)
		_ramp_level = move_toward(_ramp_level, _target, step)
		_on_level(get_level())
	_animate(delta, get_level())


func _index(node: Node) -> void:
	_parts[String(node.name)] = node
	for c: Node in node.get_children():
		_index(c)


## Yüzey malzemesinin bu örneğe özel kopyası (emisyon gibi değerler örnekler arasında paylaşılmasın).
func own_material(mi: MeshInstance3D, surface: int = 0) -> StandardMaterial3D:
	if mi == null:
		return null
	var src: Material = mi.get_active_material(surface)
	var copy: StandardMaterial3D = (src as StandardMaterial3D).duplicate() as StandardMaterial3D if src is StandardMaterial3D else null
	if copy != null:
		mi.set_surface_override_material(surface, copy)
	return copy


## Gösterge LED'i: renk + enerji (0 = sönük).
func make_indicator(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = own_material(mesh_part("Indicator"))
	if m != null:
		m.emission = color
		m.albedo_color = color.darkened(0.75)
	return m


## Gölgesiz, ucuz bir nokta ışığı (Mobile: ağ başına ışık sınırı için küçük menzil).
func make_light(anchor_name: String, color: Color, light_range: float) -> OmniLight3D:
	var a: Node3D = part(anchor_name)
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = color
	l.omni_range = light_range
	l.omni_attenuation = 1.5
	l.shadow_enabled = false
	l.light_energy = 0.0
	l.visible = false
	if a != null:
		a.add_child(l)
	else:
		add_child(l)
	return l


func set_light(l: OmniLight3D, energy: float) -> void:
	if l == null:
		return
	l.light_energy = energy
	l.visible = energy > 0.002
