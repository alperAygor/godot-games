class_name GridController
extends Node3D

## Çanta ızgarası (4x5) — sürükle-bırak, hücre parıltısı ve squash & stretch.
##
## Sahne yerleşimi: bu düğümün origin'i çantanın taban merkezidir; hücre
## koordinatları modelin iç ölçüleriyle birebir aynıdır (assets/models/README.md).
##
## Dokunmatik giriş tek yerden yönetilir: paketler `draggable` grubundadır,
## bu sınıf nerede durduklarını bilmek zorunda değildir.

signal package_placed(package: Package, cell: Vector2i)
signal package_returned(package: Package)
signal hover_changed(cell: Vector2i, valid: bool)

const COLS: int = 4
const ROWS: int = 5
const CELL: float = 0.075
const GRID_W: float = COLS * CELL          # 0.300 m
const GRID_H: float = ROWS * CELL          # 0.375 m
const CELL_PLANE_Z: float = 0.048          # paketin oturduğu derinlik
const GLOW_PLANE_Z: float = 0.091          # parıltı, paketlerin önünde kalır

const INVALID_CELL: Vector2i = Vector2i(-1, -1)

const COLOR_FREE: Color = Color(0.36, 1.0, 0.60)
const COLOR_FULL: Color = Color(1.0, 0.34, 0.32)
const ALPHA_IDLE_FREE: float = 0.18
const ALPHA_IDLE_FULL: float = 0.22
const ALPHA_HOVER: float = 0.85
## Vurgulanan hücrenin parıltısı hücreden taşar; sürüklenen paket hücreyi
## kapattığı için halka şeklinde etrafında görünür.
const HOVER_GLOW_SCALE: float = 1.6

## Squash & stretch eğrisi: sert iniş -> yaylanma -> durulma.
const SQUASH_SCALE: Vector3 = Vector3(1.26, 0.68, 1.26)
const STRETCH_SCALE: Vector3 = Vector3(0.94, 1.13, 0.94)

@export var pick_radius_px: float = 165.0
@export var settle_time: float = 0.17

var _glows: Array[MeshInstance3D] = []
var _glow_mats: Array[StandardMaterial3D] = []
var _occupied: Array[bool] = []
var _tweens: Dictionary[int, Tween] = {}

var _dragging: Package = null
var _drag_plane: Plane = Plane()
var _drag_offset: Vector3 = Vector3.ZERO
var _hover: Vector2i = INVALID_CELL
var _hover_valid: bool = false
var _glow_texture: GradientTexture2D = null


func _ready() -> void:
	_occupied.resize(COLS * ROWS)
	_occupied.fill(false)
	_build_cells()
	_refresh_glows()


# --------------------------------------------------------------------------
# giriş
# --------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_begin_drag(touch.position)
		else:
			_end_drag(touch.position)
		return
	if event is InputEventScreenDrag:
		if _dragging != null:
			_update_drag((event as InputEventScreenDrag).position)


func _begin_drag(screen_pos: Vector2) -> void:
	if _dragging != null:
		return
	var picked: Package = _pick_package(screen_pos)
	if picked == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		push_error("GridController: sahnede etkin Camera3D yok")
		return

	_dragging = picked
	# Parmakla paket arasındaki mesafeyi korumak için kameraya paralel bir düzlem.
	var normal: Vector3 = -camera.global_transform.basis.z
	_drag_plane = Plane(normal, normal.dot(picked.global_position))
	var hit: Variant = _ray_plane(screen_pos, _drag_plane)
	_drag_offset = Vector3.ZERO
	if hit is Vector3:
		_drag_offset = picked.global_position - (hit as Vector3)

	_kill_tween(picked)
	var lift: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(picked, "scale", picked.home_scale * 1.12, 0.13)
	_refresh_glows()


func _update_drag(screen_pos: Vector2) -> void:
	if _dragging == null:
		return
	var hit: Variant = _ray_plane(screen_pos, _drag_plane)
	if hit is Vector3:
		_dragging.global_position = (hit as Vector3) + _drag_offset
	var cell: Vector2i = _cell_at(screen_pos)
	var valid: bool = cell != INVALID_CELL and _can_place(_dragging, cell)
	if cell != _hover or valid != _hover_valid:
		_hover = cell
		_hover_valid = valid
		_refresh_glows()
		hover_changed.emit(_hover, _hover_valid)


func _end_drag(screen_pos: Vector2) -> void:
	if _dragging == null:
		return
	var pkg: Package = _dragging
	_dragging = null
	var cell: Vector2i = _cell_at(screen_pos)
	if cell != INVALID_CELL and _can_place(pkg, cell):
		_place(pkg, cell)
	else:
		_return_home(pkg)
	_hover = INVALID_CELL
	_hover_valid = false
	_refresh_glows()


# --------------------------------------------------------------------------
# yerleştirme
# --------------------------------------------------------------------------
func _can_place(pkg: Package, cell: Vector2i) -> bool:
	var origin: Vector2i = _anchor(cell, pkg.footprint)
	if not _fits(origin, pkg.footprint):
		return false
	for y: int in pkg.footprint.y:
		for x: int in pkg.footprint.x:
			if _occupied[_index(origin + Vector2i(x, y))]:
				return false
	return true


func _place(pkg: Package, cell: Vector2i) -> void:
	var origin: Vector2i = _anchor(cell, pkg.footprint)
	for y: int in pkg.footprint.y:
		for x: int in pkg.footprint.x:
			_occupied[_index(origin + Vector2i(x, y))] = true

	var target: Vector3 = to_global(_anchor_local(origin, pkg.footprint))
	_kill_tween(pkg)

	# 1) hücreye süzülme, 2) tabana oturunca squash & stretch
	var move: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[pkg.get_instance_id()] = move
	move.tween_property(pkg, "global_position", target, settle_time)
	move.tween_callback(_squash_and_stretch.bind(pkg))

	_flash_cell(origin, pkg.footprint)
	package_placed.emit(pkg, origin)


func _return_home(pkg: Package) -> void:
	_kill_tween(pkg)
	var t: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tweens[pkg.get_instance_id()] = t
	t.tween_property(pkg, "global_position", pkg.home_position, 0.24)
	t.parallel().tween_property(pkg, "scale", pkg.home_scale, 0.20)
	package_returned.emit(pkg)


func _squash_and_stretch(pkg: Package) -> void:
	if not is_instance_valid(pkg):
		return
	_kill_tween(pkg)
	var t: Tween = create_tween()
	_tweens[pkg.get_instance_id()] = t
	# İniş: Y'de ezil, XZ'de taş — origin tabanda olduğu için "yere yapışır".
	t.tween_property(pkg, "scale", SQUASH_SCALE, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Ters yaylanma
	t.tween_property(pkg, "scale", STRETCH_SCALE, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Durulma
	t.tween_property(pkg, "scale", pkg.home_scale, 0.24) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --------------------------------------------------------------------------
# ızgara yardımcıları
# --------------------------------------------------------------------------
func _index(cell: Vector2i) -> int:
	return cell.y * COLS + cell.x


func _anchor(cell: Vector2i, footprint: Vector2i) -> Vector2i:
	return cell - Vector2i((footprint.x - 1) / 2, (footprint.y - 1) / 2)


func _fits(origin: Vector2i, footprint: Vector2i) -> bool:
	return origin.x >= 0 and origin.y >= 0 \
		and origin.x + footprint.x <= COLS and origin.y + footprint.y <= ROWS


func _anchor_local(origin: Vector2i, footprint: Vector2i) -> Vector3:
	return Vector3(
		-GRID_W * 0.5 + (float(origin.x) + float(footprint.x) * 0.5) * CELL,
		float(origin.y) * CELL,
		CELL_PLANE_Z)


func _cell_center_local(cell: Vector2i) -> Vector3:
	return Vector3(
		-GRID_W * 0.5 + (float(cell.x) + 0.5) * CELL,
		(float(cell.y) + 0.5) * CELL,
		GLOW_PLANE_Z)


func _cell_at(screen_pos: Vector2) -> Vector2i:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return INVALID_CELL
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var local_from: Vector3 = to_local(from)
	var local_dir: Vector3 = global_transform.basis.inverse() * dir
	if absf(local_dir.z) < 0.0001:
		return INVALID_CELL
	var t: float = (CELL_PLANE_Z - local_from.z) / local_dir.z
	if t <= 0.0:
		return INVALID_CELL
	var hit: Vector3 = local_from + local_dir * t
	var x: int = int(floor((hit.x + GRID_W * 0.5) / CELL))
	var y: int = int(floor(hit.y / CELL))
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return INVALID_CELL
	return Vector2i(x, y)


func _pick_package(screen_pos: Vector2) -> Package:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null
	var best: Package = null
	var best_dist: float = pick_radius_px
	for node: Node in get_tree().get_nodes_in_group(Package.GROUP_DRAGGABLE):
		var pkg: Package = node as Package
		if pkg == null or pkg == _dragging:
			continue
		if camera.is_position_behind(pkg.global_position):
			continue
		var dist: float = camera.unproject_position(pkg.global_position).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = pkg
	return best


func _ray_plane(screen_pos: Vector2, plane: Plane) -> Variant:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null
	return plane.intersects_ray(camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos))


# --------------------------------------------------------------------------
# görsel geri bildirim
# --------------------------------------------------------------------------
func _build_cells() -> void:
	var root: Node3D = get_node_or_null("Cells") as Node3D
	if root == null:
		push_error("GridController: 'Cells' düğümü bulunamadı")
		return
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(CELL * 0.94, CELL * 0.94)
	var mat_tex: Texture2D = _make_glow_texture()
	for y: int in ROWS:
		for x: int in COLS:
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_texture = mat_tex
			mat.albedo_color = Color(COLOR_FREE.r, COLOR_FREE.g, COLOR_FREE.b, ALPHA_IDLE_FREE)
			mat.disable_receive_shadows = true
			mat.no_depth_test = false

			var glow: MeshInstance3D = MeshInstance3D.new()
			glow.name = "Cell_%d_%d" % [x, y]
			glow.mesh = quad
			glow.material_override = mat
			glow.position = _cell_center_local(Vector2i(x, y))
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			glow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			root.add_child(glow)
			_glows.append(glow)
			_glow_mats.append(mat)


func _make_glow_texture() -> GradientTexture2D:
	if _glow_texture != null:
		return _glow_texture
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_glow_texture = tex
	return tex


func _refresh_glows() -> void:
	if _glow_mats.is_empty():
		return
	var highlighted: Array[Vector2i] = []
	if _dragging != null and _hover != INVALID_CELL:
		var fp: Vector2i = _dragging.footprint
		var origin: Vector2i = _anchor(_hover, fp)
		if _fits(origin, fp):
			for y: int in fp.y:
				for x: int in fp.x:
					highlighted.append(origin + Vector2i(x, y))
		else:
			highlighted.append(_hover)

	for i: int in _glow_mats.size():
		var cell: Vector2i = Vector2i(i % COLS, i / COLS)
		var color: Color
		var alpha: float
		var is_highlighted: bool = highlighted.has(cell)
		if is_highlighted:
			color = COLOR_FREE if _hover_valid else COLOR_FULL
			alpha = ALPHA_HOVER
		elif _occupied[i]:
			color = COLOR_FULL
			alpha = ALPHA_IDLE_FULL
		else:
			color = COLOR_FREE
			alpha = ALPHA_IDLE_FREE
		_glow_mats[i].albedo_color = Color(color.r, color.g, color.b, alpha)
		_glows[i].scale = Vector3.ONE * (HOVER_GLOW_SCALE if is_highlighted else 1.0)


func _flash_cell(origin: Vector2i, footprint: Vector2i) -> void:
	for y: int in footprint.y:
		for x: int in footprint.x:
			var cell: Vector2i = origin + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
				continue
			var glow: MeshInstance3D = _glows[_index(cell)]
			glow.scale = Vector3(1.45, 1.45, 1.0)
			var t: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(glow, "scale", Vector3.ONE, 0.32)


# --------------------------------------------------------------------------
# yardımcılar
# --------------------------------------------------------------------------
func _kill_tween(pkg: Node) -> void:
	var id: int = pkg.get_instance_id()
	var tween: Tween = _tweens.get(id)
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens.erase(id)


func occupied_count() -> int:
	var n: int = 0
	for filled: bool in _occupied:
		if filled:
			n += 1
	return n
