extends Control

## Oyun ekranı (kabuk tarafı): dikey kesitin 3B oyun sahnesini (`SliceGame`) kurar ve kabuk sözleşmesine
## bağlar (docs/ARCHITECTURE.md "Game ↔ kabuk sözleşmesi"): seviye başı → `RunFlow.on_level_start`,
## kazanma sahnesi bitince → `RunFlow.on_win` + `ResultSheet.win` → Devam → (geçiş reklamı) → sıradaki seviye.
## Düz kipte kayıp yoktur. Gün kipinde (aşama 3) sigorta atınca `Progress.lose_fuse()`, haklar bitince
## `SliceGame.day_lost` → kayıp sayfası: ödüllü "+1 sigorta" (sessiz dönemde ve reklam yokken gizli), "tekrar
## dene" (plan korunur) ve çık. Yıldız = kalan cam sigorta sayısı. Ödüllü ipucu ve gün önizleme düğmeleri
## (ampul, ufukta güneş) yalnız sunulabildiğinde görünür. Ekranda RAKAM ve yazı yok.

const FADE_COLOR: Color = Color(0.06, 0.06, 0.08)
const FADE_SECONDS: float = 0.55
## Seviyeler arası gün geçişi (gece → yeni seviyenin dilimi).
const NEXT_LEVEL_TRANSITION: float = 1.8

var _flow: RunFlow = null
var _hud: GameHud = null
var _slice: SliceGame = null
var _overlay: ResultSheet = null
var _pause: Sheet = null
var _fade: ColorRect = null
var _level_number: int = 1
var _revived: bool = false
## Kazanma sayfasındaki ödenen jeton (2x için taban) ve 2x alındı mı.
var _reward: int = 0
var _doubled: bool = false
var _won: bool = false
var _lost: bool = false
## Ödüllü yerleşim düğmeleri (ipucu, gün önizleme) ve bu seviyede önizleme alındı mı.
var _hint_button: RewardButton = null
var _preview_button: RewardButton = null
var _preview_owned: bool = false
var _offer_refresh: float = 0.0


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GAME)
	GameManager.back_requested.connect(_on_pause_requested)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flow = RunFlow.new()
	add_child(_flow)
	_slice = SliceGame.new()
	_slice.name = "Slice"
	add_child(_slice)
	var layer: Control = Control.new()
	layer.name = "WorldOverlay"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_slice.set_overlay(layer)
	_slice.level_won.connect(_on_level_won)
	_slice.day_lost.connect(_on_day_lost)
	_slice.fuse_spent.connect(_on_fuse_spent)
	_hud = GameHud.new()
	_hud.pause_requested.connect(_on_pause_requested)
	add_child(_hud)
	_build_offer_buttons()
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = FADE_COLOR
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_start_level(0.0)
	# Açılış: ısıtma kareleri (parçacık, gölgelendirici) karartmanın arkasında çizilir.
	var t: Tween = create_tween()
	t.tween_interval(0.12)
	t.tween_property(_fade, "color:a", 0.0, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: _fade.visible = false)


func _exit_tree() -> void:
	if GameManager.back_requested.is_connected(_on_pause_requested):
		GameManager.back_requested.disconnect(_on_pause_requested)
	AudioService.stop_music(0.4)
	AudioService.stop_ambience()


## Yeni tur (ilk açılış, "Devam", duraklatmada "yeniden başlat").
func _start_level(transition: float = NEXT_LEVEL_TRANSITION) -> void:
	_hide_overlay()
	_level_number = Progress.level()
	_revived = false
	_doubled = false
	_won = false
	_lost = false
	_preview_owned = false
	Progress.begin_level_fuses()
	_slice.auto_hint = Progress.is_quiet_period(_level_number)
	_slice.start_level(_slice.data.index_for_progress(_level_number), transition)
	_slice.set_input_enabled(true)
	_flow.on_level_start(_level_number)
	_hud.set_level(_level_number)
	_refresh_offers()


func _on_level_won() -> void:
	_won = true
	_show_win()


# --- Tur sonu (iskelet) ----------------------------------------------------------------------

func _show_win() -> void:
	if not is_inside_tree() or not _won or _overlay != null:
		return
	_slice.set_input_enabled(false)
	var result: Dictionary = _flow.on_win(_level_number, _win_stars())
	result["won"] = true
	GameManager.finish_run(result)
	_reward = int(result["coins"])
	_doubled = false
	_overlay = ResultSheet.win(self, _reward, _flow.can_watch(AdManager.Placement.DOUBLE_COINS),
		int(result["stars"]))
	_overlay.continue_pressed.connect(_on_continue_pressed)
	_overlay.double_pressed.connect(_on_double_pressed)


## Gün kipi (aşama 3) için: sigortalar bitince kayıp sayfası. Düz kipte çağrılmaz.
func _show_lose() -> void:
	if not is_inside_tree() or _overlay != null:
		return
	_lost = true
	_slice.set_input_enabled(false)
	_flow.on_lose(_level_number)
	GameManager.finish_run({"won": false})
	_overlay = ResultSheet.lose(self, not _revived and _flow.can_watch(AdManager.Placement.EXTRA_FUSE))
	_overlay.revive_pressed.connect(_on_revive_pressed)
	_overlay.retry_pressed.connect(_on_retry_pressed)
	_overlay.home_pressed.connect(GameManager.goto_scene.bind(&"home"))
	_refresh_offers()


func _on_day_lost() -> void:
	_show_lose()


## Sigorta attı: kabuğun seviye başı hak sayacı da düşer (sözleşme: `Progress.lose_fuse()`).
func _on_fuse_spent(_rights_left: int) -> void:
	Progress.lose_fuse()


## Kazanılan yıldız: düz kipte balance.json `win_stars`; gün kipinde kalan cam sigorta sayısı (üçü
## sağlam = üç yıldız; ek hakla kazanılırsa bir).
func _win_stars() -> int:
	if _slice.is_day_mode() and _slice.state != null:
		var cap: int = ProgressData.to_count(Progress.balance_table().get("win_stars"), 3)
		return clampi(_slice.state.board.fuse_rights(), 1, cap)
	return ProgressData.to_count(Progress.balance_table().get("win_stars"), 1)


## Devam: sayfa kapanır, (gerekirse) geçiş reklamı, sonra sıradaki seviye. Karar BİTİRİLEN seviyeye göre.
func _on_continue_pressed() -> void:
	_hide_overlay()
	_flow.maybe_interstitial(_level_number, _start_level)


## 2x jeton: yalnız ödüllü reklam başarılıysa fazlalık eklenir.
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


func _on_revive_pressed() -> void:
	_flow.watch(AdManager.Placement.EXTRA_FUSE, _grant_revive)


func _grant_revive() -> void:
	if _revived or not _lost:
		return
	_revived = true
	_lost = false
	Progress.grant_extra_fuse()
	_hide_overlay()
	_slice.grant_extra_right()
	_slice.set_input_enabled(true)
	_refresh_offers()


## Tekrar dene: gün kipinde plan KORUNUR (haklar dolar, cihazlar aynı prizlerde); düz kipte baştan.
func _on_retry_pressed() -> void:
	if not _slice.is_day_mode():
		_start_level()
		return
	_hide_overlay()
	_level_number = Progress.level()
	_revived = false
	_lost = false
	_won = false
	Progress.begin_level_fuses()
	_slice.restart_keep_plan()
	_slice.set_input_enabled(true)
	_flow.on_level_start(_level_number)
	_refresh_offers()


# --- Ödüllü ipucu ve gün önizleme -------------------------------------------------------------

func _build_offer_buttons() -> void:
	var layer: Control = Control.new()
	layer.name = "OfferButtons"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	var x: float = view.x - insets.z - UiKit.SIDE_MARGIN - UiKit.MIN_TOUCH + (UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5
	var y: float = insets.y + UiKit.MIN_TOUCH + UiKit.SPACE_MD
	_hint_button = RewardButton.new()
	_hint_button.name = "HintButton"
	_hint_button.setup("priz/bulb")
	_hint_button.position = Vector2(x, y)
	_hint_button.pressed.connect(_on_hint_pressed)
	layer.add_child(_hint_button)
	_preview_button = RewardButton.new()
	_preview_button.name = "PreviewButton"
	_preview_button.setup("priz/day")
	_preview_button.position = Vector2(x, y + UiKit.MIN_TOUCH + UiKit.SPACE_SM)
	_preview_button.pressed.connect(_on_preview_pressed)
	layer.add_child(_preview_button)
	_hint_button.visible = false
	_preview_button.visible = false


## Düğmeler yalnız sunulabilirken görünür (sessiz dönem, reklam yok, sınır dolu → gizli; ölü düğme yok).
func _refresh_offers() -> void:
	if _hint_button == null:
		return
	var planning: bool = _overlay == null and _slice.state != null and _slice.mode == SliceGame.Mode.IDLE \
		and _slice.state.board.is_planning()
	_hint_button.visible = planning and _flow.can_watch(AdManager.Placement.HINT)
	var can_preview: bool = planning and _slice.can_preview()
	_preview_button.visible = can_preview and (_preview_owned or _flow.can_watch(AdManager.Placement.DAY_PREVIEW))
	_preview_button.show_badge = not _preview_owned


func _process(delta: float) -> void:
	_offer_refresh -= delta
	if _offer_refresh <= 0.0:
		_offer_refresh = 0.25
		_refresh_offers()


func _on_hint_pressed() -> void:
	_flow.watch(AdManager.Placement.HINT, _slice.show_hint)


func _on_preview_pressed() -> void:
	if _preview_owned:
		_slice.begin_preview()
		return
	_flow.watch(AdManager.Placement.DAY_PREVIEW, _grant_preview)


func _grant_preview() -> void:
	_preview_owned = true
	_slice.begin_preview()
	_refresh_offers()


func _hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.close()
	_overlay = null


# --- Duraklatma ------------------------------------------------------------------------------

func _on_pause_requested() -> void:
	if _overlay != null or (_pause != null and is_instance_valid(_pause)):
		return
	_slice.set_input_enabled(false)
	var sheet: PauseSheet = PauseSheet.open(self)
	sheet.restart_pressed.connect(_start_level.bind(0.6))
	sheet.home_pressed.connect(GameManager.goto_scene.bind(&"home"))
	sheet.tree_exited.connect(_on_pause_closed)
	_pause = sheet


func _on_pause_closed() -> void:
	_pause = null
	if _overlay == null and is_inside_tree():
		_slice.set_input_enabled(true)
