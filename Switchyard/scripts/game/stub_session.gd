class_name StubSession
extends LevelSession

## Kabuğun SAHTE sahası: `DemoYard` (vektörle çizilmiş küçük manevra sahası) üstünde `LevelSession` sözleşmesini uygular.
## Oyun kipinde her dokunuş bir hamledir (saha bir adım ilerler); `solve_at` hamleye ulaşınca (varsayılan: par)
## seviye çözülür. Demo kipinde (`start_demo`) saha kendi kendine döngüde oynar: girdi yok, sinyal yok, ses yok.
## Gerçek görünüm (YardSession) geldiğinde `game.gd`/`home.gd`'deki tek KANCA bunu değiştirir.
## Sahayı bilmez: yalnız `LevelSession` yüzeyini uygular.

const HINT_SECONDS: float = 0.9
## Çözüm anından `solved` sinyaline kadar "kutlama" bekleyişi.
const CELEBRATE_SECONDS: float = 0.35
const PRESS_SECONDS: float = 0.12
const STEP_SECONDS: float = 0.55
## Oyun kipinde saha, kutunun neredeyse tamamına sığar; demoda ana ekran başlık/düğmeleri için orta bantta durur.
const PLAY_STAGE: Rect2 = Rect2(0.04, 0.05, 0.92, 0.90)
const DEMO_STAGE: Rect2 = Rect2(0.04, 0.31, 0.92, 0.45)

## Probe/geliştirme: çözümün kaç hamlede olacağı (0 = seviyenin par'ı).
var solve_at: int = 0

var _yard: DemoYard = null
var _level_id: String = ""
var _par: int = 0
var _moves: int = 0
var _input_enabled: bool = true
var _solved: bool = false
var _demo: bool = false
var _tween: Tween = null
var _step_tween: Tween = null
var _pending_solve: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_yard = DemoYard.new()
	_yard.name = "Yard"
	add_child(_yard)
	_yard.stage = PLAY_STAGE
	_apply_time(false)


func load_level(level_id: String) -> bool:
	var index: int = LevelCatalog.index_of(level_id)
	if index < 0:
		return false
	_demo = false
	_yard.stop_loop()
	_level_id = level_id
	_par = int(LevelCatalog.entries()[index].get("par", 1))
	_reset()
	return true


func start_demo(level_id: String) -> bool:
	if LevelCatalog.index_of(level_id) < 0:
		return false
	_demo = true
	_input_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_yard.stage = DEMO_STAGE
	_yard.time = DemoYard.T_START
	_yard.start_loop()
	return true


func stop_demo() -> void:
	_demo = false
	_yard.stop_loop()


func undo() -> void:
	if _solved or _moves <= 0:
		return
	_moves -= 1
	_emit_state()
	_apply_time(true)


func restart() -> void:
	_reset()


func show_hint() -> void:
	if _solved:
		hint_finished.emit()
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_hint_phase, 0.0, 1.0, HINT_SECONDS)
	_tween.tween_callback(_finish_hint)


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled and not _demo


## Probeler için: sahaya dokunmuş gibi bir hamle yapar. Dönen: işlendi mi.
func tap() -> bool:
	if _demo or not _input_enabled or _solved:
		return false
	_moves += 1
	_press_feedback()
	_emit_state()
	_apply_time(true)
	if _moves >= _target():
		_solved = true
		_pending_solve = true
		get_tree().create_timer(CELEBRATE_SECONDS).timeout.connect(_emit_solved)
	return true


func moves() -> int:
	return _moves


## Demo kipinde mi (probe/test).
func is_demo() -> bool:
	return _demo


## Koç katmanı için: lokomotifin kontrol uzayındaki konumu (gerçek görünüm ileride kesin konum verir).
func focus_point() -> Vector2:
	return _yard.loco_screen_position() if _yard != null else size * 0.5


func switch_point() -> Vector2:
	return _yard.switch_screen_position() if _yard != null else size * 0.5


func yard() -> DemoYard:
	return _yard


func _target() -> int:
	return solve_at if solve_at > 0 else maxi(_par, 1)


func _reset() -> void:
	_moves = 0
	_solved = false
	_pending_solve = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _yard != null:
		_yard.hint_phase = -1.0
	_emit_state()
	_apply_time(false)


func _emit_state() -> void:
	move_count_changed.emit(_moves, _par)
	can_undo_changed.emit(_moves > 0 and not _solved)


## Hamle sayısını saha zamanına çevirir; yumuşakça oraya akar (saha "oynar").
func _apply_time(animated: bool) -> void:
	if _yard == null or _demo:
		return
	var fraction: float = float(_moves) / float(maxi(mini(_target(), maxi(_par, 1)), 1))
	var wanted: float = DemoYard.play_time(fraction)
	if _step_tween != null and _step_tween.is_valid():
		_step_tween.kill()
	if not animated:
		_yard.time = wanted
		return
	_step_tween = create_tween()
	_step_tween.tween_property(_yard, "time", wanted, STEP_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _emit_solved() -> void:
	if not _pending_solve:
		return
	_pending_solve = false
	solved.emit({"level_id": _level_id, "moves": _moves, "par": _par})


func _finish_hint() -> void:
	if _yard != null:
		_yard.hint_phase = -1.0
	hint_finished.emit()


func _set_hint_phase(value: float) -> void:
	if _yard != null:
		_yard.hint_phase = value


func _press_feedback() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_yard, "press", 0.0, PRESS_SECONDS).from(1.0)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		tap()
