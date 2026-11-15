extends RefCounted
class_name RunState
## Koşu mantığı: dalgalar, boss, puan/XP, seviye ve harita geçişi. Sahneye bağlı değil.
##
## C1 koşu yapısı (veri: `data/balance/waves.json` → `run`): koşu bir MOD seçimiyle başlar (`set_mode` → `begin`).
##   standart  3 sektör × 5 dalga; her sektör boss'la biter → (son değilse) SEKTÖR KAPISI → sonraki sektör; 3. boss → ZAFER
##   hızlı     3 sektör × 3 dalga, kapısız, "etkin dalga" (wave_scale) ile sıkıştırılmış zorluk
##   sonsuz    eski oyun: sektör sınırı/kapı/zafer yok (aynı tohumla eskisiyle birebir aynı akış)
## Aşamalar: READY → BATTLE ⇄ BREAK → BOSS → BREAK → (GATE → BATTLE | VICTORY → BATTLE (sonsuza devam) | OVER) … → OVER
## Kapı ve zafer RunState'i BEKLETİR (step bir şey yapmaz): sahne `choose_gate(id)` / `continue_endless()` /
## `finish_victory()` çağırana kadar. Kapı seçenekleri ayrı bir RNG'den (`gate_rng`) çekilir: dalga planı akışı değişmez.
## Ödül: `reward()` (eğri veride; mod tanımı yoksa eski MetaProgress.run_reward formülü).

signal wave_started(wave: int)
signal spawn_due(kind: String)
signal boss_due
signal wave_cleared(wave: int)
signal map_cleared(map_index: int)
signal map_changed(map_index: int)
signal level_up(level: int)
signal run_ended(score: int)
## C1: sektörün boss'u yenildi (0 tabanlı sektör sırası, bu koşuda temizlenen toplam).
signal sector_cleared(sector: int, total: int)
## C1: sektör kapısı açıldı (seçenek kimlikleri; ilk her zaman güvenli seçenek). `choose_gate` ile kapanır.
signal gate_opened(options: Array)
## C1: kapı seçildi ("" = atlandı); bu sinyalden SONRA harita değişir ve sonraki dalga başlar.
signal gate_closed(option_id: String)
## C1: son sektör temizlendi. `continue_endless()` ya da `finish_victory()` bekler.
signal victory_reached
## C1: zaferden sonra sonsuza devam edildi.
signal endless_continued

const PHASE_READY := 0
const PHASE_BATTLE := 1
const PHASE_BREAK := 2
const PHASE_BOSS := 3
const PHASE_OVER := 4
const PHASE_GATE := 5
const PHASE_VICTORY := 6

const MODE_STANDARD := "standard"
const MODE_QUICK := "quick"
const MODE_ENDLESS := "endless"

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

# --- C1: mod / sektör / kapı / zafer ----------------------------------------------
## Varsayılan SONSUZ: mod seçmeyen çağıranlar (eski araçlar, testler) eski davranışı alır. Oyun RunFlow'da seçer.
var mode := MODE_ENDLESS
var mode_def: Dictionary = {}
var sectors_cleared := 0
var gate_options: Array[String] = []
var gates_taken: Array[String] = []
var won := false
var continued := false
var reward_mult := 1.0
var banked_cores := 0
var enemy_hp_mod := 1.0
var enemy_damage_mod := 1.0
var victory_wave := 0
var victory_score := 0
var victory_bosses := 0
var victory_time := 0.0
var gate_rng := RandomNumberGenerator.new()
var _mod_sector := -1

func _init(balance: Dictionary, seed_value: int = 0) -> void:
	defs = balance
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	xp_next = int(defs.get("leveling", {}).get("base_xp", 70))
	set_mode(MODE_ENDLESS)

# --- Mod ---------------------------------------------------------------------------
func run_defs() -> Dictionary:
	return defs.get("run", {}) if typeof(defs.get("run", {})) == TYPE_DICTIONARY else {}

func modes() -> Array:
	## Menü sırası (veride `order`).
	var out: Array = []
	var all: Dictionary = run_defs().get("modes", {})
	for id in run_defs().get("order", all.keys()):
		if all.has(str(id)):
			out.append(str(id))
	return out

func has_mode(id: String) -> bool:
	return (run_defs().get("modes", {}) as Dictionary).has(id)

func set_mode(id: String) -> void:
	## Koşu başlamadan önce (begin öncesi). Bilinmeyen kimlik → sonsuz (eski davranış).
	var all: Dictionary = run_defs().get("modes", {})
	mode = id if all.has(id) else MODE_ENDLESS
	mode_def = all.get(mode, {})

func total_sectors() -> int:
	## 0 = sınırsız (sonsuz mod).
	return int(mode_def.get("sectors", 0))

func waves_per_sector() -> int:
	var n := int(mode_def.get("waves_per_sector", 0))
	return n if n > 0 else int(defs.get("waves", {}).get("boss_every", 5))

func gates_enabled() -> bool:
	return bool(mode_def.get("gates", false))

func has_goal() -> bool:
	## Ekranda sektör hedefi gösterilsin mi (sonlu mod ve henüz sonsuza geçilmedi).
	return total_sectors() > 0 and not continued

func current_sector() -> int:
	## 1 tabanlı, ekranda gösterilen sektör (zaferden sonra son sektörde kalır).
	return mini(sectors_cleared + 1, total_sectors()) if total_sectors() > 0 else sectors_cleared + 1

func wave_in_sector() -> int:
	return (maxi(1, wave) - 1) % waves_per_sector() + 1

func difficulty_wave(n: int) -> float:
	## "Etkin dalga": zorluk ve dalga planı bunu kullanır. wave_scale = 1 → tam olarak n (eski davranış).
	return 1.0 + float(n - 1) * float(mode_def.get("wave_scale", 1.0))

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
	sectors_cleared = 0
	gate_options.clear()
	gates_taken.clear()
	won = false
	continued = false
	reward_mult = 1.0
	banked_cores = 0
	enemy_hp_mod = 1.0
	enemy_damage_mod = 1.0
	victory_wave = 0
	victory_score = 0
	victory_bosses = 0
	victory_time = 0.0
	_mod_sector = -1
	# Kapı RNG'si koşu RNG'sinden TÜRETİLİR ama ondan sayı çekmez: dalga planı akışı (tohumlu koşu) aynı kalır.
	gate_rng.seed = rng.seed * 31 + 7
	_start_wave(1)

func is_boss_wave(n: int) -> bool:
	var every := waves_per_sector()
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
	var count := int(round(float(w["base_count"]) + float(w["growth"]) * (difficulty_wave(n) - 1.0)))
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
	var eff := difficulty_wave(n)
	var mix := sector_mix()
	for kind in defs["enemies"]:
		var stats: Dictionary = defs["enemies"][kind]
		if float(stats.get("unlock", 1)) <= eff and float(stats.get("weight", 0.0)) > 0.0:
			var weight := float(stats.get("weight", 0.0))
			if mix.has(kind):
				weight *= float(mix[kind])
			out.append({"kind": kind, "weight": weight})
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
	if phase == PHASE_OVER or phase == PHASE_READY or phase == PHASE_GATE or phase == PHASE_VICTORY:
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
				break_timer = float(defs["waves"]["intermission"]) * float(mode_def.get("intermission_mult", 1.0))
				score += int(defs["waves"]["clear_bonus"]) * wave
				wave_cleared.emit(wave)
			elif phase == PHASE_BOSS and not boss_alive:
				phase = PHASE_BREAK
				break_timer = float(defs["waves"].get("boss_break", 3.2)) * float(mode_def.get("intermission_mult", 1.0))
	elif phase == PHASE_BREAK:
		break_timer -= dt
		if break_timer <= 0.0:
			if boss_defeated:
				boss_defeated = false
				if _after_sector():
					return
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
	return (1.0 + float(d["hp_per_wave"]) * (difficulty_wave(wave) - 1.0)) * enemy_hp_mod

func damage_scale() -> float:
	var d: Dictionary = defs["difficulty"]
	return (1.0 + float(d["damage_per_wave"]) * (difficulty_wave(wave) - 1.0)) * enemy_damage_mod

func speed_scale() -> float:
	var d: Dictionary = defs["difficulty"]
	return minf(float(d["speed_cap"]), 1.0 + float(d["speed_per_wave"]) * (difficulty_wave(wave) - 1.0))

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
	sectors_cleared += 1
	if _mod_sector >= 0 and sectors_cleared > _mod_sector:
		# Kapının "sonraki sektör" zorluğu bu boss'la biter.
		enemy_hp_mod = 1.0
		enemy_damage_mod = 1.0
		_mod_sector = -1
	sector_cleared.emit(sectors_cleared - 1, sectors_cleared)
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
	## Hata ayıklama/araç: n. dalgaya atla (önceki sektörler temizlenmiş sayılır).
	alive = 0
	pending.clear()
	sectors_cleared = (maxi(1, n) - 1) / waves_per_sector()
	if total_sectors() > 0:
		sectors_cleared = mini(sectors_cleared, total_sectors() - 1)
	_start_wave(maxi(1, n))

# --- C1: sektör sonu, kapı, zafer --------------------------------------------------
func _after_sector() -> bool:
	## Boss arası bitti: zafer mi, kapı mı, yoksa (sonsuz) doğrudan sonraki sektör mü? true = bekle.
	if total_sectors() > 0 and not continued and sectors_cleared >= total_sectors():
		phase = PHASE_VICTORY
		won = true
		victory_wave = wave
		victory_score = score
		victory_bosses = bosses
		victory_time = time
		victory_reached.emit()
		return true
	if gates_enabled() and not continued and sectors_cleared < total_sectors():
		gate_options = roll_gate()
		if gate_options.is_empty():
			return false
		phase = PHASE_GATE
		gate_opened.emit(gate_options.duplicate())
		return true
	return false

func gate_defs() -> Dictionary:
	return run_defs().get("gates", {}).get("options", {})

func gate_def(id: String) -> Dictionary:
	return gate_defs().get(id, {})

func roll_gate() -> Array[String]:
	## Önce her zaman güvenli seçenek(ler) (`always`), kalanlar havuzdan `gate_rng` ile. Koşu başına sınırı dolan çıkmaz.
	var cfg: Dictionary = run_defs().get("gates", {})
	var all := gate_defs()
	var want := int(cfg.get("offer", 3))
	var out: Array[String] = []
	for id in cfg.get("always", []):
		if all.has(str(id)) and _gate_allowed(str(id)):
			out.append(str(id))
	var pool: Array[String] = []
	var ids: Array = all.keys()
	ids.sort()
	for id in ids:
		if not out.has(str(id)) and _gate_allowed(str(id)):
			pool.append(str(id))
	while out.size() < want and not pool.is_empty():
		var k := gate_rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out

func _gate_allowed(id: String) -> bool:
	var limit := int(gate_def(id).get("max_per_run", -1))
	return limit < 0 or gates_taken.count(id) < limit

func choose_gate(id: String) -> bool:
	## Kapı seçimi ("" = atla). Koşu düzeyi etkiler burada (ödül çarpanı, kasa, sonraki sektör zorluğu); oyuncuya
	## dönük etkiler (iyileşme, kart, yenileme) `gate_closed` dinleyicisinde. Sonra harita değişir, sonraki dalga başlar.
	if phase != PHASE_GATE:
		return false
	if id != "" and not gate_options.has(id):
		return false
	if id != "":
		var g := gate_def(id)
		gates_taken.append(id)
		reward_mult += float(g.get("reward_mult", 0.0))
		banked_cores += int(g.get("bank_cores", 0))
		if g.has("enemy_hp_mult") or g.has("enemy_damage_mult"):
			enemy_hp_mod *= float(g.get("enemy_hp_mult", 1.0))
			enemy_damage_mod *= float(g.get("enemy_damage_mult", 1.0))
			_mod_sector = sectors_cleared
	gate_options.clear()
	gate_closed.emit(id)
	map_index += 1
	map_changed.emit(map_index)
	_start_wave(wave + 1)
	return true

func continue_endless() -> bool:
	## Zaferden sonra sonsuza devam: sektör sınırı kalkar, harita değişir, sonraki dalga başlar (eski döngü, MK-2 bosslar).
	if phase != PHASE_VICTORY or not bool(mode_def.get("continue_endless", false)):
		return false
	continued = true
	endless_continued.emit()
	map_index += 1
	map_changed.emit(map_index)
	_start_wave(wave + 1)
	return true

func finish_victory() -> bool:
	## Zaferde koşuyu bitir (sonuç ekranı).
	if phase != PHASE_VICTORY:
		return false
	end_run()
	return true

func debug_end_sector(cleared: int) -> bool:
	## Araç/ekran görüntüsü: `cleared` sektör temizlenmiş say ve sektör sonunu (kapı/zafer) hemen işlet.
	alive = 0
	pending.clear()
	boss_alive = false
	boss_defeated = false
	sectors_cleared = clampi(cleared, 0, maxi(1, total_sectors()))
	phase = PHASE_BREAK
	return _after_sector()

func can_continue() -> bool:
	return phase == PHASE_VICTORY and bool(mode_def.get("continue_endless", false))

func sector_mix() -> Dictionary:
	## C2 kancası: `run.sector_mix[sektör]` = {tür: ağırlık çarpanı}. Boş → dalga planı değişmez.
	var mix: Array = run_defs().get("sector_mix", [])
	if mix.is_empty():
		return {}
	var entry: Variant = mix[mini(sectors_cleared, mix.size() - 1)]
	return entry if typeof(entry) == TYPE_DICTIONARY else {}

static func bot_gate_choice(options: Array, gate_table: Dictionary, hp_ratio: float, policy := "auto") -> String:
	## Bot (demo, simülasyon) kapı seçimi. safe: hep ilk (güvenli); risky: en yüksek ödül çarpanı/kasa;
	## auto: can < %50 → güvenli, değilse risky. Seçenek yoksa "" (atla).
	if options.is_empty():
		return ""
	if policy == "safe" or (policy == "auto" and hp_ratio < 0.5):
		return str(options[0])
	var best := str(options[0])
	var best_v := -1.0
	for id in options:
		var g: Dictionary = gate_table.get(str(id), {})
		var v := float(g.get("reward_mult", 0.0)) * 100.0 + float(g.get("bank_cores", 0))
		if v > best_v:
			best_v = v
			best = str(id)
	return best

# --- C1: ödül eğrisi ----------------------------------------------------------------
func reward(core_mult := 1.0) -> Dictionary:
	## Koşu sonu çekirdek dökümü. Mod ödül tanımı yoksa eski formül (MetaProgress.run_reward ile aynı sonuç).
	var r: Dictionary = mode_def.get("reward", {})
	if r.is_empty():
		var legacy := MetaProgress.run_reward(score, wave, bosses, core_mult)
		return {"waves": 0, "score": 0, "sectors": 0, "victory": 0, "extra": 0, "base": legacy, "mult": 1.0, "banked": 0, "total": legacy}
	var w_end := victory_wave if (won and continued) else wave
	var s_end := victory_score if (won and continued) else score
	var b_end := victory_bosses if (won and continued) else bosses
	var waves_part := float(r.get("per_wave", 3.0)) * float(maxi(0, w_end - 1))
	var score_part := float(s_end) / maxf(1.0, float(r.get("score_div", 150.0)))
	if float(r.get("score_cap", -1.0)) >= 0.0:
		score_part = minf(score_part, float(r["score_cap"]))
	var clears: Array = r.get("sector_clear", [])
	var sector_part := 0.0
	for i in b_end:
		if not clears.is_empty():
			sector_part += float(clears[mini(i, clears.size() - 1)])
	var victory_part := float(r.get("victory", 0)) if won else 0.0
	var base := waves_part + score_part + sector_part + victory_part
	if float(r.get("cap", -1)) >= 0.0:
		base = minf(base, float(r["cap"]))
	var extra := 0.0
	if won and continued:
		extra = float(r.get("after_victory_per_wave", 0.0)) * float(maxi(0, wave - victory_wave)) \
			+ float(r.get("after_victory_boss", 0)) * float(maxi(0, bosses - victory_bosses))
		if float(r.get("extra_cap", -1)) >= 0.0:
			extra = minf(extra, float(r["extra_cap"]))
	var total := maxi(0, int(round((base + extra) * reward_mult * core_mult))) + banked_cores
	return {
		"waves": int(round(waves_part)), "score": int(round(score_part)), "sectors": int(round(sector_part)),
		"victory": int(round(victory_part)), "extra": int(round(extra)), "base": int(round(base)),
		"mult": snappedf(reward_mult * core_mult, 0.01), "banked": banked_cores, "total": total,
	}

func reward_total(core_mult := 1.0) -> int:
	return int(reward(core_mult)["total"])

# --- C1: anlık görüntü (uygulama arka plana alınınca/ileride koşu sürdürme için) -------------
## Not: proje bugün yarım kalan koşuyu SÜRDÜRMÜYOR (uygulama duraklayınca yalnız duraklatma menüsü açılır). Bu çift,
## sektör yapısının durumunu kaybetmeden kaydedip geri yüklemeyi sağlar ve testle sabitlenir; sahne düzeyi sürdürme ayrı iştir.
const SNAPSHOT_KEYS := ["mode", "wave", "phase", "map_index", "score", "xp", "level", "xp_next", "kills", "bosses", "time",
	"max_combo", "sectors_cleared", "won", "continued", "reward_mult", "banked_cores", "enemy_hp_mod", "enemy_damage_mod",
	"victory_wave", "victory_score", "victory_bosses", "victory_time", "_mod_sector"]

func snapshot() -> Dictionary:
	var out := {}
	for key in SNAPSHOT_KEYS:
		out[key] = get(key)
	out["gates_taken"] = Array(gates_taken)
	out["gate_options"] = Array(gate_options)
	# 64 bit durum metin olarak: JSON sayıları kayan noktaya düşer ve hassasiyet kaybolur.
	out["rng_state"] = str(rng.state)
	out["gate_rng_state"] = str(gate_rng.state)
	return out

func restore(data: Dictionary) -> void:
	set_mode(str(data.get("mode", MODE_ENDLESS)))
	for key in SNAPSHOT_KEYS:
		if key != "mode" and data.has(key):
			set(key, data[key])
	gates_taken.clear()
	for id in data.get("gates_taken", []):
		gates_taken.append(str(id))
	gate_options.clear()
	for id in data.get("gate_options", []):
		gate_options.append(str(id))
	rng.state = str(data.get("rng_state", str(rng.state))).to_int()
	gate_rng.state = str(data.get("gate_rng_state", str(gate_rng.state))).to_int()
	for key in ["wave", "phase", "map_index", "score", "xp", "level", "xp_next", "kills", "bosses", "max_combo", "sectors_cleared",
			"banked_cores", "victory_wave", "victory_score", "victory_bosses", "_mod_sector"]:
		set(key, int(get(key)))   # JSON'dan gelen sayılar kayan nokta olabilir
	pending.clear()
	alive = 0
	boss_alive = false
	boss_defeated = false
	if phase == PHASE_BATTLE or phase == PHASE_BOSS or phase == PHASE_BREAK or phase == PHASE_READY:
		# Yarıdaki dalga kaydedilmez: aynı dalga yeniden başlar (en fazla bir dalga kaybı).
		_start_wave(maxi(1, wave))
