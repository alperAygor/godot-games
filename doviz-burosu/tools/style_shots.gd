extends SceneTree
## Görsel stil kontrolü: tüm ana ekranların 720x1280 görüntüsünü alır (geçici kayıt kullanır, gerçek kaydı bozmaz).
## Kullanım: godot --resolution 720x1280 --path . -s res://tools/style_shots.gd -- [--prefix=ad] [--guide] [--simulate-safe-area=88,0,68,0]
## Çıktı: tools/screenshots/style/<önek>_<ekran>.png (--headless ile çalışmaz).

var _prefix := "style"
var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _shot(shot_name: String, wait := 0.8) -> void:
	DisplayServer.window_move_to_foreground()  # (macOS'ta örtülen pencere çizilmeyip eski kareyi verebiliyor)
	await create_timer(wait).timeout  # geliş animasyonları bitsin
	RenderingServer.force_draw()
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [_prefix, shot_name]))


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	if DisplayServer.get_name() == "headless":
		printerr("style_shots.gd: --headless ile görüntü alınamaz.")
		quit(2)
		return
	_out = ProjectSettings.globalize_path("res://tools/screenshots/style")
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	var save := root.get_node("SaveManager")
	var session := root.get_node("GameSession")
	var scenes := root.get_node("SceneManager")
	save.save_path = "user://style_shots_save.json"
	save.data = {}
	scenes.transition_time = 0.0
	TranslationServer.set_locale("tr")

	session.new_game()
	var career: Career = session.career
	career.day = 5
	career.begin_day()
	session.save()
	await scenes.goto(Scenes.MAIN)
	await _shot("1_menu")
	if OS.get_cmdline_user_args().has("--guide"):  # (bazı makinelerde rehber sonrası görüntü donuyor; yalnızca isteyince)
		var guide: Control = load("res://scripts/ui/guide_sheet.gd").new()
		current_scene.add_child(guide)
		await _shot("1a_guide")
		guide._show(2)
		await _shot("1b_guide3")
		guide._show(5)
		await _shot("1c_guide6")
		guide.queue_free()
	await scenes.goto(Scenes.MORNING)
	await _shot("2_morning")

	career.day = 5
	await scenes.goto(Scenes.DESK)
	var desk := current_scene
	desk.set_process(false)
	var bot := ClerkBot.new("perfect", "shots")
	for i in 3:
		desk.tick(3.0)
		await process_frame
		desk.shift.submit(bot.move_for(desk.shift.current, desk.shift.current_verdict))
		desk._shown = null
		desk._clear_customer()
		desk._sync()
	desk.tick(3.0)
	await _shot("3_story")
	desk.shift.resolve_beat("take")
	desk._close_sheet()
	desk._sync()
	await _shot("4_desk", 3.2)
	desk._open_inspect_sheet(0)
	await _shot("5_inspect")
	desk._close_sheet()
	desk.shift.advance(400.0)
	session.shift = desk.shift
	await scenes.goto(Scenes.EVENING)
	await _shot("6_evening")
	career.day = 16
	career.story.set_flag("passport")
	await scenes.goto(Scenes.GAME_OVER)
	await _shot("7_ending")
	await scenes.goto(Scenes.SETTINGS)
	await _shot("13_settings")
	await scenes.goto(Scenes.MARKET)
	await _shot("11_market")
	save.data["purchases"] = ["no_ads"]
	await scenes.goto(Scenes.MARKET)
	await _shot("12_market_owned")
	session.modes().note_day_reached(11)
	await scenes.goto(Scenes.MAIN)
	await _shot("8_menu_modes")
	session.start_daily("2026-10-26")
	await scenes.goto(Scenes.DESK)
	var daily_desk := current_scene
	daily_desk.set_process(false)
	await _shot("9_daily_desk", 3.2)
	session.mode.shift.stats["correct"] = 10
	session.mode.shift.stats["mistake_transactions"] = 1
	session.mode.shift.elapsed = 120.0
	session.finish_mode()
	await scenes.goto(Scenes.MODE_RESULT)
	await _shot("10_daily_result")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://style_shots_save.json"))
	session.abort_mode()
	session.mode_result = {}
	root.get_node("AudioManager").stop_all()
	for i in 4:
		await process_frame
	quit(0)
