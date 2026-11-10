class_name SocketNode
extends Node3D

## Tek priz görseli: koyu metal plaka + renkli emissive halka + gerilim etiketi.
## Durumlar: boş (idle pulse), dolu (snap sonrası parlak), yanlış (kırmızı flash).
## Sahne kuralları burada değil: LevelController "doğru renk + boş" kuralını uygular.

const PLATE_SIZE: float = 0.172
const IDLE_ENERGY: float = 0.75
const OCCUPIED_ENERGY: float = 1.5
const WRONG_ENERGY: float = 2.0
const WRONG_COLOR: Color = Color(1.0, 0.16, 0.14)

var spec: SocketSpec = null
var index: int = 0
var is_occupied: bool = false

var _ring: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null
var _label: Label3D = null
var _time: float = 0.0
var _tween: Tween = null


## SocketSpec'i (renk/gerilim/konum) görsele çevirir. Ağaçta çağrılmalı.
func setup(socket_spec: SocketSpec) -> void:
	spec = socket_spec
	index = socket_spec.index
	position = socket_spec.position
	_build_plate()
	_build_ring()
	_build_slots()
	_build_label()


func _process(delta: float) -> void:
	if _ring_material == null:
		return
	_time += delta
	if is_occupied:
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


## Efekt konumu (kıvılcım/partikül panonun önünde patlasın).
func effect_position() -> Vector3:
	return global_position + Vector3(0.0, 0.0, 0.06)


func voltage_label() -> String:
	return "%d V" % (spec.voltage if spec != null else 0)


func _build_plate() -> void:
	var plate: MeshInstance3D = _add_mesh("Plate", BoxMesh.new(), _metal_material(0.10, 0.11, 0.13))
	(plate.mesh as BoxMesh).size = Vector3(PLATE_SIZE, PLATE_SIZE, 0.016)
	plate.position = Vector3(0.0, 0.0, 0.008)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# iç yatak: priz deliğinin karanlık çukuru
	var cup: MeshInstance3D = _add_mesh("Cup", CylinderMesh.new(), _metal_material(0.03, 0.035, 0.045))
	var cup_mesh: CylinderMesh = cup.mesh as CylinderMesh
	cup_mesh.top_radius = 0.042
	cup_mesh.bottom_radius = 0.042
	cup_mesh.height = 0.02
	cup_mesh.radial_segments = 16
	cup_mesh.rings = 1
	cup.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	cup.position = Vector3(0.0, 0.0, 0.018)
	cup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
