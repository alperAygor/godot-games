extends Control

## Ana ekran: arkada oyunun kendisi (canlı saha, `LevelSession.start_demo`) oynar; üstte hafif örtü (scrim) altında
## başlık bloğu, altta (başparmak bölgesi) büyük "Seviye N" ve sakin "Seviyeler". Üst satırda yıldız hapı,
## reklam kaldırma ve ayarlar. Saha oturumu `SessionHook` kancasından gelir (gerçek görünüm gelince kendiliğinden o olur).
## Yerleşim kapsayıcılarla kurulur: uzun/kısa dikey ekranda düğmeler alt-orta bölgede, başlık üstte durur.

const PLAY_WIDTH: float = float(UiTokens.SIZE_PLAY_W)
const PLAY_HEIGHT: float = float(UiTokens.H_PLAY)
const PLAY_BREATH_SCALE: float = 0.022
const PLAY_BREATH_SECONDS: float = 2.4
const BUTTON_GAP: float = UiKit.SPACE_LG
## Başlık bloğundan önceki boşluk ile saha bandı arasındaki oran (üst:orta).
const LOGO_SPACE_ABOVE: float = 0.02
const STAGE_SPACE: float = 1.0
## Düğmelerin alt boşluğu ekran yüksekliğinin bu oranından az olmaz: baş parmak rahat erişir.
const BOTTOM_RATIO: float = 0.085
## Az harekette demo bu süre sonra dondurulur (sahne kurulsun, sonra sabit kalsın).
const STILL_AFTER_SECONDS: float = 0.7

var _content: Control = null
var _session: LevelSession = null
var _logo: HomeLogo = null
var _stars_chip: UiChip = null
var _play_button: Button = null
var _levels_button: Button = null
var _shop_button: UiIconButton = null
var _sheet: Sheet = null
var _target_id: String = ""
var _breath: Tween = null


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.HOME)
	GameManager.back_requested.connect(_on_back)
	IapService.ensure(get_tree())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	var back: ColorRect = ColorRect.new()
	back.color = UiTokens.C_GROUND_TOP
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_content = Control.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_build_stage()
	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(insets.x + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_right", int(insets.z + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_top", int(insets.y))
	safe.add_theme_constant_override("margin_bottom", int(maxf(insets.w + UiKit.SPACE_XL, view.y * BOTTOM_RATIO)))
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(safe)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	column.add_child(_build_top_row())
	column.add_child(_stretch(LOGO_SPACE_ABOVE))
	_logo = HomeLogo.new()
	column.add_child(_logo)
	column.add_child(_stretch(STAGE_SPACE))
	column.add_child(_build_bottom())
	UiData.connect_changed(_refresh)
	var store: IapService = IapService.ensure(get_tree())
	store.state_changed.connect(_refresh)
	_refresh()
	ScreenFx.fade_in(_content)
	_logo.play_intro()
	_start_demo()


func _exit_tree() -> void:
	# Progress sinyali sahneden uzun yaşar: ölü ekrana bağlı kalmasın.
	var progress: Node = UiData.progress()
	if progress != null and progress.is_connected("changed", _refresh):
		progress.disconnect("changed", _refresh)
	if GameManager.back_requested.is_connected(_on_back):
		GameManager.back_requested.disconnect(_on_back)
	if _session != null and is_instance_valid(_session):
		_session.stop_demo()


func _stretch(ratio: float) -> Control:
	var node: Control = Control.new()
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_stretch_ratio = ratio
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Canlı saha (tam ekran) ve okunabilirlik için üst/alt örtü.
func _build_stage() -> void:
	_session = SessionHook.create()
	_session.name = "DemoSession"
	_content.add_child(_session)
	_session.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_session.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_scrim(true))
	_content.add_child(_scrim(false))


func _scrim(top: bool) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	var edge: Color = Color(UiTokens.C_GROUND_TOP, 0.94)
	var clear: Color = Color(UiTokens.C_GROUND_TOP, 0.0)
	gradient.set_color(0, edge if top else clear)
	gradient.set_color(1, clear if top else edge)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var rect: TextureRect = TextureRect.new()
	rect.name = "ScrimTop" if top else "ScrimBottom"
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	if top:
		rect.anchor_bottom = UiTokens.SIZE_SCRIM_TOP
	else:
		rect.anchor_top = 1.0 - UiTokens.SIZE_SCRIM_BOTTOM
	rect.offset_top = 0.0
	rect.offset_bottom = 0.0
	return rect


func _start_demo() -> void:
	if _target_id.is_empty() or not _session.start_demo(_target_id):
		return
	if UiData.reduced_motion():
		# Sahne kurulsun, sonra sabit kalsın (alt düğümlerin süreci de durur).
		get_tree().create_timer(STILL_AFTER_SECONDS).timeout.connect(_freeze_demo, CONNECT_ONE_SHOT)


func _freeze_demo() -> void:
	if _session != null and is_instance_valid(_session):
		_session.process_mode = Node.PROCESS_MODE_DISABLED


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
	if not UiData.reduced_motion():
		# Çok hafif "nefes": dikkat çeker ama sakin kalır.
		_play_button.pivot_offset = Vector2(PLAY_WIDTH, PLAY_HEIGHT) * 0.5
		_breath = _play_button.create_tween().set_loops()
		_breath.tween_property(_play_button, "scale", Vector2.ONE * (1.0 + PLAY_BREATH_SCALE), PLAY_BREATH_SECONDS * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_breath.tween_property(_play_button, "scale", Vector2.ONE, PLAY_BREATH_SECONDS * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return box


func _refresh() -> void:
	var entries: Array[Dictionary] = LevelCatalog.entries()
	var ids: Array[String] = LevelProgress.ids_of(entries)
	var progress: LevelProgress = LevelProgress.load_saved()
	var index: int = progress.frontier(ids)
	_target_id = ids[index] if not ids.is_empty() else ""
	UiKit.set_button_text(_play_button, UiStrings.level(index + 1) if not ids.is_empty() else UiStrings.home_empty())
	UiKit.set_enabled(_play_button, not _target_id.is_empty())
	UiKit.set_enabled(_levels_button, not ids.is_empty())
	_stars_chip.set_value(progress.total_stars(ids))
	_shop_button.visible = not Progress.remove_ads_owned()


func _on_play() -> void:
	if _target_id.is_empty():
		return
	# Bağlantı kapısı sayfa açacaksa içerik solmaz (boş ekran kalmasın).
	if OnlineGate.passes_now():
		ScreenFx.leave(_content, GameManager.start_level.bind(_target_id))
	else:
		GameManager.start_level(_target_id)


func _on_levels() -> void:
	ScreenFx.leave(_content, GameManager.goto_scene.bind(&"map"))


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
