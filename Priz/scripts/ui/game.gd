extends Control

## Oyun ekranı (kabuk tarafı): dikey kesitin 3B oyun sahnesini (`SliceGame`) kurar ve kabuk sözleşmesine
## bağlar (docs/ARCHITECTURE.md "Game ↔ kabuk sözleşmesi"): seviye başı → `RunFlow.on_level_start`,
## kazanma sahnesi bitince → `RunFlow.on_win` + `ResultSheet.win` → Devam → (geçiş reklamı) → sıradaki seviye.
## Düz kipte (seviye 1-14) kayıp yoktur; kayıp/ek hak yolu gün kipi (aşama 3) için `SliceGame.level_lost`
## sinyaline bağlı bekler. Ekranda RAKAM ve yazı yok: HUD noktaları + dünya içi sigorta kutusu.

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
	_hud = GameHud.new()
	_hud.pause_requested.connect(_on_pause_requested)
	add_child(_hud)
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
	Progress.begin_level_fuses()
	_slice.start_level(_slice.data.index_for_progress(_level_number), transition)
	_slice.set_input_enabled(true)
	_flow.on_level_start(_level_number)
	_hud.set_level(_level_number)


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


## Kazanılan yıldız (balance.json `win_stars`).
func _win_stars() -> int:
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
	_slice.set_input_enabled(true)


func _on_retry_pressed() -> void:
	_start_level()


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
