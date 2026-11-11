class_name BoardBuilder
extends Node3D

## Koyu endüstriyel pano (1.7 x 3.1 m) — tamamen kodla üretilir, .tscn minimal.
## Koordinat: pano düzlemi XY, ön yüz z=0, kamera +Z'den bakar.
##
## v0.2 optimizasyonu (ARCHITECTURE §14): TÜM statik parçalar iki vertex-renkli
## batch mesh'te toplanır:
##   * BatchMatte — gövde/çerçeve/cıvata/kelepçe yuvaları (assets/shaders/batched_matte)
##   * BatchNeon  — sigorta göstergeleri, neon kelepçe halkaları, göstergeler
## Böylece eskiden ~27 MeshInstance3D (27 draw call) olan pano ~10 draw call'a iner:
## 2 batch + 2 uyarı şeridi + devre ızgarası + 4 Label3D + toz partikülü.
## Gölge yok. Işıklar nefes alır (ASMR §16), toz partikülü vardır.
##
## Blackout modifier API'si (ARCHITECTURE §12): set_blackout(amount) — ışıkları,
## neon emission'ı ve etiketleri yumuşakça kısar; drag engellenmez.

const DEFAULT_WIDTH: float = 1.7
const DEFAULT_HEIGHT: float = 3.1
const BOARD_DEPTH: float = 0.14
const FRAME_WIDTH: float = 0.09
const WARNING_YELLOW: Color = Color(0.82, 0.62, 0.16)
const WARNING_BLACK: Color = Color(0.05, 0.05, 0.06)
const NEON_CYAN: Color = Color(0.20, 0.91, 0.77)
const NEON_AMBER: Color = Color(1.0, 0.72, 0.22)
const NEON_RED: Color = Color(1.0, 0.30, 0.28)
const ZONE_TOP_DEFAULT: float = 0.68
const ZONE_BOTTOM_DEFAULT: float = -0.55
const ZONE_HALF_WIDTH: float = 0.73

## Matte parça renkleri + vertex-alpha ile taşınan metallic değerleri.
const COLOR_PANEL: Color = Color(0.075, 0.086, 0.105)
const COLOR_FRAME: Color = Color(0.175, 0.185, 0.205)
const COLOR_DARK: Color = Color(0.075, 0.085, 0.105)
const COLOR_BRUSHED: Color = Color(0.33, 0.355, 0.40)
const METALLIC_PANEL: float = 0.20
const METALLIC_FRAME: float = 0.80
const METALLIC_DARK: float = 0.60
const METALLIC_BRUSHED: float = 0.90
## Neon batch emission enerjisi (glow eşiği 1.1'in altında tutulur ki beyaza yıkanmasın).
const NEON_EMISSION: float = 0.85

## ASMR: pano ışıkları nefes alır (period >= 2 sn; yumuşak, düşük kontrast).
const BREATH_PERIOD: float = 6.5
const BREATH_DEPTH: float = 0.16
## Blackout geçiş süresi: ışık sıçraması yok, yumuşak sönme/yanma.
const BLACKOUT_SECONDS: float = 0.9
const BLACKOUT_LIGHT_FLOOR: float = 0.10
const BLACKOUT_EMISSIVE_FLOOR: float = 0.16
const BLACKOUT_LABEL_FLOOR: float = 0.22
## Toz partikülleri: 40-60 parça, yavaş ve döngüsel (§16 "toz partikülleri").
const DUST_AMOUNT: int = 48
const DUST_LIFETIME: float = 11.0
const DUST_QUAD_SIZE: float = 0.014

## 3D voltmetre HUD'daki 2D göstergeyle çakıştığı için panodan kaldırıldı
## (Lead kararı). Sınıf duruyor; istenirse küçük gösterge olarak geri takılır.
var voltmeter: Voltmeter = null

var width: float = DEFAULT_WIDTH
var height: float = DEFAULT_HEIGHT
var surface_z: float = 0.055

var _built: bool = false
var _font: Font = null
var _stripe_texture: ImageTexture = null

var _matte_ops: Array[Dictionary] = []
var _neon_ops: Array[Dictionary] = []
var _matte_mesh: MeshInstance3D = null
var _neon_mesh: MeshInstance3D = null
var _matte_material: ShaderMaterial = null
var _neon_material: ShaderMaterial = null
var _grid_material: ShaderMaterial = null

var _lights: Array[OmniLight3D] = []
var _light_base_energy: PackedFloat32Array = PackedFloat32Array()
var _labels: Array[Label3D] = []
var _label_base_colors: Array[Color] = []
var _dust: GPUParticles3D = null

var _zone_top: float = ZONE_TOP_DEFAULT + 0.08
var _zone_bottom: float = ZONE_BOTTOM_DEFAULT - 0.34
var _time: float = 0.0
var _blackout: float = 0.0
var _blackout_target: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	var previous_blackout: float = _blackout
	_blackout = move_toward(_blackout, _blackout_target, delta / BLACKOUT_SECONDS)
	var light_scale: float = lerpf(1.0, BLACKOUT_LIGHT_FLOOR, _blackout)
	for i: int in _lights.size():
		var light: OmniLight3D = _lights[i]
		var breath: float = 1.0 + sin(
			TAU * _time / BREATH_PERIOD + float(i) * 1.7) * BREATH_DEPTH
		light.light_energy = _light_base_energy[i] * breath * light_scale
	if _neon_material != null:
		var neon_breath: float = 1.0 + sin(
			TAU * _time / (BREATH_PERIOD * 1.35)) * BREATH_DEPTH * 0.5
		_neon_material.set_shader_parameter("emission_energy",
			NEON_EMISSION * neon_breath * lerpf(1.0, BLACKOUT_EMISSIVE_FLOOR, _blackout))
	if _grid_material != null:
		var grid_scale: float = lerpf(1.0, BLACKOUT_EMISSIVE_FLOOR, _blackout)
		_grid_material.set_shader_parameter("grid_intensity", 0.16 * grid_scale)
		_grid_material.set_shader_parameter("trace_intensity", 0.45 * grid_scale)
	if _dust != null and absf(previous_blackout - _blackout) > 0.001:
		_dust.amount_ratio = clampf(1.0 - 0.55 * _blackout, 0.2, 1.0)
	var label_scale: float = lerpf(1.0, BLACKOUT_LABEL_FLOOR, _blackout)
	for i: int in _labels.size():
		var base: Color = _label_base_colors[i]
		_labels[i].modulate = Color(
			base.r * label_scale, base.g * label_scale, base.b * label_scale, base.a)


## Blackout modifier (ARCHITECTURE §12): 0 = normal, 1 = karanlık.
## Geçiş BLACKOUT_SECONDS içinde yumuşakça lerp edilir; drag engellenmez.
func set_blackout(amount: float) -> void:
	_blackout_target = clampf(amount, 0.0, 1.0)


func blackout_amount() -> float:
	return _blackout


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
	_font = load("res://assets/fonts/Manrope.ttf") as Font
	if _font == null:
		_font = load("res://assets/fonts/Baloo2.ttf") as Font
	_build_materials()
	_build_body()
	_build_frame()
	_build_warning_stripes()
	_build_socket_strip()
	_build_header()
	_build_work_zone()
	_build_grid_overlay()
	_build_underglow()
	_build_labels()
	_build_dust()
	_flush_matte()
	_flush_neon()
	set_process(true)


## Bölümdeki her kablo kaynağı için renkli kelepçe halkası.
## build() sonrası çağrılır: yalnızca neon batch mesh'i tazelenir.
func add_source_clamp(source_position: Vector3, color: Color, voltage: int) -> void:
	_dark_box(Vector3(0.10, 0.14, 0.05), source_position + Vector3(0.0, 0.0, 0.03))
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.030
	ring.outer_radius = 0.045
	ring.rings = 14
	ring.ring_segments = 6
	_add_neon(ring, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)),
		source_position + Vector3(0.0, 0.0, 0.055)), color)
	# Gerilim işareti: halkayla aynı neon batch'te (draw call bütçesi).
	_add_neon(_box_mesh(Vector3(0.07, 0.008, 0.01)),
		_xform(source_position + Vector3(0.0, -0.088, 0.056)), color)
	_flush_neon()


func board_bounds() -> Rect2:
	return Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height))


# --- iskelet --------------------------------------------------------------

func _build_body() -> void:
	_add_matte(_box_mesh(Vector3(width, height, BOARD_DEPTH)),
		_xform(Vector3(0.0, 0.0, -BOARD_DEPTH * 0.5)), COLOR_PANEL, METALLIC_PANEL)
	for side: float in [-1.0, 1.0]:
		_frame_box(Vector3(width - 0.01, 0.028, 0.02),
			Vector3(0.0, side * (height * 0.5 - 0.014), 0.004))
		_frame_box(Vector3(0.028, height - 0.01, 0.02),
			Vector3(side * (width * 0.5 - 0.014), 0.0, 0.004))
	# Köşe plakaları 45 derece döner: batch'e dönüşüm pişirilerek girer.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_brushed_box(Vector3(0.062, 0.062, 0.016),
				Vector3(sx * (width * 0.5 - 0.085), sy * (height * 0.5 - 0.085), 0.008),
				Vector3(0.0, 0.0, 45.0))
			_bolt(Vector3(sx * (width * 0.5 - 0.085), sy * (height * 0.5 - 0.085), 0.02))
	for sx: float in [-1.0, 1.0]:
		_bolt(Vector3(sx * (width * 0.5 - 0.045), 0.0, 0.02))


func _build_frame() -> void:
	var depth: float = BOARD_DEPTH + 0.035
	_frame_box(Vector3(width + FRAME_WIDTH * 2.0, FRAME_WIDTH, depth),
		Vector3(0.0, height * 0.5 + FRAME_WIDTH * 0.5, -0.004))
	_frame_box(Vector3(width + FRAME_WIDTH * 2.0, FRAME_WIDTH, depth),
		Vector3(0.0, -height * 0.5 - FRAME_WIDTH * 0.5, -0.004))
	_frame_box(Vector3(FRAME_WIDTH, height, depth),
		Vector3(-width * 0.5 - FRAME_WIDTH * 0.5, 0.0, -0.004))
	_frame_box(Vector3(FRAME_WIDTH, height, depth),
		Vector3(width * 0.5 + FRAME_WIDTH * 0.5, 0.0, -0.004))


## Uyarı şeritleri dokulu: kendi birleşik mesh'i (UV korunur), 2 draw call.
func _build_warning_stripes() -> void:
	if _stripe_texture == null:
		_stripe_texture = _make_stripe_texture()
	var horizontal_ops: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		horizontal_ops.append({"mesh": _box_mesh(Vector3(width - 0.02, 0.046, 0.024)),
			"xform": _xform(Vector3(0.0, side * (height * 0.5 - 0.04), 0.012))})
	var horizontal: MeshInstance3D = _textured_instance("WarningStripesH", horizontal_ops,
		_stripe_material(10.0, 1.0))
	add_child(horizontal)
	var vertical_ops: Array[Dictionary] = []
	for side: float in [-1.0, 1.0]:
		vertical_ops.append({"mesh": _box_mesh(Vector3(0.048, 2.05, 0.022)),
			"xform": _xform(Vector3(side * (width * 0.5 - 0.038), 0.06, 0.012))})
	var vertical: MeshInstance3D = _textured_instance("WarningStripesV", vertical_ops,
		_stripe_material(1.4, 11.0))
	add_child(vertical)


func _build_socket_strip() -> void:
	var strip_y: float = -height * 0.5 + 0.33
	_dark_box(Vector3(width - 0.20, 0.34, 0.06), Vector3(0.0, strip_y, 0.03))
	_brushed_box(Vector3(width - 0.18, 0.032, 0.075),
		Vector3(0.0, strip_y + 0.175, 0.035))
	_frame_box(Vector3(width - 0.18, 0.022, 0.06),
		Vector3(0.0, strip_y - 0.175, 0.03))


func _build_header() -> void:
	# ana pano / şalter kutusu (sol üst) — metal arka plaka üzerinde
	var header_position: Vector3 = Vector3(-0.50, 1.38, 0.03)
	_brushed_box(Vector3(0.56, 0.26, 0.018), header_position)
	_dark_box(Vector3(0.44, 0.19, 0.075), header_position + Vector3(0.0, 0.0, 0.045))
	_frame_box(Vector3(0.48, 0.024, 0.09), header_position + Vector3(0.0, 0.105, 0.045))
	for i: int in 3:
		var lever_x: float = -0.105 + 0.105 * float(i)
		var lever_rotation: float = -16.0 if i == 1 else 10.0
		_brushed_box(Vector3(0.024, 0.07, 0.022),
			header_position + Vector3(lever_x, -0.015, 0.095),
			Vector3(0.0, 0.0, lever_rotation))
		_neon_sphere(0.013, header_position + Vector3(lever_x, 0.03, 0.11),
			NEON_AMBER if i != 2 else NEON_RED)
	# sigorta göstergeleri + acil stop
	for i: int in 3:
		_neon_box(Vector3(0.05, 0.022, 0.012),
			header_position + Vector3(-0.105 + 0.105 * float(i), -0.062, 0.086),
			NEON_CYAN)
	var stop: CylinderMesh = CylinderMesh.new()
	stop.top_radius = 0.022
	stop.bottom_radius = 0.022
	stop.height = 0.026
	stop.radial_segments = 12
	stop.rings = 1
	_add_neon(stop, _xform(header_position + Vector3(0.17, -0.045, 0.09),
		Vector3(90.0, 0.0, 0.0)), NEON_RED)


func _build_work_zone() -> void:
	var half: float = ZONE_HALF_WIDTH
	var top: float = _zone_top
	var bottom: float = _zone_bottom
	_neon_box(Vector3(half * 2.0, 0.006, 0.008), Vector3(0.0, top, 0.012),
		Color(0.20, 0.55, 0.50))
	_neon_box(Vector3(half * 2.0, 0.006, 0.008), Vector3(0.0, bottom, 0.012),
		Color(0.20, 0.55, 0.50))
	_neon_box(Vector3(0.006, top - bottom, 0.008),
		Vector3(-half, (top + bottom) * 0.5, 0.012), Color(0.20, 0.55, 0.50))
	_neon_box(Vector3(0.006, top - bottom, 0.008),
		Vector3(half, (top + bottom) * 0.5, 0.012), Color(0.20, 0.55, 0.50))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var edge_y: float = top if sy > 0.0 else bottom
			_brushed_box(Vector3(0.10, 0.014, 0.012),
				Vector3(sx * (half - 0.05), edge_y, 0.014))
			_brushed_box(Vector3(0.014, 0.10, 0.012),
				Vector3(sx * (half - 0.05), edge_y - sy * 0.05, 0.014))
	_label(Loc.t("board.work_zone"), Vector3(0.0, bottom + 0.05, 0.13), 30,
		Color(0.48, 0.94, 0.86))


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
	_grid_material = ShaderMaterial.new()
	_grid_material.shader = shader
	_grid_material.set_shader_parameter("grid_intensity", 0.16)
	_grid_material.set_shader_parameter("trace_intensity", 0.45)
	quad.material_override = _grid_material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)


func _build_underglow() -> void:
	# 2 alt + 1 yan accent: mobilde ışık başına maliyet düşük tutulur.
	var underglow_positions: Array[Vector3] = [
		Vector3(-0.48, -height * 0.5 - 0.14, 0.26),
		Vector3(0.56, -height * 0.5 - 0.14, 0.26),
	]
	var underglow_colors: Array[Color] = [NEON_AMBER, NEON_CYAN]
	for i: int in underglow_positions.size():
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Underglow%d" % i
		light.position = underglow_positions[i]
		light.light_color = underglow_colors[i]
		light.light_energy = 0.95
		light.omni_range = 1.15
		light.omni_attenuation = 1.6
		light.shadow_enabled = false
		add_child(light)
		_register_light(light, 0.95)
	var accent: OmniLight3D = OmniLight3D.new()
	accent.name = "TopAccent"
	accent.position = Vector3(-(width * 0.5 + 0.05), 0.3, 0.3)
	accent.light_color = NEON_CYAN
	accent.light_energy = 0.55
	accent.omni_range = 1.1
	accent.shadow_enabled = false
	add_child(accent)
	_register_light(accent, 0.55)


func _build_labels() -> void:
	# Etiketler kabloların/fişlerin ÜSTÜNDE okunur (no_depth_test): pano yazıları
	# kabloların arkasında kaybolmaz (signal-qa/Lead görsel QA geri bildirimi).
	# "ANA PANEL": şalter kutusunun arkasında kalmasın diye bloğun sağına taşındı.
	_label(Loc.t("board.main_panel"), Vector3(-0.10, 1.29, 0.13), 30,
		Color(1.0, 0.84, 0.40))
	# "PRIZ ŞERİDİ": şeridin hemen üstünde, kablo uçlarının üstünde okunur.
	_label(Loc.t("board.socket_strip"), Vector3(0.0, -0.99, 0.13), 28,
		Color(0.48, 0.94, 0.86))
	# sağ üstteki HUD göstergesiyle çakışmasın diye şalter kutusunun sağında
	_label(Loc.t("board.high_voltage"), Vector3(0.44, 1.40, 0.13), 30,
		Color(1.0, 0.84, 0.40))


## Yavaş toz partikülleri: pano önünde asılı, ışıkta parlayan toz (ASMR §16).
func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "Dust"
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = DUST_LIFETIME
	_dust.preprocess = DUST_LIFETIME * 0.5
	_dust.one_shot = false
	_dust.local_coords = false
	_dust.fixed_fps = 30
	_dust.visibility_aabb = AABB(Vector3(-1.2, -1.9, -0.2), Vector3(2.4, 3.8, 1.2))
	_dust.position = Vector3(0.0, 0.0, 0.28)
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(width * 0.42, height * 0.46, 0.30)
	process_material.direction = Vector3(0.35, 1.0, 0.1)
	process_material.spread = 55.0
	process_material.initial_velocity_min = 0.008
	process_material.initial_velocity_max = 0.030
	process_material.gravity = Vector3(0.004, 0.008, 0.0)
	process_material.damping_min = 0.004
	process_material.damping_max = 0.010
	process_material.scale_min = 0.5
	process_material.scale_max = 1.6
	process_material.color = Color(1.0, 0.93, 0.80, 0.30)
	_dust.process_material = process_material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(DUST_QUAD_SIZE, DUST_QUAD_SIZE)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	quad.material = material
	_dust.draw_pass_1 = quad
	add_child(_dust)
	_dust.emitting = true


# --- malzemeler -----------------------------------------------------------

func _build_materials() -> void:
	_matte_material = _shader_material("res://assets/shaders/batched_matte.gdshader")
	if _matte_material != null:
		_matte_material.set_shader_parameter("roughness", 0.42)
		_matte_material.set_shader_parameter("metallic_scale", 1.0)
	_neon_material = _shader_material("res://assets/shaders/batched_neon.gdshader")
	if _neon_material != null:
		_neon_material.set_shader_parameter("albedo_scale", 0.35)
		_neon_material.set_shader_parameter("emission_energy", NEON_EMISSION)


func _shader_material(path: String) -> ShaderMaterial:
	var shader: Shader = load(path) as Shader
	if shader == null:
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


func _stripe_material(uv_x: float, uv_y: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = _stripe_texture
	material.uv1_scale = Vector3(uv_x, uv_y, 1.0)
	material.roughness = 0.72
	material.metallic = 0.05
	return material


func _make_stripe_texture() -> ImageTexture:
	var image: Image = Image.create(64, 16, false, Image.FORMAT_RGB8)
	for y: int in 16:
		for x: int in 64:
			var band: int = int(floor(float(x + y) / 10.0)) % 2
			image.set_pixel(x, y, WARNING_YELLOW if band == 0 else WARNING_BLACK)
	return ImageTexture.create_from_image(image)


# --- batch altyapısı ------------------------------------------------------

func _add_matte(mesh: PrimitiveMesh, xform: Transform3D, base_color: Color,
		metallic: float) -> void:
	var color: Color = base_color.srgb_to_linear()
	color.a = clampf(metallic, 0.0, 1.0)
	_matte_ops.append({"mesh": mesh, "xform": xform, "color": color})


func _add_neon(mesh: PrimitiveMesh, xform: Transform3D, neon_color: Color) -> void:
	var color: Color = neon_color.srgb_to_linear()
	color.a = 1.0
	_neon_ops.append({"mesh": mesh, "xform": xform, "color": color})


func _flush_matte() -> void:
	if _matte_mesh == null:
		_matte_mesh = MeshInstance3D.new()
		_matte_mesh.name = "BatchMatte"
		_matte_mesh.material_override = _matte_material
		_matte_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_matte_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_matte_mesh)
	_matte_mesh.mesh = _merged_colored_mesh(_matte_ops)


func _flush_neon() -> void:
	if _neon_mesh == null:
		_neon_mesh = MeshInstance3D.new()
		_neon_mesh.name = "BatchNeon"
		_neon_mesh.material_override = _neon_material
		_neon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_neon_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(_neon_mesh)
	_neon_mesh.mesh = _merged_colored_mesh(_neon_ops)


## Vertex-renkli birleşik mesh: tüm parçalar tek yüzeyde, tek material.
func _merged_colored_mesh(ops: Array[Dictionary]) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var offset: int = 0
	for op: Dictionary in ops:
		var mesh: PrimitiveMesh = op["mesh"] as PrimitiveMesh
		if mesh == null:
			continue
		var xform: Transform3D = op["xform"] as Transform3D
		var color: Color = op["color"] as Color
		var arrays: Array = mesh.get_mesh_arrays()
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		for i: int in source_vertices.size():
			vertices.append(xform * source_vertices[i])
			if i < source_normals.size():
				normals.append((xform.basis * source_normals[i]).normalized())
			else:
				normals.append(Vector3.UP)
			colors.append(color)
		if source_indices.is_empty():
			for i: int in source_vertices.size():
				indices.append(offset + i)
		else:
			for index: int in source_indices:
				indices.append(offset + index)
		offset += source_vertices.size()
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = vertices
	arrays_out[Mesh.ARRAY_NORMAL] = normals
	arrays_out[Mesh.ARRAY_COLOR] = colors
	arrays_out[Mesh.ARRAY_INDEX] = indices
	var mesh_out: ArrayMesh = ArrayMesh.new()
	mesh_out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
	return mesh_out


## Dokulu (UV'li) birleşik mesh: uyarı şeritleri.
func _textured_instance(node_name: String, ops: Array[Dictionary],
		material: Material) -> MeshInstance3D:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for op: Dictionary in ops:
		tool.append_from(op["mesh"] as Mesh, 0, op["xform"] as Transform3D)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit() as ArrayMesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


# --- geometri yardımcıları ------------------------------------------------

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder_mesh(radius: float, cylinder_height: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = cylinder_height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _xform(position: Vector3, rotation_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	var basis: Basis = Basis.from_euler(rotation_deg * (PI / 180.0))
	return Transform3D(basis, position)


func _frame_box(size: Vector3, position: Vector3,
		rotation_deg: Vector3 = Vector3.ZERO) -> void:
	_add_matte(_box_mesh(size), _xform(position, rotation_deg), COLOR_FRAME, METALLIC_FRAME)


func _dark_box(size: Vector3, position: Vector3,
		rotation_deg: Vector3 = Vector3.ZERO) -> void:
	_add_matte(_box_mesh(size), _xform(position, rotation_deg), COLOR_DARK, METALLIC_DARK)


func _brushed_box(size: Vector3, position: Vector3,
		rotation_deg: Vector3 = Vector3.ZERO) -> void:
	_add_matte(_box_mesh(size), _xform(position, rotation_deg), COLOR_BRUSHED,
		METALLIC_BRUSHED)


func _neon_box(size: Vector3, position: Vector3, neon_color: Color,
		rotation_deg: Vector3 = Vector3.ZERO) -> void:
	_add_neon(_box_mesh(size), _xform(position, rotation_deg), neon_color)


func _neon_sphere(radius: float, position: Vector3, neon_color: Color) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	_add_neon(sphere, Transform3D(Basis.IDENTITY, position), neon_color)


func _bolt(bolt_position: Vector3) -> void:
	_add_matte(_cylinder_mesh(0.014, 0.014, 8),
		_xform(bolt_position, Vector3(90.0, 0.0, 0.0)), COLOR_BRUSHED, METALLIC_BRUSHED)


# --- etiketler / ışıklar --------------------------------------------------

func _label(text: String, label_position: Vector3, size: int, color: Color,
		rotation_z: float = 0.0) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = size
	# 540 px genişlikte okunabilirlik: ~0.08 m harf yüksekliği (16-18 px).
	label.pixel_size = 0.0026
	label.position = label_position
	label.rotation_degrees = Vector3(0.0, 0.0, rotation_z)
	# Koyu kontur: parlak kablo/fişlerin önünde bile okunur kalır.
	label.outline_size = 9
	label.outline_modulate = Color(0.02, 0.02, 0.03, 0.9)
	label.modulate = color
	label.shaded = false
	label.double_sided = true
	# Pano etiketi hiçbir kablo/fiş arkasında kapanmasın (en son çizilir).
	label.no_depth_test = true
	label.render_priority = 12
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	_labels.append(label)
	_label_base_colors.append(color)


func _register_light(light: OmniLight3D, base_energy: float) -> void:
	_lights.append(light)
	_light_base_energy.append(base_energy)
