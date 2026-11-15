class_name SliceDevice
extends Node3D
## Oyundaki bir cihaz: Fx modeli (`Appliance`), fişi, fiziksel kablosu ve tepside yük blokları.
## Yerleri: TEPSİ (küçültülmüş, kameraya dönük, kaldırılabilir) → SÜRÜKLEME (fiş parmakta) →
## YOLCULUK (cihaz yay çizerek oda yerine uçar) → TAKILI (çalışır). Kural kararı vermez; SliceGame sürer.

enum Place { TRAY, DRAGGING, TRAVEL, PLUGGED, RETURNING }

const PLUG_SCENE: PackedScene = preload("res://assets/models/appliances/plug.glb")
const PLUG_MAT: Material = preload("res://assets/materials/cable_plug.tres")
const GAUGE_SHADER: Shader = preload("res://scenes/game/slice_gauge.gdshader")
## Tepside ve sürüklemede fiş, odadakinin bu katı (telefonda okunurluk).
const PLUG_TRAY_SCALE: float = 2.6
const CABLE_RADIUS: float = 0.0065
## Yük bloklarının nötr rengi (hat rengine boyanmadan önce).
const PIP_COLOR: Color = Color(1.0, 0.86, 0.6)
## Tepsi dünyanın zemininin (y=0) altında: kablo orada zemine takılmasın.
const FREE_FLOOR_Y: float = -100.0
const ROOM_FLOOR_Y: float = 0.006
const TRAVEL_SECONDS: float = 0.62
const RETURN_SECONDS: float = 0.5

signal arrived(device: SliceDevice)

var device_id: String = ""
var type: String = ""
var blocks: int = 1
var room_anchor: String = ""
var loop_sound: String = ""
var place: Place = Place.TRAY
var room_socket: String = ""

var appliance: Appliance
var plug: Node3D
var cable: PlugCable
var pips: MeshInstance3D
## Modelin yerel sınır kutusu (ölçeksiz).
var model_aabb: AABB = AABB(Vector3.ZERO, Vector3.ONE)

var tray_xform: Transform3D = Transform3D.IDENTITY
var room_xform: Transform3D = Transform3D.IDENTITY
var plug_rest_xform: Transform3D = Transform3D.IDENTITY
var tray_scale: float = 1.0

var _lift: float = 0.0
var _lift_tween: Tween
var _move_tween: Tween
var _plug_tween: Tween
var _pip_fill: float = 1.0
var _pip_tween: Tween
var _plug_scale: float = PLUG_TRAY_SCALE
var _hint: float = 0.0
var _time: float = 0.0
## Takılı cihazın kablosu: duvar/zemin boyunca döşenmiş durağan tüp (mobilyadan geçmez, her kare kurulmaz).
var _route: MeshInstance3D
## Tepside okunurluk: TV ekranı loş görüntü verir (siyah levha gibi okunmasın), modeller tepsi ışığı
## katmanında (SliceGame'in gölgesiz tepsi ışığı yalnız bu katmanı aydınlatır).
var _tray_look: bool = false


func setup(p_id: String, p_type: String, p_blocks: int, spec: Dictionary) -> void:
	device_id = p_id
	type = p_type
	blocks = p_blocks
	room_anchor = str(spec.get("anchor", ""))
	loop_sound = str(spec.get("loop", ""))
	var script: GDScript = load(str(spec.get("fx", ""))) as GDScript
	appliance = script.new() as Appliance
	appliance.name = "Appliance"
	add_child(appliance)
	model_aabb = _model_aabb(appliance)
	plug = PLUG_SCENE.instantiate() as Node3D
	plug.name = "Plug"
	add_child(plug)
	plug.top_level = true
	cable = PlugCable.new()
	cable.name = "Cable"
	cable.cable_material = PLUG_MAT
	cable.slack = 1.12
	cable.floor_y = FREE_FLOOR_Y
	cable.start_node = appliance.get_plug_anchor()
	cable.end_node = plug.find_child("CableAnchor", true, false) as Node3D
	add_child(cable)
	pips = MeshInstance3D.new()
	pips.name = "LoadBlocks"
	pips.top_level = true
	pips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	pips.mesh = quad
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GAUGE_SHADER
	mat.set_shader_parameter("slots", float(blocks))
	mat.set_shader_parameter("energy", 1.8)
	pips.material_override = mat
	pips.set_instance_shader_parameter("segments", float(blocks))
	pips.set_instance_shader_parameter("fill", 1.0)
	pips.set_instance_shader_parameter("tint", PIP_COLOR)
	add_child(pips)


## Tepsi yerleşimi: cihaz tabanı `base`, kameraya dönük `yaw`, `fit_height` boyuna ölçeklenir.
## Yük blokları `pip_origin` (alt orta) noktasında, blok boyu `block_size` (gösterge bloğuyla aynı).
func set_tray_layout(base: Vector3, yaw: float, fit_size: Vector2, pip_origin: Vector3, block_size: Vector2,
		cam_basis: Basis) -> void:
	var size: Vector3 = model_aabb.size
	var fit_fx: float = float(fit_size.x) / maxf(maxf(size.x, size.z), 0.01)
	var fit_fy: float = float(fit_size.y) / maxf(size.y, 0.01)
	tray_scale = minf(fit_fx, fit_fy)
	var b: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * tray_scale)
	# Model tabanı ortalı değilse (z kayması) düzelt.
	var center_off: Vector3 = Basis(Vector3.UP, yaw) * Vector3(model_aabb.get_center().x, 0.0, model_aabb.get_center().z) * tray_scale
	tray_xform = Transform3D(b, base - center_off)
	var face: Basis = Basis(cam_basis.x, cam_basis.y, cam_basis.z)
	pips.global_transform = Transform3D(face * Basis.from_scale(Vector3(block_size.x, block_size.y * float(blocks), 1.0)),
		pip_origin + cam_basis.y * block_size.y * float(blocks) * 0.5)
	# Fiş tepside cihazın önünde, kameraya bakar (pimler dışarı değil, yana).
	var pr: Basis = Basis(Vector3.UP, yaw + deg_to_rad(-70.0)) * Basis(Vector3.RIGHT, deg_to_rad(-12.0))
	var front: Vector3 = Basis(Vector3.UP, yaw) * Vector3(fit_size.x * 0.36, 0.0, fit_size.x * 0.42)
	plug_rest_xform = Transform3D(pr.scaled(Vector3.ONE * PLUG_TRAY_SCALE), base + front + Vector3(0.0, 0.07, 0.0))
	if place == Place.TRAY:
		_apply_tray()
		plug.global_transform = plug_rest_xform
		_set_plug_scale(PLUG_TRAY_SCALE)
		cable.snap_to_rest()


func set_room_xform(xform: Transform3D) -> void:
	room_xform = xform


func _apply_tray() -> void:
	var t: Transform3D = tray_xform
	var s: float = 1.0 + 0.12 * _lift + 0.05 * _hint
	t.basis = t.basis.scaled(Vector3.ONE * s)
	t.origin += Vector3.UP * (0.16 * _lift + 0.06 * _hint)
	appliance.global_transform = t


## Tepsiden kaldırma (dokunuş anında, 100 ms içinde görünür).
func lift(on: bool) -> void:
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	_lift_tween = create_tween()
	if on:
		_lift_tween.tween_method(_set_lift, _lift, 1.0, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_lift_tween.tween_method(_set_lift, _lift, 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _set_lift(v: float) -> void:
	_lift = v
	if place == Place.TRAY or place == Place.DRAGGING:
		_apply_tray()


## Boşta ipucu: tepsideki cihaz hafifçe zıplar (0 kapalı).
func set_hint(on: bool) -> void:
	_hint = 1.0 if on else 0.0
	if not on and (place == Place.TRAY):
		_apply_tray()


func set_pip_tint(color: Color) -> void:
	pips.set_instance_shader_parameter("tint", color)


## Blokların "boşalması" (cihaz takılınca bloklar göstergeye geçer) ya da dolması.
func set_pips_full(full: bool, seconds: float = 0.35) -> void:
	if _pip_tween != null and _pip_tween.is_valid():
		_pip_tween.kill()
	var target: float = 1.0 if full else 0.0
	if seconds <= 0.0:
		_pip_fill = target
		pips.set_instance_shader_parameter("fill", target)
		return
	_pip_tween = create_tween()
	_pip_tween.tween_method(func(v: float) -> void:
		_pip_fill = v
		pips.set_instance_shader_parameter("fill", v), _pip_fill, target, seconds)


func begin_drag() -> void:
	place = Place.DRAGGING
	if _plug_tween != null and _plug_tween.is_valid():
		_plug_tween.kill()


## Sürükleme: fiş dünya dönüşümü (ölçek dahil değil; fiş ölçeği ayrı).
func drag_plug_to(xform: Transform3D, scale_v: float) -> void:
	_set_plug_scale(scale_v)
	plug.global_transform = Transform3D(xform.basis.orthonormalized().scaled(Vector3.ONE * scale_v), xform.origin)


func _set_plug_scale(s: float) -> void:
	_plug_scale = s
	cable.radius = CABLE_RADIUS * clampf(s * 0.75, 1.0, 3.0)


## Fiş tepsiye geri sekip yerine oturur.
func return_plug(seconds: float = 0.32) -> void:
	place = Place.TRAY
	if _plug_tween != null and _plug_tween.is_valid():
		_plug_tween.kill()
	var from: Transform3D = plug.global_transform
	_plug_tween = create_tween()
	_plug_tween.tween_method(func(t: float) -> void:
		var x: Transform3D = from.interpolate_with(plug_rest_xform, t)
		x.origin += Vector3.UP * sin(t * PI) * 0.35
		plug.global_transform = x
		_set_plug_scale(lerpf(_plug_scale, PLUG_TRAY_SCALE, t)), 0.0, 1.0, seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lift(false)


## Fiş prize oturur: kısa çekim + oturma. `socket_xform` priz dönüşümü (+Z duvardan dışarı).
func seat_plug(socket_xform: Transform3D, seconds: float = 0.09) -> void:
	if _plug_tween != null and _plug_tween.is_valid():
		_plug_tween.kill()
	var from: Transform3D = plug.global_transform
	var from_scale: float = _plug_scale
	var target: Transform3D = Transform3D(socket_xform.basis.orthonormalized(), socket_xform.origin)
	_plug_tween = create_tween()
	_plug_tween.tween_method(func(t: float) -> void:
		var s: float = lerpf(from_scale, 1.0, t)
		var x: Transform3D = Transform3D(from.basis.orthonormalized().slerp(target.basis, t), from.origin.lerp(target.origin, t))
		drag_plug_to(x, s), 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Cihaz yay çizerek oda yerine uçar; varınca `arrived` yayılır (SliceGame cihazı çalıştırır).
func travel_to_room() -> void:
	place = Place.TRAVEL
	_lift = 0.0
	_kill_move()
	var from: Transform3D = appliance.global_transform
	_move_tween = create_tween()
	_move_tween.tween_method(func(t: float) -> void:
		appliance.global_transform = _arc(from, room_xform, t, 0.9), 0.0, 1.0, TRAVEL_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(_on_arrived)
	# Kablo uzun yolda gergin kalmasın.
	cable.slack = 1.06


func _on_arrived() -> void:
	place = Place.PLUGGED
	cable.floor_y = ROOM_FLOOR_Y
	_squash()
	arrived.emit(self)


## Varışta küçük ezilme-esneme (sesi kapalıyken de "oturdu" hissi).
func _squash() -> void:
	var base: Transform3D = room_xform
	var t: Tween = create_tween()
	t.tween_method(func(v: float) -> void:
		var sy: float = 1.0 - 0.14 * v
		var sxz: float = 1.0 + 0.08 * v
		appliance.global_transform = Transform3D(base.basis * Basis.from_scale(Vector3(sxz, sy, sxz)), base.origin),
		0.0, 1.0, 0.07).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void:
		var sy: float = 1.0 - 0.14 * v
		var sxz: float = 1.0 + 0.08 * v
		appliance.global_transform = Transform3D(base.basis * Basis.from_scale(Vector3(sxz, sy, sxz)), base.origin),
		1.0, 0.0, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Tepsiye dönüş (fiş çekildi): fiş cihazla birlikte tepsiye uçar.
func travel_to_tray() -> void:
	_unroute()
	place = Place.RETURNING
	room_socket = ""
	cable.floor_y = FREE_FLOOR_Y
	_kill_move()
	if _plug_tween != null and _plug_tween.is_valid():
		_plug_tween.kill()
	var from: Transform3D = appliance.global_transform
	var plug_from: Transform3D = plug.global_transform
	_move_tween = create_tween()
	_move_tween.tween_method(func(t: float) -> void:
		appliance.global_transform = _arc(from, tray_xform, t, 0.7)
		var px: Transform3D = _arc(plug_from, plug_rest_xform, minf(t * 1.25, 1.0), 0.5)
		plug.global_transform = px
		_set_plug_scale(lerpf(1.0, PLUG_TRAY_SCALE, t)), 0.0, 1.0, RETURN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(func() -> void:
		place = Place.TRAY
		cable.slack = 1.12
		_apply_tray())


## Seviye bitince ya da anında yerleşim (prob/çekim aracı).
func snap_plugged(socket_xform: Transform3D) -> void:
	_kill_move()
	place = Place.PLUGGED
	cable.floor_y = ROOM_FLOOR_Y
	appliance.global_transform = room_xform
	drag_plug_to(Transform3D(socket_xform.basis.orthonormalized(), socket_xform.origin), 1.0)
	cable.slack = 1.06
	cable.snap_to_rest()


## Fiş oturup cihaz yerine varınca kablo duvar diplerinden prize döşenir: cihazın fiş çıkışından duvara,
## duvar boyunca (yerdeki cihazlarda süpürgelik hizasında) prizin altına, oradan fişe. Köşeler yumuşatılır.
## Fizik ipi gizlenir ve durur (CPU tasarrufu); tepsiye dönüşte geri gelir.
func route_cable(socket: Node3D) -> void:
	if socket == null or appliance.get_plug_anchor() == null:
		return
	var a: Vector3 = appliance.get_plug_anchor().global_position
	var end: Node3D = plug.find_child("CableAnchor", true, false) as Node3D
	var b: Vector3 = end.global_position if end != null else plug.global_position
	var n: Vector3 = socket.global_basis.z.normalized()
	var back_wall: bool = absf(n.z) >= absf(n.x)
	var off: float = 0.03
	var floor_y: float = ROOM_FLOOR_Y + CABLE_RADIUS * 1.2
	var low: bool = a.y < 0.55
	var run_y: float = floor_y if low else a.y
	var pts: PackedVector3Array = PackedVector3Array()
	pts.append(a)
	var on_wall: Vector3 = a
	if back_wall:
		on_wall.z = off
	else:
		on_wall.x = off
	if low:
		pts.append(Vector3(a.x, floor_y, a.z))
		on_wall.y = floor_y
	pts.append(on_wall)
	var under: Vector3 = b
	if back_wall:
		under = Vector3(b.x, run_y, off)
	else:
		under = Vector3(off, run_y, b.z)
	pts.append(under)
	var below_plug: Vector3 = Vector3(under.x, b.y - 0.07, under.z)
	if below_plug.y > under.y:
		pts.append(below_plug)
	pts.append(b)
	pts = _smooth(_dedupe(pts), 3)
	if _route == null:
		_route = MeshInstance3D.new()
		_route.name = "RoutedCable"
		_route.top_level = true
		_route.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_route)
	_route.global_transform = Transform3D.IDENTITY
	_route.mesh = _tube(pts, CABLE_RADIUS, 8)
	_route.material_override = PLUG_MAT
	_route.visible = true
	cable.visible = false
	cable.set_process(false)
	cable.set_physics_process(false)


func _unroute() -> void:
	if _route != null:
		_route.visible = false
	cable.visible = true
	cable.set_process(true)
	cable.set_physics_process(true)


func has_routed_cable() -> bool:
	return _route != null and _route.visible


static func _dedupe(pts: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.005:
			out.append(p)
	return out


## Chaikin köşe yumuşatma (uçlar sabit).
static func _smooth(pts: PackedVector3Array, iterations: int) -> PackedVector3Array:
	var cur: PackedVector3Array = pts
	for _i: int in iterations:
		if cur.size() < 3:
			return cur
		var nxt: PackedVector3Array = PackedVector3Array()
		nxt.append(cur[0])
		for k: int in range(cur.size() - 1):
			var p0: Vector3 = cur[k]
			var p1: Vector3 = cur[k + 1]
			if k > 0:
				nxt.append(p0.lerp(p1, 0.25))
			if k < cur.size() - 2:
				nxt.append(p0.lerp(p1, 0.75))
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


static func _tube(pts: PackedVector3Array, r: float, sides: int) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = pts.size()
	var prev_normal: Vector3 = Vector3.ZERO
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	for i: int in n:
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm: Vector3 = prev_normal
		if nrm == Vector3.ZERO or absf(nrm.dot(t)) > 0.95:
			nrm = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		prev_normal = nrm
		var bin: Vector3 = t.cross(nrm).normalized()
		var ring: PackedVector3Array = PackedVector3Array()
		var rn: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			var ang: float = TAU * float(k) / float(sides)
			var dir: Vector3 = nrm * cos(ang) + bin * sin(ang)
			ring.append(pts[i] + dir * r)
			rn.append(dir)
		rings.append(ring)
		normals.append(rn)
	for i: int in range(n - 1):
		for k: int in sides:
			var k2: int = (k + 1) % sides
			for v: Array in [[i, k], [i + 1, k], [i, k2], [i, k2], [i + 1, k], [i + 1, k2]]:
				var ri: int = int(v[0])
				var ki: int = int(v[1])
				st.set_normal(normals[ri][ki])
				st.set_uv(Vector2(float(ki) / float(sides), float(ri) / float(n - 1)))
				st.add_vertex(rings[ri][ki])
	return st.commit()


## Küçük "ben buradayım" ezilmesi (sigorta nedeni, yalnız takılan gün cihazı).
func nudge() -> void:
	if place == Place.PLUGGED:
		_squash()


func is_busy() -> bool:
	return place == Place.TRAVEL or place == Place.RETURNING


## Ekranda cihazın kapladığı yaklaşık merkez (dünya) — dokunma sınaması için.
func pick_center() -> Vector3:
	var h: float = model_aabb.size.y * appliance.global_transform.basis.get_scale().y
	return appliance.global_position + Vector3.UP * h * 0.5


func pick_radius_world() -> float:
	var s: float = appliance.global_transform.basis.get_scale().x
	return maxf(model_aabb.size.x, model_aabb.size.y) * s * 0.5


## Tepsi ışığı katmanı (bit 2). Odada yalnız varsayılan katman.
const TRAY_LAYER: int = 2
const TV_TRAY_POWER: float = 0.32


func _set_tray_look(on: bool) -> void:
	if on == _tray_look:
		return
	_tray_look = on
	for node: Node in appliance.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = node as VisualInstance3D
		vi.layers = (1 | TRAY_LAYER) if on else 1
	if type == "tv":
		var screen: MeshInstance3D = appliance.mesh_part("Screen")
		if screen != null:
			screen.set_instance_shader_parameter("power", TV_TRAY_POWER if on else appliance.get_level())


func _process(delta: float) -> void:
	_time += delta
	_set_tray_look(place == Place.TRAY or place == Place.DRAGGING)
	if _hint > 0.0 and place == Place.TRAY:
		var t: Transform3D = tray_xform
		var hop: float = absf(sin(_time * 5.0))
		t.origin += Vector3.UP * hop * 0.12
		appliance.global_transform = t


func _arc(a: Transform3D, b: Transform3D, t: float, height: float) -> Transform3D:
	var x: Transform3D = a.interpolate_with(b, t)
	x.origin += Vector3.UP * sin(t * PI) * height
	return x


func _kill_move() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()


static func _model_aabb(root: Node3D) -> AABB:
	var acc: AABB = AABB()
	var first: bool = true
	var inv: Transform3D = root.transform.affine_inverse()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if String(mi.name).ends_with("_shadowonly"):
			continue
		var xf: Transform3D = inv * _local_to(root, mi)
		var a: AABB = xf * mi.get_aabb()
		acc = a if first else acc.merge(a)
		first = false
	return acc if not first else AABB(Vector3.ZERO, Vector3.ONE)


## Düğümün `root`a göre dönüşümü (ağaç dışındayken de çalışır).
static func _local_to(root: Node3D, node: Node3D) -> Transform3D:
	var x: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			x = (n as Node3D).transform * x
		n = n.get_parent()
	return root.transform * x
