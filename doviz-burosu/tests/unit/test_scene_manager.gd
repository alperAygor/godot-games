extends "res://tests/test_case.gd"
## Sahne geçişi, geri tuşu ve dokunmayla gezinme (headless).

const TouchInput := preload("res://tools/touch_input.gd")

var _scenes: Node
var _original_transition: float
var _original_consent := true


func before_each() -> void:
	_original_consent = tree.root.get_node("SettingsManager").get_value("game", "consent_asked")
	tree.root.get_node("SettingsManager").set_value("game", "consent_asked", true, false)
	tree.root.get_node("SettingsManager").set_value("game", "guide_seen", true, false)
	_scenes = tree.root.get_node("SceneManager")
	_original_transition = _scenes.transition_time
	_scenes.transition_time = 0.0
	await _scenes.goto(Scenes.MAIN)


func after_each() -> void:
	tree.root.get_node("SettingsManager").set_value("game", "consent_asked", _original_consent, false)
	_scenes.transition_time = _original_transition


func _wait_idle() -> void:
	for i in 30:
		if not _scenes.is_busy():
			return
		await tree.process_frame


func test_push_then_back_returns_to_previous_scene() -> void:
	assert_eq(_scenes.current_path(), Scenes.MAIN)
	await _scenes.push(Scenes.SETTINGS)
	assert_eq(_scenes.current_path(), Scenes.SETTINGS)
	assert_eq(_scenes.history_size(), 1)
	await _scenes.back()
	assert_eq(_scenes.current_path(), Scenes.MAIN)
	assert_eq(_scenes.history_size(), 0)


func test_android_back_notification_navigates_back() -> void:
	await _scenes.push(Scenes.SETTINGS)
	await TouchInput.back(tree)
	await _wait_idle()
	assert_eq(_scenes.current_path(), Scenes.MAIN)


func test_back_at_root_emits_signal_when_listened() -> void:
	var hits := [0]
	var on_root_back := func() -> void: hits[0] += 1
	_scenes.root_back_requested.connect(on_root_back)
	await _scenes.back()
	_scenes.root_back_requested.disconnect(on_root_back)
	assert_eq(hits[0], 1, "kökte geri tuşu sinyal yayınlamalı (dinleyen varken kapanmamalı)")
	assert_eq(_scenes.current_path(), Scenes.MAIN)


func test_tapping_settings_button_opens_settings() -> void:
	var tapped: bool = await TouchInput.tap_node(tree, "SettingsButton")
	assert_true(tapped, "SettingsButton bulunmalı")
	await _wait_idle()
	assert_eq(_scenes.current_path(), Scenes.SETTINGS)


func test_back_closes_open_popup_before_leaving_scene() -> void:
	await _scenes.push(Scenes.SETTINGS)
	var option: OptionButton = tree.current_scene.get_node("%LanguageOption")
	option.show_popup()
	await tree.process_frame
	assert_true(option.get_popup().visible, "dil menüsü açılmalı")
	await TouchInput.back(tree)
	await _wait_idle()
	assert_false(option.get_popup().visible, "geri tuşu önce menüyü kapatmalı")
	assert_eq(_scenes.current_path(), Scenes.SETTINGS, "sahnede kalınmalı")
