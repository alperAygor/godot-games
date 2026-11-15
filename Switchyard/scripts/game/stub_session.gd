class_name StubSession
extends LevelSession

## Kabuğun kendi probeları için SAHTE saha: büyük, dokunulabilir tek panel. Her dokunuş bir hamledir;
## `solve_at` hamleye ulaşınca seviye çözülür (varsayılan: seviyenin par'ı). Geri al / baştan başlat /
## ipucu sözleşmeye uygun çalışır. Gerçek saha görünümü (YardSession) geldiğinde `game.gd`
## içindeki tek KANCA bunu değiştirir; bu dosya yalnız probe ve geliştirme içindir.
## Sahayı bilmez: yalnız `LevelSession` yüzeyini uygular.

const PANEL_RADIUS: int = UiTokens.RADIUS_CARD
const PANEL_MARGIN: float = UiKit.SPACE_XL
const DOT_SIZE: float = 28.0
const DOT_GAP: float = 20.0
const DOT_ROWS_MAX: int = 12
const RING_WIDTH: float = 10.0
const HINT_SECONDS: float = 0.9
## Çözüm anından `solved` sinyaline kadar "kutlama" bekleyişi.
const CELEBRATE_SECONDS: float = 0.35
const PRESS_SECONDS: float = 0.12
const ICON_NAME: String = "lucide/play"

## Probe/geliştirme: çözümün kaç hamlede olacağı (0 = seviyenin par'ı).
var solve_at: int = 0

var _level_id: String = ""
var _par: int = 0
var _moves: int = 0
var _input_enabled: bool = true
var _solved: bool = false
var _hint_phase: float = -1.0
var _press: float = 0.0
var _tween: Tween = null
var _pending_solve: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func load_level(level_id: String) -> bool:
	var index: int = LevelCatalog.index_of(level_id)
	if index < 0:
		return false
	_level_id = level_id
	_par = int(LevelCatalog.entries()[index].get("par", 1))
	_reset()
	return true


func undo() -> void:
	if _solved or _moves <= 0:
		return
	_moves -= 1
	_emit_state()


func restart() -> void:
	_reset()


func show_hint() -> void:
	if _solved:
		hint_finished.emit()
		return
	_hint_phase = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_hint_phase, 0.0, 1.0, HINT_SECONDS)
	_tween.tween_callback(_finish_hint)


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


## Probeler için: panele dokunmuş gibi bir hamle yapar. Dönen: işlendi mi.
func tap() -> bool:
	if not _input_enabled or _solved:
		return false
	_moves += 1
	_press_feedback()
	_emit_state()
	if _moves >= _target():
		_solved = true
		_pending_solve = true
		get_tree().create_timer(CELEBRATE_SECONDS).timeout.connect(_emit_solved)
	return true


func moves() -> int:
	return _moves


func _target() -> int:
	return solve_at if solve_at > 0 else maxi(_par, 1)


func _reset() -> void:
	_moves = 0
	_solved = false
	_pending_solve = false
	_hint_phase = -1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_emit_state()
	queue_redraw()


func _emit_state() -> void:
	move_count_changed.emit(_moves, _par)
	can_undo_changed.emit(_moves > 0 and not _solved)
	queue_redraw()


func _emit_solved() -> void:
	if not _pending_solve:
		return
	_pending_solve = false
	solved.emit({"level_id": _level_id, "moves": _moves, "par": _par})


func _finish_hint() -> void:
	_hint_phase = -1.0
	queue_redraw()
	hint_finished.emit()


func _set_hint_phase(value: float) -> void:
	_hint_phase = value
	queue_redraw()


func _press_feedback() -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_press, 1.0, 0.0, PRESS_SECONDS)


func _set_press(value: float) -> void:
	_press = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		tap()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size).grow(-PANEL_MARGIN)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT_SOFT.lerp(UiKit.ACCENT, _press * 0.6)
	box.set_corner_radius_all(PANEL_RADIUS)
	box.anti_aliasing = true
	draw_style_box(box, rect)
	var center: Vector2 = rect.get_center()
	var icon: Texture2D = Icons.texture(ICON_NAME)
	if icon != null:
		var half: float = UiKit.ICON_LG * (1.0 + _press * 0.15)
		draw_texture_rect(icon, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false,
			Color(UiKit.ACCENT, 0.9))
	if _hint_phase >= 0.0:
		var radius: float = lerpf(UiKit.DISC_LG, minf(rect.size.x, rect.size.y) * 0.45, _hint_phase)
		draw_arc(center, radius, 0.0, TAU, 64, Color(UiKit.FLAME, 1.0 - _hint_phase), RING_WIDTH, true)
	# Hamle noktaları: doldurulan = yapılan hamle, boş halka = par'a kalan.
	var total: int = mini(_target(), DOT_ROWS_MAX)
	var row_width: float = float(total) * DOT_SIZE + float(total - 1) * DOT_GAP
	var start: Vector2 = Vector2(center.x - row_width * 0.5 + DOT_SIZE * 0.5, rect.end.y - PANEL_MARGIN - DOT_SIZE)
	for index: int in total:
		var at: Vector2 = start + Vector2(float(index) * (DOT_SIZE + DOT_GAP), 0.0)
		if index < _moves:
			draw_circle(at, DOT_SIZE * 0.5, UiKit.ACCENT, true, -1.0, true)
		else:
			draw_arc(at, DOT_SIZE * 0.5 - 2.0, 0.0, TAU, 24, Color(UiKit.ACCENT, 0.45), 4.0, true)
