extends Control

## Oyun ekranı (kabuk): HUD (seviye, hamle, par), saha alanı, alt çubuk (geri al, baştan, ipucu, atla),
## duraklatma, atlama onayı ve sonuç sayfası. Sahaya YALNIZ `LevelSession` sözleşmesiyle konuşur;
## saha görünümü `_create_session()` içindeki tek KANCA'dan gelir.
##
## Akış: seviye yüklenir -> oyuncu oynar -> `solved` -> ilerleme kaydı + yıldız -> sonuç sayfası ->
## Sonraki (geçiş reklamı sırası gelmişse önce o) / Tekrar / Seviyeler.
## İpucu = bir ödüllü reklam, ödülden sonra `show_hint()`. Atla = onay + bir ödüllü reklam, ödülden sonra
## seviye "atlandı" işaretlenir ve sıradaki açılır (yıldız yok).

const BOTTOM_EXTRA: float = UiKit.SPACE_XL
const BOARD_GAP: float = UiKit.SPACE_MD
const TOAST_ABOVE_BAR: float = 56.0

var _flow: RunFlow = null
var _hud: GameHud = null
var _bar: GameBar = null
var _board: Control = null
var _session: LevelSession = null
var _overlay: ResultSheet = null
var _pause: Sheet = null
var _skip_sheet: SkipSheet = null
var _progress: LevelProgress = null
var _ids: Array[String] = []
var _level_id: String = ""
var _level_number: int = 0
## Bu seviye ilk kez tamamlandı mı (geçiş reklamı sırası yalnız bunu sayar); ilk çözüm anında kurulur,
## sonuç sayfasından çıkışta tüketilir (tekrar oynayıp ikinci kez reklam çıkmaz).
var _first_completion: bool = false
## Ödüllü reklam sürüyor (düğmeler ve saha girdisi kapalı).
var _ad_busy: bool = false
var _hint_showing: bool = false
var _toast_bottom: float = 0.0


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GAME)
	GameManager.back_requested.connect(_on_back_requested)
	_flow = RunFlow.new()
	add_child(_flow)
	_flow.ad_unavailable.connect(_on_ad_unavailable)
	_progress = LevelProgress.load_saved()
	_ids = LevelProgress.ids_of(LevelCatalog.entries())
	_build_ui()
	_session = _create_session()
	_board.add_child(_session)
	_session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_session.move_count_changed.connect(_on_moves_changed)
	_session.can_undo_changed.connect(_bar.set_undo_enabled)
	_session.solved.connect(_on_session_solved)
	_session.hint_finished.connect(_on_hint_finished)
	var wanted: String = GameManager.selected_level_id
	if _ids.is_empty() or not _load_level(wanted if _ids.has(wanted) else _ids[_progress.frontier(_ids)]):
		GameManager.goto_scene.call_deferred(&"map")
		return
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.SCREEN_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if GameManager.back_requested.is_connected(_on_back_requested):
		GameManager.back_requested.disconnect(_on_back_requested)


## Saha görünümünün TEK bağlandığı yer. Şimdilik kabuğun sahte sahası; gerçek görünüm geldiğinde
## yalnız bu fonksiyonun gövdesi `return YardSession.new()` olur (başka hiçbir yere dokunulmaz).
# KANCA: gerçek saha görünümü (YardSession) burada bağlanır
func _create_session() -> LevelSession:
	return StubSession.new()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	_toast_bottom = insets.w + BOTTOM_EXTRA + UiKit.MIN_TOUCH + TOAST_ABOVE_BAR
	var back: ColorRect = ColorRect.new()
	back.color = UiTokens.C_BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(insets.x + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_right", int(insets.z + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_top", int(insets.y))
	safe.add_theme_constant_override("margin_bottom", int(insets.w + BOTTOM_EXTRA))
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(BOARD_GAP))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	_hud = GameHud.new()
	_hud.pause_requested.connect(_on_pause_requested)
	_hud.levels_requested.connect(_on_levels_requested)
	column.add_child(_hud)
	_board = Control.new()
	_board.name = "Board"
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.clip_contents = true
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_board)
	_bar = GameBar.new()
	_bar.undo_pressed.connect(_on_undo_pressed)
	_bar.restart_pressed.connect(_on_restart_pressed)
	_bar.hint_pressed.connect(_on_hint_pressed)
	_bar.skip_pressed.connect(_on_skip_pressed)
	column.add_child(_bar)


## Seviyeyi yükler (ilk açılış, Sonraki, atlama sonrası). Dönen: yüklendi mi.
func _load_level(level_id: String) -> bool:
	var index: int = _ids.find(level_id)
	if index < 0 or not _session.load_level(level_id):
		push_error("Game: seviye yüklenemedi: " + level_id)
		return false
	_hide_overlay()
	_level_id = level_id
	_level_number = index + 1
	_first_completion = false
	_ad_busy = false
	_hint_showing = false
	_flow.on_level_start(_level_number)
	_hud.set_level(_level_number)
	_bar.set_rewarded_visible(_flow.rewarded_buttons_visible(_level_number))
	_refresh_ad_buttons()
	_session.set_input_enabled(true)
	return true


func _refresh_ad_buttons() -> void:
	_bar.set_hint_enabled(not _ad_busy and not _hint_showing)
	_bar.set_skip_enabled(not _ad_busy)


func _on_moves_changed(moves: int, par: int) -> void:
	_hud.set_moves(moves, par)


func _on_undo_pressed() -> void:
	if _input_blocked():
		return
	_session.undo()


func _on_restart_pressed() -> void:
	if _input_blocked():
		return
	_session.restart()


## Saha girdisi şu an kapalı mı (sonuç, duraklatma, onay sayfası ya da reklam).
func _input_blocked() -> bool:
	return _ad_busy or _overlay != null or _is_open(_pause) or _is_open(_skip_sheet)


static func _is_open(sheet: Sheet) -> bool:
	return sheet != null and is_instance_valid(sheet)


# --- İpucu: bir ödüllü reklam, ödülden sonra show_hint --------------------------------------------

func _on_hint_pressed() -> void:
	if _input_blocked() or _hint_showing:
		return
	_begin_ad()
	_flow.watch(AdManager.Placement.HINT, _grant_hint, _end_ad)


func _grant_hint() -> void:
	_end_ad()
	_hint_showing = true
	_refresh_ad_buttons()
	_session.show_hint()


func _on_hint_finished() -> void:
	_hint_showing = false
	_refresh_ad_buttons()


# --- Atla: onay + bir ödüllü reklam, ödülden sonra "atlandı" + sıradaki seviye -----------------------

func _on_skip_pressed() -> void:
	if _input_blocked():
		return
	if not _flow.can_watch(AdManager.Placement.SKIP):
		# Reklam yoksa onay sayfası açmanın anlamı yok: neden hemen söylenir.
		_flow.ad_unavailable.emit(AdManager.Placement.SKIP, _flow.unavailable_reason())
		return
	_session.set_input_enabled(false)
	_skip_sheet = SkipSheet.open(self)
	_skip_sheet.watch_pressed.connect(_on_skip_confirmed)
	_skip_sheet.cancel_pressed.connect(_on_skip_cancelled)


func _on_skip_cancelled() -> void:
	_skip_sheet = null
	_session.set_input_enabled(true)


func _on_skip_confirmed() -> void:
	_skip_sheet = null
	_begin_ad()
	_flow.watch(AdManager.Placement.SKIP, _grant_skip, _end_ad)


func _grant_skip() -> void:
	_ad_busy = false
	_progress.record_skip(_level_id)
	_progress.save(_level_id)
	AnalyticsLog.record("level_skip", {"level": _level_number})
	# Atlama geçişinde ödüllü izlendi: geçiş reklamı yok (RunFlow.rewarded_this_level). Sıradaki seviye açılır.
	_go_next()


func _begin_ad() -> void:
	_ad_busy = true
	_session.set_input_enabled(false)
	_refresh_ad_buttons()


func _end_ad() -> void:
	_ad_busy = false
	_session.set_input_enabled(true)
	_refresh_ad_buttons()


func _on_ad_unavailable(_placement: AdManager.Placement, reason: String) -> void:
	UiToast.show_text(self, UiStrings.ad_reason(reason), _toast_bottom)


# --- Çözüm ve sonuç sayfası ---------------------------------------------------------------------

func _on_session_solved(result: Dictionary) -> void:
	if _overlay != null:
		return
	var moves: int = int(result.get("moves", 0))
	var par: int = int(result.get("par", 0))
	var slack: int = ProgressData.to_count(GameData.value("balance", "three_star_slack", 0))
	var info: Dictionary = _progress.record_solve(_level_id, moves, par, slack)
	_progress.save(_level_id)
	_first_completion = _first_completion or bool(info["first_completion"])
	_flow.on_solved(_level_number)
	_session.set_input_enabled(false)
	var has_next: bool = _level_number < _ids.size()
	GameManager.finish_run({"level_id": _level_id, "moves": moves, "par": par, "stars": int(info["stars"])})
	_overlay = ResultSheet.solved(self, {
		"stars": int(info["stars"]), "moves": moves, "par": par,
		"new_best": bool(info["new_best"]), "has_next": has_next,
	})
	_overlay.next_pressed.connect(_on_next_pressed)
	_overlay.retry_pressed.connect(_on_retry_pressed)
	_overlay.levels_pressed.connect(_on_result_levels_pressed)


## Sonraki: geçiş reklamı sırası gelmişse önce o (yalnız seviye arasında), sonra sıradaki seviye.
func _on_next_pressed() -> void:
	_leave_result(_go_next)


func _on_result_levels_pressed() -> void:
	_leave_result(_open_map)


func _leave_result(then: Callable) -> void:
	_hide_overlay()
	var first: bool = _first_completion
	_first_completion = false
	_flow.maybe_interstitial(_level_number, first, then)


func _on_retry_pressed() -> void:
	_hide_overlay()
	_session.restart()
	_session.set_input_enabled(true)


func _go_next() -> void:
	if _level_number >= _ids.size():
		_open_map()
		return
	# Her seviye başlamadan önce çevrimiçi kapısı (kapalıysa anında).
	OnlineGate.guard(self, _load_level.bind(_ids[_level_number]))


func _open_map() -> void:
	GameManager.goto_scene(&"map")


func _hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.close()
	_overlay = null


# --- Duraklatma / geri tuşu ---------------------------------------------------------------------

func _on_levels_requested() -> void:
	if _input_blocked():
		return
	_open_map()


func _on_back_requested() -> void:
	if _is_open(_skip_sheet):
		_skip_sheet.close()
		return
	_on_pause_requested()


func _on_pause_requested() -> void:
	# Sonuç/onay sayfası, reklam ya da zaten duraklatılmışken yeni sayfa açılmaz.
	if _input_blocked():
		return
	_session.set_input_enabled(false)
	var sheet: PauseSheet = PauseSheet.open(self)
	sheet.levels_pressed.connect(_open_map)
	sheet.home_pressed.connect(GameManager.goto_scene.bind(&"home"))
	sheet.closed.connect(_on_pause_closed)
	_pause = sheet


func _on_pause_closed() -> void:
	_pause = null
	if _overlay == null:
		_session.set_input_enabled(true)
