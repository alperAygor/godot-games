class_name GameInput
extends RefCounted

## Dokunma -> sürükleme girişi: ekran rayini panonun önündeki drag düzlemine
## çevirir, grab_radius içindeki fişi seçer, hedefi LevelController'a aktarır.
## Kamera paralaksı ve fiş highlight'i da burada; ses/HUD game.gd'de.

signal grabbed(cable_index: int)

const PARALLAX_HALF_EXTENTS: Vector2 = Vector2(0.85, 1.55)

var _camera: CameraRig = null
var _level: LevelController = null
const DEFAULT_BOUNDS: Rect2 = Rect2(-0.85, -1.55, 1.7, 3.1)
const BOUNDS_MARGIN: float = 0.02

var _drag_plane: Plane = Plane(Vector3.BACK, 0.3)
var _bounds: Rect2 = DEFAULT_BOUNDS
var _touch_index: int = -1
var _drag_cable: int = -1
var _enabled: bool = true


func setup(camera: CameraRig, level: LevelController, drag_lift: float,
		board_bounds: Rect2 = DEFAULT_BOUNDS) -> void:
	_camera = camera
	_level = level
	_drag_plane = Plane(Vector3.BACK, drag_lift)
	_bounds = board_bounds


func set_enabled(on: bool) -> void:
	_enabled = on


func is_dragging() -> bool:
	return _drag_cable >= 0


## false dönerse olay işlenmedi (başka sistemler dinleyebilir).
func handle_event(event: InputEvent) -> bool:
	if not _enabled or _level == null or _camera == null:
		return false
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and touch.index == 0:
			return _begin(touch.position)
		if not touch.pressed and touch.index == _touch_index:
			_release()
			return true
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			_move(drag.position)
			return true
	return false


## Fail/pause anında sürüklemeyi bırak ve highlight'i temizle.
func cancel() -> void:
	if _drag_cable >= 0 and _drag_cable < _level.cables.size():
		_level.cables[_drag_cable].highlight(false)
	_drag_cable = -1
	_touch_index = -1
	_level.end_drag()
	if _camera != null:
		_camera.reset_parallax()


func _begin(screen_position: Vector2) -> bool:
	var point: Vector3 = _clamp_to_board(_plane_point(screen_position))
	var cable_index: int = _level.pick_cable(point)
	if cable_index < 0:
		return false
	if not _level.begin_drag(cable_index, point):
		return false
	_touch_index = 0
	_drag_cable = cable_index
	_level.cables[cable_index].highlight(true)
	grabbed.emit(cable_index)
	return true


func _move(screen_position: Vector2) -> void:
	if _drag_cable < 0:
		return
	var point: Vector3 = _clamp_to_board(_plane_point(screen_position))
	_level.update_drag(point)
	_camera.set_parallax(Vector2(point.x / PARALLAX_HALF_EXTENTS.x,
		point.y / PARALLAX_HALF_EXTENTS.y))


func _release() -> void:
	if _drag_cable >= 0 and _drag_cable < _level.cables.size():
		_level.cables[_drag_cable].highlight(false)
	_drag_cable = -1
	_touch_index = -1
	if _camera != null:
		_camera.reset_parallax()
	_level.end_drag()


## Sürükleme hedefi panonun dışına (HUD üstüne / ekran dışına) taşmasın.
func _clamp_to_board(point: Vector3) -> Vector3:
	if _bounds.size == Vector2.ZERO:
		return point
	return Vector3(
		clampf(point.x, _bounds.position.x + BOUNDS_MARGIN, _bounds.end.x - BOUNDS_MARGIN),
		clampf(point.y, _bounds.position.y + BOUNDS_MARGIN, _bounds.end.y - BOUNDS_MARGIN),
		point.z)


## Ekran noktasını drag düzlemine (z = drag_lift) ışınlar.
## LevelController RefCounted'tır (get_tree yok); kamera ağaçtaki CameraRig'den alınır.
func _plane_point(screen_position: Vector2) -> Vector3:
	if _camera == null or not _camera.is_inside_tree():
		return Vector3.ZERO
	var camera: Camera3D = _camera.get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.ZERO
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	if absf(direction.z) < 0.00001:
		return Vector3.ZERO
	var travel: float = (_drag_plane.d - origin.z) / direction.z
	return origin + direction * travel
