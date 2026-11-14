extends RefCounted
class_name RunState
## Koşu mantığı: dalgalar, boss, puan/XP, seviye ve harita geçişi. Sahneye bağlı değil.

signal wave_started(wave: int)
signal spawn_due(kind: String)
signal boss_due
signal wave_cleared(wave: int)
signal map_cleared(map_index: int)
signal map_changed(map_index: int)
signal level_up(level: int)
signal run_ended(score: int)

const PHASE_READY := 0
const PHASE_BATTLE := 1
const PHASE_BREAK := 2
const PHASE_BOSS := 3
const PHASE_OVER := 4

var defs: Dictionary
var wave := 0
var phase := PHASE_READY
var map_index := 0
var score := 0
var xp := 0
var level := 1
var xp_next := 70
var pending_levels := 0
var kills := 0
var bosses := 0
var xp_mult := 1.0
var combo := 0
var max_combo := 0
var time := 0.0
var combo_time_left := 0.0
var alive := 0
var pending: Array[String] = []
var spawn_timer := 0.0
var break_timer := 0.0
var boss_alive := false
var boss_defeated := false
var rng := RandomNumberGenerator.new()

func _init(balance: Dictionary, seed_value: int = 0) -> void:
	defs = balance
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	xp_next = int(defs.get("leveling", {}).get("base_xp", 70))

func begin() -> void:
	wave = 0
	phase = PHASE_READY
	map_index = 0
	score = 0
	xp = 0
	level = 1
	pending_levels = 0
	xp_next = int(defs.get("leveling", {}).get("base_xp", 70))
	kills = 0
	bosses = 0
	combo = 0
	max_combo = 0
	time = 0.0
	combo_time_left = 0.0
	alive = 0
	pending.clear()
	boss_alive = false
	boss_defeated = false
	_start_wave(1)

func is_boss_wave(n: int) -> bool:
	var every := int(defs.get("waves", {}).get("boss_every", 5))
	return every > 0 and n % every == 0

func _start_wave(n: int) -> void:
	wave = n
	pending = plan_wave(n)
	spawn_timer = 0.45
	if is_boss_wave(n):
		phase = PHASE_BOSS
		boss_alive = true
		boss_defeated = false
		boss_due.emit()
	else:
		phase = PHASE_BATTLE
	wave_started.emit(wave)

func plan_wave(n: int) -> Array[String]:
	var w: Dictionary = defs["waves"]
	var count := int(round(float(w["base_count"]) + float(w["growth"]) * float(n - 1)))
	if is_boss_wave(n):
		count = maxi(int(w.get("boss_wave_count", 3)), int(round(float(count) / 3.0)))
	var kinds := unlocked_kinds(n)
	var plan: Array[String] = []
	var guard := 0
	while plan.size() < count and guard < 500:
		guard += 1
		var kind := _pick(kinds)
		plan.append(kind)
		var pack := int((defs["enemies"][kind] as Dictionary).get("pack", 1))
		for i in range(1, pack):
			plan.append(kind)
	return plan

func unlocked_kinds(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind in defs["enemies"]:
		var stats: Dictionary = defs["enemies"][kind]
		if int(stats.get("unlock", 1)) <= n and float(stats.get("weight", 0.0)) > 0.0:
			out.append({"kind": kind, "weight": float(stats.get("weight", 0.0))})
	if out.is_empty():
		out.append({"kind": "chaser", "weight": 1.0})
	return out

func _pick(kinds: Array[Dictionary]) -> String:
	var total := 0.0
	for entry in kinds:
		total += float(entry["weight"])
	var roll := rng.randf() * total
	for entry in kinds:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return str(entry["kind"])
	return str(kinds[kinds.size() - 1]["kind"])

func step(dt: float) -> void:
	if phase == PHASE_OVER or phase == PHASE_READY:
		return
	time += dt
	if combo > 0:
		combo_time_left -= dt
		if combo_time_left <= 0.0:
			combo = 0
	if phase == PHASE_BATTLE or phase == PHASE_BOSS:
		if not pending.is_empty() and alive < int(defs["waves"]["max_alive"]):
			spawn_timer -= dt
			if spawn_timer <= 0.0:
				var kind: String = pending.pop_front()
				alive += 1
				spawn_timer = spawn_interval()
				spawn_due.emit(kind)
		if pending.is_empty() and alive <= 0:
			if phase == PHASE_BATTLE:
				phase = PHASE_BREAK
				break_timer = float(defs["waves"]["intermission"])
				score += int(defs["waves"]["clear_bonus"]) * wave
				wave_cleared.emit(wave)
			elif phase == PHASE_BOSS and not boss_alive:
				phase = PHASE_BREAK
				break_timer = float(defs["waves"].get("boss_break", 3.2))
	elif phase == PHASE_BREAK:
		break_timer -= dt
		if break_timer <= 0.0:
			if boss_defeated:
				boss_defeated = false
				map_index += 1
				map_changed.emit(map_index)
			_start_wave(wave + 1)

func spawn_interval() -> float:
	var w: Dictionary = defs["waves"]
	return maxf(float(w["min_interval"]), float(w["spawn_interval"]) - float(w["interval_decay"]) * float(wave - 1))

func multiplier() -> float:
	var s: Dictionary = defs["scoring"]
	return minf(float(s["combo_max"]), 1.0 + float(s["combo_step"]) * float(combo - 1)) if combo > 0 else 1.0

func hp_scale() -> float:
	var d: Dictionary = defs["difficulty"]
	return 1.0 + float(d["hp_per_wave"]) * float(wave - 1)

func damage_scale() -> float:
	var d: Dictionary = defs["difficulty"]
	return 1.0 + float(d["damage_per_wave"]) * float(wave - 1)

func speed_scale() -> float:
	var d: Dictionary = defs["difficulty"]
	return minf(float(d["speed_cap"]), 1.0 + float(d["speed_per_wave"]) * float(wave - 1))

func enemy_died(points: int) -> void:
	alive = maxi(0, alive - 1)
	kills += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_time_left = float(defs["scoring"]["combo_window"])
	var gain := int(round(float(points) * multiplier()))
	score += gain
	add_xp(int(round(float(gain) * xp_mult)))

func boss_died() -> void:
	boss_alive = false
	boss_defeated = true
	bosses += 1
	combo += 1
	combo_time_left = float(defs["scoring"]["combo_window"])
	var points := int(defs["boss"].get("points", 600))
	score += points
	add_xp(int(round(float(points) * xp_mult)))
	map_cleared.emit(map_index)

func add_alive(count: int) -> void:
	alive += count

func enemy_escaped() -> void:
	alive = maxi(0, alive - 1)

func add_xp(amount: int) -> void:
	xp += amount
	var guard := 0
	while xp >= xp_next and guard < 50:
		guard += 1
		xp -= xp_next
		level += 1
		pending_levels += 1
		xp_next = int(round(float(defs["leveling"]["base_xp"]) * pow(float(defs["leveling"]["growth"]), float(level - 1))))
		level_up.emit(level)

func consume_level() -> void:
	pending_levels = maxi(0, pending_levels - 1)

func combo_ratio() -> float:
	return clampf(combo_time_left / maxf(0.01, float(defs["scoring"]["combo_window"])), 0.0, 1.0) if combo > 0 else 0.0

func hp_ratio_for_next() -> float:
	return clampf(float(xp) / maxf(1.0, float(xp_next)), 0.0, 1.0)

func enemies_left() -> int:
	return alive + pending.size() + (1 if boss_alive else 0)

func end_run() -> void:
	if phase == PHASE_OVER:
		return
	phase = PHASE_OVER
	run_ended.emit(score)

func jump_to(n: int) -> void:
	alive = 0
	pending.clear()
	_start_wave(maxi(1, n))
