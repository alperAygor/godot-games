class_name BoardBuilder
extends Node3D

## Koyu endüstriyel pano (1.7 x 3.1 m) — tamamen kodla üretilir, .tscn minimal.
## Gövde + kalın çerçeve + sarı-siyah uyarı şeritleri + üst ana pano (şalter
## kutusu, sigortalar) + alt priz şeridi + düğüm alanı gravürü + devre şeması
## + neon underglow. Koordinat: pano düzlemi XY, ön yüz z=0, kamera +Z'den bakar.

const DEFAULT_WIDTH: float = 1.7
const DEFAULT_HEIGHT: float = 3.1
const BOARD_DEPTH: float = 0.14
const FRAME_WIDTH: float = 0.09
const WARNING_YELLOW: Color = Color(0.82, 0.62, 0.16)
const WARNING_BLACK: Color = Color(0.05, 0.05, 0.06)
const NEON_CYAN: Color = Color(0.20, 0.91, 0.77)
const NEON_AMBER: Color = Color(1.0, 0.72, 0.22)
const ZONE_TOP_DEFAULT: float = 0.68
const ZONE_BOTTOM_DEFAULT: float = -0.55
const ZONE_HALF_WIDTH: float = 0.73

var width: float = DEFAULT_WIDTH
var height: float = DEFAULT_HEIGHT
var surface_z: float = 0.055
## 3D voltmetre HUD'daki 2D göstergeyle çakıştığı için panodan kaldırıldı
## (Lead kararı). Sınıf duruyor; istenirse küçük gösterge olarak geri takılır.
var voltmeter: Voltmeter = null

var _built: bool = false
var _font: Font = null
var _mat_panel: StandardMaterial3D = null
var _mat_frame: StandardMaterial3D = null
var _mat_dark: StandardMaterial3D = null
var _mat_brushed: StandardMaterial3D = null
var _mat_zone: StandardMaterial3D = null
var _stripe_material: StandardMaterial3D = null
var _zone_top: float = ZONE_TOP_DEFAULT + 0.08
var _zone_bottom: float = ZONE_BOTTOM_DEFAULT - 0.34


## data/balance.json "board" bölümüyle panoyu kurar. İdempotenttir.
func build(layout: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	width = float(layout.get("width", DEFAULT_WIDTH))
	height = float(layout.get("height", DEFAULT_HEIGHT))
	surface_z = float(layout.get("board_surface_z", 0.055))
	# Düğüm alanı çerçevesi forge-core'un ürettiği fiş satırlarından okunur:
	# üstte fiş satırı payı, altta halat sarkma payı (priz şeridine değmeden).
	_zone_top = float(layout.get("knot_y_top", ZONE_TOP_DEFAULT)) + 0.08
	_zone_bottom = float(layout.get("knot_y_bottom", ZONE_BOTTOM_DEFAULT)) - 0.34
	_font = load("res://assets/fonts/Baloo2.ttf") as Font
	_mat_panel = _plain(Color(0.075, 0.086, 0.105), 0.55, 0.52)
	_mat_frame = _plain(Color(0.17, 0.185, 0.215), 0.78, 0.34)
	_mat_dark = _plain(Color(0.075, 0.085, 0.105), 0.70, 0.45)
	_mat_brushed = _plain(Color(0.33, 0.36, 0.41), 0.85, 0.28)
	_mat_zone = _emissive(Color(0.20, 0.55, 0.50), 0.25)
	_build_body()
	_build_frame()
	_build_warning_stripes()
	_build_socket_strip()
	_build_header()
	_build_work_zone()
	_build_grid_overlay()
	_build_underglow()
	_build_labels()


## Bölümdeki her kablo kaynağı için renkli kelepçe halkası.
func add_source_clamp(source_position: Vector3, color: Color, voltage: int) -> void:
	_box("SourceBracket", Vector3(0.10, 0.14, 0.05),
		source_position + Vector3(0.0, 0.0, 0.03), _mat_dark)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "SourceRing"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.030
	torus.outer_radius = 0.045
	torus.rings = 20
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.position = source_position + Vector3(0.0, 0.0, 0.055)
	ring.material_override = _emissive(color, 0.85)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var dash: MeshInstance3D = _box("SourceVoltage%d" % voltage,
		Vector3(0.07, 0.008, 0.01), source_position + Vector3(0.0, -0.088, 0.056),
		_emissive(color, 0.55))
	dash.name = "SourceVoltage%d" % voltage


func board_bounds() -> Rect2:
	return Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height))


func _build_body() -> void:
	_box("Panel", Vector3(width, height, BOARD_DEPTH),
		Vector3(0.0, 0.0, -BOARD_DEPTH * 0.5), _mat_panel)
	for side: float in [-1.0, 1.0]:
		_box("BevelTop", Vector3(width - 0.01, 0.028, 0.02),
			Vector3(0.0, side * (height * 0.5 - 0.014), 0.004), _mat_frame)
		_box("BevelSide", Vector3(0.028, height - 0.01, 0.02),
			Vector3(side * (width * 0.5 - 0.014), 0.0, 0.004), _mat_frame)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner: MeshInstance3D = _box("CornerPlate", Vector3(0.062, 0.062, 0.016),
				Vector3(sx * (width * 0.5 - 0.085), sy * (height * 0.5 - 0.085), 0.008),
				_mat_brushed)
			corner.rotation_degrees = Vector3(0.0, 0.0, 45.0)
			_bolt(Vector3(sx * (width * 0.5 - 0.085), sy * (height * 0.5 - 0.085), 0.02))
	for sx: float in [-1.0, 1.0]:
		_bolt(Vector3(sx * (width * 0.5 - 0.045), 0.0, 0.02))


func _build_frame() -> void:
	var depth: float = BOARD_DEPTH + 0.035
	_box("FrameTop", Vector3(width + FRAME_WIDTH * 2.0, FRAME_WIDTH, depth),
		Vector3(0.0, height * 0.5 + FRAME_WIDTH * 0.5, -0.004), _mat_frame)
	_box("FrameBottom", Vector3(width + FRAME_WIDTH * 2.0, FRAME_WIDTH, depth),
		Vector3(0.0, -height * 0.5 - FRAME_WIDTH * 0.5, -0.004), _mat_frame)
	_box("FrameLeft", Vector3(FRAME_WIDTH, height, depth),
		Vector3(-width * 0.5 - FRAME_WIDTH * 0.5, 0.0, -0.004), _mat_frame)
	_box("FrameRight", Vector3(FRAME_WIDTH, height, depth),
		Vector3(width * 0.5 + FRAME_WIDTH * 0.5, 0.0, -0.004), _mat_frame)


func _build_warning_stripes() -> void:
	var texture: ImageTexture = _make_stripe_texture()
	_stripe_material = StandardMaterial3D.new()
	_stripe_material.albedo_texture = texture
	_stripe_material.uv1_scale = Vector3(10.0, 1.0, 1.0)
	_stripe_material.roughness = 0.72
	_stripe_material.metallic = 0.05
	for side: float in [-1.0, 1.0]:
		_box("WarningTop", Vector3(width - 0.02, 0.046, 0.024),
			Vector3(0.0, side * (height * 0.5 - 0.04), 0.012), _stripe_material)
	# dikey şeritler: ayrı UV ölçeğiyle (yoksa doku tek renge dönüşüyor)
	var side_material: StandardMaterial3D = _stripe_material.duplicate() as StandardMaterial3D
	side_material.uv1_scale = Vector3(1.4, 11.0, 1.0)
	for side: float in [-1.0, 1.0]:
		_box("WarningSide", Vector3(0.048, 2.05, 0.022),
			Vector3(side * (width * 0.5 - 0.038), 0.06, 0.012), side_material)


func _build_socket_strip() -> void:
	var strip_y: float = -height * 0.5 + 0.33
	_box("SocketStrip", Vector3(width - 0.20, 0.34, 0.06),
		Vector3(0.0, strip_y, 0.03), _mat_dark)
	_box("SocketRail", Vector3(width - 0.18, 0.032, 0.075),
		Vector3(0.0, strip_y + 0.175, 0.035), _mat_brushed)
	_box("SocketRailBottom", Vector3(width - 0.18, 0.022, 0.06),
		Vector3(0.0, strip_y - 0.175, 0.03), _mat_frame)


func _build_header() -> void:
	# ana pano / şalter kutusu (sol üst) — metal arka plaka üzerinde
	var header_position: Vector3 = Vector3(-0.50, 1.38, 0.03)
	_box("BreakerPlate", Vector3(0.56, 0.26, 0.018),
		header_position + Vector3(0.0, 0.0, 0.0), _mat_brushed)
	_box("BreakerBox", Vector3(0.44, 0.19, 0.075),
		header_position + Vector3(0.0, 0.0, 0.045), _mat_dark)
	_box("BreakerLip", Vector3(0.48, 0.024, 0.09),
		header_position + Vector3(0.0, 0.105, 0.045), _mat_frame)
	for i: int in 3:
		var lever_x: float = -0.105 + 0.105 * float(i)
		var lever: MeshInstance3D = _box("Lever%d" % i, Vector3(0.024, 0.07, 0.022),
			header_position + Vector3(lever_x, -0.015, 0.095), _mat_brushed)
		lever.rotation_degrees = Vector3(0.0, 0.0, -16.0 if i == 1 else 10.0)
		var knob: MeshInstance3D = MeshInstance3D.new()
		knob.name = "LeverKnob%d" % i
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.013
		sphere.height = 0.026
		sphere.radial_segments = 10
		sphere.rings = 5
		knob.mesh = sphere
		knob.position = header_position + Vector3(lever_x, 0.03, 0.11)
		knob.material_override = _emissive(NEON_AMBER if i != 2 else Color(1.0, 0.3, 0.28), 0.95)
		add_child(knob)
	# sigorta göstergeleri + acil stop
	for i: int in 3:
		_box("FuseSlot%d" % i, Vector3(0.05, 0.022, 0.012),
			header_position + Vector3(-0.105 + 0.105 * float(i), -0.062, 0.086),
			_emissive(NEON_CYAN, 0.6))
	var stop: MeshInstance3D = MeshInstance3D.new()
	stop.name = "EmergencyStop"
	var stop_mesh: CylinderMesh = CylinderMesh.new()
	stop_mesh.top_radius = 0.022
	stop_mesh.bottom_radius = 0.022
	stop_mesh.height = 0.026
	stop_mesh.radial_segments = 12
	stop_mesh.rings = 1
	stop.mesh = stop_mesh
	stop.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	stop.position = header_position + Vector3(0.17, -0.045, 0.09)
	stop.material_override = _emissive(Color(1.0, 0.28, 0.24), 0.95)
	add_child(stop)


func _build_work_zone() -> void:
	# düğüm alanı: ince gravür çerçeve + köşe braketleri (boş orta bölgeye yapı)
	var half: float = ZONE_HALF_WIDTH
	var top: float = _zone_top
	var bottom: float = _zone_bottom
	_box("ZoneTop", Vector3(half * 2.0, 0.006, 0.008),
		Vector3(0.0, top, 0.012), _mat_zone)
	_box("ZoneBottom", Vector3(half * 2.0, 0.006, 0.008),
		Vector3(0.0, bottom, 0.012), _mat_zone)
	_box("ZoneLeft", Vector3(0.006, top - bottom, 0.008),
		Vector3(-half, (top + bottom) * 0.5, 0.012), _mat_zone)
	_box("ZoneRight", Vector3(0.006, top - bottom, 0.008),
		Vector3(half, (top + bottom) * 0.5, 0.012), _mat_zone)
	# köşe kancaları
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var edge_y: float = top if sy > 0.0 else bottom
			_box("ZoneHookH", Vector3(0.10, 0.014, 0.012),
				Vector3(sx * (half - 0.05), edge_y, 0.014), _mat_brushed)
			_box("ZoneHookV", Vector3(0.014, 0.10, 0.012),
				Vector3(sx * (half - 0.05), edge_y - sy * 0.05, 0.014), _mat_brushed)
	# düğüm alanı etiketi (alt şeridin hemen üstünde, kabloların arkasında kalmaz)
	_label("DÜĞÜM ALANI", Vector3(0.0, bottom - 0.05, 0.02), 34, Color(0.35, 0.78, 0.70))


func _build_grid_overlay() -> void:
	var shader: Shader = load("res://assets/shaders/pano_grid.gdshader") as Shader
	if shader == null:
		return
	var quad: MeshInstance3D = MeshInstance3D.new()
	quad.name = "CircuitGrid"
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(width - 0.12, height - 0.12)
	quad.mesh = mesh
	quad.position = Vector3(0.0, 0.0, 0.006)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grid_intensity", 0.16)
	material.set_shader_parameter("trace_intensity", 0.45)
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)


func _build_underglow() -> void:
	var colors: Array[Color] = [NEON_CYAN, NEON_AMBER, NEON_CYAN]
	for i: int in colors.size():
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Underglow%d" % i
		light.position = Vector3(-0.62 + 0.62 * float(i), -height * 0.5 - 0.16, 0.24)
		light.light_color = colors[i]
		light.light_energy = 1.3
		light.omni_range = 1.15
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		add_child(light)
	for side: float in [-1.0, 1.0]:
		var accent: OmniLight3D = OmniLight3D.new()
		accent.name = "TopAccent"
		accent.position = Vector3(side * (width * 0.5 + 0.05), 0.3, 0.3)
		accent.light_color = NEON_AMBER if side > 0.0 else NEON_CYAN
		accent.light_energy = 0.7
		accent.omni_range = 1.1
		accent.shadow_enabled = false
		add_child(accent)


func _build_labels() -> void:
	_label("ANA PANO", Vector3(-0.50, 1.256, 0.06), 34, WARNING_YELLOW)
	_label("PRIZ ŞERİDİ", Vector3(0.0, -height * 0.5 + 0.115, 0.075), 36, NEON_CYAN)
	# sağ üstteki HUD göstergesiyle çakışmasın diye şalter kutusunun sağında
	_label("YÜKSEK GERİLİM", Vector3(0.02, 1.40, 0.05), 36, WARNING_YELLOW)


func _label(text: String, label_position: Vector3, size: int, color: Color,
		rotation_z: float = 0.0) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = size
	# 540 px genişlikte okunabilirlik için ~0.06 m harf yüksekliği
	label.pixel_size = 0.00175
	label.position = label_position
	label.rotation_degrees = Vector3(0.0, 0.0, rotation_z)
	label.modulate = color
	label.shaded = false
	label.double_sided = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)


func _bolt(bolt_position: Vector3) -> void:
	var bolt: MeshInstance3D = MeshInstance3D.new()
	bolt.name = "Bolt"
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.014
	cylinder.bottom_radius = 0.014
	cylinder.height = 0.014
	cylinder.radial_segments = 8
	cylinder.rings = 1
	bolt.mesh = cylinder
	bolt.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bolt.position = bolt_position
	bolt.material_override = _mat_brushed
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt)


func _box(node_name: String, size: Vector3, box_position: Vector3,
		material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = box_position
	if material != null:
		instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _plain(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color * 0.35
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.roughness = 0.3
	return material


func _make_stripe_texture() -> ImageTexture:
	var image: Image = Image.create(64, 16, false, Image.FORMAT_RGB8)
	for y: int in 16:
		for x: int in 64:
			var band: int = int(floor(float(x + y) / 10.0)) % 2
			image.set_pixel(x, y, WARNING_YELLOW if band == 0 else WARNING_BLACK)
	return ImageTexture.create_from_image(image)
