extends SceneTree

## Sonsuz mod parça kütüphanesi kabul probu (Faz 9 / F9.4).
##
##   godot --headless --path . -s res://tools/segment_probe.gd
##
## `data/segments.json` içindeki HER parça için şunları denetler:
##   1. sahne yüklenir ve kök `Segment` (scripts/gameplay/segment.gd) olur;
##   2. `length` kütüphane girdisiyle aynıdır;
##   3. hiçbir çarpışma şekli x ∈ [-5.1, 5.1] ve z ∈ [-length-0.2, 0.2] dışına taşmaz;
##   4. ADIMLANABİLİR GEÇİŞ: sabit engellerin (StaticBody3D, zemin hariç) XZ izdüşümü
##      z boyunca taranır; her dilimde robotun sığacağı (>= 1.2 m) kesintisiz boşluk
##      olmalı VE bu boşluk dilimden dilime >= 1 m örtüşmeli. Dinamik tuzakların
##      (tuş/kalem/fan) kapladığı alan geçilebilir sayılır (engel değildir).
## Çıkış: 0 tümü geçti, 1 en az bir ölçüt başarısız, 2 kurulum hatası.
## `-s` modunda autoload kimliği derlenmez (GOTCHAS #2); burada autoload kullanılmaz.

const SEGMENTS_JSON: String = "res://data/segments.json"
const SEGMENT_SCRIPT: String = "res://scripts/gameplay/segment.gd"

## Masa genişliği ve kabul sınırları (görev: x ∈ [-5.1, 5.1], z ∈ [-length-0.2, 0.2]).
const DESK_HALF_X: float = 5.0
const BOUND_X_MARGIN: float = 0.1
const BOUND_Z_MARGIN: float = 0.2
## Robot genişliği 0.8 m + 0.4 m pay = en az 1.2 m boşluk gerekir.
const ROBOT_CLEARANCE: float = 1.2
## Dilimden dilime boşluğun en az bu kadar örtüşmesi gerekir (sürekli koridor).
const SLICE_OVERLAP: float = 1.0
const SLICE_STEP: float = 0.25
## Zemin StaticBody3D'sinin adı; geçilebilir yüzeydir, engel sayılmaz.
const FLOOR_NAME: String = "Floor"

var _failures: Array[String] = []
var _setup_error: String = ""


func _initialize() -> void:
	_run()
	_finish()


func _run() -> void:
	var text: String = _read_file(SEGMENTS_JSON)
	if text.is_empty():
		_setup_error = "%s okunamadı" % SEGMENTS_JSON
		return
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_setup_error = "%s geçerli JSON değil" % SEGMENTS_JSON
		return
	var entries: Variant = (parsed as Dictionary).get("segments", [])
	if not (entries is Array):
		_setup_error = "'segments' dizisi yok"
		return
	var total: int = 0
	var passed: int = 0
	for entry_raw: Variant in (entries as Array):
		if not (entry_raw is Dictionary):
			_fail("girdi Dictionary değil: %s" % str(entry_raw))
			continue
		total += 1
		var report: String = _check_segment(entry_raw as Dictionary)
		print(report)
		if report.begins_with("OK"):
			passed += 1
	if total == 0:
		_setup_error = "kütüphane boş"
		return
	print("PROBE SONUC: %d/%d parça geçti" % [passed, total])


func _check_segment(entry: Dictionary) -> String:
	var seg_id: String = String(entry.get("id", ""))
	var scene_path: String = String(entry.get("scene", ""))
	var length: float = float(entry.get("length", 0.0))
	if seg_id.is_empty() or scene_path.is_empty():
		_fail("girdide id/scene eksik: %s" % str(entry))
		return "FAIL %s: id/scene eksik" % seg_id
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_fail("%s yüklenemedi: %s" % [seg_id, scene_path])
		return "FAIL %s: sahne yüklenemedi" % seg_id
	var segment: Node = packed.instantiate()
	if segment == null:
		_fail("%s örneklenemedi" % seg_id)
		return "FAIL %s: örneklenemedi" % seg_id

	var reason: String = ""
	if not _is_segment(segment):
		reason = "kök Segment değil"
	elif not is_equal_approx(float(segment.get("length")), length):
		reason = "length uyuşmuyor (sahne %.3f != girdi %.3f)" % [float(segment.get("length")), length]
	else:
		reason = _check_bounds(segment, length)
		if reason.is_empty():
			reason = _check_passable(segment, length)

	segment.free()
	if reason.is_empty():
		return "OK   %s (length=%s)" % [seg_id, str(length)]
	_fail("%s: %s" % [seg_id, reason])
	return "FAIL %s: %s" % [seg_id, reason]


func _is_segment(node: Node) -> bool:
	var script: Script = node.get_script() as Script
	if script == null:
		return false
	return script.resource_path == SEGMENT_SCRIPT


func _check_bounds(segment: Node, length: float) -> String:
	var limit_x: float = DESK_HALF_X + BOUND_X_MARGIN
	var limit_z_min: float = -length - BOUND_Z_MARGIN
	var limit_z_max: float = BOUND_Z_MARGIN
	for shape_node: Node in _collision_shapes(segment):
		var aabb: Vector4 = _shape_xz_aabb(shape_node)
		if aabb.x < -limit_x or aabb.y > limit_x or aabb.z < limit_z_min or aabb.w > limit_z_max:
			return "çocuk sınır dışı (%s: x[%.2f,%.2f] z[%.2f,%.2f])" % [
				shape_node.name, aabb.x, aabb.y, aabb.z, aabb.w]
	return ""


func _check_passable(segment: Node, length: float) -> String:
	var obstacles: Array[Vector4] = _static_obstacles(segment)
	# İlk dilimden son dilime erişilebilir aralık kümesini yuvarlayarak taşır (BFS'e
	# gerek yok: geçiş yalnız ileri yöndedir, bu yüzden "erişilebilir aralıklar" kümesi
	# dilimden dilime yayılır; son dilimde boş değilse yol vardır).
	var reachable: Array[Vector2] = _free_intervals(0.0, obstacles)
	if reachable.is_empty():
		return "giriş diliminde >= %.1f m boşluk yok" % ROBOT_CLEARANCE
	var slice_count: int = int(round(length / SLICE_STEP)) + 1
	for i: int in range(1, slice_count):
		var z: float = -float(i) * SLICE_STEP
		var candidates: Array[Vector2] = _free_intervals(z, obstacles)
		var next_reachable: Array[Vector2] = []
		for b: Vector2 in candidates:
			for a: Vector2 in reachable:
				var overlap: float = minf(a.y, b.y) - maxf(a.x, b.x)
				if overlap >= SLICE_OVERLAP:
					next_reachable.append(b)
					break
		reachable = next_reachable
		if reachable.is_empty():
			return "adımlanabilir geçiş yok (z=%.2f diliminde koridor koptu)" % z
	return ""


## Segment altındaki tüm CollisionShape3D'leri döndürür (statik/dinamik ayırmadan).
func _collision_shapes(segment: Node) -> Array[Node]:
	var out: Array[Node] = []
	_collect_shapes(segment, out)
	return out


func _collect_shapes(node: Node, out: Array[Node]) -> void:
	if node is CollisionShape3D:
		out.append(node)
	for child: Node in node.get_children():
		_collect_shapes(child, out)


## Sabit engellerin (StaticBody3D, zemin hariç) XZ izdüşümleri (Vector4 = minx,maxx,minz,maxz).
func _static_obstacles(segment: Node) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for shape_node: Node in _collision_shapes(segment):
		var body: Node = _owning_body(shape_node as CollisionShape3D)
		if body == null or not (body is StaticBody3D):
			continue
		if (body as StaticBody3D).name == FLOOR_NAME:
			continue
		out.append(_shape_xz_aabb(shape_node))
	return out


## CollisionShape3D'nin bağlı olduğu gövdeyi bulur (ilk fizik gövdesi atası).
func _owning_body(shape_node: CollisionShape3D) -> Node:
	var current: Node = shape_node.get_parent()
	while current != null:
		if current is StaticBody3D or current is AnimatableBody3D or current is RigidBody3D or current is Area3D:
			return current
		current = current.get_parent()
	return null


## Şeklin dünya (segment-yerel) XZ sınırlarını döndürür: Vector4(minx, maxx, minz, maxz).
func _shape_xz_aabb(shape_node: Node) -> Vector4:
	var cs: CollisionShape3D = shape_node as CollisionShape3D
	var shape: Shape3D = cs.shape
	if shape == null:
		return Vector4.ZERO
	var half: Vector3 = _shape_half_extents(shape)
	var gt: Transform3D = _world_transform(cs)
	var minx: float = INF
	var maxx: float = -INF
	var minz: float = INF
	var maxz: float = -INF
	for i: int in 2:
		for j: int in 2:
			for k: int in 2:
				var local: Vector3 = Vector3(half.x * (i * 2.0 - 1.0), half.y * (j * 2.0 - 1.0), half.z * (k * 2.0 - 1.0))
				var world: Vector3 = gt * local
				minx = minf(minx, world.x)
				maxx = maxf(maxx, world.x)
				minz = minf(minz, world.z)
				maxz = maxf(maxz, world.z)
	return Vector4(minx, maxx, minz, maxz)


## Düğümün dünya dönüşümünü yerel dönüşümleri yukarı doğru çarparak bulur.
## Ağaca eklemeden de çalışır: `-s` + `_initialize` içinde `get_global_transform()`
## "!is_inside_tree()" döndürür; manuel çarpım bundan bağımsızdır. Parça kökü kimlik
## dönüşümde olduğundan sonuç segment-yerel koordinattır.
func _world_transform(node: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var current: Node = node.get_parent()
	while current is Node3D:
		result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


## Şeklin yarı-boyutlarını (eksen hizalı kapsayıcı kutu için) döndürür.
func _shape_half_extents(shape: Shape3D) -> Vector3:
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		return Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	if shape is CylinderShape3D:
		var radius: float = (shape as CylinderShape3D).radius
		var height: float = (shape as CylinderShape3D).height
		return Vector3(radius, height * 0.5, radius)
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return Vector3(r, r, r)
	if shape is CapsuleShape3D:
		var cr: float = (shape as CapsuleShape3D).radius
		var ch: float = (shape as CapsuleShape3D).height
		return Vector3(cr, ch * 0.5 + cr, cr)
	return Vector3.ZERO


## Belirli bir z diliminde engellerin dışında kalan ve >= ROBOT_CLEARANCE genişliğindeki
## serbest x aralıklarını döndürür: Vector2(lo, hi) listesi.
func _free_intervals(z: float, obstacles: Array[Vector4]) -> Array[Vector2]:
	var blocked: Array[Vector2] = []
	for ob: Vector4 in obstacles:
		if z >= ob.z - 0.0001 and z <= ob.w + 0.0001:
			blocked.append(Vector2(ob.x, ob.y))
	blocked.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for interval: Vector2 in blocked:
		if merged.is_empty() or interval.x > merged[merged.size() - 1].y:
			merged.append(interval)
		else:
			merged[merged.size() - 1].y = maxf(merged[merged.size() - 1].y, interval.y)
	var free: Array[Vector2] = []
	var cursor: float = -DESK_HALF_X
	for interval: Vector2 in merged:
		var lo: float = cursor
		var hi: float = minf(interval.x, DESK_HALF_X)
		if hi - lo >= ROBOT_CLEARANCE:
			free.append(Vector2(lo, hi))
		cursor = maxf(cursor, interval.y)
	if DESK_HALF_X - cursor >= ROBOT_CLEARANCE:
		free.append(Vector2(cursor, DESK_HALF_X))
	return free


func _read_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	var code: int = 0
	if _setup_error != "":
		print("PROBE KURULUM HATASI: %s" % _setup_error)
		code = 2
	elif not _failures.is_empty():
		for message: String in _failures:
			print("PROBE BAŞARISIZ: %s" % message)
		code = 1
	quit(code)
