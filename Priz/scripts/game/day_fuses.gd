class_name DayFuses
extends Node3D
## Sigorta kutusundaki üç cam kartuş sigorta = seviyenin sigorta hakları (rakamsız). Her sigorta atmasında
## biri patlar (parlama + is + kopuk tel); ödüllü "+1 sigorta" ile yenisi yuvasına kayar. Gün kipinde görünür.
## Çizim: seramik taban (1) + cam tüpler (MultiMesh, 1) + pirinç başlıklar (MultiMesh, 1); hepsi gölgesiz.

const GLASS_SHADER: Shader = preload("res://scenes/game/fuse_glass.gdshader")
const COUNT: int = 3
## Kutu yerelinde: kadranın sağı, yatay üç sigorta.
const CENTER: Vector3 = Vector3(0.145, 0.235, 0.106)
const PITCH: float = 0.058
const LENGTH: float = 0.072
const RADIUS: float = 0.0125
const CAP_LEN: float = 0.014

var _glass: MultiMeshInstance3D
var _caps: MultiMeshInstance3D
var _base: MeshInstance3D
var _glass_mat: ShaderMaterial
var _burnt: Array[float] = [0.0, 0.0, 0.0]
var _flash: Array[float] = [0.0, 0.0, 0.0]
var _offset: Array[float] = [0.0, 0.0, 0.0]
var _rights: int = COUNT


func _ready() -> void:
	_base = MeshInstance3D.new()
	_base.name = "FuseHolder"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(LENGTH + 0.026, PITCH * float(COUNT) + 0.008, 0.01)
	_base.mesh = bm
	var ceramic: StandardMaterial3D = StandardMaterial3D.new()
	ceramic.albedo_color = Color(0.9, 0.87, 0.8)
	ceramic.roughness = 0.35
	ceramic.clearcoat_enabled = true
	ceramic.clearcoat = 0.4
	_base.material_override = ceramic
	_base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_base.position = CENTER - Vector3(0.0, 0.0, 0.003)
	add_child(_base)
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = GLASS_SHADER
	_glass_mat.set_shader_parameter("half_len", (LENGTH - CAP_LEN) * 0.5)
	_glass = _make_mm("FuseGlass", _cylinder(RADIUS, LENGTH - CAP_LEN, 32), _glass_mat, COUNT)
	var cap_mat: StandardMaterial3D = StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.86, 0.66, 0.32)
	cap_mat.metallic = 1.0
	cap_mat.roughness = 0.28
	_caps = _make_mm("FuseCaps", _cylinder(RADIUS * 1.12, CAP_LEN, 32), cap_mat, COUNT * 2)
	_layout()


func _make_mm(node_name: String, mesh: Mesh, mat: Material, n: int) -> MultiMeshInstance3D:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


static func _cylinder(r: float, h: float, segs: int) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


## Kalan hak (0..3+): fazlası gösterilmez, eksikler yanık.
func set_rights(rights: int, animate: bool = false) -> void:
	var before: int = _rights
	_rights = rights
	for i: int in COUNT:
		var intact: bool = i < rights
		if animate and not intact and i < before:
			_blow(i)
		elif animate and intact and i >= before:
			_insert(i)
		else:
			_burnt[i] = 0.0 if intact else 1.0
			_flash[i] = 0.0
			_offset[i] = 0.0
	_layout()


func rights() -> int:
	return _rights


func is_burnt(i: int) -> bool:
	return i >= 0 and i < COUNT and _burnt[i] > 0.5


## Ekran sorgusu (prob/çekim): i. sigortanın dünya merkezi.
func fuse_position(i: int) -> Vector3:
	return global_transform * _center_of(i)


func _blow(i: int) -> void:
	var t: Tween = create_tween()
	t.tween_method(func(v: float) -> void:
		_flash[i] = v
		_burnt[i] = minf(1.0, v * 1.6)
		_layout(), 0.0, 1.0, 0.06)
	t.tween_method(func(v: float) -> void:
		_flash[i] = v
		_layout(), 1.0, 0.0, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_burnt[i] = 1.0
		_layout())


## Yeni sigorta yuvasına kayar (ödüllü ek hak).
func _insert(i: int) -> void:
	_burnt[i] = 0.0
	_flash[i] = 0.0
	var t: Tween = create_tween()
	t.tween_method(func(v: float) -> void:
		_offset[i] = v
		_layout(), 0.06, 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _center_of(i: int) -> Vector3:
	var y: float = CENTER.y + PITCH * (float(i) - float(COUNT - 1) * 0.5)
	return Vector3(CENTER.x + _offset[i], y, CENTER.z + RADIUS + 0.002)


func _layout() -> void:
	if _glass == null:
		return
	var axis: Basis = Basis(Vector3.BACK, PI * 0.5)
	for i: int in COUNT:
		var c: Vector3 = _center_of(i)
		_glass.multimesh.set_instance_transform(i, Transform3D(axis, c))
		_glass.multimesh.set_instance_custom_data(i, Color(_burnt[i], _flash[i], 0.0, 0.0))
		var half: float = (LENGTH - CAP_LEN) * 0.5 + CAP_LEN * 0.5
		for k: int in 2:
			var sgn: float = -1.0 if k == 0 else 1.0
			_caps.multimesh.set_instance_transform(i * 2 + k, Transform3D(axis, c + Vector3(sgn * half, 0.0, 0.0)))
			_caps.multimesh.set_instance_custom_data(i * 2 + k, Color(0.0, 0.0, 0.0, 0.0))
