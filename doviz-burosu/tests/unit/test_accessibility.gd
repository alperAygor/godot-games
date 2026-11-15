extends "res://tests/session_case.gd"
## T-A2: erişilebilirlik ayarları (yazı boyutu, renk körü, hareketi azalt), ana ses, Ayarlar ekranı ve kalıcılık.

var _settings: Node
var _saved := {}


func before_each() -> void:
	super.before_each()
	_settings = tree.root.get_node("SettingsManager")
	_saved = {
		"master": _settings.get_value("audio", "master"), "size": _settings.get_value("access", "text_size"),
		"cb": _settings.get_value("access", "color_blind"), "rm": _settings.get_value("access", "reduced_motion"),
	}


func after_each() -> void:
	_settings.set_value("audio", "master", _saved["master"], false)
	_settings.set_value("access", "text_size", _saved["size"], false)
	_settings.set_value("access", "color_blind", _saved["cb"], false)
	_settings.set_value("access", "reduced_motion", _saved["rm"], false)
	await super.after_each()


# --- saf kurallar -------------------------------------------------------------------------------------------------

func test_text_sizes_are_sanitized_and_scaled() -> void:
	assert_eq(Accessibility.sanitize_text_size("huge"), "normal")
	assert_eq(Accessibility.sanitize_text_size(7), "normal")
	assert_eq(Accessibility.sanitize_text_size("large"), "large")
	assert_almost_eq(Accessibility.text_scale("normal"), 1.0)
	assert_true(Accessibility.text_scale("large") > 1.1)
	assert_eq(Accessibility.scaled_size(30, "normal"), 30)
	assert_eq(Accessibility.scaled_size(30, "large"), 36)


func test_marks_only_in_color_blind_mode() -> void:
	assert_eq(Accessibility.marked("good", "Kabul", false), "Kabul")
	assert_eq(Accessibility.marked("good", "Kabul", true), "[+] Kabul")
	assert_eq(Accessibility.marked("warn", "İade", true), "[!] İade")
	assert_eq(Accessibility.marked("bad", "El koy", true), "[x] El koy")
	assert_eq(Accessibility.marked("other", "x", true), "x")


func test_color_blind_palette_separates_red_green_and_keeps_greys() -> void:
	var good := Accessibility.adapt(UiKit.GOOD_COLOR, true)
	var bad := Accessibility.adapt(UiKit.BAD_COLOR, true)
	var warn := Accessibility.adapt(UiKit.WARN_COLOR, true)
	assert_true(good.b > good.r and good.b > good.g, "yeşil mavi olur: %s" % good)
	assert_true(bad.r > bad.b and bad.r > bad.g, "kırmızı turuncu-kırmızı kalır: %s" % bad)
	assert_true(absf(good.h - bad.h) > 0.3, "iyi/kötü tonları ayrık")
	assert_true(absf(warn.h - bad.h) > 0.04 or absf(warn.v - bad.v) > 0.12, "uyarı/kötü ayrık")
	assert_eq(Accessibility.adapt(UiKit.GOOD_COLOR, false), UiKit.GOOD_COLOR, "kip kapalıyken renk aynen")
	var grey := Color(0.5, 0.5, 0.5, 0.7)
	assert_eq(Accessibility.adapt(grey, true), grey, "gri değişmez, alfa korunur")
	assert_almost_eq(Accessibility.adapt(Color(0.2, 0.7, 0.2, 0.4), true).a, 0.4)


func test_tone_marks_are_stable_and_in_range() -> void:
	assert_eq(Accessibility.tone_marks(Color(0.5, 0.5, 0.5)), 0)
	for hex in ["#8FBF7A", "#6FB3A0", "#E0A458", "#D9776B", "#9B7ED0", "#5E8FD6"]:
		var marks := Accessibility.tone_marks(Color(hex))
		assert_true(marks >= 1 and marks <= 6, hex)
		assert_eq(Accessibility.tone_marks(Color(hex)), marks)


# --- tema türetme -------------------------------------------------------------------------------------------------

func test_large_text_theme_scales_every_font_size_and_leaves_base_untouched() -> void:
	var base: Theme = ThemeDB.get_project_theme()
	var before := base.get_font_size("font_size", "Label")
	var large := ThemeVariants.build(base, "large", false)
	assert_true(large != base)
	assert_eq(base.get_font_size("font_size", "Label"), before, "taban tema değişmedi")
	assert_eq(large.get_font_size("font_size", "Label"), Accessibility.scaled_size(before, "large"))
	for type: StringName in base.get_font_size_type_list():
		for item: StringName in base.get_font_size_list(type):
			assert_true(large.get_font_size(item, type) > base.get_font_size(item, type), "%s/%s büyüdü" % [type, item])
	assert_eq(ThemeVariants.build(base, "normal", false), base, "varsayılan: taban tema döner")


func test_color_blind_theme_recolors_buttons_without_touching_the_base() -> void:
	var base: Theme = ThemeDB.get_project_theme()
	var original: StyleBoxFlat = base.get_stylebox("normal", "Button")
	var original_color := original.bg_color
	var variant := ThemeVariants.build(base, "normal", true)
	var recolored: StyleBoxFlat = variant.get_stylebox("normal", "Button")
	assert_eq(original.bg_color, original_color, "taban stil kutusu değişmedi")
	assert_true(recolored != original)
	assert_true(recolored.bg_color.b > recolored.bg_color.g, "yeşil onay düğmesi mavileşti: %s" % recolored.bg_color)


func test_settings_apply_theme_to_the_root_window_live() -> void:
	assert_true(tree.root.theme == null, "varsayılan: proje teması")
	_settings.set_value("access", "text_size", "large", false)
	assert_true(tree.root.theme != null)
	var large := tree.root.theme.get_font_size("font_size", "Label")
	_settings.set_value("access", "text_size", "normal", false)
	assert_true(tree.root.theme == null)
	assert_true(large > ThemeDB.get_project_theme().get_font_size("font_size", "Label"))


# --- kalıcılık ----------------------------------------------------------------------------------------------------

func test_new_settings_have_defaults_and_persist() -> void:
	assert_eq(SettingsManager.DEFAULTS["access"]["text_size"], "normal")
	assert_false(SettingsManager.DEFAULTS["access"]["color_blind"])
	assert_false(SettingsManager.DEFAULTS["access"]["reduced_motion"])
	var path := "user://_sandbox/test_access_settings.cfg"
	var writer: Node = preload("res://scripts/autoload/settings_manager.gd").new()
	writer.settings_path = path
	writer.set_value("access", "text_size", "large")
	writer.set_value("access", "color_blind", true)
	writer.set_value("access", "reduced_motion", true)
	writer.set_value("audio", "master", 0.35)
	var reader: Node = preload("res://scripts/autoload/settings_manager.gd").new()
	reader.settings_path = path
	reader.load_settings()
	assert_eq(reader.get_value("access", "text_size"), "large")
	assert_true(reader.get_value("access", "color_blind"))
	assert_true(reader.get_value("access", "reduced_motion"))
	assert_almost_eq(float(reader.get_value("audio", "master")), 0.35)
	writer.free()
	reader.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func test_unknown_text_size_in_a_saved_file_falls_back_to_normal() -> void:
	var path := "user://_sandbox/test_access_bad.cfg"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[access]\ntext_size=\"gigantic\"\ncolor_blind=true\n")
	file.close()
	var reader: Node = preload("res://scripts/autoload/settings_manager.gd").new()
	reader.settings_path = path
	reader.load_settings()
	assert_eq(reader.get_value("access", "text_size"), "normal")
	assert_true(reader.get_value("access", "color_blind"))
	reader.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_master_volume_reaches_the_master_bus() -> void:
	_settings.set_value("audio", "master", 0.5, false)
	var index := AudioServer.get_bus_index(&"Master")
	assert_almost_eq(AudioServer.get_bus_volume_linear(index), 0.5, 0.02)
	_settings.set_value("audio", "master", 1.0, false)
	assert_almost_eq(AudioServer.get_bus_volume_linear(index), 1.0, 0.02)


# --- hareketi azalt -----------------------------------------------------------------------------------------------

func test_reduced_motion_flag_is_read_by_helpers() -> void:
	assert_false(A11y.reduced_motion())
	_settings.set_value("access", "reduced_motion", true, false)
	assert_true(A11y.reduced_motion())
	# Sallantı bu kipte hiçbir tween kurmaz.
	var root := Control.new()
	tree.root.add_child(root)
	var before := root.position
	Feel.shake(root, 9.0)
	assert_eq(root.position, before)
	root.queue_free()


# --- Ayarlar ekranı -----------------------------------------------------------------------------------------------

func test_settings_screen_text_size_and_toggles_take_effect_and_persist() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	assert_true((node("TextNormalButton") as Button).button_pressed)
	await tap("TextLargeButton")
	assert_eq(_settings.get_value("access", "text_size"), "large")
	assert_true(tree.root.theme != null, "tema anında büyüdü")
	assert_true((node("TextLargeButton") as Button).button_pressed)
	assert_false((node("TextNormalButton") as Button).button_pressed)
	await tap("TextNormalButton")
	assert_eq(_settings.get_value("access", "text_size"), "normal")
	await tap("ColorBlindToggle")
	assert_true(bool(_settings.get_value("access", "color_blind")))
	assert_true(_label_text("Preview_good").begins_with("[+]"), "önizleme işaretli: %s" % _label_text("Preview_good"))
	await tap("ColorBlindToggle")
	assert_false(_label_text("Preview_good").begins_with("[+]"))
	await tap("ReducedMotionToggle")
	assert_true(bool(_settings.get_value("access", "reduced_motion")))


func test_settings_screen_master_slider_is_bound() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	var slider: HSlider = node("MasterSlider")
	slider.value = 0.4
	assert_almost_eq(float(_settings.get_value("audio", "master")), 0.4)


func test_settings_screen_rows_are_phone_sized_and_scrollable() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	for name in ["TextNormalButton", "TextLargeButton", "ColorBlindToggle", "ReducedMotionToggle", "VibrationToggle", "PixelToggle", "LanguageOption",
			"ReplayTutorialButton", "PrivacyButton", "RestoreButton", "AboutButton", "BackButton"]:
		var control: Control = node(name)
		assert_true(control != null, name)
		if control != null:
			assert_true(control.custom_minimum_size.y >= 76.0 or control.size.y >= 76.0, "%s dokunma hedefi >= 76 px" % name)
	assert_true(node("Scroll") is ScrollContainer, "liste kaydırılabilir")


func test_settings_replay_tutorial_requests_a_replay() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	await tap("ReplayTutorialButton")
	assert_true(bool(DeskTutorial.read_state()["replay"]))
	assert_true((node("ReplayTutorialButton") as Button).disabled)


func test_settings_back_closes_about_before_leaving() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	await tap("AboutButton")
	assert_true(node("AboutSheet") != null)
	await TouchInput.back(tree)
	await tree.process_frame
	await tree.process_frame
	assert_true(node("AboutSheet") == null, "geri tuşu önce Hakkında'yı kapatır")
	assert_eq(scenes.current_path(), Scenes.SETTINGS, "ekrandan çıkılmadı")


func _label_text(node_name: String) -> String:
	var control := node(node_name)
	return (control as Label).text if control is Label else ""
