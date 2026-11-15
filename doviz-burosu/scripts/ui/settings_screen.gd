extends Control
## Ayarlar ekranı. Ayarları yalnızca SettingsManager'dan okur/yazar; uygulama başka yerde: ses AudioManager, dil SettingsManager,
## yazı boyutu + renk körü paleti A11y/ThemeVariants (kök tema), hareketi azalt Feel/Atmosphere, titreşim Feel, piksel filtre SceneManager.
## Her değişiklik anında uygulanır ve diske yazılır (kaydırıcıda bırakınca).
## Düğüm adları (TouchInput/testler): MasterSlider, MusicSlider, SfxSlider, TextNormalButton, TextLargeButton, ColorBlindToggle,
## ReducedMotionToggle, VibrationToggle, PixelToggle, LanguageOption, ReplayTutorialButton, PrivacyButton, PrivacyPolicyButton,
## RestoreButton, AboutButton, BackButton.

@onready var _master: HSlider = %MasterSlider
@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _text_normal: Button = %TextNormalButton
@onready var _text_large: Button = %TextLargeButton
@onready var _color_blind: CheckButton = %ColorBlindToggle
@onready var _reduced_motion: CheckButton = %ReducedMotionToggle
@onready var _vibration: CheckButton = %VibrationToggle
@onready var _pixel: CheckButton = %PixelToggle
@onready var _language: OptionButton = %LanguageOption
@onready var _preview: HBoxContainer = %PreviewRow
@onready var _actions: VBoxContainer = %ActionsBox
@onready var _back: Button = %BackButton

var _about: AboutSheet = null


func _ready() -> void:
	add_child(ScreenBackdrop.new())
	move_child(get_child(get_child_count() - 1), 1)
	_bind_volume(_master, "master")
	_bind_volume(_music, "music")
	_bind_volume(_sfx, "sfx")

	_bind_text_size()
	_bind_toggle(_color_blind, "access", "color_blind")
	_bind_toggle(_reduced_motion, "access", "reduced_motion")
	_bind_toggle(_vibration, "game", "vibration")
	_bind_toggle(_pixel, "game", "pixel_filter")
	SettingsManager.setting_changed.connect(_on_setting_changed)
	_build_preview()

	_fill_languages()
	_language.item_selected.connect(_on_language_selected)

	_build_actions()
	for child in %Body.get_children():  # uzun başlık/açıklama büyük yazıda taşmasın: satıra sarılır
		if child is Label:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_back.pressed.connect(SceneManager.back)


## SceneManager geri tuşunda önce bunu sorar: açık Hakkında penceresi / menü varsa onu kapat, sahneden çıkma.
func handle_back() -> bool:
	if _about != null and is_instance_valid(_about):
		_about.handle_back()
		return true
	var popup := _language.get_popup()
	if popup.visible:
		popup.hide()
		return true
	return false


func _bind_volume(slider: HSlider, key: String) -> void:
	slider.value = SettingsManager.get_value("audio", key)
	# Sürüklerken anında uygula ama diske sadece bırakınca yaz.
	slider.value_changed.connect(func(v: float) -> void: SettingsManager.set_value("audio", key, v, false))
	slider.drag_ended.connect(func(_changed: bool) -> void: SettingsManager.save_settings())


func _bind_toggle(toggle: CheckButton, section: String, key: String) -> void:
	toggle.button_pressed = bool(SettingsManager.get_value(section, key))
	toggle.toggled.connect(func(on: bool) -> void: SettingsManager.set_value(section, key, on))


## Yazı boyutu: iki düğmeli seçim (normal / büyük); seçilince tema anında yeniden ölçeklenir.
func _bind_text_size() -> void:
	var group := ButtonGroup.new()
	_text_normal.button_group = group
	_text_large.button_group = group
	_sync_text_buttons()
	_text_normal.pressed.connect(func() -> void: SettingsManager.set_value("access", "text_size", Accessibility.TEXT_NORMAL))
	_text_large.pressed.connect(func() -> void: SettingsManager.set_value("access", "text_size", Accessibility.TEXT_LARGE))


func _sync_text_buttons() -> void:
	var current := A11y.text_size()
	_text_normal.set_pressed_no_signal(current == Accessibility.TEXT_NORMAL)
	_text_large.set_pressed_no_signal(current == Accessibility.TEXT_LARGE)


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section == "access" and key == "color_blind":
		_build_preview()


## Renk körü kipinin canlı örneği: kabul / iade / el koy renkleri ve işaretleri.
func _build_preview() -> void:
	UiKit.clear(_preview)
	var entries := [
		[Accessibility.KIND_GOOD, UiKit.GOOD_COLOR, "FATE_ACCEPT"],
		[Accessibility.KIND_WARN, UiKit.WARN_COLOR, "FATE_RETURN"],
		[Accessibility.KIND_BAD, UiKit.BAD_COLOR, "FATE_CONFISCATE"],
	]
	for entry: Array in entries:
		var chip := UiKit.label(A11y.mark(entry[0], tr(entry[2])), &"GoalLabel", "Preview_%s" % entry[0])
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_color_override("font_color", A11y.color(entry[1]))
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"CardPanel"
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(chip)
		_preview.add_child(panel)


## Oyun / gizlilik ve satın alımlar / hakkında satırları.
func _build_actions() -> void:
	_actions.add_child(UiKit.wrapped(tr("ACC_SECTION_GAME"), &"BoothHeading"))
	var replay := UiKit.icon_button("back", tr("TUT_REPLAY"), "ReplayTutorialButton", true, true, 88.0)
	replay.pressed.connect(func() -> void:
		DeskTutorial.request_replay()
		replay.text = tr("TUT_REPLAY_SET")
		replay.disabled = true)
	_actions.add_child(replay)

	_actions.add_child(UiKit.wrapped(tr("ACC_SECTION_PRIVACY"), &"BoothHeading"))
	var privacy := UiKit.icon_button("shield", tr("SETTINGS_PRIVACY"), "PrivacyButton", true, true, 88.0)
	privacy.pressed.connect(func() -> void:
		Monetization.open_provider_privacy_options()
		add_child(ConsentSheet.new()))
	_actions.add_child(privacy)
	if Monetization.privacy_policy_visible():  # yer tutucu adreste (yayın sürümü) düğme gizli; bkz. docs/MONETIZATION.md
		var policy := UiKit.icon_button("document", tr("MON_PRIVACY_POLICY"), "PrivacyPolicyButton", true, true, 88.0)
		policy.pressed.connect(Monetization.open_privacy_policy)
		_actions.add_child(policy)
	var restore := UiKit.icon_button("refresh", tr("MARKET_RESTORE"), "RestoreButton", true, true, 88.0)
	restore.pressed.connect(Monetization.restore)
	_actions.add_child(restore)

	var about := UiKit.icon_button("info", tr("ACC_ABOUT"), "AboutButton", true, true, 88.0)
	about.pressed.connect(open_about)
	_actions.add_child(about)


func open_about() -> void:
	if _about != null and is_instance_valid(_about):
		return
	_about = AboutSheet.new()
	add_child(_about)


func _fill_languages() -> void:
	_language.clear()
	var current := TranslationServer.get_locale()
	var languages := SettingsManager.available_languages()
	for code: String in languages:
		_language.add_item(languages[code])
		var index := _language.item_count - 1
		_language.set_item_metadata(index, code)
		if current.begins_with(code):
			_language.select(index)


func _on_language_selected(index: int) -> void:
	SettingsManager.set_value("game", "language", _language.get_item_metadata(index))
