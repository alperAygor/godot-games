extends "res://tests/session_case.gd"
## "His" katmanı: damga, sarsıntı, kazanç yazısı, müşteri geliş animasyonu ve yüz çizimi.


func _open_desk() -> Control:
	var career := Career.load_default("feel-test")
	await scenes.goto(Scenes.DESK)
	var desk := tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame
	return desk


func test_faces_are_deterministic_and_varied() -> void:
	assert_eq(FaceView.traits(17), FaceView.traits(17), "aynı kimlik aynı yüz")
	var seen := {}
	for id in 400:
		seen[str(FaceView.traits(id))] = true
	assert_true(seen.size() > 150, "400 yüz yeterince çeşitli olmalı (%d)" % seen.size())
	for character_id in ["riza", "tilki", "deniz", "hayri", "stranger"]:
		var face_id := int(StoryDb.load_default().character(character_id)["face_id"])
		assert_true(FaceView.traits(face_id).has("skin"), character_id)


func test_missing_sound_and_disabled_haptics_are_harmless() -> void:
	Feel.sfx("no_such_sound")
	var settings := tree.root.get_node("SettingsManager")
	var original: bool = settings.get_value("game", "vibration")
	settings.set_value("game", "vibration", false, false)
	Feel.haptic(30)
	settings.set_value("game", "vibration", original, false)
	assert_true(true)


func test_every_sound_the_game_plays_exists() -> void:
	for sound in ["bell", "note_drop", "stamp", "coin", "error", "page"]:
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.mp3" % sound), sound)


func test_decision_stamps_the_screen_shakes_and_settles() -> void:
	var desk := await _open_desk()
	await tap("CompleteButton")
	var mark := desk.get_node_or_null("StampMark") as Label
	assert_true(mark != null, "karar damga bırakır")
	assert_eq(mark.text, "ONAYLANDI")
	await tree.create_timer(0.5).timeout
	assert_eq(desk.position, Vector2.ZERO, "sarsıntı bitince ekran yerine döner")
	await tree.create_timer(0.9).timeout
	assert_true(desk.get_node_or_null("StampMark") == null, "damga silinir")


func test_stamp_text_follows_the_decision() -> void:
	for pair in [["reject", "RED"], ["police", "POLİS"]]:
		var desk := await _open_desk()
		desk._decide(pair[0], "R_EXCHANGE")
		assert_eq((desk.get_node("StampMark") as Label).text, pair[1])
		await tree.create_timer(1.0).timeout


func test_arrival_animation_ends_with_everything_visible_and_in_place() -> void:
	var desk := await _open_desk()
	await tree.create_timer(0.8).timeout
	for tile in node("NoteTile0").get_parent().get_children():
		assert_eq((tile as Control).modulate.a, 1.0, "banknot görünür olmalı")
		assert_eq((tile as Control).scale, Vector2.ONE)
	assert_eq(desk.position, Vector2.ZERO)
