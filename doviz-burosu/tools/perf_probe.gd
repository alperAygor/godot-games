extends SceneTree
## Performans ölçümü. Kullanım:
##   godot --headless --path . -s res://tools/perf_probe.gd -- --part=cpu      (çekirdek işlemlerin süresi, ms)
##   godot --resolution 720x1280 --path . -s res://tools/perf_probe.gd -- --part=frames   (masa sahnesinde kare süresi/çizim/bellek; ekranlı)
## Sayılar bu makineye göredir; telefonda mutlak değerler farklıdır, KARŞILAŞTIRMA için kullan.

var _part := "cpu"


func _initialize() -> void:
	_run.call_deferred()


func _time(label: String, repeat: int, action: Callable) -> void:
	var start := Time.get_ticks_usec()
	for i in repeat:
		action.call()
	var per := float(Time.get_ticks_usec() - start) / repeat / 1000.0
	print("%-44s %8.3f ms  (x%d)" % [label, per, repeat])


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--part="):
			_part = arg.trim_prefix("--part=")
	await process_frame
	if _part == "cpu":
		_cpu()
	else:
		await _frames()
	quit(0)


func _cpu() -> void:
	print("== CPU (ms/çağrı) ==")
	_time("JsonIO.read_dict balance.json", 200, func() -> void: JsonIO.read_dict("res://data/balance.json"))
	_time("JsonIO.read_dict currencies.json", 200, func() -> void: JsonIO.read_dict("res://data/currencies.json"))
	_time("JsonIO.read_dict customers.json", 200, func() -> void: JsonIO.read_dict("res://data/customers.json"))
	_time("CurrencyBook.load_default", 100, func() -> void: CurrencyBook.load_default())
	_time("RuleSet.load_default", 100, func() -> void: RuleSet.load_default())
	_time("StoryDb.load_default (16 dosya)", 20, func() -> void: StoryDb.load_default())
	var career := Career.load_default("perf")
	career.day = 13
	_time("Career.load_default", 50, func() -> void: Career.load_default("perf"))
	_time("career.make_context", 50, func() -> void: career.make_context())
	_time("career.new_shift", 50, func() -> void: career.new_shift())
	_time("Newspaper.build", 20, func() -> void: Newspaper.build(career))
	var ctx := career.make_context()
	var factory := CustomerFactory.new(ctx, Seed.rng("perf-customers"))
	_time("CustomerFactory.make_random", 300, func() -> void: factory.make_random())
	var customers: Array[Customer] = []
	for i in 100:
		customers.append(factory.make_random())
	var engine := RuleEngine.new(ctx)
	var index := [0]
	_time("RuleEngine.evaluate", 300, func() -> void:
		engine.evaluate(customers[index[0] % customers.size()])
		index[0] += 1)
	_time("DailyChallenge.new (12 müşteri + vardiya)", 5, func() -> void: DailyChallenge.new("2026-10-26"))
	_time("EndlessRun.new", 10, func() -> void: EndlessRun.new("perf"))
	var story_career := Career.load_default("perf")
	story_career.day = 10
	story_career.story_enabled = true
	var director := StoryDirector.new(story_career)
	var beats: Array = director.day_def.get("beats", [])
	if not beats.is_empty():
		_time("StoryDirector.build_customer (gün 10 olayı)", 10, func() -> void: director.build_customer(beats[0], story_career.make_context()))
	_time("Seed.rng + 50 randi", 2000, func() -> void:
		var generator := Seed.rng("perf")
		for i in 50:
			generator.randi())
	_time("career.to_dict + load_dict", 50, func() -> void:
		var saved := career.to_dict()
		Career.load_default("perf").load_dict(saved))
	_time("JSON.stringify(career dict)", 50, func() -> void: JSON.stringify(career.to_dict()))
	var bot := ClerkBot.new("perfect", "perf")
	_time("bir günü botla oyna (play_shift)", 3, func() -> void:
		var shift := Career.load_default("perf2").new_shift()
		bot.play_shift(shift))


func _snapshot(label: String) -> void:
	print("%-26s fps=%5.1f  süreç=%6.2f ms  çizim çağrısı=%3d  ilkel=%5d  nesne=%5d  düğüm=%4d  yetim=%2d  kaynak=%4d  bellek=%6.1f MB" % [
		label, Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])


## Ortalama kare ölçümü: [fps, ort. render CPU ms, ort. render GPU ms, en kötü GPU ms]. (TIME_PROCESS vsync'i de kapsar; bu yüzden render süreleri ölçülür.)
func _average_frame(seconds: float) -> Array:
	var rid := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	await process_frame
	var start := Time.get_ticks_msec()
	var frames := 0
	var cpu_total := 0.0
	var gpu_total := 0.0
	var worst := 0.0
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await process_frame
		frames += 1
		cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		gpu_total += gpu
		worst = maxf(worst, gpu)
	return [frames / seconds, cpu_total / maxf(frames, 1), gpu_total / maxf(frames, 1), worst]


func _frames() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("--part=frames ekranlı çalışmalı")
		return
	var save := root.get_node("SaveManager")
	var session := root.get_node("GameSession")
	var scenes := root.get_node("SceneManager")
	save.save_path = "user://perf_save.json"
	save.data = {}
	scenes.transition_time = 0.0
	root.get_node("SettingsManager").set_value("game", "consent_asked", true, false)
	session.story_enabled = false
	print("== Kare ölçümü (ekranlı; Mac GPU) ==")
	var t0 := Time.get_ticks_usec()
	await scenes.goto(Scenes.MAIN)
	print("   MAIN'e geçiş: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	await create_timer(1.0).timeout
	_snapshot("menü (açılış)")
	var menu_stats: Array = await _average_frame(3.0)
	print("   menü 3 sn: fps=%.1f  render CPU=%.2f ms  GPU=%.2f ms  en kötü GPU=%.2f ms" % menu_stats)
	session.new_game()
	session.career.day = 8
	t0 = Time.get_ticks_usec()
	await scenes.goto(Scenes.DESK)
	print("   DESK'e geçiş: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for scene_path in [Scenes.MORNING, Scenes.EVENING, Scenes.MARKET, Scenes.SETTINGS]:
		t0 = Time.get_ticks_usec()
		await scenes.goto(scene_path)
		print("   %s geçiş: %.1f ms" % [scene_path.get_file(), (Time.get_ticks_usec() - t0) / 1000.0])
	await create_timer(0.3).timeout
	await scenes.goto(Scenes.DESK)
	var desk := current_scene
	print("   şimdiki sahne: ", scenes.current_path())
	await create_timer(3.0).timeout
	_snapshot("masa (müşteri geldi)")
	var stats: Array = await _average_frame(4.0)
	print("   masa 4 sn: fps=%.1f  render CPU=%.2f ms  GPU=%.2f ms  en kötü GPU=%.2f ms" % stats)
	var atmosphere := desk.get_node("Atmosphere") as Control
	atmosphere.visible = false
	stats = await _average_frame(3.0)
	print("   atmosfersiz 3 sn: fps=%.1f  render CPU=%.2f ms  GPU=%.2f ms  en kötü GPU=%.2f ms" % stats)
	atmosphere.visible = true
	_snapshot("masa (son)")
	# Sahne geçişi sızıntı kontrolü: 15 kez masa <-> menü
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 15:
		await scenes.goto(Scenes.MAIN)
		await scenes.goto(Scenes.DESK)
		await create_timer(0.3).timeout
	await create_timer(1.0).timeout
	_snapshot("15 geçiş sonrası")
	print("   düğüm sayısı farkı: %d" % (int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - before)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://perf_save.json"))
	session.abort_mode()
	root.get_node("AudioManager").stop_all()
