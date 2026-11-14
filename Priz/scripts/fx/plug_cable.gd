class_name PlugCable
extends MeshInstance3D

## Fiziksel fiş kablosu: hafif Verlet ipi (≈20 parça) + her karede yeniden kurulan pürüzsüz tüp.
## Fiş sürüklenirken sarkar ve sallanır. Uçlar iki düğüme (ya da elle verilen noktalara) iğnelenir.
##
## Kamu arayüzü:
##   start_node / end_node : Node3D  — kablonun iki ucu (örn. cihaz PlugAnchor, fiş CableAnchor)
##   set_endpoints(a, b)              — düğüm yerine dünya noktaları
##   slack                            — ip uzunluğu / uçlar arası mesafe (sarkma miktarı)
##   snap_to_rest()                   — ipi anında dinlenme (sarkık) biçimine getirir
## Maliyet: segments × sides × 2 üçgen (varsayılan 20 × 8 × 2 = 320), CPU'da ~20 nokta × 10 iterasyon.

@export var start_node: Node3D
@export var end_node: Node3D
@export_range(8, 32) var segments: int = 20
@export_range(4, 12) var sides: int = 8
@export var radius: float = 0.0065
@export var slack: float = 1.18
@export var min_length: float = 0.25
@export var gravity: Vector3 = Vector3(0.0, -9.8, 0.0)
@export var damping: float = 0.985
@export var iterations: int = 10
## Zemin yüksekliği (dünya y); kablo bunun altına inmez.
@export var floor_y: float = 0.006
@export var cable_material: Material

var _pts: PackedVector3Array = PackedVector3Array()
var _prev: PackedVector3Array = PackedVector3Array()
var _a: Vector3 = Vector3.ZERO
var _b: Vector3 = Vector3.ZERO
var _manual: bool = false
var _imesh: ImmediateMesh


func _ready() -> void:
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if cable_material == null:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.93, 0.91, 0.87)
		m.roughness = 0.45
		cable_material = m
	# Tüp dünya koordinatında kurulur; düğüm dönüşümü etkisiz olsun.
	top_level = true
	global_transform = Transform3D.IDENTITY
	_read_ends()
	snap_to_rest()


func set_endpoints(a: Vector3, b: Vector3) -> void:
	_manual = true
	_a = a
	_b = b


func snap_to_rest() -> void:
	_read_ends()
	_pts.resize(segments + 1)
	_prev.resize(segments + 1)
	var L: float = _rest_length()
	var d: float = _a.distance_to(_b)
	var sag: float = sqrt(maxf(L * L - d * d, 0.0)) * 0.5
	for i: int in range(segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector3 = _a.lerp(_b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		p.y = maxf(p.y, floor_y + radius)
		_pts[i] = p
		_prev[i] = p


func _rest_length() -> float:
	return maxf(_a.distance_to(_b) * slack, min_length)


func _read_ends() -> void:
	if _manual:
		return
	if start_node != null and start_node.is_inside_tree():
		_a = start_node.global_position
	if end_node != null and end_node.is_inside_tree():
		_b = end_node.global_position


func _physics_process(delta: float) -> void:
	_read_ends()
	if _pts.size() != segments + 1:
		snap_to_rest()
	var n: int = segments + 1
	var dt2: float = delta * delta
	for i: int in range(1, n - 1):
		var p: Vector3 = _pts[i]
		var v: Vector3 = (p - _prev[i]) * damping
		_prev[i] = p
		_pts[i] = p + v + gravity * dt2
	_pts[0] = _a
	_pts[n - 1] = _b
	var seg_len: float = _rest_length() / float(segments)
	for _k: int in range(iterations):
		for i: int in range(n - 1):
			var p0: Vector3 = _pts[i]
			var p1: Vector3 = _pts[i + 1]
			var delta_v: Vector3 = p1 - p0
			var dist: float = delta_v.length()
			if dist < 0.00001:
				continue
			var diff: float = (dist - seg_len) / dist
			var w0: float = 0.0 if i == 0 else 0.5
			var w1: float = 0.0 if i + 1 == n - 1 else 0.5
			if w0 + w1 <= 0.0:
				continue
			var s: float = 1.0 / (w0 + w1)
			_pts[i] = p0 + delta_v * diff * w0 * s
			_pts[i + 1] = p1 - delta_v * diff * w1 * s
		for i: int in range(1, n - 1):
			if _pts[i].y < floor_y + radius:
				var q: Vector3 = _pts[i]
				q.y = floor_y + radius
				_pts[i] = q
				# Zemin sürtünmesi
				_prev[i] = _prev[i].lerp(q, 0.5)


func _process(_delta: float) -> void:
	_build_tube()


func _build_tube() -> void:
	if _imesh == null or _pts.size() < 2:
		return
	_imesh.clear_surfaces()
	var n: int = _pts.size()
	# Paralel taşıma çerçeveleri (burulmasız tüp)
	var tangents: Array[Vector3] = []
	for i: int in range(n):
		var t: Vector3 = _pts[mini(i + 1, n - 1)] - _pts[maxi(i - 1, 0)]
		tangents.append(t.normalized() if t.length() > 0.00001 else Vector3.FORWARD)
	var up: Vector3 = Vector3.UP if absf(tangents[0].y) < 0.9 else Vector3.RIGHT
	var normal: Vector3 = tangents[0].cross(up).normalized()
	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	for i: int in range(n):
		if i > 0:
			var axis: Vector3 = tangents[i - 1].cross(tangents[i])
			if axis.length() > 0.000001:
				normal = normal.rotated(axis.normalized(), tangents[i - 1].angle_to(tangents[i]))
		var binormal: Vector3 = tangents[i].cross(normal).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		var rn: PackedVector3Array = PackedVector3Array()
		for s: int in range(sides):
			var a: float = TAU * float(s) / float(sides)
			var dir: Vector3 = normal * cos(a) + binormal * sin(a)
			ring.append(_pts[i] + dir * radius)
			rn.append(dir)
		rings.append(ring)
		ring_normals.append(rn)
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, cable_material)
	for i: int in range(n - 1):
		for s: int in range(sides):
			var s2: int = (s + 1) % sides
			var v0: float = float(i) / float(n - 1)
			var v1: float = float(i + 1) / float(n - 1)
			var u0: float = float(s) / float(sides)
			var u1: float = float(s + 1) / float(sides)
			_vert(ring_normals[i][s], Vector2(u0, v0), rings[i][s])
			_vert(ring_normals[i + 1][s], Vector2(u0, v1), rings[i + 1][s])
			_vert(ring_normals[i][s2], Vector2(u1, v0), rings[i][s2])
			_vert(ring_normals[i][s2], Vector2(u1, v0), rings[i][s2])
			_vert(ring_normals[i + 1][s], Vector2(u0, v1), rings[i + 1][s])
			_vert(ring_normals[i + 1][s2], Vector2(u1, v1), rings[i + 1][s2])
	_imesh.surface_end()


func _vert(nrm: Vector3, uv: Vector2, pos: Vector3) -> void:
	_imesh.surface_set_normal(nrm)
	_imesh.surface_set_uv(uv)
	_imesh.surface_add_vertex(pos)
