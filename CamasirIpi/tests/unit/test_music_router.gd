extends TestCase

## MusicRouter: bağlam -> parça eşlemesi, tekrar isteğinde yeniden başlatmama ve geçiş eğrisi.


func test_scene_context() -> void:
	assert_eq(MusicRouter.context_for_scene("res://scenes/Game.tscn"), MusicRouter.Context.GAME)
	assert_eq(MusicRouter.context_for_scene("res://scenes/Home.tscn"), MusicRouter.Context.MENU)
	assert_eq(MusicRouter.context_for_scene("res://scenes/shop/Shop.tscn"), MusicRouter.Context.MENU)


func test_menu_context_resolves_location_track_to_menu_theme() -> void:
	# Eski çağrı play_music("music_garden") ana ekranda menü temasına dönüşür.
	assert_eq(MusicRouter.resolve("music_garden", MusicRouter.Context.MENU), MusicRouter.MENU_TRACK)
	assert_eq(MusicRouter.resolve("music_beach", MusicRouter.Context.MENU), MusicRouter.MENU_TRACK)
	assert_eq(MusicRouter.resolve("", MusicRouter.Context.MENU), MusicRouter.MENU_TRACK)


func test_game_context_uses_ambience_hint() -> void:
	assert_eq(MusicRouter.resolve("music_garden", MusicRouter.Context.GAME, "beach_ambience"), "music_beach")
	assert_eq(MusicRouter.resolve("music_garden", MusicRouter.Context.GAME, "night_ambience"), "music_night")
	assert_eq(MusicRouter.resolve("music_garden", MusicRouter.Context.GAME), "music_garden")


func test_every_ambience_has_a_known_track() -> void:
	for ambience_name: String in MusicRouter.TRACK_BY_AMBIENCE:
		assert_true(MusicRouter.TRACK_BY_AMBIENCE[ambience_name] in MusicRouter.GAME_TRACKS)
	assert_eq(MusicRouter.track_for_ambience("bilinmeyen"), MusicRouter.DEFAULT_GAME_TRACK)


func test_state_follows_scene_and_ambience() -> void:
	var router: MusicRouter = MusicRouter.new()
	assert_eq(router.target(), MusicRouter.MENU_TRACK)
	assert_eq(router.on_ambience("rooftop_ambience"), "music_rooftop")
	assert_eq(router.on_scene("res://scenes/Game.tscn"), "music_rooftop")
	assert_eq(router.on_scene("res://scenes/Home.tscn"), MusicRouter.MENU_TRACK)
	assert_eq(router.on_ambience("garden_ambience"), "music_garden")


func test_same_track_does_not_restart() -> void:
	var router: MusicRouter = MusicRouter.new()
	assert_true(router.needs_switch(MusicRouter.MENU_TRACK))
	router.commit(MusicRouter.MENU_TRACK)
	assert_false(router.needs_switch(MusicRouter.MENU_TRACK))
	assert_false(router.needs_switch(""))
	assert_true(router.needs_switch("music_garden"))


func test_crossfade_durations() -> void:
	assert_eq(MusicRouter.crossfade_seconds("", "music_menu"), MusicRouter.CROSSFADE_MENU_S)
	assert_eq(MusicRouter.crossfade_seconds("music_menu", "music_garden"), MusicRouter.CROSSFADE_MENU_S)
	assert_eq(MusicRouter.crossfade_seconds("music_garden", "music_beach"), MusicRouter.CROSSFADE_PLACE_S)


func test_equal_power_curve() -> void:
	var start: Vector2 = MusicRouter.equal_power_db(0.0)
	var end: Vector2 = MusicRouter.equal_power_db(1.0)
	assert_true(start.x > -0.01)
	assert_true(start.y < -60.0)
	assert_true(end.y > -0.01)
	assert_true(end.x < -60.0)
	# Ortada iki yarı toplam gücü korur: her biri -3 dB.
	var mid: Vector2 = MusicRouter.equal_power_db(0.5)
	assert_true(absf(mid.x + 3.01) < 0.05 and absf(mid.y + 3.01) < 0.05)


func test_volume_and_duck_helpers() -> void:
	assert_eq(MusicRouter.volume_db_for(MusicRouter.MENU_TRACK), MusicRouter.MENU_VOLUME_DB)
	assert_true(MusicRouter.volume_db_for("music_garden") < MusicRouter.MENU_VOLUME_DB)
	assert_eq(MusicRouter.duck_hold_seconds(5.0, 2.2), 2.2)
	assert_eq(MusicRouter.duck_hold_seconds(1.0, 2.2), 1.0)
	var names: Array[String] = ["win", "lose"]
	assert_true(MusicRouter.is_duck_sound("win", names))
	assert_false(MusicRouter.is_duck_sound("coin", names))
