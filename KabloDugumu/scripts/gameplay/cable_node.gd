class_name CableNode
extends Node3D

## Tek kablo: fiş görseli (kodla üretilmiş primitifler) + CableRope + durum.
## Fiş, halatın son noktasını (uç) takip eder; sürükleme/snap durumları burada
## yönetilir. Konumlar pano uzayındadır: CableNode kimlik dönüşümde tutulur.

signal grabbed(cable_index: int)
signal released(cable_index: int, plug_position: Vector3)
signal snapped(cable_index: int, socket_index: int)
signal wrong_socket(cable_index: int)

enum State { IDLE = 0, DRAGGING = 1, CONNECTED = 2 }

## Fis govdesi: pano uzerinde okunur boyutta koyu metal cerceve.
const BODY_SIZE: Vector3 = Vector3(0.15, 0.12, 0.09)
## Renkli neon kabuk (govdenin on yuzu; cerceve kenarlardan gorunur).
const SHELL_SIZE: Vector3 = Vector3(0.118, 0.088, 0.042)
const SHELL_Z: float = 0.032
## Pirinc pimler: silindir ekseni Z, uclari panoya (-Z) donuk.
const PIN_RADIUS: float = 0.009
const PIN_HEIGHT: float = 0.05
const PIN_X_OFFSET: float = 0.04
const PIN_Y_OFFSET: float = -0.022
const PIN_Z: float = -0.06
## Ustteki kucuk parlak halka (fisin tutama izlenimi).
const TOP_RING_Y: float = 0.09
const TOP_RING_INNER: float = 0.018
const TOP_RING_OUTER: float = 0.027
const LABEL_Y: float = -0.1
const LABEL_Z: float = 0.022
const LABEL_FONT_SIZE: int = 40
const LABEL_PIXEL_SIZE: float = 0.0016
## Glow esigi Environment'ta 1.1: emission'i bunun altinda tut ki renk beyaza
## yikanmasin (panel-world geri bildirimi).
const PLUG_CORE_ENERGY: float = 0.85
const PLUG_CORE_HIGHLIGHT_ENERGY: float = 1.8
const PLUG_RING_ENERGY: float = 1.2
const PLUG_RING_HIGHLIGHT_ENERGY: float = 2.0
## Suruklerken fis hafif buyur (highlight()) ve parlar.
const DRAG_SCALE: float = 1.12
const GOLD_ARC_SECONDS: float = 0.6
## Fis govdesi halat ucunun biraz onunde dursun: tupe ucu govde icine girsin,
## boylece kablo ile fis arasinda bosluk gorunmez.
const PLUG_VISUAL_OFFSET: Vector3 = Vector3(0.0, 0.0, 0.028)

var index: int = 0
var spec: CableSpec = null
var state: int = State.IDLE
var grabbable: bool = true

var _rope: CableRope = null
var _plug_root: Node3D = null
var _body_material: StandardMaterial3D = null
var _core_material: StandardMaterial3D = null
var _ring_material: StandardMaterial3D = null
var _label: Label3D = null
var _gold_arc: MeshInstance3D = null
var _gold_tween: Tween = null
var _highlight_tween: Tween = null
var _pending_socket_index: int = -1
var _highlighted: bool = false


func _process(_delta: float) -> void:
	if _rope == null or _plug_root == null:
		return
	_plug_root.position = _rope.tip_position() + PLUG_VISUAL_OFFSET


## Fiş görselini kurar ve halatı spec.points/spec.length ile hazırlar.
## Ağaçta olmayı şart koşmaz (önce add_child, sonra setup akışı desteklenir).
func setup(cable_spec: CableSpec) -> void:
	if cable_spec == null:
		push_error("CableNode.setup: spec null")
		return
	spec = cable_spec
	index = cable_spec.index
	state = State.IDLE
	grabbable = true
	_highlighted = false
	_build_plug_visuals()
	_update_label(cable_spec.voltage)
	if _rope == null:
		_rope = CableRope.new()
		_rope.name = "Rope"
		add_child(_rope)
		_rope.snap_finished.connect(_on_rope_snap_finished)
	_rope.setup(cable_spec.points, cable_spec.length, cable_spec.color, cable_spec.voltage)
	if _plug_root != null:
		_plug_root.position = _rope.tip_position() + PLUG_VISUAL_OFFSET


func plug_position() -> Vector3:
	if _rope != null:
		return _rope.tip_world_position()
	if spec != null:
		return _to_world(spec.plug_rest)
	return _to_world(Vector3.ZERO)


func socket_position() -> Vector3:
	if spec == null:
		return _to_world(Vector3.ZERO)
	return _to_world(spec.socket)


## Fişi sürüklemeye başlar; grabbed sinyali yayınlar.
func begin_drag(target: Vector3) -> void:
	if _rope == null or not grabbable or state == State.CONNECTED:
		return
	state = State.DRAGGING
	_rope.begin_drag(target)
	highlight(true)
	grabbed.emit(index)


func update_drag(target: Vector3) -> void:
	if _rope == null or state != State.DRAGGING:
		return
	_rope.update_drag(target)


## locked=false: fiş bulunduğu yerde mıknatısla asılı kalır (panoya yumuşak iniş).
## locked=true: bağlantı kararı verildi; çağıran snap_to() ile oturtur.
func end_drag(locked: bool) -> void:
	if _rope == null or state != State.DRAGGING:
		return
	_rope.end_drag(locked)
	if not locked:
		state = State.IDLE
	highlight(false)
	var plug: Vector3 = plug_position()
	released.emit(index, plug)


## Halatı (fişi) prize oturtur; animasyon bitince snapped sinyali yayınlanır.
func snap_to(target: Vector3) -> void:
	snap_to_with_socket(target, _default_socket_index())


## Prize oturtma (priz indeksi açıkça verilerek).
func snap_to_with_socket(target: Vector3, socket_index: int) -> void:
	if _rope == null:
		return
	state = State.CONNECTED
	grabbable = false
	_pending_socket_index = socket_index
	highlight(false)
	_rope.snap_to(target)


## QA/force_snap: animasyonsuz anında bağlar.
func snap_instant(target: Vector3) -> void:
	snap_to_with_socket(target, _default_socket_index())
	_rope.finish_animations()


## Altın yan keski: 0.6 sn altın yay animasyonu + prize oturma.
func force_snap_animation(target: Vector3) -> void:
	if _rope == null:
		return
	state = State.CONNECTED
	grabbable = false
	_pending_socket_index = _default_socket_index()
	highlight(false)
	if not is_inside_tree():
		_rope.snap_to(target)
		_rope.finish_animations()
		return
	_ensure_gold_arc()
	_gold_arc.position = _rope.tip_position()
	_gold_arc.scale = Vector3.ONE * 0.2
	_gold_arc.visible = true
	if _gold_tween != null and _gold_tween.is_valid():
		_gold_tween.kill()
	_gold_tween = create_tween()
	_gold_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_gold_tween.tween_property(_gold_arc, "scale", Vector3.ONE * 1.5, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gold_tween.tween_property(_gold_arc, "scale", Vector3.ONE * 0.1, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_gold_tween.tween_interval(0.06)
	_gold_tween.tween_callback(_finish_gold_arc.bind(target))


## Yanlış priz sekmasi: fiş height kadar yukarı sekip panoya geri oturur.
func bounce_up(height: float) -> void:
	if _rope == null:
		return
	state = State.IDLE
	highlight(false)
	_rope.bounce_tip_up(height)


## Yanlış priz olayını game.gd adına yayınlar.
func notify_wrong_socket() -> void:
	wrong_socket.emit(index)


func highlight(on: bool) -> void:
	if _core_material == null:
		return
	_highlighted = on
	var core_energy: float = PLUG_CORE_HIGHLIGHT_ENERGY if on else PLUG_CORE_ENERGY
	var ring_energy: float = PLUG_RING_HIGHLIGHT_ENERGY if on else PLUG_RING_ENERGY
	var plug_scale: Vector3 = Vector3.ONE * (DRAG_SCALE if on else 1.0)
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	if not is_inside_tree():
		_core_material.emission_energy_multiplier = core_energy
		if _ring_material != null:
			_ring_material.emission_energy_multiplier = ring_energy
		if _plug_root != null:
			_plug_root.scale = plug_scale
		return
	_highlight_tween = create_tween()
	_highlight_tween.set_parallel(true)
	_highlight_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_highlight_tween.tween_property(_core_material, "emission_energy_multiplier", core_energy, 0.12)
	if _ring_material != null:
		_highlight_tween.tween_property(_ring_material, "emission_energy_multiplier", ring_energy, 0.12)
	if _plug_root != null:
		_highlight_tween.tween_property(_plug_root, "scale", plug_scale, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Kalkan görselini halat malzemesine delege eder.
func set_shielded(active: bool) -> void:
	if _rope != null:
		_rope.set_shielded(active)


## Fiş tutulabilir mi (yanlış priz cezası, bağlı fiş vb. için kapatılır).
func set_grabbable(on: bool) -> void:
	grabbable = on


func is_grabbable() -> bool:
	return grabbable


func is_highlighted() -> bool:
	return _highlighted


func is_dragging() -> bool:
	return state == State.DRAGGING or (_rope != null and _rope.is_dragging())


## NOT: Godot'un Object.is_connected(signal, callable) native metodu oldugu icin
## is_connected() adi GDScript'te tanimlanamaz (native_method_override = hata).
## Sozlesmedeki karsiligi: is_linked() ya da state == CableNode.State.CONNECTED.
func is_linked() -> bool:
	return state == State.CONNECTED


## Baglanti durumu (salt okunur ozellik; is_linked() ile ayni).
var connected: bool:
	get:
		return state == State.CONNECTED


## Temas taraması için dünya uzayında halat segmentleri.
func segments() -> PackedVector3Array:
	if _rope == null:
		return PackedVector3Array()
	return _rope.segments()


func taut_ratio() -> float:
	if _rope == null:
		return 0.0
	return _rope.taut_ratio()


func rope() -> CableRope:
	return _rope


func color() -> Color:
	if spec == null:
		return Color.WHITE
	return spec.color


# --- iç işler ------------------------------------------------------------

func _default_socket_index() -> int:
	if spec == null:
		return -1
	return spec.socket_index


func _to_world(point: Vector3) -> Vector3:
	if is_inside_tree():
		return to_global(point)
	return point


func _on_rope_snap_finished() -> void:
	state = State.CONNECTED
	grabbable = false
	var socket_index: int = _pending_socket_index
	if socket_index < 0:
		socket_index = _default_socket_index()
	_pending_socket_index = -1
	snapped.emit(index, socket_index)


func _finish_gold_arc(target: Vector3) -> void:
	if _gold_arc != null:
		_gold_arc.visible = false
	if _rope != null:
		_rope.snap_to(target)


func _ensure_gold_arc() -> void:
	if _gold_arc != null:
		return
	_gold_arc = MeshInstance3D.new()
	_gold_arc.name = "GoldArc"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.06
	torus.outer_radius = 0.085
	torus.rings = 16
	torus.ring_segments = 8
	_gold_arc.mesh = torus
	_gold_arc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_gold_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.83, 0.35)
	material.metallic = 0.9
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.3)
	material.emission_energy_multiplier = 1.6
	_gold_arc.material_override = material
	_gold_arc.visible = false
	add_child(_gold_arc)


## Fis gorseli: koyu metal cerceve + renkli neon kabuk + 2 pirinc pim +
## ustte parlak halka + voltaj etiketi. Hepsi kodla uretilir (dis varlik yok).
func _build_plug_visuals() -> void:
	if _plug_root != null:
		return
	_plug_root = Node3D.new()
	_plug_root.name = "Plug"
	add_child(_plug_root)

	# Govde: cok koyu ama kablo rengiyle tonlanmis metal — renk kimligi koyu
	# cerceveden de okunur (albedo parlakligi ~0.1).
	_body_material = StandardMaterial3D.new()
	if spec != null:
		_body_material.albedo_color = spec.color.darkened(0.82)
	else:
		_body_material.albedo_color = Color(0.1, 0.11, 0.13)
	_body_material.metallic = 0.75
	_body_material.roughness = 0.35
	_add_box_visual("Body", BODY_SIZE, Vector3.ZERO, _body_material)

	# Neon kabuk: canli albedo + glow esiginin altinda emission (beyaza yikamasin).
	_core_material = StandardMaterial3D.new()
	if spec != null:
		_core_material.albedo_color = spec.color.darkened(0.25)
		_core_material.emission_enabled = true
		_core_material.emission = spec.color
		_core_material.emission_energy_multiplier = PLUG_CORE_ENERGY
	_core_material.metallic = 0.1
	_core_material.roughness = 0.22
	_add_box_visual("Shell", SHELL_SIZE, Vector3(0.0, 0.0, SHELL_Z), _core_material)

	var pin_material: StandardMaterial3D = StandardMaterial3D.new()
	pin_material.albedo_color = Color(0.83, 0.64, 0.3)
	pin_material.metallic = 1.0
	pin_material.roughness = 0.28
	_add_cylinder_visual("PinA", Vector3(-PIN_X_OFFSET, PIN_Y_OFFSET, PIN_Z), pin_material)
	_add_cylinder_visual("PinB", Vector3(PIN_X_OFFSET, PIN_Y_OFFSET, PIN_Z), pin_material)

	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = Color(0.85, 0.9, 0.95)
	_ring_material.metallic = 0.5
	_ring_material.roughness = 0.2
	_ring_material.emission_enabled = true
	if spec != null:
		_ring_material.emission = spec.color.lerp(Color.WHITE, 0.3)
	_ring_material.emission_energy_multiplier = PLUG_RING_ENERGY
	_add_torus_visual("TopRing", Vector3(0.0, TOP_RING_Y, 0.0), _ring_material)

	_label = Label3D.new()
	_label.name = "VoltageLabel"
	_label.font_size = LABEL_FONT_SIZE
	_label.pixel_size = LABEL_PIXEL_SIZE
	_label.outline_size = 6
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	_label.modulate = Color(1.0, 1.0, 1.0)
	_label.position = Vector3(0.0, LABEL_Y, LABEL_Z)
	_label.text = "0V"
	_label.no_depth_test = false
	_plug_root.add_child(_label)


func _add_box_visual(node_name: String, size: Vector3, offset: Vector3,
		material: StandardMaterial3D) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _plug_root != null:
		_plug_root.add_child(instance)


## Pirinc pim: silindir ekseni 90 derece cevrilerek Z'ye alinir (pano yonu -Z).
func _add_cylinder_visual(node_name: String, offset: Vector3,
		material: StandardMaterial3D) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = PIN_RADIUS
	mesh.bottom_radius = PIN_RADIUS
	mesh.height = PIN_HEIGHT
	mesh.radial_segments = 8
	mesh.rings = 1
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _plug_root != null:
		_plug_root.add_child(instance)


## Ustteki parlak halka (torus XZ duzleminde, yatay).
func _add_torus_visual(node_name: String, offset: Vector3,
		material: StandardMaterial3D) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = TOP_RING_INNER
	mesh.outer_radius = TOP_RING_OUTER
	mesh.rings = 16
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	# Kamera +Z'den bakar; halka da kameraya baksin (yatay torus kenardan
	# gorunup beyaz cubuk gibi okunmasin).
	instance.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _plug_root != null:
		_plug_root.add_child(instance)


func _update_label(voltage: int) -> void:
	if _label == null:
		return
	_label.text = "%dV" % voltage
