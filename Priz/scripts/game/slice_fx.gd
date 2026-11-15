class_name SliceFx
extends Node3D
## Kesitin anlık efektleri — hepsi seviye yüklenirken bir kez kurulur ve ısıtılır (takma anında
## takılma olmasın): priz haleleri (sürüklemede uygun prizler hat renginde atar), oturma tozu,
## oturma halkası (parlayan genişleyen halka) ve ipucu halkası.

const HALO_SIZE: float = 0.62
const DUST_AMOUNT: int = 22

var _halos: Dictionary = {}        # oda prizi -> MeshInstance3D
var _halo_target: Dictionary = {}  # oda prizi -> 0..1 (görünürlük hedefi)
var _halo_value: Dictionary = {}
var _halo_color: Dictionary = {}
var _dust: CPUParticles3D
var _sparks: CPUParticles3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_t: float = 1.0
var _time: float = 0.0
var _soft_tex: GradientTexture2D


func _ready() -> void:
	_soft_tex = _radial_texture()
	_build_dust()
	_build_ring()


## Her oda prizi için bir hale (ışıltı) yaratır.
func add_halo(socket_name: String, socket: Node3D, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Halo_%s" % socket_name
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(HALO_SIZE, HALO_SIZE)
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.albedo_texture = _soft_tex
	mat.albedo_color = Color(color, 0.0)
	mat.render_priority = 2
	mi.material_override = mat
	add_child(mi)
	mi.global_position = socket.global_position + socket.global_basis.z * 0.05
	_halos[socket_name] = mi
	_halo_target[socket_name] = 0.0
	_halo_value[socket_name] = 0.0
	_halo_color[socket_name] = color


## v: 0 kapalı, 1 "takılabilir" atışı, 2 "fiş yakında" (daha parlak).
func set_halo(socket_name: String, v: float) -> void:
	if _halo_target.has(socket_name):
		_halo_target[socket_name] = v


func clear_halos() -> void:
	for k: Variant in _halo_target.keys():
		_halo_target[k] = 0.0


func halo_value(socket_name: String) -> float:
	return float(_halo_target.get(socket_name, 0.0))


## Oturma anı: toz bulutu + kıvılcım + genişleyen halka (`normal` duvardan dışarı).
func seat_burst(pos: Vector3, normal: Vector3, color: Color) -> void:
	_dust.global_position = pos + normal * 0.04
	_dust.direction = Vector3(0.0, 0.0, 1.0)
	_dust.global_basis = Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT)
	_dust.restart()
	_sparks.global_transform = _dust.global_transform
	_sparks.color = color.lightened(0.45)
	_sparks.restart()
	_ring.global_position = pos + normal * 0.05
	_ring_mat.albedo_color = Color(color.lightened(0.3), 1.0)
	_ring_t = 0.0
	_ring.visible = true


## Isıtma: tüm efektler bir kez görünmeden çizilir (gölgelendirici derlemesi yükleme anına düşsün).
func prewarm(pos: Vector3) -> void:
	seat_burst(pos, Vector3.BACK, Color.WHITE)
	for k: Variant in _halos.keys():
		var mi: MeshInstance3D = _halos[k] as MeshInstance3D
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.02


func _process(delta: float) -> void:
	_time += delta
	for k: Variant in _halos.keys():
		var target: float = float(_halo_target[k])
		var v: float = lerpf(float(_halo_value[k]), target, 1.0 - exp(-12.0 * delta))
		_halo_value[k] = v
		var mi: MeshInstance3D = _halos[k] as MeshInstance3D
		var pulse: float = 0.75 + 0.25 * sin(_time * 6.5)
		var a: float = clampf(v, 0.0, 2.0) * 0.55 * pulse
		var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
		mat.albedo_color = Color(_halo_color[k] as Color, minf(a, 1.0))
		var s: float = 0.85 + 0.25 * v + 0.08 * sin(_time * 6.5)
		mi.scale = Vector3.ONE * s
		mi.visible = a > 0.003
	if _ring_t < 1.0:
		_ring_t = minf(1.0, _ring_t + delta / 0.42)
		var e: float = 1.0 - pow(1.0 - _ring_t, 3.0)
		_ring.scale = Vector3.ONE * lerpf(0.2, 1.6, e)
		_ring_mat.albedo_color.a = (1.0 - _ring_t) * 0.9
		_ring.visible = _ring_t < 1.0


func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "SeatDust"
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = 0.75
	_dust.explosiveness = 0.95
	_dust.spread = 70.0
	_dust.initial_velocity_min = 0.35
	_dust.initial_velocity_max = 0.9
	_dust.gravity = Vector3(0.0, -0.9, 0.0)
	_dust.damping_min = 1.6
	_dust.damping_max = 2.4
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.4
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_dust.scale_amount_curve = curve
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 0.96, 0.88, 0.75))
	grad.set_color(1, Color(0.9, 0.86, 0.8, 0.0))
	_dust.color_ramp = grad
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_tex
	quad.material = mat
	_dust.mesh = quad
	add_child(_dust)
	_sparks = _dust.duplicate() as CPUParticles3D
	_sparks.name = "SeatSparks"
	_sparks.amount = 10
	_sparks.lifetime = 0.35
	_sparks.initial_velocity_min = 1.2
	_sparks.initial_velocity_max = 2.4
	_sparks.spread = 55.0
	_sparks.gravity = Vector3(0.0, -4.0, 0.0)
	_sparks.color_ramp = null
	var smesh: QuadMesh = QuadMesh.new()
	smesh.size = Vector2(0.03, 0.03)
	var smat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smesh.material = smat
	_sparks.mesh = smesh
	add_child(_sparks)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "SeatRing"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	_ring.mesh = quad
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_ring_mat.no_depth_test = true
	_ring_mat.render_priority = 3
	_ring_mat.albedo_texture = _ring_texture()
	_ring.material_override = _ring_mat
	_ring.visible = false
	add_child(_ring)


static func _radial_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


static func _ring_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t
