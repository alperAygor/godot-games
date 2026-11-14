extends Node3D
## 3B toplanabilir: dönen halka + çekirdek. Mıknatıs menzilinde oyuncuya doğru çekilir.

const COLORS := {
	"heal": Color(0.35, 1.0, 0.62),
	"overdrive": Color(1.0, 0.85, 0.25),
	"shield": Color(0.45, 0.72, 1.0),
}

static var _ring_mesh: TorusMesh
static var _core_mesh: SphereMesh
static var _mats: Dictionary = {}

var kind := "heal"
var pos2 := Vector2.ZERO
var life := 14.0
var _t := 0.0
var _model: Node3D
var _pull := 0.0

func setup(kind_name: String, at: Vector2) -> void:
	kind = kind_name
	pos2 = at
	_t = randf() * TAU
	position = ArenaSpace.to_world(pos2, 1.0)

static func _mat(c: Color, energy: float) -> StandardMaterial3D:
	var key := c.to_html() + str(energy)
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(c.r * energy, c.g * energy, c.b * energy)
		_mats[key] = mat
	return _mats[key]

func _ready() -> void:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.27
		_ring_mesh.outer_radius = 0.37
		_ring_mesh.rings = 20
		_ring_mesh.ring_segments = 6
		_core_mesh = SphereMesh.new()
		_core_mesh.radius = 0.16
		_core_mesh.height = 0.32
		_core_mesh.radial_segments = 10
		_core_mesh.rings = 5
	_model = Node3D.new()
	add_child(_model)
	var c := color()
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = _mat(c, 2.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(ring)
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.material_override = _mat(Color(1, 1, 1) if kind != "heal" else c, 2.6)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(core)
	if kind == "shield":
		var second := MeshInstance3D.new()
		second.mesh = _ring_mesh
		second.rotation.x = PI * 0.5
		second.material_override = _mat(c, 2.2)
		second.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_model.add_child(second)

func color() -> Color:
	return COLORS.get(kind, Color.WHITE)

func tick(delta: float, target := Vector2.ZERO, pull_radius := 0.0) -> bool:
	_t += delta
	life -= delta
	var dist := pos2.distance_to(target)
	if pull_radius > 0.0 and dist < pull_radius:
		_pull = minf(1.0, _pull + delta * 3.0)
		pos2 = pos2.move_toward(target, (260.0 + 900.0 * _pull) * delta)
	position = ArenaSpace.to_world(pos2, 1.0 + sin(_t * 2.4) * 0.12)
	_model.rotation.y = _t * 1.8
	_model.rotation.x = sin(_t * 1.3) * 0.35
	var pop := minf(1.0, (14.0 - life) * 5.0)
	_model.scale = Vector3.ONE * (0.2 + 0.8 * pop) * (1.0 + 0.08 * sin(_t * 6.0))
	visible = life > 3.0 or int(life * 8.0) % 2 == 0
	return life > 0.0
