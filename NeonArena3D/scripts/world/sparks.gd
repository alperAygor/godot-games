extends Node3D
## Görsel efekt merkezi — hepsi MultiMesh, yani toplam 2 çizim çağrısı:
##   • kıvılcımlar ve ışınlar (hız yönünde uzayan eklemeli kutular)
##   • zemin halkaları ve ışık diskleri (şok dalgası, doğma uyarısı, neon yansıması)
## Ayrıca patlamalar için havuzlanmış kısa ömürlü ışıklar.

const MAX_SPARKS := 520
const MAX_BEAMS := 28
const MAX_RINGS := 56
const MAX_GLOWS := 230
const MAX_LIGHTS := 4

var budget := 1.0

var _mm: MultiMesh
var _ring_mm: MultiMesh
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _max_life: PackedFloat32Array = PackedFloat32Array()
var _size: PackedFloat32Array = PackedFloat32Array()
var _grav: PackedFloat32Array = PackedFloat32Array()
var _col: PackedColorArray = PackedColorArray()
var _count := 0
var _beams: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _glows: Array = []
var _lights: Array[OmniLight3D] = []
var _light_life: Array[float] = []
var _light_max: Array[float] = []
var _light_energy: Array[float] = []

func _ready() -> void:
	_pos.resize(MAX_SPARKS)
	_vel.resize(MAX_SPARKS)
	_life.resize(MAX_SPARKS)
	_max_life.resize(MAX_SPARKS)
	_size.resize(MAX_SPARKS)
	_grav.resize(MAX_SPARKS)
	_col.resize(MAX_SPARKS)

	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, 0.07)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/particle.gdshader")
	box.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = box
	_mm.instance_count = MAX_SPARKS + MAX_BEAMS
	_mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = _mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-120, -5, -120), Vector3(240, 30, 240))
	add_child(node)

	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = load("res://assets/shaders/ring.gdshader")
	quad.material = ring_mat
	_ring_mm = MultiMesh.new()
	_ring_mm.transform_format = MultiMesh.TRANSFORM_3D
	_ring_mm.use_colors = true
	_ring_mm.use_custom_data = true
	_ring_mm.mesh = quad
	_ring_mm.instance_count = MAX_RINGS + MAX_GLOWS
	_ring_mm.visible_instance_count = 0
	var ring_node := MultiMeshInstance3D.new()
	ring_node.multimesh = _ring_mm
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_node.custom_aabb = AABB(Vector3(-120, -5, -120), Vector3(240, 30, 240))
	add_child(ring_node)

	for i in MAX_LIGHTS:
		var light := OmniLight3D.new()
		light.visible = false
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)
		_light_life.append(0.0)
		_light_max.append(1.0)
		_light_energy.append(1.0)

# --- Kıvılcım -----------------------------------------------------------------
func burst(at: Vector3, color: Color, count: int, speed: float, life := 0.5, size := 1.0, up := 1.0) -> void:
	count = int(ceil(float(count) * budget))
	for i in count:
		if _count >= MAX_SPARKS:
			return
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.05, 1.0) * up, randf_range(-1.0, 1.0)).normalized()
		var k := _count
		_count += 1
		_pos[k] = at
		_vel[k] = dir * speed * randf_range(0.3, 1.0)
		_life[k] = life * randf_range(0.55, 1.2)
		_max_life[k] = _life[k]
		_size[k] = size * randf_range(0.6, 1.4)
		_grav[k] = 9.0
		_col[k] = color

func spray(at: Vector3, direction: Vector3, color: Color, count: int, speed: float, life := 0.35, size := 1.0, spread := 0.45) -> void:
	## Belirli bir yöne püsküren kıvılcımlar (namlu, isabet).
	count = int(ceil(float(count) * budget))
	for i in count:
		if _count >= MAX_SPARKS:
			return
		var dir := (direction + Vector3(randf_range(-spread, spread), randf_range(-spread * 0.4, spread), randf_range(-spread, spread))).normalized()
		var k := _count
		_count += 1
		_pos[k] = at
		_vel[k] = dir * speed * randf_range(0.4, 1.0)
		_life[k] = life * randf_range(0.6, 1.2)
		_max_life[k] = _life[k]
		_size[k] = size * randf_range(0.6, 1.3)
		_grav[k] = 4.0
		_col[k] = color

func trail(at: Vector3, direction: Vector3, color: Color, size := 1.5) -> void:
	if _count >= MAX_SPARKS:
		return
	var k := _count
	_count += 1
	_pos[k] = at + Vector3(randf_range(-0.06, 0.06), randf_range(-0.05, 0.05), randf_range(-0.06, 0.06))
	_vel[k] = -direction * 2.2 + Vector3(randf_range(-0.5, 0.5), randf_range(-0.1, 0.3), randf_range(-0.5, 0.5))
	_life[k] = randf_range(0.16, 0.32)
	_max_life[k] = _life[k]
	_size[k] = size
	_grav[k] = 0.0
	_col[k] = color

# --- Işın / şimşek -------------------------------------------------------------
func beam(from: Vector3, to: Vector3, color: Color, width := 0.08, life := 0.14) -> void:
	if _beams.size() >= MAX_BEAMS:
		_beams.pop_front()
	_beams.append({"a": from, "b": to, "c": color, "w": width, "life": life, "max": life})

func lightning(from: Vector3, to: Vector3, color: Color, width := 0.07, life := 0.16) -> void:
	## Kırık çizgili şimşek: 3 parça.
	var prev := from
	var segments := 3
	var side := (to - from).cross(Vector3.UP).normalized()
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var p := from.lerp(to, t)
		if i < segments:
			p += side * randf_range(-0.45, 0.45) + Vector3.UP * randf_range(-0.1, 0.25)
		beam(prev, p, color, width, life)
		prev = p

# --- Halka / disk ---------------------------------------------------------------
func ring(at: Vector3, color: Color, r0: float, r1: float, life := 0.4, thickness := 0.16, fill := 0.0) -> void:
	if _rings.size() >= MAX_RINGS:
		_rings.pop_front()
	_rings.append({"at": Vector3(at.x, 0.05, at.z), "c": color, "r0": r0, "r1": r1, "life": life, "max": life, "th": thickness, "fill": fill})

func glow_begin() -> void:
	_glows.clear()

func glow_add(x: float, z: float, radius: float, color: Color) -> void:
	if _glows.size() < MAX_GLOWS * 3:
		_glows.append(Vector3(x, 0.03, z))
		_glows.append(radius)
		_glows.append(color)

# --- Anlık ışık -----------------------------------------------------------------
func flash(at: Vector3, color: Color, energy := 6.0, radius := 9.0, life := 0.25) -> void:
	if budget < 0.75:
		return
	var slot := 0
	var lowest := 1e9
	for i in MAX_LIGHTS:
		if _light_life[i] < lowest:
			lowest = _light_life[i]
			slot = i
	var light := _lights[slot]
	light.position = Vector3(at.x, maxf(at.y, 1.4), at.z)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.visible = true
	_light_life[slot] = life
	_light_max[slot] = life
	_light_energy[slot] = energy

# --- Güncelleme -----------------------------------------------------------------
func tick(delta: float) -> void:
	var drag := maxf(0.0, 1.0 - 3.0 * delta)
	var i := 0
	while i < _count:
		var left := _life[i] - delta
		if left <= 0.0:
			_count -= 1
			if i != _count:
				_pos[i] = _pos[_count]
				_vel[i] = _vel[_count]
				_life[i] = _life[_count]
				_max_life[i] = _max_life[_count]
				_size[i] = _size[_count]
				_grav[i] = _grav[_count]
				_col[i] = _col[_count]
			continue
		_life[i] = left
		var v := _vel[i] * drag
		v.y -= _grav[i] * delta
		var p := _pos[i] + v * delta
		if p.y < 0.05:
			p.y = 0.05
			v.y = absf(v.y) * 0.45
		_vel[i] = v
		_pos[i] = p
		i += 1
	var written := 0
	for k in _count:
		var t := _life[k] / _max_life[k]
		var v := _vel[k]
		var speed := v.length()
		var s := _size[k] * (0.3 + 0.7 * t)
		var basis := Basis.IDENTITY
		if speed > 0.6:
			var fwd := v / speed
			var side := fwd.cross(Vector3.UP)
			if side.length_squared() < 0.0001:
				side = Vector3.RIGHT
			side = side.normalized()
			var up := side.cross(fwd)
			basis = Basis(side * s, up * s, fwd * s * (1.0 + minf(speed * 0.38, 7.0)))
		else:
			basis = Basis.IDENTITY.scaled(Vector3.ONE * s)
		_mm.set_instance_transform(written, Transform3D(basis, _pos[k]))
		var c := _col[k]
		c.a = minf(1.0, t * 1.6)
		_mm.set_instance_color(written, c)
		written += 1
	var b := 0
	while b < _beams.size():
		var beam_data: Dictionary = _beams[b]
		beam_data["life"] = float(beam_data["life"]) - delta
		if float(beam_data["life"]) <= 0.0:
			_beams.remove_at(b)
			continue
		var a: Vector3 = beam_data["a"]
		var e: Vector3 = beam_data["b"]
		var span := e - a
		var length := span.length()
		if length > 0.01:
			var fwd := span / length
			var side := fwd.cross(Vector3.UP)
			if side.length_squared() < 0.0001:
				side = Vector3.RIGHT
			side = side.normalized()
			var up := side.cross(fwd)
			var t := float(beam_data["life"]) / float(beam_data["max"])
			var w: float = float(beam_data["w"]) / 0.07 * (0.4 + 0.6 * t)
			_mm.set_instance_transform(written, Transform3D(Basis(side * w, up * w, fwd * (length / 0.07)), a + span * 0.5))
			var c: Color = beam_data["c"]
			c.a = t
			_mm.set_instance_color(written, c)
			written += 1
		b += 1
	_mm.visible_instance_count = written

	var rw := 0
	var r := 0
	while r < _rings.size():
		var ring_data: Dictionary = _rings[r]
		ring_data["life"] = float(ring_data["life"]) - delta
		if float(ring_data["life"]) <= 0.0:
			_rings.remove_at(r)
			continue
		var t := 1.0 - float(ring_data["life"]) / float(ring_data["max"])
		var eased := 1.0 - pow(1.0 - t, 2.6)
		var radius: float = lerpf(float(ring_data["r0"]), float(ring_data["r1"]), eased)
		_ring_mm.set_instance_transform(rw, Transform3D(Basis.IDENTITY.scaled(Vector3(radius, 1.0, radius)), ring_data["at"]))
		var c: Color = ring_data["c"]
		c.a *= 1.0 - t * t
		_ring_mm.set_instance_color(rw, c)
		_ring_mm.set_instance_custom_data(rw, Color(0.0, float(ring_data["th"]), 0.0, float(ring_data["fill"])))
		rw += 1
		r += 1
	var g := 0
	while g < _glows.size():
		var radius: float = _glows[g + 1]
		_ring_mm.set_instance_transform(rw, Transform3D(Basis.IDENTITY.scaled(Vector3(radius, 1.0, radius)), _glows[g]))
		_ring_mm.set_instance_color(rw, _glows[g + 2])
		_ring_mm.set_instance_custom_data(rw, Color(0.0, 0.0, 1.0, 0.0))
		rw += 1
		g += 3
	_ring_mm.visible_instance_count = rw

	for l in MAX_LIGHTS:
		if _light_life[l] <= 0.0:
			continue
		_light_life[l] -= delta
		if _light_life[l] <= 0.0:
			_lights[l].visible = false
		else:
			_lights[l].light_energy = _light_energy[l] * (_light_life[l] / _light_max[l])

func clear_all() -> void:
	_count = 0
	_beams.clear()
	_rings.clear()
	_glows.clear()
	if _mm != null:
		_mm.visible_instance_count = 0
		_ring_mm.visible_instance_count = 0
	for l in MAX_LIGHTS:
		_light_life[l] = 0.0
		_lights[l].visible = false
