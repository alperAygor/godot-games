extends SceneTree
## GERÇEK sahne üzerinde bot koşusu (scenes/main.tscn, otopilot): modeli kalibre etmek ve game3d.gd
## bölünürken (F2) davranış kaymasını ölçmek için. Saf-mantık simülasyonundan farkı: gerçek dövüş kodu çalışır,
## ama sahne tohumlanamaz (game3d randomize eder), bu yüzden sonuçlar yaklaşıktır ve belirlenimli DEĞİLDİR.
##
##   godot --headless --path . -s res://tools/sim/scene_probe.gd -- --demo --ship=sahin --seconds=60 --out=build/sim/scene_sahin.json
## Oyun hızı 3x; `--seconds` GERÇEK saniyedir (oyun süresi = 3x). Kayıt dosyasına yazmaz (--demo zorunlu).

const SPEED := 3.0

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.get_slice("=", 1)
	return fallback

func _run() -> void:
	if not ("--demo" in OS.get_cmdline_user_args() or "--no-save" in OS.get_cmdline_user_args()):
		printerr("PROBE HATA: --demo ya da --no-save gerekli (kayıt dosyası korunur)")
		quit(2)
		return
	var seconds := float(_arg("seconds", "60"))
	await process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = SPEED
	var t := 0.0
	var last_hp := -1.0
	var hp_lost := 0.0
	var hp_lost_boss := 0.0
	var boss_time := 0.0
	var boss_first_seen := -1.0
	var boss_killed_at: Array = []
	var prev_bosses := 0
	var wave_time := {}
	var max_alive := 0
	var samples := 0
	while t < seconds * SPEED:
		await create_timer(0.1, true, false, true).timeout
		t += 0.1 * SPEED
		if not is_instance_valid(scene) or scene.run == null:
			continue
		var r = scene.run
		samples += 1
		max_alive = maxi(max_alive, r.alive)
		var hp: float = scene.player.hp
		var boss_up: bool = scene.boss != null and is_instance_valid(scene.boss)
		if last_hp >= 0.0 and hp < last_hp:
			hp_lost += last_hp - hp
			if boss_up:
				hp_lost_boss += last_hp - hp
		last_hp = hp
		if boss_up:
			boss_time += 0.1 * SPEED
			if boss_first_seen < 0.0:
				boss_first_seen = t
		if r.bosses > prev_bosses:
			prev_bosses = r.bosses
			boss_killed_at.append(snappedf(t, 0.1))
		if not wave_time.has(str(r.wave)):
			wave_time[str(r.wave)] = snappedf(t, 0.1)
		if scene.state == "dead":
			break
	Engine.time_scale = 1.0
	var r = scene.run
	var out := {
		"ship": _arg("ship", "default"), "game_seconds": snappedf(t, 0.1), "wave": r.wave, "kills": r.kills, "score": r.score,
		"level": r.level, "bosses": r.bosses, "dead": scene.state == "dead", "hp_lost": snappedf(hp_lost, 0.1),
		"hp_lost_during_boss": snappedf(hp_lost_boss, 0.1), "boss_time_s": snappedf(boss_time, 0.1),
		"boss_killed_at": boss_killed_at, "wave_first_time": wave_time, "max_alive": max_alive, "cards": scene.loadout.taken,
	}
	var text := JSON.stringify(out, "  ", true)
	print("SAHNE: " + JSON.stringify(out, "", true))
	var out_path := _arg("out", "")
	if out_path != "":
		var abs_path := out_path if out_path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out_path)
		DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	_protect_build_dir(abs_path)
		var f := FileAccess.open(abs_path, FileAccess.WRITE)
		if f != null:
			f.store_string(text + "\n")
			f.close()
	quit(0)

func _protect_build_dir(abs_path: String) -> void:
	## build/ altına yazılan çıktılar Godot tarafından kaynak sayılıp PCK'ya sızmasın: .gdignore koy.
	var marker := ProjectSettings.globalize_path("res://").path_join("build")
	if abs_path.begins_with(marker + "/") and not FileAccess.file_exists(marker + "/.gdignore"):
		var g := FileAccess.open(marker + "/.gdignore", FileAccess.WRITE)
		if g != null:
			g.close()
