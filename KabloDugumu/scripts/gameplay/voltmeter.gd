class_name Voltmeter
extends Node3D

## Üst panodaki 3D analog voltmetre: metal gövde + krem kadran + kırmızı iğne.
## set_load(0..1) iğneyi soldan (0 V) sağa (250 V) sürer; idle'da hafif salınır,
## kazanınca settle() ile 0'a sakinleşir. Sahne kuralları burada değil.

const DIAL_RADIUS: float = 0.122
const NEEDLE_DEGREES: float = 50.0
const MAX_VOLTS: float = 250.0
const TICK_COLOR: Color = Color(0.12, 0.13, 0.16)
const FACE_COLOR: Color = Color(0.90, 0.87, 0.78)
const NEEDLE_COLOR: Color = Color(1.0, 0.27, 0.30)

var _needle: Node3D = null
var _target_load: float = 0.0
var _display_load: float = 0.0
var _time: float = 0.0
var _calm: bool = false


func _ready() -> void:
	_build()


## 0..1 yük: 0 = iğne solda (0 V), 1 = iğne sağda (250 V).
func set_load(load_value: float) -> void:
	_calm = false
	_target_load = clampf(load_value, 0.0, 1.0)


func set_voltage(volts: float) -> void:
	set_load(volts / MAX_VOLTS)


## Kazanma: iğne yumuşakça 0'a döner ve salınım söner.
func settle() -> void:
	_calm = true
	_target_load = 0.0


func reset() -> void:
	_calm = false
	_target_load = 0.0
	_display_load = 0.0


func needle_angle_degrees() -> float:
	return NEEDLE_DEGREES - 2.0 * NEEDLE_DEGREES * _display_load


func _process(delta: float) -> void:
	if _needle == null:
		return
	_time += delta
	var speed: float = 2.2 if _calm else 7.5
	_display_load = lerpf(_display_load, _target_load, clampf(delta * speed, 0.0, 1.0))
	var wobble: float = 0.0
	if _calm:
		# zafer: salınım söner, iğne 0'da durur
		wobble = sin(_time * 1.8) * 0.5 * _display_load
	else:
		# canlı ama okunur: iki frekanslı küçük iğne titremesi
		wobble = sin(_time * 2.3) * 0.9 - sin(_time * 3.7) * 0.3
		if _display_load > 0.72:
			wobble *= 1.8  # yüksek yükte iğne daha huzursuz
	_needle.rotation.z = deg_to_rad(needle_angle_degrees() + wobble)


func _build() -> void:
	_build_body()
	_build_face()
	_build_ticks()
	_build_labels()
	_build_needle()


func _build_body() -> void:
	var body: MeshInstance3D = _mesh_instance("Body", CylinderMesh.new())
	var body_mesh: CylinderMesh = body.mesh as CylinderMesh
	body_mesh.top_radius = 0.146
	body_mesh.bottom_radius = 0.146
	body_mesh.height = 0.045
	body_mesh.radial_segments = 24
	body_mesh.rings = 1
	body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	body.position = Vector3(0.0, 0.0, 0.0225)
	body.material_override = _metal(Color(0.10, 0.11, 0.14), 0.78, 0.38)

	var bezel: MeshInstance3D = _mesh_instance("Bezel", TorusMesh.new())
	var bezel_mesh: TorusMesh = bezel.mesh as TorusMesh
	bezel_mesh.inner_radius = 0.126
	bezel_mesh.outer_radius = 0.148
	bezel_mesh.rings = 28
	bezel_mesh.ring_segments = 8
	bezel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bezel.position = Vector3(0.0, 0.0, 0.02)
	bezel.material_override = _metal(Color(0.34, 0.37, 0.42), 0.85, 0.28)


func _build_face() -> void:
	var face: MeshInstance3D = _mesh_instance("Face", CylinderMesh.new())
	var face_mesh: CylinderMesh = face.mesh as CylinderMesh
	face_mesh.top_radius = DIAL_RADIUS
	face_mesh.bottom_radius = DIAL_RADIUS
	face_mesh.height = 0.012
	face_mesh.radial_segments = 32
	face_mesh.rings = 1
	face.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	face.position = Vector3(0.0, 0.0, 0.028)
	var face_material: StandardMaterial3D = StandardMaterial3D.new()
	face_material.albedo_color = FACE_COLOR
	face_material.roughness = 0.82
	face_material.metallic = 0.0
	face.material_override = face_material


func _build_ticks() -> void:
	var tick_material: StandardMaterial3D = StandardMaterial3D.new()
	tick_material.albedo_color = TICK_COLOR
	tick_material.roughness = 0.9
	for i: int in 9:
		var t: float = float(i) / 8.0
		var angle: float = deg_to_rad(NEEDLE_DEGREES - 2.0 * NEEDLE_DEGREES * t)
		var is_major: bool = i == 0 or i == 4 or i == 8
		var tick: MeshInstance3D = _mesh_instance("Tick%d" % i, BoxMesh.new())
		var tick_mesh: BoxMesh = tick.mesh as BoxMesh
		tick_mesh.size = Vector3(0.004 if not is_major else 0.006, 0.016 if not is_major else 0.022, 0.002)
		var radius: float = 0.100 if not is_major else 0.096
		tick.position = Vector3(sin(angle) * radius, cos(angle) * radius, 0.036)
		tick.rotation.z = angle
		tick.material_override = tick_material


func _build_labels() -> void:
	var font: Font = load("res://assets/fonts/Baloo2.ttf") as Font
	var left_angle: float = deg_to_rad(NEEDLE_DEGREES)
	var right_angle: float = deg_to_rad(-NEEDLE_DEGREES)
	_add_label("0", Vector3(sin(left_angle) * 0.072, cos(left_angle) * 0.072, 0.038), font)
	_add_label("250", Vector3(sin(right_angle) * 0.072, cos(right_angle) * 0.072, 0.038), font)
	_add_label("V", Vector3(0.0, -0.062, 0.038), font)

	var lamp: MeshInstance3D = _mesh_instance("Lamp", SphereMesh.new())
	var lamp_mesh: SphereMesh = lamp.mesh as SphereMesh
	lamp_mesh.radius = 0.007
	lamp_mesh.height = 0.014
	lamp_mesh.radial_segments = 8
	lamp_mesh.rings = 4
	lamp.position = Vector3(0.0, -0.096, 0.038)
	var lamp_material: StandardMaterial3D = StandardMaterial3D.new()
	lamp_material.albedo_color = Color(0.12, 0.09, 0.04)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(1.0, 0.72, 0.22)
	lamp_material.emission_energy_multiplier = 2.2
	lamp.material_override = lamp_material


func _build_needle() -> void:
	_needle = Node3D.new()
	_needle.name = "NeedlePivot"
	_needle.position = Vector3(0.0, 0.0, 0.045)
	add_child(_needle)

	var needle: MeshInstance3D = _mesh_instance("Needle", BoxMesh.new(), _needle)
	var needle_mesh: BoxMesh = needle.mesh as BoxMesh
	needle_mesh.size = Vector3(0.005, 0.100, 0.004)
	needle.position = Vector3(0.0, 0.050, 0.0)
	var needle_material: StandardMaterial3D = StandardMaterial3D.new()
	needle_material.albedo_color = NEEDLE_COLOR
	needle_material.emission_enabled = true
	needle_material.emission = NEEDLE_COLOR
	needle_material.emission_energy_multiplier = 0.8
	needle.material_override = needle_material


	var hub: MeshInstance3D = _mesh_instance("Hub", SphereMesh.new(), _needle)
	var hub_mesh: SphereMesh = hub.mesh as SphereMesh
	hub_mesh.radius = 0.013
	hub_mesh.height = 0.026
	hub_mesh.radial_segments = 10
	hub_mesh.rings = 6
	hub.position = Vector3(0.0, 0.0, 0.004)
	hub.material_override = _metal(Color(0.08, 0.09, 0.11), 0.9, 0.25)


func _add_label(text: String, label_position: Vector3, font: Font) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = font
	label.font_size = 28
	label.pixel_size = 0.0005
	label.position = label_position
	label.modulate = TICK_COLOR
	label.shaded = false
	label.double_sided = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


func _mesh_instance(mesh_name: String, mesh: PrimitiveMesh,
		parent: Node = null) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var target: Node = self if parent == null else parent
	target.add_child(instance)
	return instance


func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
