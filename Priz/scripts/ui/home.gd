extends Control

## Ana ekran iskeleti = "mahalle" ekranı: oyun adı, jeton hapı, ayarlar düğmesi ve alt bölgede tek büyük
## "Oyna" düğmesi (başparmak bölgesi) + üstünde seviye ilerleme noktaları. Priz: ekranda RAKAM YOK.
## Her şey kodla kurulur; düz, çizgisiz, az metinli. Banner yalnız bu ekranda (politika AdManager'da).
## Oyuna özgü süs (mahalle manzarası, sekmeler, günlük daire...) bu ekrana eklenir.

const TITLE_Y: float = 560.0
const TITLE_SIZE: int = 112
const TITLE_WIDTH: float = 900.0
const PLAY_WIDTH: float = 620.0
const PLAY_HEIGHT: float = 150.0
const PLAY_CENTER_Y: float = 1560.0
const PLAY_BREATH_SCALE: float = 0.022
const PLAY_BREATH_SECONDS: float = 2.4
const CHIP_GAP: int = 20
const PIPS_GAP: float = 40.0
const SCREEN_ID: StringName = &"neighbourhood"

var _coin_chip: UiChip = null
var _play_button: Button = null
var _pips: UiPips = null
var _sheet: Sheet = null


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.HOME)
	GameManager.back_requested.connect(_on_back)
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	_build_background()
	_build_title(view)
	_build_counters(view, insets)
	_build_play(view)
	UiData.connect_changed(_refresh)
	_refresh()
	AdManager.set_banner_visible(SCREEN_ID)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.SCREEN_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	# Progress sinyali sahneden uzun yaşar: ölü ekrana bağlı kalmasın.
	var progress: Node = UiData.progress()
	if progress != null and progress.is_connected("changed", _refresh):
		progress.disconnect("changed", _refresh)


func _build_background() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = UiTokens.C_BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


func _build_title(view: Vector2) -> void:
	var title: Label = UiKit.wrap_label(UiStrings.game_title(), TITLE_SIZE)
	title.name = "Title"
	title.position = Vector2((view.x - TITLE_WIDTH) * 0.5, TITLE_Y)
	title.size = Vector2(TITLE_WIDTH, TITLE_SIZE * 1.4)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)


func _build_counters(view: Vector2, insets: Vector4) -> void:
	var row_top: float = insets.y
	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", CHIP_GAP)
	chips.position = Vector2(insets.x + UiKit.SIDE_MARGIN, row_top + (UiKit.MIN_TOUCH - UiChip.HEIGHT) * 0.5)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chips)
	_coin_chip = UiChip.new()
	_coin_chip.setup("lucide/coins", UiKit.GOLD)
	chips.add_child(_coin_chip)
	var settings: UiIconButton = UiIconButton.new()
	settings.name = "SettingsButton"
	settings.setup("lucide/settings")
	settings.position = Vector2(view.x - insets.z - UiKit.SIDE_MARGIN - UiKit.MIN_TOUCH \
		+ (UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5, row_top)
	settings.pressed.connect(_open_settings)
	add_child(settings)


func _build_play(view: Vector2) -> void:
	_pips = UiPips.new()
	_pips.name = "LevelPips"
	_pips.size = Vector2(PLAY_WIDTH, UiPips.HEIGHT)
	_pips.position = Vector2((view.x - PLAY_WIDTH) * 0.5, PLAY_CENTER_Y - PLAY_HEIGHT * 0.5 - PIPS_GAP - UiPips.HEIGHT)
	add_child(_pips)
	_play_button = UiKit.button(UiStrings.play(), &"", "lucide/play", PLAY_HEIGHT)
	_play_button.name = "PlayButton"
	_play_button.size = Vector2(PLAY_WIDTH, PLAY_HEIGHT)
	_play_button.custom_minimum_size = Vector2(PLAY_WIDTH, PLAY_HEIGHT)
	_play_button.position = Vector2((view.x - PLAY_WIDTH) * 0.5, PLAY_CENTER_Y - PLAY_HEIGHT * 0.5)
	_play_button.pivot_offset = _play_button.size * 0.5
	_play_button.pressed.connect(_on_play)
	add_child(_play_button)
	# Çok hafif "nefes": dikkat çeker ama sakin kalır.
	var breath: Tween = _play_button.create_tween().set_loops()
	breath.tween_property(_play_button, "scale", Vector2.ONE * (1.0 + PLAY_BREATH_SCALE), PLAY_BREATH_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(_play_button, "scale", Vector2.ONE, PLAY_BREATH_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _refresh() -> void:
	_coin_chip.set_value(UiData.coins())
	var pips: Dictionary = Quantity.level_pips(UiData.level(), Quantity.block_size(UiData.balance_block("level_pips")))
	_pips.set_state(int(pips["total"]), int(pips["done"]), int(pips["current"]), bool(pips["hard_last"]))


func _on_play() -> void:
	GameManager.start_game()


func _open_settings() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = SettingsSheet.open(self)


## Geri tuşu: açık sayfa varsa onu kapatır, yoksa uygulamadan çıkar.
func _on_back() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.close()
		return
	get_tree().quit()
