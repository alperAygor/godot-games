class_name SliceGauges
extends RefCounted
## Bir `FuseBox`un hat göstergelerine kesit gölgelendiricisini (`scenes/game/slice_gauge.gdshader`) takar
## ve oyunun ek göstergelerini sürer: hayalet bloklar (önizleme), ret parlaması, dolum sekmesi ve
## tek göstergenin sarsılması. FuseBox'ın kendi parametreleri (fill, segments, tint, highlight) aynen çalışır.

const GAUGE_SHADER: Shader = preload("res://scenes/game/slice_gauge.gdshader")
## Göstergedeki sabit yuva sayısı: blok boyu tüm hatlarda aynı (kesitte kapasite ≤ 6).
const SLOTS: float = 6.0

var box: FuseBox
var _gauges: Dictionary = {}       # hat -> MeshInstance3D
var _rest: Dictionary = {}         # hat -> Vector3 (göstergenin yerel konumu)
var _ghost: Dictionary = {}        # hat -> hedef hayalet blok
var _ghost_shown: Dictionary = {}  # hat -> çizilen (yumuşak)
var _reject: Dictionary = {}       # hat -> 0..1
var _bounce: Dictionary = {}       # hat -> 0..1
var _shake: Dictionary = {}        # hat -> 0..1
var _time: float = 0.0


func _init(p_box: FuseBox) -> void:
	box = p_box
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GAUGE_SHADER
	mat.set_shader_parameter("slots", SLOTS)
	for line: int in range(1, 5):
		var g: MeshInstance3D = box.find_child("Gauge_%d" % line, true, false) as MeshInstance3D
		if g == null:
			continue
		g.material_override = mat
		_gauges[line] = g
		_rest[line] = g.position
		_ghost[line] = 0.0
		_ghost_shown[line] = 0.0
		_reject[line] = 0.0
		_bounce[line] = 0.0
		_shake[line] = 0.0


## Sürüklenen cihazın bu hatta ekleyeceği blok (0 = temizle).
func set_ghost(line: int, blocks: float) -> void:
	for l: Variant in _ghost.keys():
		_ghost[l] = blocks if int(l) == line else 0.0


func clear_ghost() -> void:
	for l: Variant in _ghost.keys():
		_ghost[l] = 0.0


## Ret: sığmayan bloklar kırmızı yanıp söner, gösterge sarsılır.
func reject(line: int) -> void:
	if _reject.has(line):
		_reject[line] = 1.0
		_shake[line] = 1.0


## Yeni blok dolarken kısa parlama + küçük sekme.
func bounce(line: int) -> void:
	if _bounce.has(line):
		_bounce[line] = 1.0
		_shake[line] = maxf(float(_shake[line]), 0.25)


func gauge(line: int) -> MeshInstance3D:
	return _gauges.get(line, null) as MeshInstance3D


func ghost_of(line: int) -> float:
	return float(_ghost.get(line, 0.0))


func process(delta: float) -> void:
	_time += delta
	for key: Variant in _gauges.keys():
		var line: int = int(key)
		var g: MeshInstance3D = _gauges[line] as MeshInstance3D
		var gs: float = lerpf(float(_ghost_shown[line]), float(_ghost[line]), 1.0 - exp(-18.0 * delta))
		if absf(gs - float(_ghost[line])) < 0.01:
			gs = float(_ghost[line])
		_ghost_shown[line] = gs
		_reject[line] = maxf(0.0, float(_reject[line]) - delta * 1.4)
		_bounce[line] = maxf(0.0, float(_bounce[line]) - delta * 3.0)
		_shake[line] = maxf(0.0, float(_shake[line]) - delta * 2.6)
		g.set_instance_shader_parameter("ghost", roundf(gs) if gs > 0.5 else 0.0)
		g.set_instance_shader_parameter("reject", float(_reject[line]))
		g.set_instance_shader_parameter("bounce", float(_bounce[line]))
		var s: float = float(_shake[line])
		var rest: Vector3 = _rest[line] as Vector3
		if s > 0.0:
			var a: float = s * s * 0.012
			g.position = rest + Vector3(sin(_time * 62.0 + float(line)) * a, absf(sin(_time * 31.0)) * a * 0.6, 0.0)
		else:
			g.position = rest
