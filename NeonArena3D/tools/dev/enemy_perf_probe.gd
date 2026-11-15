extends SceneTree
## C2 performans ölçümü (headless DEĞİL — çizim sayaçları için gerçek pencere gerekir):
## geç dalgada (varsayılan 18) aynı sayıda düşmanla "eski türler" ve "yeni türler + elit ön ekleri" karışımını bot oynarken
## ölçer: çizim çağrısı, nesne sayısı, çizilen üçgen, kare süresi (ort./p95/maks). Kayıt dosyasına dokunmaz (--no-save).
##
##   godot --path . --resolution 1280x720 -s res://tools/dev/enemy_perf_probe.gd -- --no-save --quality=0 --mix=new --frames=600
##   --mix=old|new   --wave=18   --count=36   --frames=600   --seed=5
## Çıktı: "PERF: {json}" satırı.

var _mix := "new"
var _wave := 18
var _count := 36
var _frames := 600
var _seed := 5

const OLD_MIX := ["chaser", "chaser", "chaser", "chaser", "shooter", "shooter", "swarmer", "swarmer", "swarmer", "orbiter", "tank", "sniper", "bomber"]
const NEW_MIX := ["charger", "charger", "shielder", "shielder", "medic", "minelayer", "blinker", "brooder", "chaser", "chaser", "shooter", "swarmer", "orbiter"]
const PREFIXES := ["armored", "swift", "splitting", "vampiric"]

func _initialize() -> void:
	_run.call_deferred()

func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.get_slice("=", 1)
	return fallback

func _run() -> void:
	_mix = _arg("mix", "new")
	_wave = int(_arg("wave", "18"))
	_count = int(_arg("count", "36"))
	_frames = int(_arg("frames", "600"))
	_seed = int(_arg("seed", "5"))
	var EnemyScript = load("res://scripts/entities3d/enemy3d.gd")
	var gd = root.get_node("GameData")
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.run_seed = _seed
	root.add_child(scene)
	for i in 3:
		await process_frame
	scene._start_game()
	await process_frame
	var ctx = scene.ctx
	ctx.run.jump_to(_wave)
	ctx.run.pending.clear()
	ctx.player.max_hp = 1.0e6
	ctx.player.hp = 1.0e6
	var quality: int = root.get_node("Settings").quality
	# Düşman halkası: oyuncunun çevresinde 350-900 px; her 4. düşman elit (yeni karışımda ön ek dönüşümlü).
	var list: Array = NEW_MIX if _mix == "new" else OLD_MIX
	var pp: Vector2 = ctx.player.pos2
	var made := 0
	for i in _count:
		var kind: String = list[i % list.size()]
		var ang := TAU * float(i) / float(_count)
		var at: Vector2 = pp + Vector2.from_angle(ang) * (350.0 + float((i * 37) % 550))
		at = at.clamp(Vector2(80, 80), Vector2(2560, 1600))
		var stats: Dictionary = gd.enemy_stats(kind)
		stats["spawn_delay"] = 0.0
		var elite_def: Dictionary = {}
		if i % 4 == 0:
			elite_def = EnemyData.merged_elite(gd.elite_def(), PREFIXES[(i / 4) % 4] if _mix == "new" else "")
		var e = EnemyScript.new()
		e.setup(kind, stats, ctx.run.hp_scale(), ctx.run.damage_scale(), ctx.run.speed_scale(), elite_def)
		e.pos2 = at
		e.position = ArenaSpace.to_world(at, 0.3)
		ctx.entities.add_child(e)
		ctx.enemies.append(e)
		ctx.run.alive += 1
		made += 1
	for i in 60:
		await process_frame   # ısınma
	var frame_ms: Array[float] = []
	var draws: Array[float] = []
	var objs: Array[float] = []
	var prims: Array[float] = []
	var nodes_max := 0
	var last := Time.get_ticks_usec()
	for i in _frames:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		nodes_max = maxi(nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		# oyuncuyu ve düşman sayısını sabit tut: ölenler yerine aynı türden yenisi gelmez, ama oyuncu ölümsüz (hp 1e6)
	var out := {
		"mix": _mix, "wave": _wave, "quality": quality, "spawned": made, "enemies_end": ctx.enemies.size(),
		"draw_calls_mean": snappedf(_mean(draws), 0.1), "draw_calls_max": snappedf(_max(draws), 0.1),
		"render_objects_mean": snappedf(_mean(objs), 0.1), "primitives_mean": snappedf(_mean(prims), 1.0),
		"frame_ms_mean": snappedf(_mean(frame_ms), 0.01), "frame_ms_p95": snappedf(_pct(frame_ms, 0.95), 0.01), "frame_ms_max": snappedf(_max(frame_ms), 0.01),
		"nodes_max": nodes_max, "viewport": str(root.size),
	}
	print("PERF: " + JSON.stringify(out))
	quit(0)

func _mean(v: Array[float]) -> float:
	var t := 0.0
	for x in v:
		t += x
	return t / maxf(1.0, float(v.size()))

func _max(v: Array[float]) -> float:
	var m := 0.0
	for x in v:
		m = maxf(m, x)
	return m

func _pct(v: Array[float], q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return s[clampi(int(ceil(q * float(s.size()))) - 1, 0, s.size() - 1)]
