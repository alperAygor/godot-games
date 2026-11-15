class_name DayStrips
extends RefCounted
## Gün kipinde her cihazın "ne zaman çalışır" şeridi: dört dilim hücresi (doğan güneş, tepe güneş, batan
## güneş, ay), cihazın çalıştığı dilimler kendi renginde yanar. Tepside cihazın önünde, odada cihazın
## üstünde (kameraya dönük). Tüm şeritler TEK MultiMesh (tek çizim çağrısı, gölgesiz); gölgelendirici
## sigorta göstergesiyle aynı (`rows = 0`: yalnız ayak hücreleri) — sütun sırası göstergeyle birebir.

const HIDDEN: Transform3D = Transform3D(Vector3(0.00001, 0.0, 0.0), Vector3(0.0, 0.00001, 0.0), Vector3(0.0, 0.0, 0.00001),
	Vector3(0.0, -50.0, 0.0))

var mmi: MultiMeshInstance3D
var material: ShaderMaterial
var count: int = 0
var _masks: Array[int] = []
var _focus: int = -1
var _fault: Array[int] = []


func _init(parent: Node3D, capacity: int = 8) -> void:
	material = DayGauges.make_material(0.0, true)
	mmi = MultiMeshInstance3D.new()
	mmi.name = "DayStrips"
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = material
	mmi.top_level = true
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	mmi.multimesh = mm
	mmi.visible = false
	parent.add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY
	# Görünmez örnekler bile sınır kutusunu bozmasın: geniş özel AABB (kırpılma olmasın).
	mmi.custom_aabb = AABB(Vector3(-50.0, -50.0, -50.0), Vector3(100.0, 100.0, 100.0))


## n cihaz için şerit; maskeler (bit 0 sabah). n = 0 → kapalı.
func setup(masks: Array[int]) -> void:
	count = mini(masks.size(), mmi.multimesh.instance_count)
	_masks = masks.duplicate()
	_fault.clear()
	for i: int in count:
		_fault.append(-1)
	_focus = -1
	mmi.multimesh.visible_instance_count = count
	mmi.visible = count > 0
	for i: int in count:
		mmi.multimesh.set_instance_transform(i, HIDDEN)
	_push()


func clear() -> void:
	setup([] as Array[int])


func set_mask(i: int, mask: int) -> void:
	if i >= 0 and i < count and _masks[i] != mask:
		_masks[i] = mask
		_push_one(i)


func mask_of(i: int) -> int:
	return _masks[i] if i >= 0 and i < count else 0


func set_focus(slice: int) -> void:
	_focus = slice
	_push()


func set_fault(i: int, slice: int) -> void:
	if i >= 0 and i < count:
		_fault[i] = slice
		_push_one(i)


func clear_fault() -> void:
	for i: int in count:
		_fault[i] = -1
	_push()


## Şeridin merkezi `center`, genişliği `width` (dünya), kameraya dönük `face`.
func place(i: int, center: Vector3, width: float, face: Basis) -> void:
	if i < 0 or i >= count:
		return
	var unit: Vector2 = DayGauges.unit_size(0.0)
	var h: float = width * unit.y / unit.x
	mmi.multimesh.set_instance_transform(i, Transform3D(face * Basis.from_scale(Vector3(width, h, 1.0)), center))


func hide(i: int) -> void:
	if i >= 0 and i < count:
		mmi.multimesh.set_instance_transform(i, HIDDEN)


func set_power(v: float) -> void:
	material.set_shader_parameter("power", v)


func _push() -> void:
	for i: int in count:
		_push_one(i)


func _push_one(i: int) -> void:
	var m: int = _masks[i]
	var loads: Color = Color(float(m & 1), float((m >> 1) & 1), float((m >> 2) & 1), float((m >> 3) & 1))
	mmi.multimesh.set_instance_custom_data(i, loads)
	mmi.multimesh.set_instance_color(i, Color(0.0, 0.0, 16.0, DayGauges.pack_flags(0, _focus, _fault[i], false, false)))
