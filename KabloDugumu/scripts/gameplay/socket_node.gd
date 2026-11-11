class_name SocketNode
extends Node3D

## Tek priz görseli: koyu metal plaka + renkli emissive halka + gerilim etiketi.
## Durumlar: boş (idle pulse), dolu (snap sonrası parlak), yanlış (kırmızı flash).
## Sahne kuralları burada değil: LevelController "doğru renk + boş" kuralını uygular.

const PLATE_SIZE: float = 0.172
const IDLE_ENERGY: float = 0.75
const OCCUPIED_ENERGY: float = 1.5
const WRONG_ENERGY: float = 2.0
const LOCKED_ENERGY: float = 0.22
const WRONG_COLOR: Color = Color(1.0, 0.16, 0.14)
## locked_socket (ARCHITECTURE §12): fiş priz yanında bu kadar tutulursa kapak açılır.
const DEFAULT_HOLD_SECONDS: float = 0.6
const COVER_HINGE_ANGLE: float = -112.0
const COVER_OPEN_SECONDS: float = 0.45

var spec: SocketSpec = null
var index: int = 0
var is_occupied: bool = false
## Kapak kapalı mi (locked_socket modifier'ı). Kilitliyken snap olmaz.
var locked: bool = false

var _ring: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null
var _label: Label3D = null
var _cover_pivot: Node3D = null
var _cover_material: StandardMaterial3D = null
var _hold_disc: MeshInstance3D = null
var _hold_material: StandardMaterial3D = null
var _time: float = 0.0
var _tween: Tween = null
var _cover_tween: Tween = null


## SocketSpec'i (renk/gerilim/konum) görsele çevirir. Ağaçta çağrılmalı.
func setup(socket_spec: SocketSpec) -> void:
	spec = socket_spec
	index = socket_spec.index
	position = socket_spec.position
	_build_body_batch()
	_build_ring()
	_build_label()
	if socket_spec.locked:
		set_locked(true, false)


func _process(delta: float) -> void:
	if _ring_material == null:
		return
	_time += delta
	if is_occupied or locked:
		return
	# hafif nefes: prizler canlı görünsün ama dikkat çalmasın
	var wobble: float = sin(_time * 2.2 + float(index) * 1.7) * 0.22
	_ring_material.emission_energy_multiplier = IDLE_ENERGY + wobble


## Fiş oturunca: halka sabit ve parlak kalır, "snapshot" anında okunur.
func set_occupied(on: bool) -> void:
	is_occupied = on
	if _ring_material == null or _ring == null:
		return
	_kill_tween()
	if on:
		_ring_material.emission_energy_multiplier = OCCUPIED_ENERGY
		if _label != null:
			_label.modulate = Color(1.0, 1.0, 1.0, 0.95)
		if is_inside_tree():
			_ring.scale = Vector3.ONE * 1.28
			_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_tween.tween_property(_ring, "scale", Vector3.ONE, 0.3) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_ring.scale = Vector3.ONE
		_ring_material.emission = spec.color if spec != null else Color.WHITE
		_ring_material.emission_energy_multiplier = IDLE_ENERGY
		if _label != null:
			_label.modulate = Color(0.75, 0.82, 0.88, 0.65)


## Yanlış renk denemesi: kısa kırmızı ark flash'i + halka zıplaması.
func flash_wrong() -> void:
	if _ring_material == null or _ring == null:
		return
	_kill_tween()
	var original: Color = spec.color if spec != null else Color.WHITE
	_ring_material.emission = WRONG_COLOR
	_ring_material.emission_energy_multiplier = WRONG_ENERGY
	if not is_inside_tree():
		_ring_material.emission = original
		return
	_ring.scale = Vector3.ONE * 1.35
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_ring, "scale", Vector3.ONE, 0.32) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_restore_ring.bind(original))


## Kazanma anında tüm halkaların kısa kutlaması (LevelController kullanır).
func celebrate() -> void:
	if _ring_material == null or _ring == null:
		return
	_kill_tween()
	_ring_material.emission_energy_multiplier = OCCUPIED_ENERGY + 0.5
	if not is_inside_tree():
		return
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_ring, "scale", Vector3.ONE * 1.15, 0.22)
	_tween.tween_property(_ring, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_SINE)


## locked_socket modifier'ı: kapaklı priz. Kilitliyken snap kabul edilmez
## (LevelController kontrol eder); kapak animasyonla açılır (ASMR: yumuşak).
func set_locked(is_locked: bool, animated: bool = true) -> void:
	if locked == is_locked and _cover_pivot != null:
		return
	locked = is_locked
	if locked:
		_ensure_cover()
		_close_cover()
		set_hold_progress(0.0)
		_apply_locked_lighting(1.0)
	else:
		_apply_locked_lighting(0.0)
		if _hold_disc != null:
			_hold_disc.visible = false
		if _cover_pivot != null:
			if animated and is_inside_tree():
				_open_cover_animated()
			else:
				_cover_pivot.visible = false


func is_locked() -> bool:
	return locked


## Saf kural: fiş priz yanında tutulurken kilit açma ilerlemesi (0..hold_seconds).
static func advance_hold(progress: float, delta: float, hold_seconds: float) -> float:
	if hold_seconds <= 0.0:
		return 0.0
	return clampf(progress + maxf(delta, 0.0), 0.0, hold_seconds)


## Saf kural: fiş yeterince tutuldu mu (süre kuralı = 0.6 sn varsayılan).
static func is_hold_complete(progress: float, hold_seconds: float) -> bool:
	return hold_seconds > 0.0 and progress >= hold_seconds - 0.0001


## data/balance.json -> modifiers.locked_socket.hold_seconds (yoksa 0.6 sn).
static func hold_seconds_from(balance: Dictionary) -> float:
	var modifiers: Variant = balance.get("modifiers")
	if modifiers is Dictionary:
		var locked_cfg: Variant = (modifiers as Dictionary).get("locked_socket")
		if locked_cfg is Dictionary:
			return maxf(0.01,
				float((locked_cfg as Dictionary).get("hold_seconds", DEFAULT_HOLD_SECONDS)))
	return DEFAULT_HOLD_SECONDS


## Efekt konumu (kıvılcım/partikül panonun önünde patlasın).
func effect_position() -> Vector3:
	return global_position + Vector3(0.0, 0.0, 0.06)


func voltage_label() -> String:
	return "%d V" % (spec.voltage if spec != null else 0)


## Priz govdesi TEK birlesik mesh: plaka + yatak cukuru + iki kontak yuvasi.
## (Perf: priz basina 4 draw call yerine 1; 7 prizde ~21 draw kazanc, ARCHITECTURE §14.)
func _build_body_batch() -> void:
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plate_mesh: BoxMesh = BoxMesh.new()
	plate_mesh.size = Vector3(PLATE_SIZE, PLATE_SIZE, 0.016)
	surface.append_from(plate_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.008)))
	var cup_mesh: CylinderMesh = CylinderMesh.new()
	cup_mesh.top_radius = 0.042
	cup_mesh.bottom_radius = 0.042
	cup_mesh.height = 0.02
	cup_mesh.radial_segments = 16
	cup_mesh.rings = 1
	var cup_basis: Basis = Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	surface.append_from(cup_mesh, 0, Transform3D(cup_basis, Vector3(0.0, 0.0, 0.018)))
	for slot_x: float in [-0.022, 0.022]:
		var slot_mesh: BoxMesh = BoxMesh.new()
		slot_mesh.size = Vector3(0.025, 0.038, 0.008)
		surface.append_from(slot_mesh, 0,
			Transform3D(Basis.IDENTITY, Vector3(slot_x, 0.0, 0.03)))
	surface.set_material(_metal_material(0.10, 0.11, 0.13))
	body.mesh = surface.commit() as ArrayMesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)


func _build_ring() -> void:
	_ring = _add_mesh("Ring", TorusMesh.new(), null)
	var torus: TorusMesh = _ring.mesh as TorusMesh
	torus.inner_radius = 0.051
	torus.outer_radius = 0.069
	torus.rings = 24
	torus.ring_segments = 8
	_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_ring.position = Vector3(0.0, 0.0, 0.028)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = Color(0.04, 0.05, 0.06)
	var base_color: Color = spec.color if spec != null else Color.WHITE
	_ring_material.emission_enabled = true
	_ring_material.emission = base_color
	_ring_material.emission_energy_multiplier = IDLE_ENERGY
	_ring_material.roughness = 0.35
	_ring_material.metallic = 0.2
	_ring.material_override = _ring_material


func _build_slots() -> void:
	for slot_x: float in [-0.022, 0.022]:
		var slot: MeshInstance3D = _add_mesh("Slot", BoxMesh.new(), _metal_material(0.01, 0.012, 0.015))
		(slot.mesh as BoxMesh).size = Vector3(0.025, 0.038, 0.008)
		slot.position = Vector3(slot_x, 0.0, 0.03)
		slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_label() -> void:
	_label = Label3D.new()
	_label.name = "Voltage"
	_label.text = voltage_label()
	_label.font_size = 36
	_label.pixel_size = 0.0016
	_label.position = Vector3(0.0, -0.128, 0.03)
	_label.modulate = Color(0.82, 0.90, 0.96, 0.85)
	_label.shaded = false
	_label.double_sided = true
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_label)


func _add_mesh(mesh_name: String, mesh: PrimitiveMesh, material: StandardMaterial3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	if material != null:
		instance.material_override = material
	add_child(instance)
	return instance


## Kapak: üst kenarından menteşeli koyu metal plaka + amber kilit çubuğu.
func _ensure_cover() -> void:
	if _cover_pivot != null:
		return
	_cover_pivot = Node3D.new()
	_cover_pivot.name = "CoverPivot"
	_cover_pivot.position = Vector3(0.0, PLATE_SIZE * 0.5, 0.052)
	add_child(_cover_pivot)
	_cover_material = StandardMaterial3D.new()
	_cover_material.albedo_color = Color(0.09, 0.10, 0.12)
	_cover_material.metallic = 0.75
	_cover_material.roughness = 0.38
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.name = "CoverPlate"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(PLATE_SIZE, PLATE_SIZE, 0.012)
	plate.mesh = box
	plate.position = Vector3(0.0, -PLATE_SIZE * 0.5, 0.0)
	plate.material_override = _cover_material
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cover_pivot.add_child(plate)
	var bar: MeshInstance3D = MeshInstance3D.new()
	bar.name = "CoverBar"
	var bar_mesh: BoxMesh = BoxMesh.new()
	bar_mesh.size = Vector3(PLATE_SIZE * 0.7, 0.016, 0.014)
	bar.mesh = bar_mesh
	bar.position = Vector3(0.0, -PLATE_SIZE * 0.5, 0.010)
	var amber: StandardMaterial3D = StandardMaterial3D.new()
	amber.albedo_color = Color(0.55, 0.38, 0.10)
	amber.emission_enabled = true
	amber.emission = Color(1.0, 0.72, 0.25)
	amber.emission_energy_multiplier = 0.7
	bar.material_override = amber
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cover_pivot.add_child(bar)
	# Amber kontur: kapagin cevresinde ince emissive cerceve (kilit okunsun).
	var outline_material: StandardMaterial3D = StandardMaterial3D.new()
	outline_material.albedo_color = Color(0.35, 0.22, 0.05)
	outline_material.emission_enabled = true
	outline_material.emission = Color(1.0, 0.66, 0.18)
	outline_material.emission_energy_multiplier = 1.05
	for side: float in [-1.0, 1.0]:
		var edge_h: MeshInstance3D = MeshInstance3D.new()
		edge_h.name = "CoverEdgeH"
		var edge_h_mesh: BoxMesh = BoxMesh.new()
		edge_h_mesh.size = Vector3(PLATE_SIZE + 0.012, 0.006, 0.008)
		edge_h.mesh = edge_h_mesh
		edge_h.position = Vector3(0.0, -PLATE_SIZE * 0.5 + side * PLATE_SIZE * 0.5, 0.007)
		edge_h.material_override = outline_material
		edge_h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cover_pivot.add_child(edge_h)
		var edge_v: MeshInstance3D = MeshInstance3D.new()
		edge_v.name = "CoverEdgeV"
		var edge_v_mesh: BoxMesh = BoxMesh.new()
		edge_v_mesh.size = Vector3(0.006, PLATE_SIZE + 0.012, 0.008)
		edge_v.mesh = edge_v_mesh
		edge_v.position = Vector3(side * PLATE_SIZE * 0.5, -PLATE_SIZE * 0.5, 0.007)
		edge_v.material_override = outline_material
		edge_v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cover_pivot.add_child(edge_v)
	# Pirinc kilit rozeti: govde + kanca.
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.55, 0.24)
	brass.metallic = 0.95
	brass.roughness = 0.3
	brass.emission_enabled = true
	brass.emission = Color(1.0, 0.78, 0.35)
	brass.emission_energy_multiplier = 0.35
	var lock_body: MeshInstance3D = MeshInstance3D.new()
	lock_body.name = "LockBody"
	var lock_body_mesh: BoxMesh = BoxMesh.new()
	lock_body_mesh.size = Vector3(0.062, 0.048, 0.014)
	lock_body.mesh = lock_body_mesh
	lock_body.position = Vector3(0.0, -PLATE_SIZE * 0.5, 0.014)
	lock_body.material_override = brass
	lock_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cover_pivot.add_child(lock_body)
	var shackle: MeshInstance3D = MeshInstance3D.new()
	shackle.name = "LockShackle"
	var shackle_mesh: TorusMesh = TorusMesh.new()
	shackle_mesh.inner_radius = 0.016
	shackle_mesh.outer_radius = 0.024
	shackle_mesh.rings = 14
	shackle_mesh.ring_segments = 6
	shackle.mesh = shackle_mesh
	shackle.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	shackle.position = Vector3(0.0, -PLATE_SIZE * 0.5 - 0.026, 0.014)
	shackle.material_override = brass
	shackle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cover_pivot.add_child(shackle)
	# 0.6 sn tutma ilerlemesi: kapagin onunde buyuyen amber disk (halka dolumu).
	_hold_disc = MeshInstance3D.new()
	_hold_disc.name = "HoldProgress"
	var disc_mesh: CylinderMesh = CylinderMesh.new()
	disc_mesh.top_radius = 0.052
	disc_mesh.bottom_radius = 0.052
	disc_mesh.height = 0.006
	disc_mesh.radial_segments = 20
	disc_mesh.rings = 1
	_hold_disc.mesh = disc_mesh
	_hold_disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_hold_disc.position = Vector3(0.0, -PLATE_SIZE * 0.5, 0.020)
	_hold_material = StandardMaterial3D.new()
	_hold_material.albedo_color = Color(0.9, 0.62, 0.2)
	_hold_material.emission_enabled = true
	_hold_material.emission = Color(1.0, 0.72, 0.25)
	_hold_material.emission_energy_multiplier = 1.3
	_hold_disc.material_override = _hold_material
	_hold_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hold_disc.visible = false
	_cover_pivot.add_child(_hold_disc)


## 0..1 tutma ilerlemesi (kilitli priz kapağı açılırken görsel geri bildirim).
func set_hold_progress(progress: float) -> void:
	if _hold_disc == null:
		return
	var value: float = clampf(progress, 0.0, 1.0)
	_hold_disc.visible = value > 0.01 and locked
	if not _hold_disc.visible:
		return
	var eased: float = 0.15 + 0.85 * value
	_hold_disc.scale = Vector3(eased, eased, 1.0)
	if _hold_material != null:
		_hold_material.emission_energy_multiplier = 0.7 + 1.2 * value


func _close_cover() -> void:
	if _cover_pivot == null:
		return
	_kill_cover_tween()
	_cover_pivot.visible = true
	_cover_pivot.rotation_degrees = Vector3.ZERO


func _open_cover_animated() -> void:
	_kill_cover_tween()
	_cover_pivot.visible = true
	_cover_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cover_tween.tween_property(_cover_pivot, "rotation_degrees:x", COVER_HINGE_ANGLE,
		COVER_OPEN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cover_tween.tween_callback(_hide_cover)


func _hide_cover() -> void:
	if _cover_pivot != null:
		_cover_pivot.visible = false


func _kill_cover_tween() -> void:
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	_cover_tween = null


## 1.0 = kilitli (halka sönük), 0.0 = açık (normal nefes).
func _apply_locked_lighting(locked_amount: float) -> void:
	if _ring_material != null:
		var base_color: Color = spec.color if spec != null else Color.WHITE
		_ring_material.emission = base_color
		var energy: float = lerpf(IDLE_ENERGY, LOCKED_ENERGY, locked_amount)
		_ring_material.emission_energy_multiplier = energy
	if _label != null:
		var fade: float = lerpf(0.75, 0.35, locked_amount)
		_label.modulate = Color(0.75, 0.82, 0.88, fade)


func _metal_material(r: float, g: float, b: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(r, g, b)
	material.metallic = 0.7
	material.roughness = 0.42
	return material


func _restore_ring(original: Color) -> void:
	if _ring_material == null:
		return
	_ring_material.emission = original
	_ring_material.emission_energy_multiplier = OCCUPIED_ENERGY if is_occupied else IDLE_ENERGY


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
