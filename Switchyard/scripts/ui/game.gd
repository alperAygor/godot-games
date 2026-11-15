extends Control

## Oyun ekranı. BU DOSYADAKİ "YER TUTUCU" BÖLÜMLER gerçek oyunla DEĞİŞTİRİLİR; akış iskeleti
## (HUD, duraklatma, kazanma/kayıp sayfası, reklam, jeton, tekrar) olduğu gibi kalır.
##
## Yer tutucu oyun: "Dokun" düğmesine N kez bas -> kazan; "Kaybet" -> kaybet.
## Akış: _start_level -> (kazan/kaybet) -> kısa bekleme -> ResultSheet -> Devam / Tekrar / Ana ekran.
## Tur kuralı saf `PlaceholderRun`dadır (sahnesiz, birim testli); burası yalnız gösterir.

const BUTTON_WIDTH: float = 620.0
const COUNTER_SIZE: int = UiKit.TYPE_DISPLAY + 28
const CENTER_OFFSET_Y: float = -80.0
const BLOCK_GAP: float = UiKit.SPACE_XXL
const DEFAULT_TAPS: int = 5

var _run: PlaceholderRun = null
var _flow: RunFlow = null
var _hud: GameHud = null
var _overlay: ResultSheet = null
var _pause: Sheet = null
var _level_number: int = 1
## Bu turda "Devam et" (ödüllü) kullanıldı mı: tur başına bir kez.
var _revived: bool = false
## Kazanma sayfasındaki ödenen jeton (2x için taban) ve 2x alındı mı.
var _reward: int = 0
var _doubled: bool = false
var _counter: Label = null
var _left: Label = null
var _tap_button: Button = null
var _lose_button: Button = null


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GAME)
	GameManager.back_requested.connect(_on_pause_requested)
	_flow = RunFlow.new()
	add_child(_flow)
	_build_ui()
	_level_number = Progress.level()
	_start_level()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.SCREEN_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if GameManager.back_requested.is_connected(_on_pause_requested):
		GameManager.back_requested.disconnect(_on_pause_requested)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back: ColorRect = ColorRect.new()
	back.color = UiTokens.C_BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	# --- YER TUTUCU oyun alanı ---
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	column.position.y = CENTER_OFFSET_Y
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	_counter = UiKit.numeric_label("", COUNTER_SIZE)
	_counter.name = "Counter"
	column.add_child(_counter)
	_left = UiKit.label("", UiKit.TYPE_CAPTION, UiKit.TEXT_MUTED)
	_left.name = "Left"
	column.add_child(_left)
	column.add_child(UiKit.spacer(BLOCK_GAP))
	_tap_button = UiKit.button(UiStrings.placeholder_tap(), &"", "", UiKit.HEIGHT_PRIMARY)
	_tap_button.name = "TapButton"
	_tap_button.pressed.connect(_on_tap_pressed)
	column.add_child(_tap_button)
	column.add_child(UiKit.spacer(UiKit.SPACE_LG))
	_lose_button = UiKit.button(UiStrings.placeholder_lose(), &"SecondaryButton", "", UiKit.HEIGHT_SECONDARY)
	_lose_button.name = "LoseButton"
	_lose_button.pressed.connect(_on_lose_pressed)
	column.add_child(_lose_button)
	# --- Kalıcı iskelet: HUD ---
	_hud = GameHud.new()
	_hud.pause_requested.connect(_on_pause_requested)
	add_child(_hud)


## Yeni tur (ilk tur, "Devam", "Tekrar dene", duraklatmada "yeniden başlat").
func _start_level() -> void:
	_hide_overlay()
	_level_number = Progress.level()
	_revived = false
	_doubled = false
	_run = PlaceholderRun.new(_taps_to_win())
	_flow.on_level_start(_level_number)
	_hud.set_level(_level_number)
	_set_buttons_enabled(true)
	_refresh_view()


## Yer tutucu: kaç dokunuşta kazanılır (data/balance.json -> placeholder.taps_to_win).
func _taps_to_win() -> int:
	var block: Variant = GameData.value("balance", "placeholder", {})
	if block is Dictionary:
		return ProgressData.to_count((block as Dictionary).get("taps_to_win"), DEFAULT_TAPS)
	return DEFAULT_TAPS


func _refresh_view() -> void:
	_counter.text = "%d / %d" % [_run.taps, _run.target]
	_left.text = UiStrings.placeholder_left(_run.remaining())


func _set_buttons_enabled(enabled: bool) -> void:
	UiKit.set_enabled(_tap_button, enabled)
	UiKit.set_enabled(_lose_button, enabled)


func _on_tap_pressed() -> void:
	if not _run.tap():
		return
	_refresh_view()
	if _run.is_won():
		_set_buttons_enabled(false)
		get_tree().create_timer(Motion.WIN_DELAY_SECONDS).timeout.connect(_show_win)


func _on_lose_pressed() -> void:
	if not _run.is_playing():
		return
	_run.lose()
	_set_buttons_enabled(false)
	get_tree().create_timer(Motion.LOSE_DELAY_SECONDS).timeout.connect(_show_lose)


# --- Tur sonu (iskelet: oyun değişse de kalır) -----------------------------------------------

func _show_win() -> void:
	if not is_inside_tree() or not _run.is_won() or _overlay != null:
		return
	var result: Dictionary = _flow.on_win(_level_number)
	result["won"] = true
	GameManager.finish_run(result)
	_reward = int(result["coins"])
	_doubled = false
	_overlay = ResultSheet.win(self, _reward, _flow.can_watch(AdManager.Placement.DOUBLE_COINS))
	_overlay.continue_pressed.connect(_on_continue_pressed)
	_overlay.double_pressed.connect(_on_double_pressed)


func _show_lose() -> void:
	if not is_inside_tree() or not _run.is_lost() or _overlay != null:
		return
	_flow.on_lose(_level_number)
	GameManager.finish_run({"won": false})
	_overlay = ResultSheet.lose(self, not _revived and _flow.can_watch(AdManager.Placement.CONTINUE))
	_overlay.revive_pressed.connect(_on_revive_pressed)
	_overlay.retry_pressed.connect(_on_retry_pressed)


## Devam: sayfa kapanır, (gerekirse) geçiş reklamı gösterilir, sonra sıradaki tur başlar.
func _on_continue_pressed() -> void:
	_hide_overlay()
	_flow.maybe_interstitial(Progress.level(), _start_level)


## 2x jeton: yalnız ödüllü reklam başarılıysa fazlalık eklenir (ödül reklamdan ÖNCE verilmez).
func _on_double_pressed() -> void:
	if _doubled:
		return
	_flow.watch(AdManager.Placement.DOUBLE_COINS, _grant_double)


func _grant_double() -> void:
	if _doubled or _overlay == null:
		return
	_doubled = true
	var bonus: int = _flow.double_bonus(_reward)
	Progress.add_coins(bonus)
	_overlay.show_doubled(_reward + bonus)


## Kayıpta devam: yalnız ödüllü reklamla, tur başına bir kez. Tur kaldığı yerden sürer.
func _on_revive_pressed() -> void:
	_flow.watch(AdManager.Placement.CONTINUE, _grant_revive)


func _grant_revive() -> void:
	if _revived or not _run.revive():
		return
	_revived = true
	_hide_overlay()
	_set_buttons_enabled(true)
	_refresh_view()


func _on_retry_pressed() -> void:
	_start_level()


func _hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.close()
	_overlay = null


# --- Duraklatma ------------------------------------------------------------------------------

func _on_pause_requested() -> void:
	# Sonuç sayfası açıkken ya da zaten duraklatılmışken geri tuşu yeni sayfa açmaz.
	if _overlay != null or (_pause != null and is_instance_valid(_pause)):
		return
	var sheet: PauseSheet = PauseSheet.open(self)
	sheet.restart_pressed.connect(_start_level)
	sheet.home_pressed.connect(GameManager.goto_scene.bind(&"home"))
	_pause = sheet
