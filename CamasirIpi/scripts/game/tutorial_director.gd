class_name TutorialDirector
extends Node

## Öğretici yönetmeni. `game.gd` yalnız üç kanca çağırır (`on_level_started`, `on_tap`,
## `input_blocked`); tüm mantık burada. Neden ayrı düğüm: ekran betiği büyümesin, dallar
## birleşirken çakışma çıkmasın.
##
## Üç iş yapar: (1) ilk seviyelerde el imleciyle rehberlik, (2) yeni mekanik/güçlendirici
## ilk göründüğünde tek seferlik tanıtım kartı, (3) boşta kalınca yumuşak ipucu halkası.
## İpuçları hiçbir zaman girdiyi engellemez; yanlış dokunuş serbesttir. Kart yalnız açıkken
## `input_blocked` true olur.

const FLAG_CARD: String = "tut_card_%s"
const LOCAL_SEEN_PATH: String = "user://tutorial.cfg"
const LOCAL_SEEN_SECTION: String = "seen"
const PROGRESS_NODE: NodePath = ^"/root/Progress"
const SOLVER_NODE_LIMIT: int = 20000
const TARGET_Y_RATIO: float = 0.42
const GLOW_PAD: float = 14.0
const RACK_GLOW_HALF_HEIGHT: float = 100.0
const RACK_GLOW_SIDE: float = 105.0
const QUEUE_GLOW_STEP: float = 60.0
const QUEUE_GLOW_PAD: float = 56.0
const QUEUE_GLOW_HALF_HEIGHT: float = 38.0
const RACK_PRAISE_DELAY: float = 0.7
const PLAYING_PROP: StringName = &"_playing"
const PERSIST_PROP: StringName = &"_persist"
const DEFAULT_QUEUE_Y: float = 1800.0
const DEFAULT_IDLE_FIRST: float = 8.0
const DEFAULT_IDLE_REPEAT: float = 15.0

## Kapalı (kart açıkken true): oyun girdiyi bu bayrağa bakıp yutar.
var input_blocked: bool = false
## Probe/araçlar kapatabilir. Başsız (headless) çalışmada zaten kapalı sayılır.
var enabled: bool = true

var _game: Node = null
var _level: Dictionary = {}
var _board: LaundryBoard = null
var _views: Dictionary = {}
var _rack_points: Array[Vector2] = []
var _level_number: int = 0
var _generation: int = 0
var _active: bool = false
var _persist: bool = true
var _history: Array[int] = []
var _plan: Array[int] = []
var _script: Dictionary = {}
var _timing: Dictionary = {}
var _idle_spec: Dictionary = {}
var _hand: TutorialHand = null
var _glow: TutorialGlow = null
var _card: TutorialCard = null
var _memory_seen: Dictionary = {}
var _palette: Array[Color] = []
var _center_x: float = 540.0
var _queue_y: float = DEFAULT_QUEUE_Y
## Rehber durumu.
var _guide_done: bool = false
var _guide_ready: bool = false
var _hand_shown: bool = false
var _taps_done: int = 0
var _ignored: int = 0
var _stage: int = 0
var _follow_taps: int = 0
var _covered_id: int = LaundryBoard.EMPTY
var _rack_taught: bool = false
var _idle_seconds: float = 0.0
var _idle_hints_given: int = 0


func _ready() -> void:
	_game = get_parent()
	_hand = TutorialHand.new()
	add_child(_hand)
	_glow = TutorialGlow.new()
	add_child(_glow)
	set_process(false)


## Hata ayıklama/araç: bu bayrakları "görüldü" say (kart ve tek seferlik vurgular çıkmaz).
func preseed_seen(flags: Array[String]) -> void:
	for flag: String in flags:
		_mark_seen(flag)


# --- Kancalar ---------------------------------------------------------------------------------

func on_level_started(level: Dictionary, board: LaundryBoard, views: Dictionary,
		baskets: Array[BasketView], rack_points: Array[Vector2]) -> void:
	_generation += 1
	_reset()
	_level = level
	_board = board
	_views = views
	_rack_points = rack_points
	_level_number = int(level.get("level", 1))
	_persist = bool(_game.get(PERSIST_PROP)) if _game != null else false
	_active = enabled and DisplayServer.get_name() != "headless" and not TutorialFeatures.table().is_empty()
	if not _active:
		return
	var table: Dictionary = TutorialFeatures.table()
	_timing = table.get("timing", {}) as Dictionary
	_idle_spec = table.get("idle", {}) as Dictionary
	_script = (table.get("levels", {}) as Dictionary).get(str(_level_number), {}) as Dictionary
	_read_game_layout(baskets)
	# `_process` yalnız boşta ipucunu sayar; ipucu verilmeyen seviyelerde (below_level ve üstü)
	# her kare boşuna işlenmesin.
	set_process(float(_level_number) < float(_idle_spec.get("below_level", 0)))
	_start(_generation)


## Oyuncunun her geçerli/geçersiz dokunuşu. `events`: tahtanın döndürdüğü olaylar.
func on_tap(id: int, events: Array[Dictionary]) -> void:
	if not _active or events.is_empty():
		return
	_idle_seconds = 0.0
	_glow.hide_now()
	var first: String = String(events[0]["type"])
	var accepted: bool = first != LaundryBoard.EVENT_BLOCKED and first != LaundryBoard.EVENT_LOCKED \
		and first != LaundryBoard.EVENT_RACK_FULL
	if accepted:
		_history.append(id)
	var was_shown: bool = _hand_shown
	_hide_hand()
	if _board.is_over():
		_guide_done = true
		return
	if _guide_done or not _guide_ready or _script.is_empty():
		return
	match String(_script.get("mode", "")):
		"follow":
			_after_follow_tap(accepted, was_shown)
		"layers":
			_after_layers_tap(id, first, accepted)
		"rack":
			_after_rack_tap(events, accepted)


func _process(delta: float) -> void:
	if not _active or input_blocked or _board == null or _board.is_over() or _hand_shown:
		return
	if not _guide_ready or bool(_game.get(PLAYING_PROP)):
		return
	var limit: float = float(_idle_spec.get("below_level", 0))
	if float(_level_number) >= limit:
		return
	_idle_seconds += delta
	var wait: float = float(_idle_spec.get("first_seconds", DEFAULT_IDLE_FIRST)) if _idle_hints_given == 0 \
		else float(_idle_spec.get("repeat_seconds", DEFAULT_IDLE_REPEAT))
	if _idle_seconds >= wait:
		_idle_seconds = 0.0
		_idle_hints_given += 1
		_idle_hint()


# --- Başlangıç --------------------------------------------------------------------------------

func _reset() -> void:
	_hide_hand()
	if _glow != null:
		_glow.hide_now()
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	input_blocked = false
	_history.clear()
	_plan.clear()
	_guide_done = false
	_guide_ready = false
	_taps_done = 0
	_ignored = 0
	_stage = 0
	_follow_taps = 0
	_covered_id = LaundryBoard.EMPTY
	_rack_taught = false
	_idle_seconds = 0.0
	_idle_hints_given = 0
	set_process(false)


func _read_game_layout(baskets: Array[BasketView]) -> void:
	var constants: Dictionary = {}
	if _game != null and _game.get_script() != null:
		constants = (_game.get_script() as Script).get_script_constant_map()
	_queue_y = float(constants.get("QUEUE_Y", DEFAULT_QUEUE_Y))
	_palette.clear()
	for entry: Variant in constants.get("COLORS", []) as Array:
		_palette.append(entry as Color)
	_center_x = _game.get_viewport_rect().size.x * 0.5
	if not baskets.is_empty():
		_center_x = baskets[0].rest_position.x + (baskets[baskets.size() - 1].rest_position.x - baskets[0].rest_position.x) * 0.5


## Seviye açılışı: önce (varsa) tanıtım kartı, kapanınca rehber. Her bekleme sonrası nesil
## kontrol edilir; oyuncu bu arada seviyeyi yeniden başlattıysa eski akış sessizce biter.
func _start(generation: int) -> void:
	await get_tree().create_timer(float(_timing.get("start_delay", 0.9))).timeout
	if generation != _generation:
		return
	var feature: String = _next_unseen_card()
	if not feature.is_empty():
		await get_tree().create_timer(float(_timing.get("card_delay", 0.45))).timeout
		if generation != _generation:
			return
		await _show_card(feature)
		if generation != _generation:
			return
	_guide_ready = true
	_begin_guide()


func _next_unseen_card() -> String:
	for feature: String in TutorialFeatures.detect(_level):
		if not _is_seen(FLAG_CARD % feature):
			return feature
	return ""


func _show_card(feature: String) -> void:
	var spec: Dictionary = (TutorialFeatures.table().get("cards", {}) as Dictionary).get(feature, {}) as Dictionary
	_card = TutorialCard.new()
	add_child(_card)
	_card.setup(feature, spec, _palette)
	input_blocked = true
	await _card.dismissed
	input_blocked = false
	_mark_seen(FLAG_CARD % feature)
	_card = null
	_idle_seconds = 0.0


# --- Rehber -----------------------------------------------------------------------------------

func _begin_guide() -> void:
	match String(_script.get("mode", "")):
		"follow":
			_show_hand_on(_next_id())
		"layers":
			_covered_id = _pick_covered()
			_stage = 0
			_show_hand_on(_covered_id if _covered_id != LaundryBoard.EMPTY else _next_id())
		"rack":
			_show_hand_on(_rack_target())
		"queue":
			_queue_glow()


func _after_follow_tap(accepted: bool, was_shown: bool) -> void:
	if accepted:
		_taps_done += 1
	if not was_shown:
		_ignored += 1
	if _taps_done >= int(_script.get("max_taps", 3)) or _ignored >= int(_script.get("ignore_limit", 2)):
		_guide_done = true
		return
	_return_hand(_generation, _next_id)


## Katman dersi: önce örtülü çamaşır (dokununca sallanır, örten parlar), sonra örten, sonra
## birkaç çözücü adımı. Oyuncu sırayı kendisi atlarsa aşama kendiliğinden ilerler.
func _after_layers_tap(id: int, first: String, accepted: bool) -> void:
	var covered_open: bool = not _board.is_on_line(_covered_id) or _board.blockers_of(_covered_id).is_empty()
	match _stage:
		0:
			if first == LaundryBoard.EVENT_BLOCKED and id == _covered_id:
				_stage = 1
			elif covered_open:
				_stage = 2
		1:
			if covered_open:
				_stage = 2
		_:
			if accepted:
				_follow_taps += 1
	if _stage == 2 and _follow_taps >= int(_script.get("follow_taps", 2)):
		_guide_done = true
		return
	_return_hand(_generation, _layers_target)


func _layers_target() -> int:
	if _stage == 0:
		return _covered_id
	if _stage == 1:
		for blocker: int in _board.blockers_of(_covered_id):
			if _board.is_open(blocker):
				return blocker
	return _next_id()


func _after_rack_tap(events: Array[Dictionary], accepted: bool) -> void:
	if accepted:
		_taps_done += 1
	for event: Dictionary in events:
		if String(event["type"]) == LaundryBoard.EVENT_TO_RACK:
			_rack_taught = true
	if _rack_taught:
		_guide_done = true
		_rack_glow()
		return
	if _taps_done >= int(_script.get("give_up_taps", 6)):
		_guide_done = true
		return
	_return_hand(_generation, _rack_target)


func _return_hand(generation: int, chooser: Callable) -> void:
	await get_tree().create_timer(float(_timing.get("return_delay", 0.6))).timeout
	if generation != _generation or _guide_done or input_blocked or _board.is_over():
		return
	_show_hand_on(chooser.call() as int)


# --- Hamle seçimi -----------------------------------------------------------------------------

## Çözücünün bir sonraki önerdiği çamaşır. Oyuncunun şimdiye dek yaptığı geçerli dokunuşlar
## önek olarak verilir; çözücü oradan devam eder. Oyuncu çözümden saptıysa yeniden hesaplanır.
func _next_id() -> int:
	if not _plan_matches_history():
		_plan = _solve_from_history()
	if _plan.size() > _history.size():
		return _plan[_history.size()]
	return _fallback_id()


func _plan_matches_history() -> bool:
	if _plan.size() < _history.size():
		return false
	for index: int in range(_history.size()):
		if _plan[index] != _history[index]:
			return false
	return true


func _solve_from_history() -> Array[int]:
	return LevelSolver.solve_from(_level, _history, SOLVER_NODE_LIMIT)


## Çözüm bulunamazsa (oyuncu çıkmaza girdiyse) açık olanlardan sepete gideni, yoksa herhangi birini.
func _fallback_id() -> int:
	var open: Array[int] = _board.open_ids()
	for id: int in open:
		if _goes_to_basket(id):
			return id
	return open[0] if not open.is_empty() else LaundryBoard.EMPTY


func _goes_to_basket(id: int) -> bool:
	var color: int = _board.color_of(id)
	for basket: Dictionary in _board.baskets():
		if not basket.is_empty() and int(basket["color"]) == color \
				and int(basket["count"]) < LaundryBoard.BASKET_CAPACITY:
			return true
	return false


## Kapalı (üstü örtülü) bir çamaşır; tercihen rengi şu an bir sepete uyan.
func _pick_covered() -> int:
	var fallback: int = LaundryBoard.EMPTY
	for id: int in _board.item_ids():
		if not _board.is_on_line(id) or _board.blockers_of(id).is_empty():
			continue
		if _goes_to_basket(id):
			return id
		if fallback == LaundryBoard.EMPTY:
			fallback = id
	return fallback


## Askı dersi: çözümü bozmayan, sepete gitmeyen açık bir çamaşır; yoksa çözücünün adımı.
func _rack_target() -> int:
	for id: int in _board.open_ids():
		if _goes_to_basket(id) or _board.is_wet(id):
			continue
		var probe: Array[int] = _history.duplicate()
		probe.append(id)
		if not LevelSolver.solve_from(_level, probe, SOLVER_NODE_LIMIT).is_empty():
			return id
	return _next_id()


# --- Görünüm ---------------------------------------------------------------------------------

func _point_of(id: int) -> Vector2:
	var view: GarmentView = _views.get(id) as GarmentView
	if view == null or not is_instance_valid(view):
		return Vector2.ZERO
	return view.position + Vector2(0.0, view.size * TARGET_Y_RATIO)


func _show_hand_on(id: int) -> void:
	if id == LaundryBoard.EMPTY or not _views.has(id):
		return
	_hand_shown = true
	_hand.show_hint(_point_of(id))


func _hide_hand() -> void:
	_hand_shown = false
	if _hand != null:
		_hand.dismiss()


func _idle_hint() -> void:
	var id: int = _next_id()
	if id == LaundryBoard.EMPTY or not _views.has(id):
		return
	_hand.show_ring(_point_of(id), int(_idle_spec.get("pulses", 3)))


func _rack_glow() -> void:
	if _rack_points.is_empty():
		return
	await get_tree().create_timer(RACK_PRAISE_DELAY).timeout
	var first: Vector2 = _rack_points[0]
	var last: Vector2 = _rack_points[_rack_points.size() - 1]
	var rect: Rect2 = Rect2(first.x - RACK_GLOW_SIDE, first.y - RACK_GLOW_HALF_HEIGHT,
		last.x - first.x + RACK_GLOW_SIDE * 2.0, RACK_GLOW_HALF_HEIGHT * 2.0)
	_glow.pulse(rect, int(_timing.get("rack_glow_pulses", 2)))


func _queue_glow() -> void:
	var flag: String = String(_script.get("flag", "tut_queue"))
	if _is_seen(flag):
		return
	_mark_seen(flag)
	var shown: int = mini(_board.queue().size(), 6)
	if shown <= 0:
		return
	var half: float = float(shown - 1) * QUEUE_GLOW_STEP * 0.5 + QUEUE_GLOW_PAD
	_glow.pulse(Rect2(_center_x - half, _queue_y - QUEUE_GLOW_HALF_HEIGHT, half * 2.0,
		QUEUE_GLOW_HALF_HEIGHT * 2.0), int(_timing.get("queue_glow_pulses", 3)))


# --- "Görüldü" kaydı --------------------------------------------------------------------------
# Kalıcı kayıt `Progress` otoyükleyicisindedir (başka dal yazıyor); yoksa özel küçük dosya.
# Kayıt yazmayan çalıştırmalar (`_persist` kapalı: prob/araç) yalnız bellekte tutar, oyuncunun
# gerçek kaydına dokunmaz.

func _is_seen(flag: String) -> bool:
	if _memory_seen.has(flag):
		return true
	if not _persist:
		return false
	var progress: Node = get_node_or_null(PROGRESS_NODE)
	if progress != null and progress.has_method(&"seen"):
		return bool(progress.call(&"seen", flag))
	var config: ConfigFile = ConfigFile.new()
	return config.load(LOCAL_SEEN_PATH) == OK and bool(config.get_value(LOCAL_SEEN_SECTION, flag, false))


func _mark_seen(flag: String) -> void:
	_memory_seen[flag] = true
	if not _persist:
		return
	var progress: Node = get_node_or_null(PROGRESS_NODE)
	if progress != null and progress.has_method(&"mark_seen"):
		progress.call(&"mark_seen", flag)
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(LOCAL_SEEN_PATH)
	config.set_value(LOCAL_SEEN_SECTION, flag, true)
	config.save(LOCAL_SEEN_PATH)
