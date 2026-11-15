class_name TrackBuilder
extends RefCounted

## Seviyenin hücre çizgesinden (CORE_API §1 "cells") pürüzsüz ray ağı kurar: balast yatağı, traversler (MultiMesh),
## ray profili süpürmesi, makas dilleri + makas feneri, tamponlar. Ayrıca araç pozlarını verir (ray teğetine dönük).
##
## Neden sabit parçalar değil: hücreler kesirli koordinatta olabilir ve her hücrenin kendi teğeti vardır; çoklu
## çizgiden üretilen ağ düz-çapraz geçişlerde kırık bırakmaz, makas dalları gerçek makas gibi gövde teğetinden ayrılır.
##
## Geometri: hücre c'nin teğeti T_c (a yanından b yanına). Her "yarım kenar" c -> m (m = komşuyla orta nokta) kübik
## Bezier'dir: c'de T_c, m'de kenar yönü. Böylece komşu yarımlar m'de teğet-sürekli birleşir ve araç tam hücre
## merkezinde durur. Makas hücresinde T_c gövde yönüdür: iki dal makas ucundan aynı teğetle ayrılır.
##
##   var tb := TrackBuilder.from_cells(level["cells"])
##   var track: Node3D = tb.build()          # sahneye ekle
##   vehicle.transform = tb.cell_transform(cell, TrackBuilder.SIDE_B)
##   vehicle.transform = tb.travel_transform(from_cell, to_cell, 0.4)
##   tb.set_switch(track, cell, 1)            # makas dili + fener dal 1'e

const SIDE_A: int = 0
const SIDE_B: int = 1
## Yarım kenar örnek sayısı (eğri); düz yarımlar tek parça.
const CURVE_SAMPLES: int = 10
const BEZIER_K: float = 0.40
## Makas dili: makas ucundan itibaren dal boyunca bu uzunluk "dil" (seçili dal görünür, öteki açık kalır).
const BLADE_LEN: float = 0.30
const STUB_LEN: float = 0.5
const BUFFER_SCENE: String = "res://assets/models/track/buffer_stop.glb"
const SWITCH_STAND_SCENE: String = "res://assets/models/track/switch_stand.glb"
const TRACK_KIT_SCENE: String = "res://assets/models/track/track_kit.glb"
const MAT_DIR: String = "res://assets/materials/"

var _pos: Array[Vector3] = []
var _sides: Array[Array] = []          # [hücre] -> [PackedInt32Array (a), PackedInt32Array (b)]
var _tan: Array[Vector3] = []          # a -> b yönünde birim teğet
## Yarım kenar önbelleği: "c:n" -> PackedVector3Array (c'den m'ye)
var _half: Dictionary[String, PackedVector3Array] = {}


static func from_cells(cells: Array) -> TrackBuilder:
	var tb: TrackBuilder = TrackBuilder.new()
	for raw: Variant in cells:
		var c: Dictionary = raw as Dictionary
		tb._pos.append(Vector3(float(c.get("x", 0.0)), 0.0, float(c.get("y", 0.0))))
		var a: PackedInt32Array = PackedInt32Array()
		var b: PackedInt32Array = PackedInt32Array()
		for v: Variant in c.get("a", []) as Array:
			a.append(int(v))
		for v: Variant in c.get("b", []) as Array:
			b.append(int(v))
		tb._sides.append([a, b])
	tb._compute_tangents()
	return tb


func cell_count() -> int:
	return _pos.size()


func cell_position(cell: int) -> Vector3:
	return _pos[cell]


func neighbors(cell: int, side: int) -> PackedInt32Array:
	return _sides[cell][side] as PackedInt32Array


## a -> b yönündeki birim teğet.
func cell_tangent(cell: int) -> Vector3:
	return _tan[cell]


## Hücredeki aracın dönüşümü: aracın önü (+Z) `toward_side` yanına bakar.
func cell_transform(cell: int, toward_side: int) -> Transform3D:
	var fwd: Vector3 = _tan[cell] if toward_side == SIDE_B else -_tan[cell]
	return Transform3D(Basis.looking_at(-fwd, Vector3.UP), _pos[cell])


## from -> to komşu hücreleri arasında t (0..1) noktası; araç önü hareket yönüne bakar.
## `reverse` true ise araç geri geri gidiyor (önü hareketin tersine).
func travel_transform(from_cell: int, to_cell: int, t: float, reverse: bool = false) -> Transform3D:
	var path: PackedVector3Array = edge_points(from_cell, to_cell)
	var lengths: PackedFloat32Array = _cumulative(path)
	var total: float = lengths[lengths.size() - 1]
	var d: float = clampf(t, 0.0, 1.0) * total
	var i: int = 1
	while i < lengths.size() - 1 and lengths[i] < d:
		i += 1
	var seg: float = maxf(lengths[i] - lengths[i - 1], 0.00001)
	var u: float = (d - lengths[i - 1]) / seg
	var p: Vector3 = path[i - 1].lerp(path[i], u)
	var fwd: Vector3 = (path[i] - path[i - 1]).normalized()
	if reverse:
		fwd = -fwd
	return Transform3D(Basis.looking_at(-fwd, Vector3.UP), p)


## from merkezinden to merkezine yol (yarım + ters yarım).
func edge_points(from_cell: int, to_cell: int) -> PackedVector3Array:
	var first: PackedVector3Array = _half_edge(from_cell, to_cell)
	var second: PackedVector3Array = _half_edge(to_cell, from_cell)
	var out: PackedVector3Array = first.duplicate()
	for i: int in range(second.size() - 2, -1, -1):
		out.append(second[i])
	return out


func switch_cells() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for c: int in range(_pos.size()):
		if _switch_side(c) >= 0:
			out.append(c)
	return out


## Izgara sınırı (hücre merkezleri), Godot XZ -> Rect2(x, z).
func bounds() -> Rect2:
	if _pos.is_empty():
		return Rect2()
	var r: Rect2 = Rect2(Vector2(_pos[0].x, _pos[0].z), Vector2.ZERO)
	for p: Vector3 in _pos:
		r = r.expand(Vector2(p.x, p.z))
	return r


# ------------------------------------------------------------------ kurulum

## Hat düğümü: Ballast, Sleepers, Rails, Blades_<hücre>_<dal>, SwitchStand_<hücre>, Buffer_<hücre>.
## sleeper_style: "wood" | "concrete".
func build(sleeper_style: String = "wood") -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Track"
	var ballast: MeshInstance3D = MeshInstance3D.new()
	ballast.name = "Ballast"
	ballast.mesh = _build_ballast()
	ballast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ballast)
	var sleepers: MultiMeshInstance3D = MultiMeshInstance3D.new()
	sleepers.name = "Sleepers"
	sleepers.multimesh = _build_sleepers(sleeper_style)
	sleepers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sleepers)
	var rails: MeshInstance3D = MeshInstance3D.new()
	rails.name = "Rails"
	rails.mesh = _build_rails(false)
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rails)
	_build_switches(root)
	_build_buffers(root)
	return root


## Makas durumu: seçili dalın dilleri görünür ve fener o dala döner.
func set_switch(track: Node3D, cell: int, branch: int) -> void:
	for b: int in range(2):
		var blades: Node3D = track.get_node_or_null("Blades_%d_%d" % [cell, b]) as Node3D
		if blades != null:
			blades.visible = b == branch
	var stand: Node3D = track.get_node_or_null("SwitchStand_%d" % cell) as Node3D
	if stand != null:
		var disc: Node3D = stand.find_child("Indicator", true, false) as Node3D
		if disc != null:
			disc.rotation.y = deg_to_rad(-35.0 if branch == 0 else 35.0) * float(stand.get_meta("hand", 1.0))


# ------------------------------------------------------------------ geometri çekirdeği

func _compute_tangents() -> void:
	_tan.resize(_pos.size())
	for c: int in range(_pos.size()):
		var a: PackedInt32Array = _sides[c][SIDE_A] as PackedInt32Array
		var b: PackedInt32Array = _sides[c][SIDE_B] as PackedInt32Array
		var t: Vector3 = Vector3.ZERO
		var sw: int = _switch_side(c)
		if sw == SIDE_B and a.size() == 1:
			t = (_pos[c] - _pos[a[0]]).normalized()
		elif sw == SIDE_A and b.size() == 1:
			t = (_pos[b[0]] - _pos[c]).normalized()
		elif sw >= 0:
			# Gövdesiz makas: dalların ortalaması
			var br: PackedInt32Array = _sides[c][sw] as PackedInt32Array
			var avg: Vector3 = Vector3.ZERO
			for n: int in br:
				avg += (_pos[n] - _pos[c]).normalized()
			t = avg.normalized() if sw == SIDE_B else -avg.normalized()
		else:
			if a.size() == 1:
				t += (_pos[c] - _pos[a[0]]).normalized()
			if b.size() == 1:
				t += (_pos[b[0]] - _pos[c]).normalized()
		if t.length() < 0.001:
			t = Vector3.RIGHT
		_tan[c] = t.normalized()


func _switch_side(c: int) -> int:
	if (_sides[c][SIDE_B] as PackedInt32Array).size() == 2:
		return SIDE_B
	if (_sides[c][SIDE_A] as PackedInt32Array).size() == 2:
		return SIDE_A
	return -1


func _side_of(c: int, n: int) -> int:
	return SIDE_B if (_sides[c][SIDE_B] as PackedInt32Array).has(n) else SIDE_A


## c merkezinden c-n kenar ortasına kübik Bezier örnekleri.
func _half_edge(c: int, n: int) -> PackedVector3Array:
	var key: String = "%d:%d" % [c, n]
	if _half.has(key):
		return _half[key]
	var p0: Vector3 = _pos[c]
	var m: Vector3 = (_pos[c] + _pos[n]) * 0.5
	var d_c: Vector3 = _tan[c] if _side_of(c, n) == SIDE_B else -_tan[c]
	var e: Vector3 = (_pos[n] - _pos[c]).normalized()
	var pts: PackedVector3Array = _bezier(p0, d_c, m, e)
	_half[key] = pts
	return pts


func _bezier(p0: Vector3, d0: Vector3, p3: Vector3, d3: Vector3) -> PackedVector3Array:
	var length: float = p0.distance_to(p3)
	var p1: Vector3 = p0 + d0 * length * BEZIER_K
	var p2: Vector3 = p3 - d3 * length * BEZIER_K
	var pts: PackedVector3Array = PackedVector3Array()
	var straight: bool = d0.dot(d3) > 0.9999 and d0.dot((p3 - p0).normalized()) > 0.9999
	var n: int = 1 if straight else CURVE_SAMPLES
	for i: int in range(n + 1):
		var t: float = float(i) / float(n)
		var u: float = 1.0 - t
		pts.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return pts


## Ölü uç (0 komşulu yan): hücreden dışarı düz uzantı.
func _stub(c: int, side: int, length: float) -> PackedVector3Array:
	var d: Vector3 = _tan[c] if side == SIDE_B else -_tan[c]
	return PackedVector3Array([_pos[c], _pos[c] + d * length])


## Hattın bütün parçaları: [yol, makas hücresi ya da -1, dal ya da -1]
func _segments(stub_len: float) -> Array[Array]:
	var out: Array[Array] = []
	for c: int in range(_pos.size()):
		for side: int in [SIDE_A, SIDE_B]:
			var ns: PackedInt32Array = _sides[c][side] as PackedInt32Array
			if ns.is_empty():
				out.append([_stub(c, side, stub_len), -1, -1])
			for i: int in range(ns.size()):
				var branch: int = i if ns.size() == 2 else -1
				out.append([_half_edge(c, ns[i]), c if branch >= 0 else -1, branch])
	return out


static func _cumulative(path: PackedVector3Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, path.size()):
		out.append(out[i - 1] + path[i].distance_to(path[i - 1]))
	return out


static func _side_vec(path: PackedVector3Array, i: int) -> Vector3:
	var a: Vector3 = path[maxi(i - 1, 0)]
	var b: Vector3 = path[mini(i + 1, path.size() - 1)]
	var t: Vector3 = (b - a).normalized()
	return t.cross(Vector3.UP).normalized()


static func _resample(path: PackedVector3Array, step: float) -> PackedVector3Array:
	var lengths: PackedFloat32Array = _cumulative(path)
	var total: float = lengths[lengths.size() - 1]
	var n: int = maxi(1, int(ceil(total / step)))
	var out: PackedVector3Array = PackedVector3Array()
	var j: int = 1
	for k: int in range(n + 1):
		var d: float = total * float(k) / float(n)
		while j < lengths.size() - 1 and lengths[j] < d:
			j += 1
		var seg: float = maxf(lengths[j] - lengths[j - 1], 0.00001)
		out.append(path[j - 1].lerp(path[j], clampf((d - lengths[j - 1]) / seg, 0.0, 1.0)))
	return out


# ------------------------------------------------------------------ balast

func _build_ballast() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_y: float = ArtDims.BALLAST_TOP
	var low_y: float = ArtDims.GROUND_Y - 0.004
	var tw: float = ArtDims.BALLAST_TOP_W * 0.5
	var bw: float = ArtDims.BALLAST_BOTTOM_W * 0.5
	# Kesit: alt kenar -> yuvarlak omuz -> tepe -> omuz -> alt kenar (x, y)
	var prof: PackedVector2Array = PackedVector2Array([Vector2(-bw, low_y), Vector2(-tw - 0.035, top_y - 0.012),
		Vector2(-tw, top_y - 0.002), Vector2(-tw + 0.03, top_y), Vector2(tw - 0.03, top_y), Vector2(tw, top_y - 0.002),
		Vector2(tw + 0.035, top_y - 0.012), Vector2(bw, low_y)])
	for seg: Array in _segments(STUB_LEN + 0.16):
		var path: PackedVector3Array = seg[0] as PackedVector3Array
		_sweep(st, path, prof, true)
		# Ölü uçta yokuşla biten kapak
		if int(seg[1]) == -1 and path.size() == 2 and path[0].distance_to(path[1]) > STUB_LEN:
			_end_cap(st, path, prof)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, load(MAT_DIR + "ballast.tres") as Material)
	return mesh


func _sweep(st: SurfaceTool, path: PackedVector3Array, prof: PackedVector2Array, smooth: bool,
		color_fn: Callable = Callable()) -> void:
	var rings: Array[PackedVector3Array] = []
	for i: int in range(path.size()):
		var side: Vector3 = _side_vec(path, i)
		var ring: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in prof:
			ring.append(path[i] + side * p.x + Vector3.UP * p.y)
		rings.append(ring)
	st.set_smooth_group(0 if smooth else -1)
	for i: int in range(rings.size() - 1):
		for k: int in range(prof.size() - 1):
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k + 1]
			var c: Vector3 = rings[i + 1][k + 1]
			var d: Vector3 = rings[i + 1][k]
			if color_fn.is_valid():
				st.set_color(color_fn.call(k) as Color)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(a)
			st.add_vertex(d)
			st.add_vertex(c)


func _end_cap(st: SurfaceTool, path: PackedVector3Array, prof: PackedVector2Array) -> void:
	var end: Vector3 = path[path.size() - 1]
	var dir: Vector3 = (end - path[path.size() - 2]).normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	var tip: Vector3 = end + dir * 0.12 + Vector3.UP * (ArtDims.GROUND_Y - 0.004)
	for k: int in range(prof.size() - 1):
		var a: Vector3 = end + side * prof[k].x + Vector3.UP * prof[k].y
		var b: Vector3 = end + side * prof[k + 1].x + Vector3.UP * prof[k + 1].y
		var ta: Vector3 = tip + side * prof[k].x * 0.7
		var tb: Vector3 = tip + side * prof[k + 1].x * 0.7
		st.add_vertex(a)
		st.add_vertex(tb)
		st.add_vertex(b)
		st.add_vertex(a)
		st.add_vertex(ta)
		st.add_vertex(tb)


# ------------------------------------------------------------------ traversler

func _sleeper_mesh(style: String) -> Mesh:
	var kit: PackedScene = load(TRACK_KIT_SCENE) as PackedScene
	if kit != null:
		var inst: Node = kit.instantiate()
		var node_name: String = "SleeperConcrete" if style == "concrete" else "Sleeper"
		var mi: MeshInstance3D = inst.find_child(node_name, true, false) as MeshInstance3D
		var mesh: Mesh = mi.mesh if mi != null else null
		inst.free()
		if mesh != null:
			return mesh
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(ArtDims.SLEEPER_L, ArtDims.SLEEPER_H, ArtDims.SLEEPER_W)
	return box


func _build_sleepers(style: String) -> MultiMesh:
	var xforms: Array[Transform3D] = []
	var y: float = ArtDims.SLEEPER_TOP
	for seg: Array in _segments(STUB_LEN):
		var path: PackedVector3Array = seg[0] as PackedVector3Array
		var cell: int = int(seg[1])
		var branch: int = int(seg[2])
		if cell >= 0 and branch == 1:
			continue   # makas dalları birlikte (dal 0 geçişinde) uzun traverslerle döşenir
		var other: PackedVector3Array = PackedVector3Array()
		if cell >= 0:
			var ns: PackedInt32Array = _sides[cell][_switch_side(cell)] as PackedInt32Array
			other = _resample(_half_edge(cell, ns[1]), 0.01)
		var lengths: PackedFloat32Array = _cumulative(path)
		var total: float = lengths[lengths.size() - 1]
		var count: int = maxi(1, int(round(total / ArtDims.SLEEPER_STEP)))
		var step: float = total / float(count)
		# Yarım kenar başından yarım adım içeride başla: komşu yarımlarla eşit aralık, ortada çift travers yok.
		var res: PackedVector3Array = _resample(path, 0.01)
		var res_len: PackedFloat32Array = _cumulative(res)
		for k: int in range(count):
			var d: float = step * (float(k) + 0.5)
			var idx: int = _index_at(res_len, d)
			var p: Vector3 = res[idx]
			var fwd: Vector3 = (res[mini(idx + 1, res.size() - 1)] - res[maxi(idx - 1, 0)]).normalized()
			var length: float = ArtDims.SLEEPER_L
			var center: Vector3 = p
			if not other.is_empty():
				# Uzun makas traversi: iki dalın orta çizgisinde, ikisini de taşıyacak boyda.
				var q: Vector3 = other[_index_at(_cumulative(other), d)]
				center = (p + q) * 0.5
				length = ArtDims.SLEEPER_L + p.distance_to(q)
			var basis: Basis = Basis.looking_at(-fwd, Vector3.UP)
			basis = basis.scaled_local(Vector3(length / ArtDims.SLEEPER_L, 1.0, 1.0))
			xforms.append(Transform3D(basis, Vector3(center.x, y, center.z)))
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _sleeper_mesh(style)
	mm.instance_count = xforms.size()
	for i: int in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	return mm


static func _index_at(lengths: PackedFloat32Array, d: float) -> int:
	var lo: int = 0
	var hi: int = lengths.size() - 1
	while lo < hi:
		var mid: int = (lo + hi) / 2
		if lengths[mid] < d:
			lo = mid + 1
		else:
			hi = mid
	return lo


# ------------------------------------------------------------------ raylar

## Ray kesiti (x yan, y yukarı; ray üstü y = 0). Mantar parlak çelik, gövde paslı (köşe rengi).
static func rail_profile() -> PackedVector2Array:
	var h: float = ArtDims.RAIL_H
	var hw: float = ArtDims.RAIL_HEAD_W * 0.5
	var fw: float = ArtDims.RAIL_FOOT_W * 0.5
	return PackedVector2Array([Vector2(-fw, -h), Vector2(fw, -h), Vector2(fw, -h + 0.004), Vector2(0.005, -h + 0.009),
		Vector2(0.004, -0.013), Vector2(hw, -0.009), Vector2(hw, -0.0025), Vector2(hw - 0.003, 0.0),
		Vector2(-hw + 0.003, 0.0), Vector2(-hw, -0.0025), Vector2(-hw, -0.009), Vector2(-0.004, -0.013),
		Vector2(-0.005, -h + 0.009), Vector2(-fw, -h + 0.004), Vector2(-fw, -h)])


static func _rail_color(k: int) -> Color:
	# 5..9 arası kenarlar mantar (parlak), gerisi gövde/taban (pas)
	if k >= 5 and k <= 8:
		return Color(0.86, 0.87, 0.88)
	return Color(0.36, 0.26, 0.2)


func _build_rails(_unused: bool) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof: PackedVector2Array = rail_profile()
	for seg: Array in _segments(STUB_LEN + 0.06):
		var path: PackedVector3Array = seg[0] as PackedVector3Array
		var cell: int = int(seg[1])
		if cell >= 0:
			# Makas dalı: dil kısmı ayrı düğümde (durum ipucu); burada dil sonrası kısım.
			path = _trim_start(path, BLADE_LEN)
		_rail_pair(st, path, prof)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, load(MAT_DIR + "rail.tres") as Material)
	return mesh


func _rail_pair(st: SurfaceTool, path: PackedVector3Array, prof: PackedVector2Array) -> void:
	for s: float in [-0.5, 0.5]:
		var offset: PackedVector3Array = PackedVector3Array()
		for i: int in range(path.size()):
			offset.append(path[i] + _side_vec(path, i) * ArtDims.GAUGE * s)
		_sweep(st, offset, prof, false, _rail_color)


static func _trim_start(path: PackedVector3Array, d: float) -> PackedVector3Array:
	var res: PackedVector3Array = _resample(path, 0.02)
	var lengths: PackedFloat32Array = _cumulative(res)
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in range(res.size()):
		if lengths[i] >= d - 0.0001:
			out.append(res[i])
	return out


static func _take_start(path: PackedVector3Array, d: float) -> PackedVector3Array:
	var res: PackedVector3Array = _resample(path, 0.02)
	var lengths: PackedFloat32Array = _cumulative(res)
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in range(res.size()):
		if lengths[i] <= d + 0.0001:
			out.append(res[i])
	return out


func _build_switches(root: Node3D) -> void:
	var prof: PackedVector2Array = rail_profile()
	var stand_scene: PackedScene = load(SWITCH_STAND_SCENE) as PackedScene
	for c: int in switch_cells():
		var side: int = _switch_side(c)
		var ns: PackedInt32Array = _sides[c][side] as PackedInt32Array
		for b: int in range(2):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_rail_pair(st, _take_start(_half_edge(c, ns[b]), BLADE_LEN + 0.01), prof)
			st.generate_normals()
			var mesh: ArrayMesh = st.commit()
			mesh.surface_set_material(0, load(MAT_DIR + "rail_blade.tres") as Material)
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.name = "Blades_%d_%d" % [c, b]
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = b == 0
			root.add_child(mi)
		if stand_scene != null:
			var stand: Node3D = stand_scene.instantiate() as Node3D
			stand.name = "SwitchStand_%d" % c
			# Fener makas ucunun yanında, dalların AÇILMADIĞI tarafta (dalları örtmez).
			var fwd: Vector3 = _tan[c] if side == SIDE_B else -_tan[c]
			var right: Vector3 = fwd.cross(Vector3.UP).normalized()
			var spread: Vector3 = ((_pos[ns[0]] + _pos[ns[1]]) * 0.5 - _pos[c])
			var hand: float = -1.0 if spread.dot(right) > 0.0 else 1.0
			stand.set_meta("hand", hand)
			stand.transform = Transform3D(Basis.looking_at(-fwd, Vector3.UP),
				_pos[c] + right * hand * 0.36 - fwd * 0.12 + Vector3.UP * ArtDims.GROUND_Y)
			root.add_child(stand)
		set_switch(root, c, 0)


func _build_buffers(root: Node3D) -> void:
	var scene: PackedScene = load(BUFFER_SCENE) as PackedScene
	if scene == null:
		return
	for c: int in range(_pos.size()):
		for side: int in [SIDE_A, SIDE_B]:
			if not (_sides[c][side] as PackedInt32Array).is_empty():
				continue
			var d: Vector3 = _tan[c] if side == SIDE_B else -_tan[c]
			var buf: Node3D = scene.instantiate() as Node3D
			buf.name = "Buffer_%d_%d" % [c, side]
			# Tampon önü (yerel +Z) hücreye bakar; tampon kirişi hücre sınırında.
			buf.transform = Transform3D(Basis.looking_at(d, Vector3.UP), _pos[c] + d * (STUB_LEN - 0.02))
			root.add_child(buf)
