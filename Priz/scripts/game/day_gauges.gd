class_name DayGauges
extends RefCounted
## Gün kipinde başparmak bölgesindeki sigorta kutusunun dilim göstergeleri: her hat için dört tüp
## (sabah, öğle, akşam, gece) yan yana, tüp boyu = hattın kapasitesi, yanan blok = o dilimin yükü.
## Tüm hatlar TEK MultiMesh (tek çizim çağrısı, gölgesiz); veriler örnek başına (INSTANCE_CUSTOM + COLOR)
## `scenes/game/day_gauge.gdshader`'a gider. Modüller (levha, şalter) tüplere yer açmak için aralanır;
## kutunun kendi tek sütunlu göstergeleri gün kipinde gizlenir. Düz kipte `disable()` her şeyi geri verir.

const SHADER: Shader = preload("res://scenes/game/day_gauge.gdshader")
## Gölgelendiriciyle AYNI birim ölçüler (sütun genişliği = 1).
const COL_GAP: float = 0.28
const MARGIN: float = 0.32
const BLOCK_H: float = 1.1
const FOOT_H: float = 1.15
const FOOT_GAP: float = 0.18
const TOP_M: float = 0.3
const BOT_M: float = 0.28
## Kutu yerelinde göstergelere ayrılan bant: levhaların altı ile şalter gövdelerinin üstü arası.
const BAND_TOP: float = 0.097
const BAND_BOTTOM: float = -0.132
const BAND_Z: float = 0.124
## Kutunun çerçevesi dahil kullanılabilir genişlik ve göstergeler arası boşluk.
const MAX_WIDTH: float = 0.42
const GAP: float = 0.008
const LINE_COLORS: Array[Color] = [Color(0.95, 0.4, 0.33), Color(0.33, 0.62, 0.95), Color(0.98, 0.78, 0.3),
	Color(0.62, 0.45, 0.88)]

var box: FuseBox
var mmi: MultiMeshInstance3D
var material: ShaderMaterial
var lines: Array[int] = []
## Kutu yerelinde bir sütunun genişliği (blok genişliği).
var col_local: float = 0.02
var rows: int = 6
var enabled: bool = false

var _loads: Dictionary = {}     # hat -> Vector4
var _caps: Dictionary = {}      # hat -> int
var _ghost: Dictionary = {}     # hat -> Vector2(blok, maske)
var _tint: Dictionary = {}      # hat -> 0 hat rengi, 1 nötr, 2 kırmızı
var _highlight: Dictionary = {} # hat -> bool
var _dim: Dictionary = {}       # hat -> bool
var _fault: Dictionary = {}     # hat -> dilim (-1 yok)
var _focus: int = -1
var _reveal_tween: Tween


## Gösterge ölçüsü (birim): satır sayısına göre.
static func unit_size(p_rows: float) -> Vector2:
	var w: float = 4.0 + 3.0 * COL_GAP + 2.0 * MARGIN
	var h: float = TOP_M + p_rows * BLOCK_H + (FOOT_GAP if p_rows > 0.0 else 0.0) + FOOT_H + BOT_M
	return Vector2(w, h)


static func make_material(p_rows: float, multimesh: bool) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("from_multimesh", multimesh)
	mat.set_shader_parameter("rows", p_rows)
	for i: int in LINE_COLORS.size():
		mat.set_shader_parameter("line_color_%d" % (i + 1), LINE_COLORS[i])
	return mat


## flags: line | (focus+1)<<2 | (fault+1)<<5 | highlight<<8 | dim<<9
static func pack_flags(line_index: int, focus: int, fault: int, highlight: bool, dim: bool) -> float:
	return float((line_index & 3) | ((focus + 1) << 2) | ((fault + 1) << 5) | (int(highlight) << 8) | (int(dim) << 9))


func _init(p_box: FuseBox) -> void:
	box = p_box
	material = make_material(6.0, true)
	mmi = MultiMeshInstance3D.new()
	mmi.name = "DayGauges"
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = material
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = 4
	mm.visible_instance_count = 0
	mmi.multimesh = mm
	mmi.visible = false
	var model: Node = box.get_node_or_null("Model")
	(model if model != null else box).add_child(mmi)


## Gün kipi: `room_lines` hatları (1..4), kapasiteleri, sabit satır sayısı. Modüller aralanır.
func enable(room_lines: Array[int], caps: Dictionary, p_rows: int) -> void:
	enabled = true
	lines = room_lines.duplicate()
	rows = maxi(p_rows, 2)
	material.set_shader_parameter("rows", float(rows))
	material.set_shader_parameter("power", 1.0)
	material.set_shader_parameter("reveal", 1.0)
	_focus = -1
	for line: int in lines:
		_caps[line] = int(caps.get(line, 1))
		_loads[line] = Vector4.ZERO
		_ghost[line] = Vector2.ZERO
		_tint[line] = 0
		_highlight[line] = false
		_dim[line] = false
		_fault[line] = -1
	var unit: Vector2 = unit_size(float(rows))
	var band_h: float = BAND_TOP - BAND_BOTTOM
	col_local = band_h / unit.y
	var n: int = lines.size()
	var total_w: float = float(n) * unit.x * col_local + float(n - 1) * GAP
	if total_w > MAX_WIDTH:
		col_local = (MAX_WIDTH - float(n - 1) * GAP) / (float(n) * unit.x)
	var w: float = unit.x * col_local
	# Bant yüksekliği her zaman dolar (eski gösterge çerçevesi görünmesin): genişlik sınırlıysa bloklar uzar.
	var h: float = band_h
	var fixed_h: float = TOP_M + FOOT_GAP + FOOT_H + BOT_M
	material.set_shader_parameter("block_h", maxf((h / col_local - fixed_h) / float(rows), BLOCK_H))
	var spacing: float = w + GAP
	var start: float = -spacing * float(n - 1) * 0.5
	var mm: MultiMesh = mmi.multimesh
	mm.visible_instance_count = n
	for i: int in n:
		var x: float = start + spacing * float(i)
		var module: Node3D = box.find_child("Module_%d" % lines[i], true, false) as Node3D
		if module != null:
			module.position.x = x
		var g: Node3D = box.find_child("Gauge_%d" % lines[i], true, false) as Node3D
		if g != null:
			g.visible = false
		var y: float = BAND_BOTTOM + h * 0.5 + (band_h - h) * 0.5
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w, h, 1.0)), Vector3(x, y, BAND_Z)))
	mmi.visible = true
	_push()


## Düz kip: kutunun kendi göstergeleri ve modül yerleri geri gelir.
func disable() -> void:
	enabled = false
	mmi.visible = false
	for line: int in range(1, 5):
		var g: Node3D = box.find_child("Gauge_%d" % line, true, false) as Node3D
		if g != null:
			g.visible = true
	box.set_line_count(box.get("_line_count") as int)


## Bir sütunun kutu yerelindeki genişliği × kutu ölçeği = dünyada blok genişliği.
func column_world_width() -> float:
	return col_local * box.global_transform.basis.get_scale().x


func set_loads(line: int, loads: Vector4, capacity: int) -> void:
	if not _loads.has(line):
		return
	_loads[line] = loads
	_caps[line] = capacity
	_push()


func loads_of(line: int) -> Vector4:
	return _loads.get(line, Vector4.ZERO) as Vector4


func capacity_of(line: int) -> int:
	return int(_caps.get(line, 0))


## Sürüklenen cihazın hayalet blokları: yalnız `mask` dilimlerinde `blocks` blok. 0 = temizle.
func set_ghost(line: int, blocks: float, mask: int, tint: int = 0) -> void:
	for l: int in lines:
		_ghost[l] = Vector2(blocks, float(mask)) if l == line else Vector2.ZERO
		_tint[l] = tint if l == line else 0
	_push()


func clear_ghost() -> void:
	for l: int in lines:
		_ghost[l] = Vector2.ZERO
		_tint[l] = 0
	_push()


func ghost_of(line: int) -> Vector2:
	return _ghost.get(line, Vector2.ZERO) as Vector2


func set_highlight(line: int, on: bool) -> void:
	for l: int in lines:
		_highlight[l] = on and l == line
	_push()


func set_dim(line: int, on: bool) -> void:
	if _dim.has(line):
		_dim[line] = on
		_push()


## Sigortanın attığı dilim (o sütun kırmızı çerçeveyle atar). slice < 0 temizler.
func set_fault(line: int, slice: int) -> void:
	if _fault.has(line):
		_fault[line] = slice
		_push()


func clear_fault() -> void:
	for l: int in lines:
		_fault[l] = -1
	_push()


func fault_of(line: int) -> int:
	return int(_fault.get(line, -1))


## Gün testi/önizleme: yalnız bu dilimin sütunu parlak (-1 = hepsi).
func set_focus(slice: int) -> void:
	_focus = slice
	_push()


func focus() -> int:
	return _focus


## Odak sütununun blokları alttan dolar (yeni dilimin yükü "gelir").
func reveal(seconds: float) -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	material.set_shader_parameter("reveal", 0.0)
	if seconds <= 0.0:
		material.set_shader_parameter("reveal", 1.0)
		return
	_reveal_tween = box.create_tween()
	_reveal_tween.tween_method(func(v: float) -> void: material.set_shader_parameter("reveal", v), 0.0, 1.0, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Yeni dilim: odak sütunu boşalır; yük olayında `reveal` ile dolar.
func reveal_hold() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	material.set_shader_parameter("reveal", 0.0)


func set_power(v: float) -> void:
	material.set_shader_parameter("power", v)


func _push() -> void:
	if not enabled:
		return
	var mm: MultiMesh = mmi.multimesh
	for i: int in lines.size():
		var line: int = lines[i]
		var gh: Vector2 = _ghost[line] as Vector2
		mm.set_instance_custom_data(i, _vec_color(_loads[line] as Vector4))
		mm.set_instance_color(i, Color(float(_caps[line]), gh.x, gh.y + 16.0 * float(_tint[line]),
			pack_flags(line - 1, _focus, int(_fault[line]), bool(_highlight[line]), bool(_dim[line]))))


static func _vec_color(v: Vector4) -> Color:
	return Color(v.x, v.y, v.z, v.w)
