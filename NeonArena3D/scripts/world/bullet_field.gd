extends Node3D
## Tüm mermiler: veri nesneleri + tek MultiMesh. Düğüm başına mermi yok, tek çizim çağrısı.

class Bullet extends RefCounted:
	var pos2 := Vector2.ZERO
	var velocity2 := Vector2.ZERO
	var damage := 10.0
	var radius := 4.0
	var friendly := true
	var life := 1.0
	var pierce := 0
	var crit := false
	var dead := false
	var size := 1.0
	var color := Color.WHITE
	var hits: Array = []
	var chain := 0
	## 0 atış, 1 saçma, 2 raylı, 3 roket
	var style := 0
	var homing := 0.0
	var blast := 0.0
	var accel := 0.0
	var max_speed := 0.0
	var target: Object = null
	var retarget := 0.0

const MAX := 520
const STYLE_BLASTER := 0
const STYLE_PELLET := 1
const STYLE_RAIL := 2
const STYLE_ROCKET := 3
const HEIGHT := 1.05
const FRIENDLY := Color(0.4, 0.92, 1.0)
const CRIT := Color(1.0, 0.82, 0.3)
const HOSTILE := Color(1.0, 0.25, 0.55)

var bullets: Array[Bullet] = []
var _mm: MultiMesh

func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/bullet.gdshader")
	sphere.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = sphere
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-120, -5, -120), Vector3(240, 30, 240))
	add_child(node)

func spawn(from: Vector2, dir: Vector2, speed: float, is_friendly: bool, dmg: float, lifetime: float, size_mult := 1.0, is_crit := false, tint := Color(0, 0, 0, 0)) -> Bullet:
	var b := Bullet.new()
	b.pos2 = from
	b.velocity2 = dir.normalized() * speed
	b.damage = dmg
	b.life = lifetime
	b.friendly = is_friendly
	b.crit = is_crit
	b.size = size_mult
	b.radius = (3.6 if is_friendly else 5.2) * (0.6 + 0.4 * size_mult)
	if tint.a > 0.0:
		b.color = tint
	elif is_friendly:
		b.color = CRIT if is_crit else FRIENDLY
	else:
		b.color = HOSTILE
	if bullets.size() < MAX:
		bullets.append(b)
	else:
		b.dead = true
	return b

func tick(delta: float) -> void:
	var i := bullets.size() - 1
	while i >= 0:
		var b := bullets[i]
		if not b.dead:
			if b.accel > 0.0:
				var spd := b.velocity2.length()
				if spd < b.max_speed:
					b.velocity2 = b.velocity2 / maxf(spd, 0.001) * minf(b.max_speed, spd + b.accel * delta)
			b.pos2 += b.velocity2 * delta
			b.life -= delta
			if b.life <= 0.0:
				b.dead = true
		if b.dead:
			bullets[i] = bullets[bullets.size() - 1]
			bullets.pop_back()
		i -= 1

func render(vfx: Node3D, time: float) -> void:
	var n := 0
	for b in bullets:
		if b.dead or n >= MAX:
			continue
		var speed := b.velocity2.length()
		var fwd := Vector3(b.velocity2.x, 0.0, b.velocity2.y) / maxf(speed, 0.001)
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		var world := ArenaSpace.to_world(b.pos2, HEIGHT)
		var basis: Basis
		if b.friendly:
			var w := 0.15 * b.size * (1.25 if b.crit else 1.0)
			var length := 0.95 * (0.7 + 0.3 * b.size)
			var glow := 0.75
			match b.style:
				STYLE_PELLET:
					w *= 0.85
					length = 0.5
					glow = 0.55
				STYLE_RAIL:
					w *= 0.7
					length = 2.8
					glow = 1.1
				STYLE_ROCKET:
					w *= 1.15
					length = 0.8
					glow = 1.0
			basis = Basis(side * w, Vector3.UP * w, fwd * length)
			if vfx != null:
				vfx.glow_add(world.x, world.z, glow * b.size, Color(b.color.r, b.color.g, b.color.b, 0.22))
		else:
			var pulse := 1.0 + 0.14 * sin(time * 16.0 + b.pos2.x * 0.05)
			var w := 0.3 * b.size * pulse
			basis = Basis(side * w, Vector3.UP * w, fwd * (w * 1.35))
			if vfx != null:
				vfx.glow_add(world.x, world.z, 1.1 * b.size, Color(b.color.r, b.color.g, b.color.b, 0.3))
		_mm.set_instance_transform(n, Transform3D(basis, world))
		_mm.set_instance_color(n, b.color)
		n += 1
	_mm.visible_instance_count = n

func clear_all() -> void:
	bullets.clear()
	if _mm != null:
		_mm.visible_instance_count = 0

func clear_hostile(center: Vector2, radius: float) -> Array:
	## Yarıçap içindeki düşman mermilerini siler; silinenlerin konumlarını döndürür.
	var out: Array = []
	for b in bullets:
		if not b.friendly and not b.dead and b.pos2.distance_to(center) < radius:
			b.dead = true
			out.append(b.pos2)
	return out
