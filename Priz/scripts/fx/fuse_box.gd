class_name FuseBox
extends Node3D

## Sigorta kutusu — dünya içi arayüz. Her hat için rakamsız blok göstergesi, şalter kolu ve
## şekil levhası; altta "günü başlat" bıçaklı şalteri; üstte gün dilimi kadranı.
##
## Kamu arayüzü:
##   set_line_count(n: int)                    — 2..4 modül görünür, kutuda ortalanır
##   set_line_capacity(line: int, blocks: int) — göstergedeki blok sayısı (= hat kapasitesi)
##   set_line_fill(line: int, ratio: float)    — yük/kapasite; >1 taşma (kırmızı yanıp söner). Yumuşak dolar.
##   set_breaker(line: int, on: bool)          — şalter kolu (yukarı açık). Kapalıyken gösterge söner.
##   trip(line: int)                           — sigorta attı: kol sertçe iner, kutu sarsılır
##   set_line_highlight(line: int, v: float)   — dokununca hat vurgusu
##   set_main_lever(on: bool, animate := true) — "günü başlat" şalteri
##   set_slice_dial(slice: int, duration)      — kadran ibresi: 0 sabah (sol), 1 öğle (üst), 2 akşam (sağ), 3 gece (alt)
## Sinyaller: main_lever_changed(on)

signal main_lever_changed(on: bool)

const MODEL: PackedScene = preload("res://assets/models/fusebox/fusebox.glb")
const LINE_COLORS: Array[Color] = [
	Color(0.88, 0.34, 0.29), Color(0.25, 0.56, 0.85), Color(0.91, 0.70, 0.23), Color(0.6, 0.42, 0.84),
]
const MODULE_SPACING: float = 0.09
const BREAKER_ON_DEG: float = -35.0
const BREAKER_OFF_DEG: float = 35.0
const MAIN_OFF_DEG: float = -40.0
const MAIN_ON_DEG: float = 45.0
const DIAL_DEG: Array[float] = [-90.0, 0.0, 90.0, 180.0]

var _model: Node3D
var _parts: Dictionary = {}
var _fill: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _fill_shown: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _breaker_on: Array[bool] = [true, true, true, true]
var _line_count: int = 3
var _main_on: bool = false
var _shake: float = 0.0
var _rest_pos: Vector3 = Vector3.ZERO
var _t: float = 0.0


func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	_index(_model)
	for i: int in range(4):
		var g: MeshInstance3D = _gauge(i + 1)
		if g != null:
			g.set_instance_shader_parameter("tint", LINE_COLORS[i])
			g.set_instance_shader_parameter("segments", 6.0)
			g.set_instance_shader_parameter("fill", 0.0)
		_set_breaker_angle(i + 1, BREAKER_ON_DEG)
	var ml: Node3D = _parts.get("MainLever", null) as Node3D
	if ml != null:
		ml.rotation.x = deg_to_rad(MAIN_OFF_DEG)
	set_line_count(_line_count)
	set_slice_dial(1, 0.0)
	_rest_pos = _model.position


func set_line_count(n: int) -> void:
	_line_count = clampi(n, 1, 4)
	var start: float = -MODULE_SPACING * float(_line_count - 1) * 0.5
	for i: int in range(4):
		var m: Node3D = _parts.get("Module_%d" % (i + 1), null) as Node3D
		if m == null:
			continue
		m.visible = i < _line_count
		# Modül düğümü (Blender boş nesnesi) kendi x konumunda; çocuklar ona göreli.
		if i < _line_count:
			m.position.x = start + MODULE_SPACING * i


func set_line_capacity(line: int, blocks: int) -> void:
	var g: MeshInstance3D = _gauge(line)
	if g != null:
		g.set_instance_shader_parameter("segments", float(maxi(blocks, 1)))


func set_line_fill(line: int, ratio: float) -> void:
	if line < 1 or line > 4:
		return
	_fill[line - 1] = maxf(ratio, 0.0)


func set_breaker(line: int, on: bool) -> void:
	if line < 1 or line > 4:
		return
	_breaker_on[line - 1] = on
	var lv: Node3D = _parts.get("Breaker_%d" % line, null) as Node3D
	if lv == null:
		return
	var t: Tween = create_tween()
	t.tween_property(lv, "rotation:x", deg_to_rad(BREAKER_ON_DEG if on else BREAKER_OFF_DEG), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func trip(line: int) -> void:
	set_breaker(line, false)
	_shake = 1.0


func set_line_highlight(line: int, v: float) -> void:
	var g: MeshInstance3D = _gauge(line)
	if g != null:
		g.set_instance_shader_parameter("highlight", v)


func set_main_lever(on: bool, animate: bool = true) -> void:
	_main_on = on
	var ml: Node3D = _parts.get("MainLever", null) as Node3D
	if ml != null:
		var target: float = deg_to_rad(MAIN_ON_DEG if on else MAIN_OFF_DEG)
		if animate:
			var t: Tween = create_tween()
			t.tween_property(ml, "rotation:x", target, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			ml.rotation.x = target
	_shake = maxf(_shake, 0.35)
	main_lever_changed.emit(on)


func is_main_on() -> bool:
	return _main_on


func set_slice_dial(slice: int, duration: float = 0.8) -> void:
	var needle: Node3D = _parts.get("DialNeedle", null) as Node3D
	if needle == null:
		return
	var target: float = -deg_to_rad(DIAL_DEG[clampi(slice, 0, 3)])
	# En kısa yoldan dön
	var cur: float = needle.rotation.z
	while target - cur > PI:
		target -= TAU
	while cur - target > PI:
		target += TAU
	if duration <= 0.0:
		needle.rotation.z = target
	else:
		var t: Tween = create_tween()
		t.tween_property(needle, "rotation:z", target, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	for i: int in range(4):
		var target: float = _fill[i] if _breaker_on[i] else 0.0
		# Yay benzeri yumuşak dolum; taşmada küçük titreşim
		_fill_shown[i] = lerpf(_fill_shown[i], target, 1.0 - exp(-8.0 * delta))
		var g: MeshInstance3D = _gauge(i + 1)
		if g != null:
			var jitter: float = 0.0
			if target > 1.0:
				jitter = 0.02 * sin(_t * 40.0 + float(i))
			g.set_instance_shader_parameter("fill", _fill_shown[i] + jitter)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		var a: float = _shake * _shake * 0.006
		_model.position = _rest_pos + Vector3(sin(_t * 70.0) * a, cos(_t * 53.0) * a * 0.5, 0.0)
	elif _model != null:
		_model.position = _rest_pos


func _gauge(line: int) -> MeshInstance3D:
	return _parts.get("Gauge_%d" % line, null) as MeshInstance3D


func _set_breaker_angle(line: int, deg: float) -> void:
	var lv: Node3D = _parts.get("Breaker_%d" % line, null) as Node3D
	if lv != null:
		lv.rotation.x = deg_to_rad(deg)


func _index(node: Node) -> void:
	_parts[String(node.name)] = node
	for c: Node in node.get_children():
		_index(c)
