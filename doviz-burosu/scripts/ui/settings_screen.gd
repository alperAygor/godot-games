extends Control
## Ayarlar ekranı. Sadece SettingsManager'ı okur/yazar; ses uygulaması AudioManager'da, dil SettingsManager'da.

@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _vibration: CheckButton = %VibrationToggle
@onready var _pixel: CheckButton = %PixelToggle
@onready var _language: OptionButton = %LanguageOption
@onready var _back: Button = %BackButton


func _ready() -> void:
	add_child(ScreenBackdrop.new())
	move_child(get_child(get_child_count() - 1), 1)
	_bind_volume(_music, "music")
	_bind_volume(_sfx, "sfx")

	_vibration.button_pressed = SettingsManager.get_value("game", "vibration")
	_vibration.toggled.connect(func(on: bool) -> void: SettingsManager.set_value("game", "vibration", on))

	_pixel.button_pressed = SettingsManager.get_value("game", "pixel_filter")
	_pixel.toggled.connect(func(on: bool) -> void: SettingsManager.set_value("game", "pixel_filter", on))

	_fill_languages()
	_language.item_selected.connect(_on_language_selected)

	var privacy := UiKit.icon_button("shield", tr("SETTINGS_PRIVACY"), "PrivacyButton", true, true, 76.0)
	privacy.pressed.connect(func() -> void:
		Monetization.open_provider_privacy_options()
		add_child(ConsentSheet.new()))
	_back.get_parent().add_child(privacy)
	_back.get_parent().move_child(privacy, _back.get_index())
	var restore := UiKit.icon_button("refresh", tr("MARKET_RESTORE"), "RestoreButton", true, true, 76.0)
	restore.pressed.connect(Monetization.restore)
	_back.get_parent().add_child(restore)
	_back.get_parent().move_child(restore, _back.get_index())
	_back.pressed.connect(SceneManager.back)


## SceneManager geri tuşunda önce bunu sorar: açık bir menü varsa onu kapat, sahneden çıkma.
func handle_back() -> bool:
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
