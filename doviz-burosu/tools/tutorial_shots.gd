extends SceneTree
## Gün 1 öğreticisinin her adımının ekran görüntüsü (pencereli; betikli çalıştığı için kayıt/ayar sandbox'ta).
##   godot --resolution 720x1280 --path . -s res://tools/tutorial_shots.gd -- [--prefix=tut] [--locale=en] [--simulate-safe-area=88,0,68,0]
## Çıktı: tools/screenshots/tutorial/<önek>_<sıra>_<adım>.png (git dışı). --headless ile çalışmaz.
## Akış `tools/tutorial_probe_flow.gd` ile aynı dokunuşları yapar; her adımda önce çeker, sonra dokunur.

const TouchInput := preload("res://tools/touch_input.gd")
const WATCHDOG_SECONDS := 150.0

var _prefix := "tut"
var _out := ""
var _index := 0


func _initialize() -> void:
	_run.call_deferred()


func _shot(shot_name: String, wait := 0.6) -> void:
	DisplayServer.window_move_to_foreground()
	await create_timer(wait).timeout
	RenderingServer.force_draw()
	_index += 1
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%02d_%s.png" % [_prefix, _index, shot_name]))


func _run() -> void:
	var locale := "en"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
		if arg.begins_with("--locale="):
			locale = arg.trim_prefix("--locale=")
	if DisplayServer.get_name() == "headless":
		printerr("tutorial_shots.gd: --headless ile görüntü alınamaz.")
		quit(2)
		return
	create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func() -> void:
		printerr("tutorial_shots.gd: zaman aşımı")
		quit(1))
	_out = ProjectSettings.globalize_path("res://tools/screenshots/tutorial")
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	var settings := root.get_node("SettingsManager")
	var scenes := root.get_node("SceneManager")
	var session := root.get_node("GameSession")
	settings.set_value("game", "consent_asked", true, false)
	settings.set_value("game", "guide_seen", false, false)
	scenes.transition_time = 0.0
	TranslationServer.set_locale(locale)
	load("res://scripts/ui/desk_tutorial.gd").write_state(false, false)
	await scenes.goto(Scenes.MAIN)
	await TouchInput.tap_node(self, "NewGameButton")
	await _shot("welcome")
	await TouchInput.tap_node(self, "GuideNext")
	for i in 30:
		if scenes.current_path() == Scenes.MORNING:
			break
		await process_frame
	await _shot("morning")
	await TouchInput.tap_node(self, "StartShiftButton")
	for i in 30:
		if scenes.current_path() == Scenes.DESK:
			break
		await process_frame
	var desk: Node = current_scene
	var story_round := 0
	while TouchInput.find_control(self, "StorySheet") != null and story_round < 6:
		story_round += 1
		if story_round == 1:
			await _shot("story")
		await TouchInput.tap_node(self, "StoryContinueButton")
	var tutorial: Node = desk.get("tutorial")
	var last := ""
	for round_index in 40:
		await process_frame
		var flow: RefCounted = tutorial.get("flow")
		var step: String = flow.call("current")
		if step == "done":
			break
		if step in ["waiting", "hidden"]:
			desk.call("tick", 0.5)
			continue
		if step != last:
			await _shot(step, 1.4 if last.is_empty() else 0.7)
			last = step
		match step:
			"request", "result", "outro":
				await TouchInput.tap_node(self, "TutorialNext")
			"inspect":
				await TouchInput.tap_node(self, "NoteTile0")
			"inspect_close", "rates_close", "close_other":
				await TouchInput.tap_node(self, "CloseSheetButton")
			"rates":
				await TouchInput.tap_node(self, "ToolBookButton")
			"pay":
				await TouchInput.tap_node(self, "PayButton_PL")
			"pay_type":
				var units := int((flow.get("lesson") as Dictionary)["payout_minor"]) / 100
				for digit in str(units):
					await TouchInput.tap_node(self, "Key_%s" % digit)
				await _shot("pay_typed", 0.3)
				await TouchInput.tap_node(self, "NumpadOk")
			"stamp":
				await TouchInput.tap_node(self, "CompleteButton")
	await _shot("after", 1.2)
	settings.set_value("game", "guide_seen", true, false)
	await scenes.goto(Scenes.MAIN)
	await TouchInput.tap_node(self, "HelpButton")
	await _shot("menu_guide")
	root.get_node("AudioManager").stop_all()
	for i in 4:
		await process_frame
	quit(0)
