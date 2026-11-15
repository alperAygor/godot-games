extends SceneTree
## T-B1 görsel kontrolü: akşam, oyun bitti (ücretsiz / bedelli / reklamsız sahip tekrar), hikaye sonu, mod sonucu.
## Geçici kayıt kullanır (user://b1_shots_save.json), gerçek kayda dokunmaz; ayar yazmaz.
## Kullanım: godot --resolution 720x1280 --path . -s res://tools/b1_shots.gd -- [--prefix=b1] (--headless ile çalışmaz)
## Çıktı: tools/screenshots/style/<önek>_<ekran>.png

var _prefix := "b1"
var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _shot(shot_name: String, wait := 0.8) -> void:
	DisplayServer.window_move_to_foreground()
	await create_timer(wait).timeout
	RenderingServer.force_draw()
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [_prefix, shot_name]))


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	if DisplayServer.get_name() == "headless":
		printerr("b1_shots.gd: --headless ile görüntü alınamaz.")
		quit(2)
		return
	_out = ProjectSettings.globalize_path("res://tools/screenshots/style")
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	var save := root.get_node("SaveManager")
	var session := root.get_node("GameSession")
	var scenes := root.get_node("SceneManager")
	var original_path: String = save.save_path
	var original_data: Dictionary = save.data.duplicate(true)
	save.save_path = "user://b1_shots_save.json"
	save.data = {}
	scenes.transition_time = 0.0
	TranslationServer.set_locale("en")

	# Akşam (6. gün, ilaç + yemek + ısınma; birkaç müşteri işlenmiş).
	session.new_game()
	var career: Career = session.career
	career.day = 6
	career.household.cash_minor = Money.units(420)
	var shift: Shift = career.new_shift()
	shift.start()
	var bot := ClerkBot.new("perfect", "shots")
	for i in 6:
		shift.advance(20.0)
		if shift.current != null:
			shift.submit(bot.move_for(shift.current, shift.current_verdict))
	shift.advance(400.0)
	session.shift = shift
	await scenes.goto(Scenes.EVENING)
	await _shot("evening")

	# Oyun bitti: kovuldun, 1) ücretsiz hak.
	session.shift = null
	session.new_game()
	career = session.career
	career.day = 6
	career.household.cash_minor = Money.units(640)
	career.begin_day()
	career.game_over = "fired"
	session.save()
	await scenes.goto(Scenes.GAME_OVER)
	await _shot("gameover_free")
	# 2) ücretsiz hak bitti: bedel + reklam alternatifi.
	career.retries["6"] = 1
	await scenes.goto(Scenes.GAME_OVER)
	await _shot("gameover_paid")
	# 3) reklamsız sahip.
	save.data["purchases"] = ["no_ads"]
	await scenes.goto(Scenes.GAME_OVER)
	await _shot("gameover_noads")
	save.data["purchases"] = []
	# Hikaye sonu (dürüst).
	career.game_over = ""
	career.day = 16
	await scenes.goto(Scenes.GAME_OVER)
	await _shot("ending")
	# Günün Kuru sonucu.
	session.start_daily("2026-10-26")
	session.mode.shift.stats["correct"] = 10
	session.mode.shift.stats["mistake_transactions"] = 1
	session.mode.shift.elapsed = 120.0
	session.finish_mode()
	await scenes.goto(Scenes.MODE_RESULT)
	await _shot("mode_result")
	session.abort_mode()
	session.mode_result = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://b1_shots_save.json"))
	for suffix in [".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://b1_shots_save.json" + suffix))
	save.save_path = original_path
	save.data = original_data
	root.get_node("AudioManager").stop_all()
	quit(0)
