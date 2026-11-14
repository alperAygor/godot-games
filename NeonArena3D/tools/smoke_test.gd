extends SceneTree
## Headless oynanış testi: bot oynar, dalga/seviye/boss istatistiği basar.
## godot --headless --path . -s res://tools/smoke_test.gd -- --demo --seconds=40

var scene
var _seconds := 40.0
var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
	await process_frame
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = 3.0
	var t := 0.0
	var last_print := -5.0
	var max_alive := 0
	var max_bullets := 0
	var max_level := 1
	var max_nova := 0.0
	var saw_boss := false
	var saw_elite := false
	while t < _seconds:
		await create_timer(0.25, true, false, true).timeout
		t += 0.25
		if not is_instance_valid(scene) or scene.run == null:
			continue
		max_alive = maxi(max_alive, scene.run.alive)
		max_bullets = maxi(max_bullets, scene.field.bullets.size())
		max_level = maxi(max_level, scene.run.level)
		max_nova = maxf(max_nova, scene.nova)
		if scene.boss != null and is_instance_valid(scene.boss):
			saw_boss = true
		for e in scene.enemies:
			if is_instance_valid(e) and e.elite:
				saw_elite = true
		if t - last_print >= 5.0:
			last_print = t
			print("t=%4.0f  dalga=%d  öldürme=%d  puan=%d  seviye=%d  can=%.0f  canlı=%d  nova=%.0f  durum=%s" % [
				t, scene.run.wave, scene.run.kills, scene.run.score, scene.run.level,
				scene.player.hp, scene.run.alive, scene.nova, scene.state])
	Engine.time_scale = 1.0
	if not is_instance_valid(scene) or scene.run == null:
		printerr("Oyun sahnesi yüklenemedi")
		quit(1)
		return
	var r = scene.run
	print("\nSONUÇ: dalga=%d öldürme=%d puan=%d seviye=%d durum=%s canlı_maks=%d mermi_maks=%d nova_maks=%.0f boss=%s elit=%s kartlar=%s" % [
		r.wave, r.kills, r.score, r.level, scene.state, max_alive, max_bullets, max_nova, str(saw_boss), str(saw_elite), str(scene.loadout.taken)])
	if r.kills < 3:
		printerr("Yetersiz kill: otomatik oynayış çalışmıyor olabilir")
		_failures += 1
	if r.wave < 2:
		printerr("İkinci dalgaya ulaşılamadı")
		_failures += 1
	if max_level < 2:
		printerr("Hiç seviye atlanmadı (kart sistemi?)")
		_failures += 1
	if max_nova <= 0.0:
		printerr("Nova hiç dolmadı")
		_failures += 1
	quit(0 if _failures == 0 else 1)
