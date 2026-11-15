extends SceneTree
## GERÇEK sahne üzerinde bot koşusu (scenes/main.tscn, otopilot): modeli kalibre etmek ve game3d.gd
## bölünürken (F2) davranış kaymasını ölçmek için. Saf-mantık simülasyonundan farkı: gerçek dövüş kodu çalışır.
##
##   godot --headless --path . -s res://tools/sim/scene_probe.gd -- --demo --ship=sahin --seconds=60 --out=build/sim/scene_sahin.json
## Oyun hızı 3x; `--seconds` örnekleme saatidir (oyun süresi = 3x). Kayıt dosyasına yazmaz (--demo zorunlu).
##
## Belirlenimli koşu (F2): `godot --headless --fixed-fps 60 --path . -s res://tools/sim/scene_probe.gd -- --demo --seed=7 ...`
## `--seed=N` sahnenin tüm rastgele akışlarını tohumlar; `--fixed-fps` kare süresini duvar saatinden ayırır. İkisi
## birlikteyken aynı kod = aynı `trace_md5` (her örnekte dalga/puan/can/konum izinin özeti). Kare süresi alanları
## (`frame_ms_*`, `wall_s`) ölçümdür, belirlenimli değildir.

const SPEED := 3.0

var _frame_us: Array[float] = []
var _last_frame_us := 0

func _on_frame() -> void:
	## Kareler arası duvar saati (motor + betik): F2 önce/sonra kare süresi karşılaştırması.
	var now := Time.get_ticks_usec()
	if _last_frame_us > 0:
		_frame_us.append(float(now - _last_frame_us) / 1000.0)
	_last_frame_us = now

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
	root.get_node("Fx").set_base_scale(SPEED)
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
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_MD5)
	var objects_max := 0
	process_frame.connect(_on_frame)
	var frames_start := Engine.get_process_frames()
	var wall_start := Time.get_ticks_usec()
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
		var pp: Vector2 = scene.player.pos2
		trace.update(("%d|%d|%d|%d|%.4f|%.3f|%.3f|%d|%d|%s;" % [r.wave, r.kills, r.score, r.level, hp, pp.x, pp.y, r.alive,
			scene.field.bullets.size(), scene.state]).to_utf8_buffer())
		objects_max = maxi(objects_max, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		if scene.state == "dead":
			break
	process_frame.disconnect(_on_frame)
	var frame_ms := _frame_us
	var frames := Engine.get_process_frames() - frames_start
	var wall_s := float(Time.get_ticks_usec() - wall_start) / 1000000.0
	root.get_node("Fx").set_base_scale(1.0)
	var r = scene.run
	var out := {
		"ship": _arg("ship", "default"), "game_seconds": snappedf(t, 0.1), "wave": r.wave, "kills": r.kills, "score": r.score,
		"level": r.level, "bosses": r.bosses, "dead": scene.state == "dead", "hp_lost": snappedf(hp_lost, 0.1),
		"hp_lost_during_boss": snappedf(hp_lost_boss, 0.1), "boss_time_s": snappedf(boss_time, 0.1),
		"boss_killed_at": boss_killed_at, "wave_first_time": wave_time, "max_alive": max_alive, "cards": scene.loadout.taken,
		"seed": int(_arg("seed", "0")), "trace_md5": trace.finish().hex_encode(), "samples": samples, "frames": frames,
		"wall_s": snappedf(wall_s, 0.001), "wall_ms_per_frame": snappedf(wall_s * 1000.0 / maxf(1.0, float(frames)), 0.001),
		"frame_ms_mean": snappedf(_mean(frame_ms), 0.001), "frame_ms_p95": snappedf(_pct(frame_ms, 0.95), 0.001),
		"frame_ms_max": snappedf(_pct(frame_ms, 1.0), 0.001), "objects_max": objects_max,
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

func _mean(values: Array[float]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxf(1.0, float(values.size()))

func _pct(values: Array[float], q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(q * float(sorted.size()))) - 1, 0, sorted.size() - 1)]

func _protect_build_dir(abs_path: String) -> void:
	## build/ altına yazılan çıktılar Godot tarafından kaynak sayılıp PCK'ya sızmasın: .gdignore koy.
	var marker := ProjectSettings.globalize_path("res://").path_join("build")
	if abs_path.begins_with(marker + "/") and not FileAccess.file_exists(marker + "/.gdignore"):
		var g := FileAccess.open(marker + "/.gdignore", FileAccess.WRITE)
		if g != null:
			g.close()
