extends Control

## Ana ekran: oyun adı, üstte yıldız hapı + (reklamlar kaldırılmadıysa) reklam düğmesi + ayarlar,
## altta (başparmak bölgesi) büyük "Seviye N" (ilk bitmemiş seviyeden devam) ve sakin "Seviyeler" düğmesi.
## Yerleşim kapsayıcılarla kurulur: uzun/kısa dikey ekranda alt düğmeler alta, başlık orta üst yarıya oturur.

const TITLE_SIZE: int = 112
const PLAY_WIDTH: float = 760.0
const PLAY_HEIGHT: float = 150.0
const PLAY_BREATH_SCALE: float = 0.022
const PLAY_BREATH_SECONDS: float = 2.4
const BUTTON_GAP: float = UiKit.SPACE_LG
## Başlık bloğu dikey boşlukta üst:alt = 1:1.35 oranında yukarı yaslanır (göz hizası).
const TITLE_SPACE_ABOVE: float = 1.0
const TITLE_SPACE_BELOW: float = 1.35
const BOTTOM_EXTRA: float = UiKit.SPACE_XL

var _stars_chip: UiChip = null
var _play_button: Button = null
var _levels_button: Button = null
var _shop_button: UiIconButton = null
var _sheet: Sheet = null
var _target_id: String = ""


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.HOME)
	GameManager.back_requested.connect(_on_back)
	IapService.ensure(get_tree())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	_build_background()
	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(insets.x + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_right", int(insets.z + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_top", int(insets.y))
	safe.add_theme_constant_override("margin_bottom", int(insets.w + BOTTOM_EXTRA))
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	column.add_child(_build_top_row())
	column.add_child(_stretch(TITLE_SPACE_ABOVE))
	column.add_child(_build_title())
	column.add_child(_stretch(TITLE_SPACE_BELOW))
	column.add_child(_build_bottom())
	UiData.connect_changed(_refresh)
	var store: IapService = IapService.ensure(get_tree())
	store.state_changed.connect(_refresh)
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.SCREEN_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	# Progress sinyali sahneden uzun yaşar: ölü ekrana bağlı kalmasın.
	var progress: Node = UiData.progress()
	if progress != null and progress.is_connected("changed", _refresh):
		progress.disconnect("changed", _refresh)
	if GameManager.back_requested.is_connected(_on_back):
		GameManager.back_requested.disconnect(_on_back)


func _stretch(ratio: float) -> Control:
	var node: Control = Control.new()
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_stretch_ratio = ratio
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _build_background() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = UiTokens.C_BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


func _build_top_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, UiKit.MIN_TOUCH)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_holder: CenterContainer = CenterContainer.new()
	chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip_holder)
	_stars_chip = UiChip.new()
	_stars_chip.name = "StarsChip"
	_stars_chip.setup("shell/star-fill", UiKit.STAR)
	chip_holder.add_child(_stars_chip)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	_shop_button = UiIconButton.new()
	_shop_button.name = "ShopButton"
	_shop_button.setup("lucide/ban")
	_shop_button.pressed.connect(_open_shop)
	row.add_child(_shop_button)
	var settings: UiIconButton = UiIconButton.new()
	settings.name = "SettingsButton"
	settings.setup("lucide/settings")
	settings.pressed.connect(_open_settings)
	row.add_child(settings)
	return row


func _build_title() -> Control:
	var title: Label = UiKit.wrap_label(UiStrings.game_title(), TITLE_SIZE)
	title.name = "Title"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return title


func _build_bottom() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", int(BUTTON_GAP))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_button = UiKit.button(UiStrings.level(1), &"", "lucide/play", PLAY_HEIGHT)
	_play_button.name = "PlayButton"
	_play_button.custom_minimum_size = Vector2(PLAY_WIDTH, PLAY_HEIGHT)
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_button.pressed.connect(_on_play)
	box.add_child(_play_button)
	_levels_button = UiKit.button(UiStrings.home_levels(), &"SecondaryButton", "lucide/grid-2x2", UiKit.HEIGHT_SECONDARY)
	_levels_button.name = "LevelsButton"
	_levels_button.custom_minimum_size = Vector2(PLAY_WIDTH, UiKit.HEIGHT_SECONDARY)
	_levels_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_levels_button.pressed.connect(_on_levels)
	box.add_child(_levels_button)
	# Çok hafif "nefes": dikkat çeker ama sakin kalır.
	_play_button.pivot_offset = Vector2(PLAY_WIDTH, PLAY_HEIGHT) * 0.5
	var breath: Tween = _play_button.create_tween().set_loops()
	breath.tween_property(_play_button, "scale", Vector2.ONE * (1.0 + PLAY_BREATH_SCALE), PLAY_BREATH_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(_play_button, "scale", Vector2.ONE, PLAY_BREATH_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return box


func _refresh() -> void:
	var entries: Array[Dictionary] = LevelCatalog.entries()
	var ids: Array[String] = LevelProgress.ids_of(entries)
	var progress: LevelProgress = LevelProgress.load_saved()
	var index: int = progress.frontier(ids)
	_target_id = ids[index] if not ids.is_empty() else ""
	UiKit.set_button_text(_play_button, UiStrings.level(index + 1))
	UiKit.set_enabled(_play_button, not _target_id.is_empty())
	_stars_chip.set_value(progress.total_stars(ids))
	_shop_button.visible = not Progress.remove_ads_owned()


func _on_play() -> void:
	if not _target_id.is_empty():
		GameManager.start_level(_target_id)


func _on_levels() -> void:
	GameManager.goto_scene(&"map")


func _open_settings() -> void:
	_close_sheet()
	_sheet = SettingsSheet.open(self)


func _open_shop() -> void:
	_close_sheet()
	_sheet = ShopSheet.open(self)


func _close_sheet() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


## Geri tuşu: açık sayfa varsa onu kapatır, yoksa uygulamadan çıkar.
func _on_back() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.close()
		return
	get_tree().quit()
