extends RefCounted
class_name RunSim
## Başsız, tohumlu, çizimsiz denge simülasyonu: bir koşuyu soyut bir dövüş modeliyle baştan sona oynar.
##
## Saf mantık katmanını kullanır (RunState dalga/boss/puan/XP, Loadout kartlar, MetaProgress atölye/ödül);
## `scripts/ui/game3d.gd` ya da sahne GEREKMEZ, otoyükler (GameData/Settings) kullanılmaz, kayıt dosyasına dokunmaz.
## Dövüş (çarpışma, hasar, isabet) oyundaki gibi fizikle değil, `sim_model.json` içindeki istatistiksel sabitlerle
## modellenir: oyundaki formüller (hasar çarpanları, atış aralığı, kart etkileri, düşman davranış kuralları,
## boss kalıpları) aynen alınır; oyuncunun kaçınma/isabet davranışı sabitlerle yaklaşıklanır.
## Bu bir DENGE TERMOMETRESİDİR, oynanış kopyası değildir; mutlak sayılar değil, sürümler arası farklar
## ve gemi/kart/zorluk arası oranlar anlamlıdır. Aynı tohum + aynı veri = aynı sonuç.

const VERSION := 2
const DATA_PATHS := {
	"balance": BalanceData.DIR, "cards": "res://data/cards.json", "ships": "res://data/ships.json",
	"upgrades": "res://data/upgrades.json", "maps": "res://data/maps.json", "model": "res://tests/sim/sim_model.json",
}
const WAVE_MARKS := [30, 60, 120, 180, 240, 480]

var bal: Dictionary = {}
var cards: Array = []
var ships: Array = []
var upgrades: Array = []
var maps: Array = []
var model: Dictionary = {}
var rng := RandomNumberGenerator.new()

# Koşu durumu
var run: RunState
var loadout: Loadout
var weapon: Dictionary = {}
var enemies: Array = []
var boss: Dictionary = {}
var t := 0.0
var hp := 100.0
var max_hp := 100.0
var shield := 0
var invuln := 0.0
var dash_cd := 0.0
var fire_cd := 0.0
var overdrive := 0.0
var nova := 0.0
var shield_timer := 0.0
var overheal := 0.0
var revives_used := 0
var last_cause := ""
var res: Dictionary = {}
var _death_cause := ""
var _hunt_timer := 35.0
# C3 kart etkileri (oyundaki CardEffects'in soyut karşılığı; sayılar data/card_rules.json → params, davranış sabitleri sim_model.json → cards)
var cp: Dictionary = {}
var cm: Dictionary = {}
var _blade_timer := 0.0
var _turrets: Array = []
var _trail_left := 0.0
var _trail_timer := 0.0
var _static_timer := 0.0
var _missile_timer := 0.0
var _kill_count := 0
var _blasts: Array = []

static func load_data() -> Dictionary:
	## Veri dosyalarını okur (otoyük gerektirmez); eksik/bozuksa boş sözlük döner.
	var out := {}
	for key in DATA_PATHS:
		if key == "balance":
			# F2: denge verisi data/balance/*.json'a bölündü; BalanceData eski tek dosyayla aynı sözlüğü birleştirir.
			var loaded := BalanceData.load_dir(DATA_PATHS[key])
			if not (loaded["errors"] as PackedStringArray).is_empty():
				return {}
			out[key] = loaded["data"]
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATHS[key]))
		if parsed == null:
			return {}
		out[key] = parsed
	return out

func _init(data: Dictionary) -> void:
	bal = data["balance"]
	cards = data["cards"]
	ships = data["ships"]
	upgrades = data["upgrades"]
	maps = data["maps"]
	model = data["model"]
	cp = (Loadout.load_rules().get("params", {}) as Dictionary)
	cm = model.get("cards", {})

func _p(key: String, fallback := 0.0) -> float:
	return float(cp.get(key, fallback))

func _c(key: String, fallback := 0.0) -> float:
	return float(cm.get(key, fallback))

# --- Yardımcılar ----------------------------------------------------------------
func ship_def(id: String) -> Dictionary:
	for def in ships:
		if str(def.get("id", "")) == id:
			return def
	return ships[0]

func meta_for_fraction(fraction: float) -> MetaProgress:
	## Atölye harcamasının `fraction` kadarını en ucuzdan başlayarak yapılmış bir MetaProgress.
	var meta := MetaProgress.new(upgrades, ships)
	var total := 0
	for def in upgrades:
		for c in def.get("costs", []):
			total += int(c)
	meta.earn(total)
	var budget := int(round(float(total) * fraction))
	var spent := 0
	while true:
		var best := ""
		var best_cost := 1 << 30
		for def in upgrades:
			var id := str(def.get("id", ""))
			var cost := meta.next_cost(id)
			if cost >= 0 and cost < best_cost:
				best_cost = cost
				best = id
		if best == "" or spent + best_cost > budget:
			break
		spent += best_cost
		meta.buy(best)
	return meta

func boss_stats(kind: String) -> Dictionary:
	var out: Dictionary = (bal.get("boss", {}) as Dictionary).duplicate()
	var kinds: Dictionary = bal.get("boss_kinds", {})
	if kinds.has(kind):
		out.merge(kinds[kind], true)
	return out

func _num(d: Dictionary, key: String, fallback: float) -> float:
	return float(d.get(key, fallback))

# --- Koşu -----------------------------------------------------------------------
func play(opts: Dictionary) -> Dictionary:
	## opts: seed, ship (id), meta (MetaProgress, ops.), give (kart kimlikleri), start_map, policy, max_time
	var seed_value := int(opts.get("seed", 1))
	rng.seed = (seed_value * 2654435761 + 12345) % 2147483647 + 1
	var meta: MetaProgress = opts.get("meta", null)
	if meta == null:
		meta = MetaProgress.new(upgrades, ships)
	var sdef := ship_def(str(opts.get("ship", "vektor")))
	var policy := str(opts.get("policy", "random"))
	var max_time := float(opts.get("max_time", model.get("max_time", 2400.0)))
	var dt := float(model.get("dt", 0.1))

	loadout = Loadout.new(cards)
	loadout.apply_effects(meta.effects())
	loadout.apply_effects(sdef.get("effect", {}))
	weapon = sdef.get("weapon", {})
	for id in opts.get("give", []):
		for card in cards:
			if str(card.get("id", "")) == str(id):
				if str(card.get("tier", "")) == "cursed":
					loadout.apply_curse(str(id))
				else:
					loadout.apply(card)
	run = RunState.new(bal, seed_value)
	run.spawn_due.connect(_on_spawn_due)
	run.boss_due.connect(_on_boss_due)
	run.wave_cleared.connect(_on_wave_cleared)
	run.wave_started.connect(_on_wave_started)
	run.map_cleared.connect(_on_map_cleared)
	enemies.clear()
	boss = {}
	t = 0.0
	invuln = 1.0
	dash_cd = 0.0
	fire_cd = 0.0
	overdrive = 0.0
	shield_timer = 0.0
	overheal = 0.0
	revives_used = 0
	last_cause = ""
	_death_cause = ""
	_blade_timer = 0.0
	_turrets.clear()
	_trail_left = 0.0
	_trail_timer = 0.0
	_static_timer = 0.0
	_missile_timer = 0.0
	_kill_count = 0
	_blasts.clear()
	max_hp = float(bal["player"]["max_health"]) + loadout.m("max_hp_bonus")
	hp = max_hp
	shield = 1 if loadout.i("start_shield") > 0 else 0
	nova = clampf(loadout.m("nova_start"), 0.0, 100.0)
	res = {
		"seed": seed_value, "ship": str(sdef["id"]), "policy": policy,
		"damage_taken": {}, "kills_by_kind": {}, "picks": [], "peak_alive": 0, "nova_uses": 0,
		"hp_lost": 0.0, "hp_lost_boss": 0.0, "boss_time": 0.0, "wave_at": {}, "rerolls_unused": 2 + loadout.i("rerolls"), "revived": 0, "boss_kills": {},
	}
	run.begin()
	run.map_index = int(opts.get("start_map", 0))
	run.xp_mult = loadout.m("xp_mult")
	var marks: Array = WAVE_MARKS.duplicate()
	while run.phase != RunState.PHASE_OVER and t < max_time:
		t += dt
		_tick(dt, policy)
		while not marks.is_empty() and t >= float(marks[0]):
			res["wave_at"][str(int(marks[0]))] = run.wave
			marks.pop_front()
	var capped: bool = run.phase != RunState.PHASE_OVER
	if capped:
		_death_cause = "timeout"
	for m in marks:
		res["wave_at"][str(int(m))] = run.wave
	res["capped"] = capped
	res["death_cause"] = _death_cause
	res["time"] = snappedf(t, 0.1)
	res["wave"] = run.wave
	res["kills"] = run.kills
	res["score"] = run.score
	res["level"] = run.level
	res["bosses"] = run.bosses
	res["max_combo"] = run.max_combo
	res["cores"] = MetaProgress.run_reward(run.score, run.wave, run.bosses, loadout.m("core_mult"))
	res["map_index"] = run.map_index
	res["cards"] = loadout.taken.duplicate()
	res["max_hp"] = snappedf(max_hp, 0.1)
	res["hp_lost"] = snappedf(float(res["hp_lost"]), 0.1)
	res["hp_lost_boss"] = snappedf(float(res["hp_lost_boss"]), 0.1)
	res["boss_time"] = snappedf(float(res["boss_time"]), 0.1)
	return res

# --- Ana tik --------------------------------------------------------------------
func _tick(dt: float, policy: String) -> void:
	run.step(dt)
	invuln = maxf(0.0, invuln - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	overdrive = maxf(0.0, overdrive - dt)
	var regen := loadout.m("regen")
	if regen > 0.0:
		_heal(regen * dt)
	if loadout.i("shield_regen") > 0 and shield <= 0:
		shield_timer += dt
		if shield_timer >= float(bal["player"].get("shield_regen_time", 18.0)):
			shield_timer = 0.0
			shield = 1
	if run.phase == RunState.PHASE_BATTLE or run.phase == RunState.PHASE_BOSS:
		_hunt_timer -= dt
		if _hunt_timer <= 0.0:
			_hunt_timer = 15.0
			_hunt_stragglers()
	var crowd := _tick_enemies(dt)
	var near_dash := float(model.get("dash_near", 0.0))
	if near_dash > 0.0 and dash_cd <= 0.0 and not _nearest(Vector2.ZERO, near_dash).is_empty():
		_dash()   # Autopilot: yakında düşman varken atılma hazırsa atılır (scripts/game/autopilot.gd)
	_tick_boss(dt)
	_tick_player_fire(dt)
	_tick_drones(dt)
	_tick_cards(dt)
	if nova >= 100.0 and (crowd >= 4 or not boss.is_empty()):
		_use_nova()
	_reap()
	res["peak_alive"] = maxi(int(res["peak_alive"]), run.alive)
	var guard := 0
	while run.pending_levels > 0 and guard < 40:
		guard += 1
		_level_up(policy)
	if hp <= 0.0:
		_on_death()

# --- Oyuncu hasarı / iyileşme -----------------------------------------------------
func _heal(amount: float) -> void:
	amount *= loadout.m("heal_mult")
	var room := max_hp - hp
	hp = minf(max_hp, hp + amount)
	if loadout.i("harvest") > 0:
		overheal += maxf(0.0, amount - room)
		if overheal >= (_p("bloodmoon_shield_at", 25.0) if loadout.i("evo_bloodmoon") > 0 else 50.0) and shield <= 0:
			overheal = 0.0
			shield = 1

func _hurt(amount: float, cause: String) -> bool:
	if invuln > 0.0 or hp <= 0.0:
		return false
	if shield > 0:
		shield -= 1
		invuln = 0.75
		if loadout.i("shield_bash") > 0:
			_area_damage(Vector2.ZERO, _p("shield_bash_radius", 210.0), _pdmg() * _p("shield_bash_damage", 5.0))
			invuln = maxf(invuln, _p("shield_bash_invuln", 1.0))
		return false
	if loadout.m("plating") > 0.0:
		amount = maxf(_p("plating_min", 1.0), amount - loadout.m("plating"))
	amount *= maxf(1.0, loadout.m("hurt_mult"))
	hp -= amount
	invuln = float(bal["player"].get("hurt_invuln", 0.7))
	last_cause = cause
	res["hp_lost"] = float(res["hp_lost"]) + amount
	if not boss.is_empty():
		res["hp_lost_boss"] = float(res["hp_lost_boss"]) + amount
	var taken: Dictionary = res["damage_taken"]
	taken[cause] = float(taken.get(cause, 0.0)) + amount
	if loadout.i("fortress") > 0 and hp > 0.0:
		var dmg := float(bal["player"]["damage"]) * loadout.m("damage_mult") * 1.4
		var hits := int(model.get("fortress_bullets_hit", 5))
		for k in hits:
			var e := _nearest(Vector2.ZERO, 900.0)
			if e.is_empty():
				break
			_damage_enemy(e, dmg, false)
	return true

func _on_death() -> void:
	if loadout.i("revive") > revives_used:
		revives_used += 1
		res["revived"] = int(res["revived"]) + 1
		hp = max_hp * 0.5
		invuln = 2.2
		var dmg := 80.0 * loadout.m("damage_mult") * (1.0 + 0.12 * float(run.wave - 1))
		_area_damage(Vector2.ZERO, 420.0, dmg)
		_boss_blast(420.0, dmg)
		return
	hp = 0.0
	_death_cause = last_cause if last_cause != "" else "unknown"
	run.end_run()

func _on_wave_started(_wave: int) -> void:
	_hunt_timer = 35.0

func _on_wave_cleared(_wave: int) -> void:
	_heal(8.0)

func _on_map_cleared(_index: int) -> void:
	_heal(max_hp * 0.25)

# --- Düşmanlar ------------------------------------------------------------------
func _on_spawn_due(kind: String) -> void:
	_spawn(kind, true, -1.0)

func _spawn(kind: String, allow_elite: bool, near_dist: float) -> void:
	var st: Dictionary = (bal["enemies"] as Dictionary)[kind]
	var elite := false
	var ed: Dictionary = bal.get("elite", {})
	if allow_elite and kind != "swarmer" and not ed.is_empty() and run.wave >= int(ed.get("from_wave", 4)) and not run.is_boss_wave(run.wave):
		var chance := minf(float(ed.get("chance_max", 0.16)), float(ed.get("chance", 0.05)) + float(ed.get("chance_per_wave", 0.006)) * float(run.wave))
		elite = rng.randf() < chance
	var w: Dictionary = bal["waves"]
	var dist := near_dist if near_dist > 0.0 else rng.randf_range(float(w["spawn_radius_min"]), float(w["spawn_radius_max"]))
	var e := {
		"kind": kind, "elite": elite,
		"hp": float(st["hp"]) * run.hp_scale() * (float(ed.get("hp_mult", 3.0)) if elite else 1.0),
		"dmg": float(st["damage"]) * run.damage_scale() * (float(ed.get("damage_mult", 1.3)) if elite else 1.0),
		"speed": float(st["speed"]) * run.speed_scale(),
		"rad": float(st["radius"]) * (float(ed.get("scale", 1.3)) if elite else 1.0),
		"pos": Vector2.from_angle(rng.randf() * TAU) * dist,
		"spawn": 0.5, "fire_cd": rng.randf_range(0.6, 1.6), "touch": 0.0, "charge": 0.0, "fuse": -1.0, "dead": false,
		"pts": int(st["points"]) * (int(ed.get("points_mult", 3)) if elite else 1),
	}
	e["max"] = e["hp"]
	enemies.append(e)

func _hunt_stragglers() -> void:
	## game3d._hunt_stragglers: uzayan dalgada kalan düşmanlar oyuncunun çevresine ışınlanır (soft-lock olmaz).
	var w: Dictionary = bal["waves"]
	for e in enemies:
		if not e["dead"]:
			e["pos"] = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(float(w["spawn_radius_min"]), float(w["spawn_radius_max"]))

func _approach_factor() -> float:
	var a: Dictionary = model["approach"]
	var speed := float(bal["player"]["speed"]) * loadout.m("speed_mult")
	if loadout.i("adrenaline") > 0 and hp < max_hp * _p("adrenaline_hp", 0.4):
		speed *= 1.0 + _p("adrenaline_speed", 0.15)
	var f := float(a["base"]) * pow(float(a["ref_speed"]) / maxf(60.0, speed), float(a["speed_exp"]))
	return clampf(f, float(a["min"]), float(a["max"]))

func _tick_enemies(dt: float) -> int:
	var crowd := 0
	var contact: Dictionary = model["contact"]
	var crowd_r := float(contact["crowd_radius"])
	for e in enemies:
		if not e["dead"] and e["spawn"] <= 0.0 and (e["pos"] as Vector2).length() < crowd_r:
			crowd += 1
	var p_contact := minf(float(contact["max"]), float(contact["base"]) + float(contact["crowd_k"]) * float(crowd))
	var approach := _approach_factor()
	var player_r := float(model["arena_player_radius"])
	var hit_cfg: Dictionary = model["bullet_hit"]
	for e in enemies:
		if e["dead"]:
			continue
		if e["spawn"] > 0.0:
			e["spawn"] = float(e["spawn"]) - dt
			continue
		e["touch"] = maxf(0.0, float(e["touch"]) - dt)
		var pos: Vector2 = e["pos"]
		var dist := pos.length()
		var dir_in := -pos / maxf(dist, 0.001)
		var spd := float(e["speed"]) * approach * dt
		var kind: String = e["kind"]
		var st: Dictionary = bal["enemies"][kind]
		var hold := 0.0
		var shoots := false
		match kind:
			"shooter":
				hold = float(st.get("keep_distance", 280.0))
				shoots = dist < 640.0
			"orbiter":
				hold = float(st.get("orbit_radius", 240.0))
				shoots = dist < 700.0
			"sniper":
				hold = float(st.get("keep_distance", 470.0))
				shoots = dist < 760.0
		if hold > 0.0:
			if dist > hold + 20.0:
				pos += dir_in * minf(spd, dist - hold)
			e["pos"] = pos
		else:
			var stop := float(e["rad"]) + player_r
			if dist > stop:
				pos += dir_in * minf(spd * (1.25 if kind == "bomber" else 1.0), dist - stop)
				e["pos"] = pos
		dist = (e["pos"] as Vector2).length()
		if shoots:
			if kind == "sniper":
				e["charge"] = float(e["charge"]) + dt
				if float(e["charge"]) >= float(st.get("charge_time", 1.1)):
					e["charge"] = -float(st.get("fire_interval", 2.8)) * 0.35
					_enemy_shot(e, float(hit_cfg.get("sniper", 0.3)))
			else:
				e["fire_cd"] = float(e["fire_cd"]) - dt
				if float(e["fire_cd"]) <= 0.0:
					e["fire_cd"] = float(st.get("fire_interval", 1.9)) * rng.randf_range(0.85, 1.2)
					_enemy_shot(e, float(hit_cfg.get("default", 0.14)))
		if kind == "bomber":
			if float(e["fuse"]) < 0.0 and dist < float(st.get("fuse_range", 105.0)):
				e["fuse"] = float(st.get("fuse_time", 0.55))
			elif float(e["fuse"]) >= 0.0:
				e["fuse"] = float(e["fuse"]) - dt
				if float(e["fuse"]) <= 0.0:
					e["dead"] = true
					e["self_blast"] = true
					continue
		if invuln <= 0.0 and float(e["touch"]) <= 0.0 and dist < float(e["rad"]) + player_r:
			e["touch"] = float(contact["touch_cd"])
			_contact(e, p_contact)
	return crowd

func _enemy_shot(e: Dictionary, hit_p: float) -> void:
	if rng.randf() < hit_p:
		_hurt(float(e["dmg"]) * float(model["bullet_dmg_mult"]), "bullet:" + str(e["kind"]))

func _contact(e: Dictionary, p_contact: float) -> void:
	if rng.randf() >= p_contact:
		return
	if dash_cd <= 0.0:
		_dash()
		return
	if _hurt(float(e["dmg"]), "contact:" + str(e["kind"])):
		var thorns := loadout.m("thorns") * (3.0 if loadout.i("fortress") > 0 else 1.0)
		if thorns > 0.0:
			_damage_enemy(e, thorns, false)

func _dash() -> void:
	dash_cd = float(bal["player"]["dash_cooldown"]) * loadout.m("dash_cd_mult")
	invuln = maxf(invuln, float(model["dash_invuln"]))
	_on_dash_cards()
	var dd := loadout.m("dash_damage")
	if dd > 0.0:
		var dmg := dd * loadout.m("damage_mult") * (2.0 if loadout.i("blitz") > 0 else 1.0)
		var left := int(model["dash_damage_targets"])
		for e in enemies:
			if left <= 0:
				break
			if e["dead"] or e["spawn"] > 0.0:
				continue
			if (e["pos"] as Vector2).length() < float(e["rad"]) + 13.0 + 40.0:
				left -= 1
				_damage_enemy(e, dmg, false)
				if e["dead"] and loadout.i("blitz") > 0:
					dash_cd = 0.0

# --- Boss -----------------------------------------------------------------------
func _on_boss_due() -> void:
	var theme: Dictionary = maps[run.map_index % maps.size()]
	var kind := str(theme.get("boss", "sentinel"))
	var lap := run.map_index / maxi(1, maps.size())
	var st := boss_stats(kind)
	var mhp := float(st.get("hp", 1600.0)) * float(st.get("hp_mult", 1.0)) * run.hp_scale() * (1.0 + 0.25 * float(lap))
	boss = {
		"kind": kind, "hp": mhp, "max_hp": mhp, "phase": 1, "intro": float(model.get("boss_intro", 2.5)),
		"dist": 900.0, "dmg": float(st.get("damage", 30.0)) * run.damage_scale(), "st": st,
		"timers": {}, "speed": float(st.get("speed", 80.0)), "summon_t": 6.0,
	}

func _pattern_interval(p: Dictionary, st: Dictionary, phase: int) -> float:
	var iv := float(st.get(str(p.get("interval_key", "")), p.get("interval", 3.0)))
	if phase == 2 and p.has("p2_interval"):
		return float(p["p2_interval"])
	return iv * float(p.get("p2_mult" if phase == 2 else "p1_mult", 1.0))

func _tick_boss(dt: float) -> void:
	if boss.is_empty():
		return
	res["boss_time"] = float(res["boss_time"]) + dt
	if float(boss["intro"]) > 0.0:
		boss["intro"] = float(boss["intro"]) - dt
		return
	var st: Dictionary = boss["st"]
	if float(boss["dist"]) > float(model["boss_hold_distance"]):
		boss["dist"] = maxf(float(model["boss_hold_distance"]), float(boss["dist"]) - float(boss["speed"]) * dt)
	if int(boss["phase"]) == 1 and float(boss["hp"]) <= float(boss["max_hp"]) * float(st.get("phase2_at", 0.5)):
		boss["phase"] = 2
	var phase: int = boss["phase"]
	var timers: Dictionary = boss["timers"]
	var hit_scale := float(model.get("boss_pattern_hit_scale", 1.0))
	for p in model["boss_patterns"].get(str(boss["kind"]), []):
		if int(p.get("phase", 0)) > phase:
			continue
		var name: String = p["name"]
		timers[name] = float(timers.get(name, _pattern_interval(p, st, phase) * 0.7)) - dt
		if float(timers[name]) > 0.0:
			continue
		timers[name] = _pattern_interval(p, st, phase)
		var bullets := float(st.get(str(p.get("bullets_key", "")), p.get("bullets", 1)))
		if phase == 2:
			bullets += float(p.get("p2_bonus", 0))
		var volleys := float(p.get("p2_volleys" if phase == 2 else "volleys", p.get("volleys", 1)))
		bullets *= volleys
		if p.has("scale_key"):
			bullets *= float(st.get(str(p["scale_key"]), p.get("scale_default", 3.0))) / float(p.get("scale_div", 1.0))
		var dmg_f := float(st.get(str(p.get("dmg_key", "")), p.get("dmg", 0.5)))
		for i in int(round(bullets)):
			if rng.randf() < float(p["hit"]) * hit_scale:
				_hurt(float(boss["dmg"]) * dmg_f, "boss:" + name)
	var sm: Dictionary = model["boss_summons"].get(str(boss["kind"]), {})
	if not sm.is_empty():
		boss["summon_t"] = float(boss["summon_t"]) - dt
		if float(boss["summon_t"]) <= 0.0:
			boss["summon_t"] = float(sm.get("interval", 7.0)) * (float(sm.get("phase_mult2", 1.0)) if phase == 2 else 1.0)
			var skind := str(sm.get("kind2" if phase == 2 else "kind1", ""))
			var scount := int(sm.get("count2" if phase == 2 else "count1", 0))
			if skind != "" and scount > 0:
				for i in scount:
					_spawn(skind, true, float(boss["dist"]) * 0.6 + 40.0)
				run.add_alive(scount)

func _boss_hit(dmg: float) -> void:
	if boss.is_empty() or float(boss["intro"]) > 0.0:
		return
	boss["hp"] = float(boss["hp"]) - dmg
	if float(boss["hp"]) <= 0.0:
		_boss_down()

func _boss_down() -> void:
	var kind := str(boss["kind"])
	var bk: Dictionary = res["boss_kills"]
	bk[kind] = int(bk.get(kind, 0)) + 1
	boss = {}
	for e in enemies:
		if not e["dead"]:
			e["dead"] = true
			e["silent"] = true
			run.enemy_died(int(e["pts"]))
	run.pending.clear()
	nova = minf(100.0, nova + 50.0)
	_heal(float(bal["pickups"].get("heal_amount", 22.0)))
	if shield <= 0:
		shield = 1
	overdrive = float(bal["pickups"].get("overdrive_time", 6.0))
	run.boss_died()

# --- Oyuncu ateşi -----------------------------------------------------------------
func _nearest(from: Vector2, radius: float, skip: Dictionary = {}) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for e in enemies:
		if e["dead"] or e["spawn"] > 0.0 or e == skip:
			continue
		var d := ((e["pos"] as Vector2) - from).length()
		if d < best_d:
			best_d = d
			best = e
	return best

func _weapon_range() -> float:
	var speed := float(weapon.get("speed", 980.0))
	if str(weapon.get("type", "")) == "rocket":
		speed = (speed + float(weapon.get("max_speed", speed))) * 0.5
	return speed * float(weapon.get("life", 0.85)) * float((model.get("chase_reach", {}) as Dictionary).get(str(weapon.get("type", "")), 1.0))

func _fire_interval() -> float:
	var rate := loadout.m("fire_rate_mult")
	if loadout.i("adrenaline") > 0 and hp < max_hp * _p("adrenaline_hp", 0.4):
		rate *= 1.0 + _p("adrenaline_rate", 0.5)
	return float(weapon.get("interval", 0.135)) * (0.5 if overdrive > 0.0 else 1.0) / maxf(0.2, rate)

func _tick_player_fire(dt: float) -> void:
	fire_cd -= dt
	var guard := 0
	while fire_cd <= 0.0 and guard < 4:
		guard += 1
		fire_cd += _fire_interval()
		_shoot()

func _shoot() -> void:
	var kind := str(weapon.get("type", "blaster"))
	var acc_cfg: Dictionary = model["accuracy"]
	var base := float(bal["player"]["damage"]) * loadout.m("damage_mult") * float(weapon.get("damage", 1.0)) * _shot_mult()
	var reach := _weapon_range()
	var extra := loadout.i("projectiles") - 1
	var size_f := clampf(sqrt(loadout.m("bullet_size") * float(weapon.get("size", 1.0))), 0.8, 1.4)
	var target: Dictionary = {}
	var tdist := 0.0
	var at_boss := not boss.is_empty() and float(boss["intro"]) <= 0.0
	if at_boss:
		tdist = float(boss["dist"])
		if tdist > reach:
			at_boss = false
	if not at_boss:
		target = _nearest(Vector2.ZERO, reach)
		if target.is_empty():
			return
		tdist = (target["pos"] as Vector2).length()
	var n := 1
	var acc := float(acc_cfg.get(kind, acc_cfg["blaster"]))
	match kind:
		"scatter":
			n = int(weapon.get("pellets", 6)) + extra * 2
			acc *= clampf(1.0 - (tdist / reach) * float(model["scatter_range_falloff"]), 0.2, 1.0)
		"rail", "rocket":
			n = extra + 1
		_:
			n = extra + 1
	acc = minf(0.98, acc * size_f)
	var pierce_extra := loadout.i("pierce") + (int(weapon.get("pierce", 0)) if kind == "rail" else 0)
	if kind == "rocket":
		pierce_extra = 0
	var crit_p := loadout.m("crit")
	_rear_shots(base, acc)
	for i in n:
		if rng.randf() >= acc:
			continue
		var crit := rng.randf() < crit_p
		var dmg := base * (2.0 if crit else 1.0)
		if at_boss:
			_boss_hit(dmg * (1.0 + loadout.m("hunter")))   # Avcı: oyunda yalnız mermi isabetinde (CardEffects.boss_damage_mult)
			continue
		if target["dead"]:
			target = _nearest(Vector2.ZERO, reach)
			if target.is_empty():
				return
		_damage_enemy(target, dmg * _elite_mult(target), crit)
		_chain_hit(target, dmg, crit)
		_on_hit_cards(target, dmg, crit, pierce_extra <= 0 or kind == "rocket")
		if kind == "rocket":
			_area_damage(target["pos"], float(weapon.get("blast", 72.0)), dmg * 0.6, target)
		elif pierce_extra > 0:
			var line_p := float(model["line_prob"]) + (0.25 if kind == "rail" else 0.0)
			var from: Vector2 = target["pos"]
			var prev: Dictionary = target
			for j in pierce_extra:
				if rng.randf() >= line_p:
					break
				var nxt := _nearest(from, 400.0, prev)
				if nxt.is_empty() or nxt == prev:
					break
				_damage_enemy(nxt, dmg, crit)
				from = nxt["pos"]
				prev = nxt

func _chain_hit(source: Dictionary, dmg: float, crit: bool) -> void:
	var jumps := loadout.i("chain")
	var storm := crit and loadout.i("storm") > 0
	if storm:
		jumps += 2
	if jumps <= 0:
		return
	var cd := dmg * (1.0 if storm else _p("chain_damage_base", 0.5) + loadout.m("chain_power"))
	var visited: Array = [source]
	var cur: Dictionary = source
	for n in jumps:
		var best: Dictionary = {}
		var best_d := 240.0 * (_p("thunder_chain_range", 1.5) if loadout.i("evo_thunder") > 0 else 1.0)
		for e in enemies:
			if e["dead"] or e["spawn"] > 0.0 or visited.has(e):
				continue
			var d := ((e["pos"] as Vector2) - (cur["pos"] as Vector2)).length()
			if d < best_d:
				best_d = d
				best = e
		if best.is_empty():
			break
		_damage_enemy(best, cd, false)
		visited.append(best)
		cur = best

func _damage_enemy(e: Dictionary, dmg: float, _crit: bool) -> void:
	if e["dead"]:
		return
	e["hp"] = float(e["hp"]) - dmg
	if float(e["hp"]) <= 0.0:
		e["dead"] = true

func _area_damage(center: Vector2, radius: float, dmg: float, skip: Dictionary = {}) -> void:
	## Yalnız düşmanlara alan hasarı (boss için _boss_blast).
	if radius <= 0.0 or dmg <= 0.0:
		return
	for e in enemies:
		if e["dead"] or e["spawn"] > 0.0 or e == skip:
			continue
		if ((e["pos"] as Vector2) - center).length() < radius + float(e["rad"]):
			_damage_enemy(e, dmg, false)

func _boss_blast(radius: float, dmg: float) -> void:
	## Oyuncu merkezli patlama (nova/ikinci şans) boss yarıçapına değiyorsa boss hasar alır.
	if boss.is_empty() or float(boss["intro"]) > 0.0:
		return
	if float(boss["dist"]) < radius + float((boss["st"] as Dictionary).get("radius", 62.0)):
		_boss_hit(dmg)

func _tick_drones(dt: float) -> void:
	var count := loadout.i("drones")
	if count <= 0:
		return
	var cd := 0.28 if loadout.i("hive") > 0 else 0.55
	var shots := float(count) * dt / cd
	var dmg := float(bal["player"]["damage"]) * loadout.m("damage_mult") * 0.55 * (_p("swarm_drone_damage", 1.5) if loadout.i("evo_swarm") > 0 else 1.0)
	var acc := float(model["accuracy"]["drone"])
	var whole := int(shots)
	if rng.randf() < shots - float(whole):
		whole += 1
	for i in whole:
		if rng.randf() >= acc:
			continue
		var target := _nearest(Vector2.ZERO, 700.0)
		if not target.is_empty():
			_damage_enemy(target, dmg, false)
			if loadout.i("evo_swarm") > 0:
				_pierce_line(target, dmg, int(_p("swarm_drone_pierce", 2.0)), float(model["line_prob"]))
		elif not boss.is_empty() and float(boss["intro"]) <= 0.0:
			_boss_hit(dmg)

func _use_nova() -> void:
	nova = 0.0
	res["nova_uses"] = int(res["nova_uses"]) + 1
	var radius := float(bal["player"]["nova_radius"]) * (_p("singularity_radius", 1.4) if loadout.i("evo_singularity") > 0 else 1.0)
	var dmg := float(bal["player"]["nova_damage"]) * loadout.m("damage_mult") * (1.0 + 0.12 * float(run.wave - 1))
	if loadout.i("doom_nova") > 0:
		radius *= 1.5
		for k in 3:
			var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(radius * 0.35, radius * 0.8)
			_area_damage(at, 150.0, dmg * 0.6)
	_area_damage(Vector2.ZERO, radius, dmg)
	_boss_blast(radius, dmg)
	invuln = maxf(invuln, 0.6)
	_on_nova_cards(radius, dmg)

# --- Ölüm / ganimet -----------------------------------------------------------------
func _reap() -> void:
	var i := enemies.size() - 1
	var dead_now: Array = []
	while i >= 0:
		if enemies[i]["dead"]:
			dead_now.append(enemies[i])
			enemies.remove_at(i)
		i -= 1
	for e in dead_now:
		if e.has("silent"):
			continue
		var kbk: Dictionary = res["kills_by_kind"]
		var kind: String = e["kind"]
		kbk[kind] = int(kbk.get(kind, 0)) + 1
		run.enemy_died(int(e["pts"]))
		var big: bool = bool(e["elite"])
		var od := _p("overdrive_nova_mult", 2.0) if loadout.i("overdrive_plus") > 0 and overdrive > 0.0 else 1.0
		nova = minf(100.0, nova + float(bal["player"]["nova_per_kill"]) * loadout.m("nova_rate_mult") * (3.0 if big else 1.0) * od)
		if loadout.m("vampire") > 0.0:
			_heal(loadout.m("vampire") * (_p("bloodmoon_vampire", 2.0) if loadout.i("evo_bloodmoon") > 0 else 1.0))
		_on_kill_cards(e)
		if kind == "tank":
			for k in 2:
				_spawn("chaser", false, (e["pos"] as Vector2).length())
			run.add_alive(2)
		if kind == "bomber":
			var st: Dictionary = bal["enemies"]["bomber"]
			var r := float(st.get("explode_radius", 135.0))
			if (e["pos"] as Vector2).length() < r and rng.randf() < float(model["bomber_hit"]):
				_hurt(float(e["dmg"]), "blast:bomber")
			_area_damage(e["pos"], r, float(e["dmg"]) * 1.6, e)
		var ex := loadout.i("explosive")
		if ex > 0:
			_area_damage(e["pos"], 85.0 + 22.0 * float(ex), float(bal["player"]["damage"]) * loadout.m("damage_mult") * (0.9 + 0.5 * float(ex)), e)
		if big or rng.randf() < float(bal["pickups"].get("drop_chance", 0.15)):
			_pickup()
		if bool(e["elite"]) and loadout.m("hunter") > 0.0:
			for k in int(_p("hunter_extra_drops", 1.0)):
				_pickup()

func _pickup() -> void:
	var pk: Dictionary = model["pickup"]
	var p := minf(float(pk["collect_max"]), float(pk["collect"]) + float(pk["magnet_gain"]) * (loadout.m("magnet") - 1.0))
	if rng.randf() >= p:
		return
	var r := rng.randf()
	var pb: Dictionary = bal["pickups"]
	var sw := float(pb.get("shield_weight", 0.16))
	var ow := float(pb.get("overdrive_weight", 0.26))
	if r < sw and shield <= 0:
		shield = 1
	elif r < sw + ow:
		overdrive = float(pb.get("overdrive_time", 6.0)) * (_p("overdrive_time_mult", 2.0) if loadout.i("overdrive_plus") > 0 else 1.0)
	else:
		_heal(float(pb.get("heal_amount", 22.0)))
	var blast := loadout.i("pickup_blast")
	if blast > 0:
		_area_damage(Vector2.ZERO, _p("pickup_blast_radius", 220.0), _pdmg() * _p("pickup_blast_damage", 4.0) * (1.0 + _p("pickup_blast_per_level", 0.5) * float(blast - 1)))
		nova = minf(100.0, nova + _p("pickup_blast_nova", 10.0))

# --- C3 kart etkileri (oyun: scripts/game/card_effects.gd) ----------------------------------------
func _pdmg() -> float:
	return float(bal["player"]["damage"]) * loadout.m("damage_mult")

func _shot_mult() -> float:
	## CardEffects.shot_damage_mult: çok mermi cezası, ivme (bot hareket payı), sabit nişan (durma payı), kombo.
	var mult := 1.0
	if loadout.i("projectiles") > 1:
		mult *= loadout.m("projectile_damage_mult")
	if loadout.m("momentum") > 0.0:
		mult *= 1.0 + loadout.m("momentum") * _c("moving_ratio", 0.7)
	if loadout.m("steady") > 0.0 and rng.randf() < _c("still_share", 0.12):
		mult *= 1.0 + loadout.m("steady")
	if loadout.m("combo_power") > 0.0:
		mult *= 1.0 + minf(_p("combo_cap", 0.45), loadout.m("combo_power") * float(run.combo))
	return mult

func _elite_mult(e: Dictionary) -> float:
	return 1.0 + loadout.m("hunter") if bool(e["elite"]) and loadout.m("hunter") > 0.0 else 1.0

func _rear_shots(base: float, acc: float) -> void:
	var rear := loadout.i("rear_guns")
	for k in rear:
		if rng.randf() >= acc * _c("rear_hit", 0.35):
			continue
		var t := _nearest(Vector2.ZERO, 560.0)
		if not t.is_empty():
			_damage_enemy(t, base * _p("rear_damage", 0.7), false)

func _pierce_line(from_e: Dictionary, dmg: float, count: int, line_p: float) -> void:
	var from: Vector2 = from_e["pos"]
	var prev: Dictionary = from_e
	for j in count:
		if rng.randf() >= line_p:
			break
		var nxt := _nearest(from, 400.0, prev)
		if nxt.is_empty():
			break
		_damage_enemy(nxt, dmg, false)
		from = nxt["pos"]
		prev = nxt

func _on_hit_cards(e: Dictionary, dmg: float, crit: bool, stopped: bool) -> void:
	var ex := loadout.m("execute")
	if ex > 0.0 and not e["dead"] and float(e["hp"]) < float(e["max"]) * (_p("execute_base", 0.12) + _p("execute_per_level", 0.08) * (ex - 1.0)):
		e["dead"] = true
	var shards := loadout.i("crit_shards")
	if shards > 0 and crit:
		var n := int(_p("shard_count", 3.0)) + int(_p("shard_per_level", 2.0)) * (shards - 1)
		for k in n:
			if rng.randf() < _c("shard_hit", 0.3):
				var t := _nearest(e["pos"], 160.0, e)
				if not t.is_empty():
					_damage_enemy(t, dmg * _p("shard_damage", 0.55), false)
	var split := loadout.i("split_shot")
	if split > 0 and e["dead"]:
		for k in int(_p("split_count", 2.0)) * split:
			if rng.randf() < _c("split_hit", 0.35):
				var t := _nearest(e["pos"], 260.0, e)
				if not t.is_empty():
					_damage_enemy(t, dmg * _p("split_damage", 0.5), false)
	var bounces := loadout.i("ricochet")
	if stopped and bounces > 0:
		var cur: Dictionary = e
		var d := dmg
		for k in bounces:
			if rng.randf() >= _c("ricochet_hit", 0.6):
				break
			var nxt := _nearest(cur["pos"], _p("ricochet_range", 300.0), cur)
			if nxt.is_empty():
				break
			d *= _p("ricochet_damage", 0.7)
			_damage_enemy(nxt, d, false)
			cur = nxt

func _on_kill_cards(_e: Dictionary) -> void:
	if loadout.i("kill_shield") > 0:
		_kill_count += 1
		var list: Array = cp.get("kill_shield_kills", [30, 20])
		if _kill_count >= int(list[mini(loadout.i("kill_shield"), list.size()) - 1]) and shield <= 0:
			_kill_count = 0
			shield = 1

func _on_dash_cards() -> void:
	if loadout.m("dash_nova") > 0.0:
		nova = minf(100.0, nova + loadout.m("dash_nova"))
	if loadout.i("turret") > 0:
		if _turrets.size() >= loadout.i("turret"):
			_turrets.pop_front()
		_turrets.append([_p("turret_life", 6.0), 0.2])
	var comet := loadout.i("evo_comet") > 0
	if loadout.i("dash_trail") > 0 or comet:
		_trail_left = _p("trail_life", 2.4)
	var slam := loadout.i("dash_blast")
	if slam > 0:
		var at := Vector2.from_angle(rng.randf() * TAU) * _c("dash_blast_offset", 90.0)
		_blasts.append([float(bal["player"].get("dash_time", 0.15)), at, _p("dash_blast_radius", 120.0) + _p("dash_blast_per_level", 40.0) * float(slam - 1),
			_pdmg() * _p("dash_blast_damage", 3.0) * (_p("comet_blast_mult", 2.0) if comet else 1.0)])
	if loadout.i("reflect") > 0:
		var shooters := 0
		for e in enemies:
			if not e["dead"] and (e["kind"] == "shooter" or e["kind"] == "sniper" or e["kind"] == "orbiter") and (e["pos"] as Vector2).length() < 760.0:
				shooters += 1
		for k in mini(shooters, int(_c("reflect_max", 4.0))):
			if rng.randf() < _c("reflect_hit", 0.5):
				var t := _nearest(Vector2.ZERO, 700.0)
				if not t.is_empty():
					_damage_enemy(t, _pdmg() * _p("reflect_damage", 2.0), false)

func _on_nova_cards(radius: float, dmg: float) -> void:
	if loadout.i("nova_vortex") > 0:
		var reach := radius * _p("vortex_reach_mult", 1.7)
		for e in enemies:
			if not e["dead"] and (e["pos"] as Vector2).length() < reach:
				e["pos"] = (e["pos"] as Vector2) * _c("vortex_pull_keep", 0.35)
		var mult := _p("singularity_vortex", 1.5) if loadout.i("evo_singularity") > 0 else 1.0
		_blasts.append([_p("vortex_delay", 0.55), Vector2.ZERO, _p("vortex_radius", 230.0), dmg * _p("vortex_damage", 0.8) * mult])
	if loadout.i("nova_shell") > 0:
		if shield <= 0:
			shield = 1
		_heal(_p("nova_shell_heal", 15.0))
	if loadout.i("evo_singularity") > 0:
		nova = minf(100.0, nova + _p("singularity_refund", 30.0))

func _tick_cards(dt: float) -> void:
	var i := _blasts.size() - 1
	while i >= 0:
		var b: Array = _blasts[i]
		b[0] = float(b[0]) - dt
		if float(b[0]) <= 0.0:
			_area_damage(b[1], float(b[2]), float(b[3]))
			if (b[1] as Vector2).length() < float(b[2]):
				_boss_blast(float(b[2]), float(b[3]))
			_blasts.remove_at(i)
		i -= 1
	var blades := loadout.i("orbit_blades")
	if blades > 0:
		_blade_timer -= dt
		if _blade_timer <= 0.0:
			var pulse := maxf(0.03, _p("orbit_pulse", 0.15))
			_blade_timer += pulse
			var r := _p("orbit_radius", 58.0)
			var hit := _p("orbit_hit_radius", 24.0)
			var dmg := _pdmg() * _p("orbit_damage", 1.0)
			for e in enemies:
				if e["dead"] or e["spawn"] > 0.0:
					continue
				var d := (e["pos"] as Vector2).length()
				var band := hit + float(e["rad"])
				if absf(d - r) < band and rng.randf() < minf(1.0, float(blades) * 2.0 * band / (TAU * r) * _c("blade_cover", 1.0)):
					_damage_enemy(e, dmg, false)
			if not boss.is_empty() and float(boss["intro"]) <= 0.0 and float(boss["dist"]) < r + hit + float((boss["st"] as Dictionary).get("radius", 62.0)):
				_boss_hit(dmg * float(blades) * _c("blade_boss_share", 0.3))
	if not _turrets.is_empty():
		var acc := float(model["accuracy"]["drone"])
		var tdmg := _pdmg() * _p("turret_damage", 0.85)
		var k := _turrets.size() - 1
		while k >= 0:
			var tu: Array = _turrets[k]
			tu[0] = float(tu[0]) - dt
			tu[1] = float(tu[1]) - dt
			if float(tu[0]) <= 0.0:
				_turrets.remove_at(k)
				k -= 1
				continue
			if float(tu[1]) <= 0.0:
				tu[1] = _p("turret_interval", 0.42)
				if rng.randf() < acc:
					var t := _nearest(Vector2.ZERO, _p("turret_range", 560.0) + _c("turret_offset", 100.0))
					if not t.is_empty():
						_damage_enemy(t, tdmg, false)
					elif not boss.is_empty() and float(boss["intro"]) <= 0.0:
						_boss_hit(tdmg)
			k -= 1
	if _trail_left > 0.0:
		_trail_left -= dt
		_trail_timer -= dt
		if _trail_timer <= 0.0:
			var tick := _p("trail_tick", 0.2)
			_trail_timer = tick
			var lvl := maxi(loadout.i("dash_trail"), int(_p("comet_trail", 1.0)) if loadout.i("evo_comet") > 0 else 0)
			var tdmg2 := _pdmg() * _p("trail_dps", 2.6) * tick * (1.0 + _p("trail_per_level", 0.5) * float(lvl - 1))
			var reach := _c("trail_reach", 200.0)
			for e in enemies:
				if not e["dead"] and e["spawn"] <= 0.0 and (e["pos"] as Vector2).length() < reach and rng.randf() < _c("trail_cover", 0.45):
					_damage_enemy(e, tdmg2, false)
	var st := loadout.i("static_field")
	if st > 0:
		var thunder := loadout.i("evo_thunder") > 0
		_static_timer -= dt * (_p("thunder_static_rate", 2.0) if thunder else 1.0)
		if _static_timer <= 0.0:
			_static_timer = _p("static_interval", 1.0)
			var want := int(_p("static_targets", 2.0)) + (st - 1) + (int(_p("thunder_static_targets", 2.0)) if thunder else 0)
			var sdmg := _pdmg() * _p("static_damage", 1.5)
			var hit_list: Array = []
			for n in want:
				var best: Dictionary = {}
				var best_d := _p("static_range", 230.0)
				for e in enemies:
					if e["dead"] or e["spawn"] > 0.0 or hit_list.has(e):
						continue
					var d := (e["pos"] as Vector2).length()
					if d < best_d:
						best_d = d
						best = e
				if best.is_empty():
					break
				hit_list.append(best)
			for e in hit_list:
				_damage_enemy(e, sdmg, false)
				_chain_hit(e, sdmg, false)
	var pods := loadout.i("missile_pod")
	if pods > 0:
		_missile_timer -= dt * float(pods)
		if _missile_timer <= 0.0:
			var t := _nearest(Vector2.ZERO, _p("missile_range", 700.0))
			if t.is_empty():
				_missile_timer = 0.2
				if not boss.is_empty() and float(boss["intro"]) <= 0.0 and float(boss["dist"]) < _p("missile_range", 700.0):
					_missile_timer = _p("missile_interval", 2.2)
					_boss_hit(_pdmg() * _p("missile_damage", 2.5) * float(model["accuracy"]["rocket"]))
			else:
				_missile_timer = _p("missile_interval", 2.2)
				if rng.randf() < float(model["accuracy"]["rocket"]):
					var md := _pdmg() * _p("missile_damage", 2.5)
					_damage_enemy(t, md, false)
					_area_damage(t["pos"], _p("missile_blast", 64.0), md * 0.6, t)

# --- Kartlar ----------------------------------------------------------------------
func _card_score(card: Dictionary, weights: Dictionary, syn_bonus: float) -> float:
	var s := 0.0
	var effect: Dictionary = card.get("effect", {})
	for key in effect:
		s += float(weights.get(key, 0.0)) * float(effect[key])
	if str(card.get("tier", "")) == "synergy":
		s += syn_bonus
	return s

func _level_up(policy: String) -> void:
	var offer := loadout.roll(int(bal["leveling"].get("cards", 3)), rng)
	if offer.is_empty():
		run.consume_level()
		return
	var pick := 0
	if policy == "greedy":
		var pol: Dictionary = model["policies"]["greedy"]
		var best := -1e9
		for i in offer.size():
			var s := _card_score(offer[i], pol["weights"], float(pol["synergy_bonus"]))
			if s > best:
				best = s
				pick = i
	else:
		pick = rng.randi() % offer.size()
	var card: Dictionary = offer[pick]
	var ids: Array = []
	for c in offer:
		ids.append(str(c["id"]))
	(res["picks"] as Array).append([ids, str(card["id"]), run.wave])
	var before := max_hp
	loadout.apply(card)
	max_hp = float(bal["player"]["max_health"]) + loadout.m("max_hp_bonus")
	if max_hp > before:
		hp += max_hp - before
	hp = clampf(hp, 0.0, max_hp)
	run.consume_level()
	invuln = maxf(invuln, 0.8)

# --- Kariyer (atölye tüketimi) ---------------------------------------------------------
func play_career(opts: Dictionary) -> Dictionary:
	## Art arda koşular: kazanılan çekirdekle atölye+gemi alır; hepsi bitince kaç koşu/dakika sürdüğünü ölçer.
	var base_seed := int(opts.get("seed", 1))
	var policy := str(opts.get("policy", "greedy"))
	var cfg: Dictionary = model["career"]
	var max_runs := int(opts.get("max_runs", cfg["max_runs"]))
	var run_cap := float(opts.get("run_cap", model.get("career_run_cap", 900.0)))
	var meta := MetaProgress.new(upgrades, ships)
	var crng := RandomNumberGenerator.new()
	crng.seed = base_seed * 977 + 5
	var mean_wave := {}
	var plays := {}
	var runs := 0
	var minutes := 0.0
	var total_cores := 0
	var log: Array = []
	var waves: Array = []
	var capped_runs := 0
	var exhausted_at := -1
	while runs < max_runs:
		var pick := meta.ship
		if crng.randf() < float(cfg["explore"]):
			pick = str(meta.ships_owned[crng.randi() % meta.ships_owned.size()])
		else:
			var best := -1.0
			for id in meta.ships_owned:
				var v := float(mean_wave.get(id, 99.0))
				if v > best:
					best = v
					pick = str(id)
		meta.select_ship(pick)
		var r := play({"seed": base_seed * 1000 + runs, "ship": pick, "meta": meta, "policy": policy, "max_time": run_cap})
		runs += 1
		minutes += float(r["time"]) / 60.0
		plays[pick] = int(plays.get(pick, 0)) + 1
		var n := float(plays[pick])
		mean_wave[pick] = (float(mean_wave.get(pick, 0.0)) * (n - 1.0) + float(r["wave"])) / n if n > 1.0 else float(r["wave"])
		meta.earn(int(r["cores"]))
		total_cores += int(r["cores"])
		waves.append(int(r["wave"]))
		if bool(r["capped"]):
			capped_runs += 1
		var bought := _career_shop(meta)
		for item in bought:
			log.append({"run": runs, "item": item})
		if _meta_complete(meta):
			exhausted_at = runs
			break
	# Her şey alındıktan sonra: hangi gemi baskın? (tüm gemiler sahip, atölye tam; ε-açgözlü seçim sürer.)
	var end_plays := {}
	var end_waves := {}
	if exhausted_at > 0:
		for k in int(cfg.get("endgame_runs", 12)):
			var pick2 := meta.ship
			if crng.randf() < float(cfg["explore"]):
				pick2 = str(meta.ships_owned[crng.randi() % meta.ships_owned.size()])
			else:
				var best2 := -1.0
				for id in meta.ships_owned:
					var v2 := float(mean_wave.get(id, 99.0))
					if v2 > best2:
						best2 = v2
						pick2 = str(id)
			var r2 := play({"seed": base_seed * 1000 + runs + k + 500, "ship": pick2, "meta": meta, "policy": policy, "max_time": run_cap})
			end_plays[pick2] = int(end_plays.get(pick2, 0)) + 1
			end_waves[pick2] = (end_waves.get(pick2, []) as Array) + [int(r2["wave"])]
			var n2 := float(plays.get(pick2, 0)) + 1.0
			plays[pick2] = int(n2)
			mean_wave[pick2] = (float(mean_wave.get(pick2, 0.0)) * (n2 - 1.0) + float(r2["wave"])) / n2 if n2 > 1.0 else float(r2["wave"])
	return {
		"endgame_plays": end_plays, "endgame_waves": end_waves,
		"runs": runs, "exhausted": exhausted_at > 0, "minutes": snappedf(minutes, 0.1), "cores_earned": total_cores,
		"ship_plays": plays, "purchases": log, "waves": waves, "capped_runs": capped_runs,
		"cores_left": meta.cores,
	}

func _career_shop(meta: MetaProgress) -> Array:
	var bought: Array = []
	var guard := 0
	while guard < 200:
		guard += 1
		var best := ""
		var best_cost := 1 << 30
		for def in upgrades:
			var id := str(def["id"])
			var cost := meta.next_cost(id)
			if cost >= 0 and cost < best_cost and cost <= meta.cores:
				best_cost = cost
				best = "u:" + id
		for def in ships:
			var id := str(def["id"])
			if not meta.owns_ship(id) and int(def.get("cost", 0)) < best_cost and int(def.get("cost", 0)) <= meta.cores:
				best_cost = int(def.get("cost", 0))
				best = "s:" + id
		if best == "":
			break
		if best.begins_with("s:"):
			meta.buy_ship(best.substr(2))
		else:
			meta.buy(best.substr(2))
		bought.append(best)
	return bought

func _meta_complete(meta: MetaProgress) -> bool:
	for def in upgrades:
		if meta.next_cost(str(def["id"])) >= 0:
			return false
	for def in ships:
		if not meta.owns_ship(str(def["id"])):
			return false
	return true
