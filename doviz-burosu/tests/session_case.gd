extends "res://tests/engine_case.gd"
## Oyun oturumuna ve sahne geçişlerine dokunan testlerin tabanı: kaydı test dosyasına yönlendirir, böylece
## kullanıcının gerçek kaydı ASLA bozulmaz. (Kendi başına test içermez.)

const TouchInput := preload("res://tools/touch_input.gd")
const SESSION_TEST_PATH := "user://test_ui_save.json"

var scenes: Node
var session: Node
var save_manager: Node

var _transition := 0.15
var _original_path := ""
var _original_consent := true
var _original_guide := true
var _original_data := {}


func before_each() -> void:
	super.before_each()
	scenes = tree.root.get_node("SceneManager")
	session = tree.root.get_node("GameSession")
	save_manager = tree.root.get_node("SaveManager")
	_transition = scenes.transition_time
	scenes.transition_time = 0.0
	_original_consent = tree.root.get_node("SettingsManager").get_value("game", "consent_asked")
	tree.root.get_node("SettingsManager").set_value("game", "consent_asked", true, false)  # gizlilik penceresi testlerde engellemesin
	_original_guide = tree.root.get_node("SettingsManager").get_value("game", "guide_seen")
	tree.root.get_node("SettingsManager").set_value("game", "guide_seen", true, false)
	_original_path = save_manager.save_path
	_original_data = save_manager.data.duplicate(true)
	save_manager.save_path = SESSION_TEST_PATH
	save_manager.data = {}
	session.career = null
	session.shift = null
	session.last_playable_day = session.LAST_PLAYABLE_DAY
	session.story_enabled = false  # arayüz akışı testleri hikayesiz; hikayeli olanlar kendisi açar
	session.office_enabled = false  # talimat/not da kapalı (maaş sayıları sabit kalsın); ilgili testler kendisi açar


func after_each() -> void:
	for i in 60:  # süren bir sahne geçişi (ör. ödüllü reklamdan sonra) bitmeden ana menüye dönülemez
		if not scenes.is_busy():
			break
		await tree.process_frame
	await scenes.goto(Scenes.MAIN)
	scenes.transition_time = _transition
	save_manager.save_path = _original_path
	save_manager.data = _original_data
	session.career = null
	session.shift = null
	session.last_playable_day = session.LAST_PLAYABLE_DAY
	session.story_enabled = true
	session.office_enabled = true
	tree.root.get_node("SettingsManager").set_value("game", "consent_asked", _original_consent, false)
	tree.root.get_node("SettingsManager").set_value("game", "guide_seen", _original_guide, false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_TEST_PATH))


func tap(node_name: String) -> void:
	var tapped: bool = await TouchInput.tap_node(tree, node_name)
	assert_true(tapped, "%s dokunulabilir olmalı" % node_name)


## Kaydırma alanının içindeki bir düğmeye dokunmadan önce onu görünür alana kaydırır (uzun listeler).
func tap_scrolled(node_name: String) -> void:
	var target := node(node_name)
	assert_true(target != null, "%s bulunmalı" % node_name)
	var parent := target.get_parent()
	while parent != null and not (parent is ScrollContainer):
		parent = parent.get_parent()
	if parent != null:
		(parent as ScrollContainer).ensure_control_visible(target)
		await tree.process_frame
		await tree.process_frame
	await tap(node_name)


func node(node_name: String) -> Control:
	return TouchInput.find_control(tree, node_name)


func wait_for_scene(path: String) -> void:
	for i in 40:
		if scenes.current_path() == path:
			break
		await tree.process_frame
	assert_eq(scenes.current_path(), path)
	await tree.process_frame
