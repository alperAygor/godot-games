class_name WorldGrid
extends Control

## Bir dünyanın karo ızgarası: TEK düğüm, tüm karolar tek `_draw` ile (yüzlerce seviyede düğüm sayısı dünya sayısıyla
## büyür, seviye sayısıyla değil). Dokunma kendi içinde çözülür: basış + bırakış aynı karodaysa ve parmak
## kaymadıysa `tile_pressed`. Kaydırma ScrollContainer'a geçer (fare filtresi PASS, olay tüketilmez).
## Şimdiki karonun üstünde ayrı küçük bir halka düğümü atar (yalnız o yeniden çizilir).

signal tile_pressed(index: int)

const DEADZONE: float = 24.0
const RING_SECONDS: float = 1.6
const RING_GROW: float = 14.0
const RING_WIDTH: float = 6.0

var _entries: Array[Dictionary] = []
var _accent: Color = UiKit.ACCENT
var _tile_size: Vector2 = Vector2.ZERO
var _columns: int = UiTokens.SIZE_COLUMNS
var _gap: float = float(UiTokens.SIZE_TILE_GAP)
var _down_index: int = -1
var _down_position: Vector2 = Vector2.ZERO
var _press_amount: float = 0.0
var _ring: Control = null
var _ring_phase: float = 0.0


## entries: { id, number, mode, stars, difficulty }; width: izgaranın genişliği (px).
func setup(entries: Array[Dictionary], accent: Color, width: float) -> void:
	_entries = entries
	_accent = accent
	mouse_filter = Control.MOUSE_FILTER_PASS
	var tile_width: float = floorf((width - _gap * float(_columns - 1)) / float(_columns))
	_tile_size = Vector2(tile_width, float(UiTokens.H_MAP_TILE))
	var rows: int = ceili(float(entries.size()) / float(_columns))
	custom_minimum_size = Vector2(width, float(rows) * _tile_size.y + float(maxi(rows - 1, 0)) * _gap)
	queue_redraw()
	_refresh_ring()


func tile_count() -> int:
	return _entries.size()


func mode_at(index: int) -> LevelTile.Mode:
	return _entries[index]["mode"] as LevelTile.Mode


func id_at(index: int) -> String:
	return str(_entries[index]["id"])


func index_of_id(level_id: String) -> int:
	for index: int in _entries.size():
		if str(_entries[index]["id"]) == level_id:
			return index
	return -1


func tile_rect(index: int) -> Rect2:
	var column: int = index % _columns
	var row: int = index / _columns
	return Rect2(Vector2(float(column) * (_tile_size.x + _gap), float(row) * (_tile_size.y + _gap)), _tile_size)


func current_index() -> int:
	for index: int in _entries.size():
		if _entries[index]["mode"] == LevelTile.Mode.CURRENT:
			return index
	return -1


func _draw() -> void:
	for index: int in _entries.size():
		var entry: Dictionary = _entries[index]
		LevelTile.paint(self, tile_rect(index), int(entry["number"]), entry["mode"] as LevelTile.Mode,
			int(entry["stars"]), int(entry["difficulty"]), _accent, _press_amount if index == _down_index else 0.0)


func _tile_at(point: Vector2) -> int:
	if _tile_size.x <= 0.0:
		return -1
	var column: int = int(point.x / (_tile_size.x + _gap))
	var row: int = int(point.y / (_tile_size.y + _gap))
	var index: int = row * _columns + column
	if column < 0 or column >= _columns or point.x < 0.0 or point.y < 0.0 or index >= _entries.size():
		return -1
	return index if tile_rect(index).has_point(point) else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			_begin(button.position)
		else:
			_end(button.position)
	elif event is InputEventMouseMotion and _down_index >= 0:
		if (event as InputEventMouseMotion).position.distance_to(_down_position) > DEADZONE:
			_cancel()


func _begin(point: Vector2) -> void:
	_down_index = _tile_at(point)
	_down_position = point
	if _down_index >= 0:
		_animate_press(1.0)


func _end(point: Vector2) -> void:
	var index: int = _down_index
	if index < 0:
		return
	var inside: bool = _tile_at(point) == index and point.distance_to(_down_position) <= DEADZONE
	_animate_press(0.0)
	_down_index = -1 if not inside else index
	if inside:
		UiKit.tap_sound()
		tile_pressed.emit(index)
	_down_index = -1
	queue_redraw()


func _cancel() -> void:
	_animate_press(0.0)
	_down_index = -1
	queue_redraw()


func _animate_press(target: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_press, _press_amount, target, UiTokens.MOTION_PRESS_SECONDS)


func _set_press(value: float) -> void:
	_press_amount = value
	queue_redraw()


## Şimdiki karonun halkası: yavaşça genişleyip silinen yumuşak çizgi (az harekette durağan ince halka).
func _refresh_ring() -> void:
	if _ring != null:
		_ring.queue_free()
		_ring = null
	var index: int = current_index()
	if index < 0:
		return
	_ring = Ring.new()
	_ring.name = "CurrentRing"
	(_ring as Ring).grid = self
	_ring.position = tile_rect(index).position
	_ring.size = _tile_size
	add_child(_ring)
	if UiData.reduced_motion():
		_ring_phase = 0.0
		return
	var tween: Tween = create_tween().set_loops()
	tween.tween_method(_set_ring, 0.0, 1.0, RING_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_ring(value: float) -> void:
	_ring_phase = value
	if _ring != null:
		_ring.queue_redraw()


class Ring extends Control:
	var grid: WorldGrid = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if grid == null:
			return
		var phase: float = grid._ring_phase
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.draw_center = false
		box.set_border_width_all(int(RING_WIDTH))
		box.border_color = Color(UiKit.ACCENT, (1.0 - phase) * 0.55 if phase > 0.0 else 0.4)
		box.set_corner_radius_all(UiKit.RADIUS_TILE + int(RING_GROW * phase))
		box.anti_aliasing = true
		var grow: float = RING_GROW * phase
		draw_style_box(box, Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2.0))
