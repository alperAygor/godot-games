extends TestCase
## Dalga akışı, boss, harita geçişi, XP/seviye.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GateScreenScript = preload("res://scripts/ui/screens/gate.gd")

func _defs() -> Dictionary:
	return BalanceData.load_dir()["data"]

func _run(seed_value: int = 11) -> RunState:
	return RunStateScript.new(_defs(), seed_value)

func test_first_wave_starts() -> void:
	var r := _run()
	r.begin()
	eq(r.wave, 1, "ilk dalga 1 olmalı")
	eq(r.phase, RunStateScript.PHASE_BATTLE, "savaş fazında başlamalı")
	gt(float(r.pending.size()), 0.0, "düşman planı boş olmamalı")

func test_only_chasers_at_wave_one() -> void:
	var r := _run()
	for kind in r.plan_wave(1):
		eq(kind, "chaser", "1. dalgada sadece avcı olmalı")

func test_more_types_unlock_later() -> void:
	var r := _run()
	var kinds := {}
	for i in 20:
		for kind in r.plan_wave(8):
			kinds[kind] = true
	gt(float(kinds.size()), 2.0, "8. dalgada birden fazla tür olmalı")
	for kind in r.plan_wave(9):
		check(kind in r.defs["enemies"], "tanımsız tür: " + kind)

func test_boss_wave_fires_signal() -> void:
	var r := _run()
	var bosses := [0]
	r.boss_due.connect(func(): bosses[0] += 1)
	r.jump_to(5)
	eq(r.phase, RunStateScript.PHASE_BOSS, "5. dalga boss fazı olmalı")
	eq(bosses[0], 1, "boss sinyali bir kez gelmeli")
	check(r.boss_alive, "boss canlı olmalı")

func test_boss_death_moves_to_next_map() -> void:
	var r := _run()
	var maps := [0]
	var waves := [0]
	r.map_changed.connect(func(i): maps[0] = i)
	r.wave_started.connect(func(w): waves[0] = w)
	r.jump_to(5)
	r.boss_died()
	check(r.boss_defeated, "boss yenildi işaretlenmeli")
	# Bekleyen minyonlar oyunda doğup ölür; testte doğrudan boşaltılır.
	r.pending.clear()
	r.alive = 0
	for i in 200:
		r.step(0.05)
	eq(maps[0], 1, "boss sonrası harita 1 olmalı")
	eq(r.wave, 6, "sıradaki dalga 6 olmalı")
	eq(r.phase, RunStateScript.PHASE_BATTLE, "yeni dalga savaş fazında olmalı")

func test_difficulty_grows() -> void:
	var r := _run()
	r.wave = 1
	var hp1: float = r.hp_scale()
	var dmg1: float = r.damage_scale()
	r.wave = 10
	gt(r.hp_scale(), hp1, "can ölçeği artmalı")
	gt(r.damage_scale(), dmg1, "hasar ölçeği artmalı")
	check(r.speed_scale() <= 1.45, "hız ölçeği sınırı aşmamalı")

func test_xp_levels_up() -> void:
	var r := _run()
	var ups := [0]
	r.level_up.connect(func(_l): ups[0] += 1)
	r.begin()
	var target: int = r.xp_next
	r.add_xp(target)
	eq(r.level, 2, "seviye 2 olmalı")
	eq(ups[0], 1, "level_up bir kez gelmeli")
	eq(r.pending_levels, 1, "bir kart hakkı verilmeli")
	r.consume_level()
	eq(r.pending_levels, 0, "kart hakkı tüketilmeli")

func test_kill_adds_score_and_xp() -> void:
	var r := _run()
	r.begin()
	var before: int = r.score
	r.enemy_died(10)
	gt(float(r.score), float(before), "skor artmalı")
	gt(float(r.xp), 0.0, "XP artmalı")
	eq(r.kills, 1, "öldürme sayılmalı")

func test_kill_clears_wave() -> void:
	var r := _run()
	r.begin()
	var cleared := [0]
	r.wave_cleared.connect(func(_w): cleared[0] += 1)
	for i in 400:
		while r.alive > 0:
			r.enemy_died(1)
		r.step(0.05)
		if cleared[0] > 0:
			break
	eq(cleared[0], 1, "dalga temizlenince sinyal gelmeli")

func test_combo_survives_wave_change_and_tracks_max() -> void:
	var r := _run()
	r.begin()
	for i in 4:
		r.enemy_died(5)
	eq(r.max_combo, 4, "en yüksek kombo izlenmeli")
	gt(r.combo_ratio(), 0.5, "kombo süresi dolu başlamalı")
	r.step(10.0)
	eq(r.combo, 0, "süre dolunca kombo sıfırlanmalı")
	eq(r.max_combo, 4, "en yüksek kombo korunmalı")

# --- C1: modlar, sektör kapısı, zafer, ödül, kayıt ---------------------------------------------------
func _mode_run(mode: String, seed_value: int = 11) -> RunState:
	var r := _run(seed_value)
	r.set_mode(mode)
	r.begin()
	return r

func _finish_sector(r: RunState) -> void:
	## Boss dalgasındayken: boss'u öldür, kalanları boşalt, ara bitene kadar ilerlet (kapı/zafer/sonraki dalga).
	r.boss_died()
	r.pending.clear()
	r.alive = 0
	for i in 400:
		r.step(0.05)
		if r.phase != RunStateScript.PHASE_BREAK and r.phase != RunStateScript.PHASE_BOSS:
			break

func test_default_mode_is_endless_and_unchanged() -> void:
	var r := _run()
	eq(r.mode, RunStateScript.MODE_ENDLESS, "mod seçilmezse sonsuz (eski davranış)")
	eq(r.total_sectors(), 0, "sonsuzda sektör sınırı yok")
	check(not r.has_goal(), "sonsuzda hedef göstergesi yok")
	r.begin()
	r.jump_to(5)
	var gates := [0]
	r.gate_opened.connect(func(_o): gates[0] += 1)
	_finish_sector(r)
	eq(gates[0], 0, "sonsuzda kapı açılmaz")
	eq(r.map_index, 1, "sonsuzda boss sonrası doğrudan sonraki harita")
	eq(r.wave, 6, "sonsuzda sonraki dalga 6")

func test_unknown_mode_falls_back_to_endless() -> void:
	var r := _run()
	r.set_mode("yok_boyle_mod")
	eq(r.mode, RunStateScript.MODE_ENDLESS, "bilinmeyen mod sonsuza düşmeli")

func test_modes_listed_in_menu_order() -> void:
	var r := _run()
	eq(r.modes(), ["standard", "quick", "endless"], "menü sırası veriden")
	for id in r.modes():
		check(r.has_mode(id), "mod tanımlı: " + id)

func test_standard_gate_opens_after_first_boss() -> void:
	var r := _mode_run("standard")
	eq(r.total_sectors(), 3, "standart: 3 sektör")
	eq(r.waves_per_sector(), 5, "standart: sektör başına 5 dalga")
	check(r.has_goal(), "standartta hedef gösterilir")
	var opened: Array = []
	r.gate_opened.connect(func(o): opened.append(o))
	r.jump_to(5)
	eq(r.current_sector(), 1, "5. dalga 1. sektörde")
	_finish_sector(r)
	eq(r.phase, RunStateScript.PHASE_GATE, "ilk boss sonrası kapı")
	eq(opened.size(), 1, "kapı sinyali bir kez")
	eq(r.sectors_cleared, 1, "bir sektör temizlendi")
	eq(r.gate_options.size(), 3, "3 seçenek")
	eq(r.gate_options[0], "repair", "ilk seçenek her zaman güvenli (çıkmaz yok)")
	var uniq := {}
	for id in r.gate_options:
		uniq[id] = true
	eq(uniq.size(), 3, "seçenekler tekrar etmez")
	var w := r.wave
	r.step(5.0)
	eq(r.phase, RunStateScript.PHASE_GATE, "kapı açıkken step ilerletmez")
	eq(r.wave, w, "kapı açıkken dalga değişmez")
	eq(r.map_index, 0, "kapı seçilmeden harita değişmez")

func test_gate_rejects_unknown_choice() -> void:
	var r := _mode_run("standard")
	r.jump_to(5)
	_finish_sector(r)
	check(not r.choose_gate("yok"), "teklif edilmeyen seçenek reddedilir")
	eq(r.phase, RunStateScript.PHASE_GATE, "reddedilince kapı açık kalır")
	check(not _mode_run("standard").choose_gate("repair"), "kapı dışında seçim reddedilir")

func test_gate_overload_harder_sector_more_reward() -> void:
	var r := _mode_run("standard")
	r.jump_to(5)
	_finish_sector(r)
	r.gate_options = ["repair", "overload", "salvage"]
	var hp_before := r.hp_scale()
	var closed: Array = []
	r.gate_closed.connect(func(id): closed.append(id))
	check(r.choose_gate("overload"), "aşırı gerilim seçilebilmeli")
	eq(closed, ["overload"], "gate_closed seçimle gelir")
	eq(r.phase, RunStateScript.PHASE_BATTLE, "seçimden sonra savaş")
	eq(r.wave, 6, "seçimden sonra 6. dalga")
	eq(r.map_index, 1, "seçimden sonra 2. harita")
	near(r.reward_mult, 1.25, 0.0001, "ödül çarpanı +%25")
	near(r.enemy_hp_mod, 1.3, 0.0001, "düşman canı ×1.3")
	gt(r.hp_scale(), hp_before * 1.25, "zorluk ölçeğine yansır")
	r.jump_to(10)
	_finish_sector(r)
	near(r.enemy_hp_mod, 1.0, 0.0001, "zor sektör boss'la biter")
	near(r.enemy_damage_mod, 1.0, 0.0001, "hasar çarpanı da sıfırlanır")
	near(r.reward_mult, 1.25, 0.0001, "ödül çarpanı koşu boyu kalır")

func test_gate_skip_and_salvage() -> void:
	var r := _mode_run("standard")
	r.jump_to(5)
	_finish_sector(r)
	check(r.choose_gate(""), "atlamak her zaman mümkün")
	eq(r.map_index, 1, "atlayınca da sektör ilerler")
	eq(r.gates_taken.size(), 0, "atlanan kapı kaydedilmez")
	r.jump_to(10)
	_finish_sector(r)
	eq(r.phase, RunStateScript.PHASE_GATE, "2. boss sonrası ikinci kapı")
	r.gate_options = ["repair", "salvage", "overload"]
	r.choose_gate("salvage")
	eq(r.banked_cores, int(r.gate_def("salvage")["bank_cores"]), "hurda kasaya")

func test_cursed_gate_limited_per_run() -> void:
	var r := _mode_run("standard")
	r.jump_to(5)
	_finish_sector(r)
	r.gate_options = ["repair", "cursed", "overload"]
	r.choose_gate("cursed")
	for i in 30:
		check(not r.roll_gate().has("cursed"), "lanetli seçenek koşuda bir kez")

func test_victory_then_finish() -> void:
	var r := _mode_run("standard")
	var wins := [0]
	var ended := [0]
	r.victory_reached.connect(func(): wins[0] += 1)
	r.run_ended.connect(func(_s): ended[0] += 1)
	r.jump_to(15)
	eq(r.current_sector(), 3, "15. dalga 3. sektör")
	_finish_sector(r)
	eq(r.phase, RunStateScript.PHASE_VICTORY, "son boss → zafer")
	eq(wins[0], 1, "zafer sinyali bir kez")
	check(r.won, "zafer işaretlendi")
	eq(r.victory_wave, 15, "zafer dalgası")
	r.step(3.0)
	eq(r.phase, RunStateScript.PHASE_VICTORY, "zaferde step ilerletmez")
	check(r.finish_victory(), "bitir")
	eq(r.phase, RunStateScript.PHASE_OVER, "koşu bitti")
	eq(ended[0], 1, "run_ended bir kez")
	check(not r.finish_victory(), "ikinci bitirme yok")
	check(not r.continue_endless(), "bittikten sonra devam yok")

func test_victory_then_continue_endless() -> void:
	var r := _mode_run("standard")
	r.jump_to(15)
	_finish_sector(r)
	check(r.can_continue(), "standartta sonsuza devam var")
	check(r.continue_endless(), "devam")
	check(r.continued, "devam işaretlendi")
	check(not r.has_goal(), "sonsuzda hedef göstergesi kalkar")
	eq(r.wave, 16, "16. dalga")
	eq(r.map_index, 1, "harita ilerler (jump_to haritayı değiştirmez)")
	eq(r.phase, RunStateScript.PHASE_BATTLE, "savaş sürer")
	r.jump_to(20)
	_finish_sector(r)
	eq(r.phase, RunStateScript.PHASE_BATTLE, "devamda kapı/zafer yok")
	eq(r.wave, 21, "sonraki dalga")

func test_quick_mode_short_and_compressed() -> void:
	var r := _mode_run("quick")
	eq(r.waves_per_sector(), 3, "hızlı: 3 dalgalık sektör")
	check(r.is_boss_wave(3) and r.is_boss_wave(9) and not r.is_boss_wave(5), "boss 3/6/9. dalgada")
	near(r.difficulty_wave(3), 4.2, 0.0001, "etkin dalga 1+2×1.6")
	check(not r.gates_enabled(), "hızlıda kapı yok")
	var gates := [0]
	r.gate_opened.connect(func(_o): gates[0] += 1)
	r.jump_to(3)
	_finish_sector(r)
	eq(gates[0], 0, "hızlıda kapı açılmaz")
	eq(r.map_index, 1, "doğrudan sonraki sektör")
	r.jump_to(9)
	_finish_sector(r)
	eq(r.phase, RunStateScript.PHASE_VICTORY, "9. dalga boss'u → zafer")
	check(not r.can_continue(), "hızlıda sonsuza devam yok")

func test_endless_wave_math_identical_to_legacy() -> void:
	## wave_scale = 1 iken etkin dalga tam olarak n: zorluk/dalga planı eskiyle bit bit aynı.
	var defs := _defs()
	var r := RunStateScript.new(defs, 5)
	var d: Dictionary = defs["difficulty"]
	for n in [1, 2, 7, 15, 33]:
		r.wave = n
		eq(r.difficulty_wave(n), float(n), "etkin dalga = n")
		eq(r.hp_scale(), 1.0 + float(d["hp_per_wave"]) * float(n - 1), "can ölçeği eski formül")
		eq(r.damage_scale(), 1.0 + float(d["damage_per_wave"]) * float(n - 1), "hasar ölçeği eski formül")

func test_gate_rng_does_not_shift_wave_plans() -> void:
	## Kapı seçenekleri ayrı RNG'den: standart ve sonsuz koşu aynı tohumla aynı dalga planlarını üretir.
	var a := _mode_run("standard", 21)
	var b := _mode_run("endless", 21)
	for r in [a, b]:
		r.jump_to(5)
		_finish_sector(r)
	a.choose_gate("repair")
	eq(a.wave, 6, "standart 6. dalga")
	eq(b.wave, 6, "sonsuz 6. dalga")
	eq(Array(a.pending), Array(b.pending), "aynı tohum → aynı 6. dalga planı")

func test_same_seed_same_gate_options() -> void:
	var a := _mode_run("standard", 33)
	var b := _mode_run("standard", 33)
	for r in [a, b]:
		r.jump_to(5)
		_finish_sector(r)
	eq(Array(a.gate_options), Array(b.gate_options), "aynı tohum → aynı kapı seçenekleri")

func test_snapshot_restore_round_trip() -> void:
	var r := _mode_run("standard", 44)
	r.jump_to(5)
	_finish_sector(r)
	r.score = 1234
	var snap := r.snapshot()
	var copy := _run(1)
	copy.restore(JSON.parse_string(JSON.stringify(snap)))
	eq(copy.mode, "standard", "mod geri yüklendi")
	eq(copy.phase, RunStateScript.PHASE_GATE, "kapı aşaması geri yüklendi")
	eq(Array(copy.gate_options), Array(r.gate_options), "kapı seçenekleri geri yüklendi")
	eq(copy.sectors_cleared, 1, "temizlenen sektör geri yüklendi")
	eq(copy.score, 1234, "puan geri yüklendi")
	check(copy.choose_gate(str(copy.gate_options[1])), "geri yüklenen kapıda seçim yapılabilir")
	r.choose_gate(str(r.gate_options[1]))
	eq(copy.wave, r.wave, "aynı dalgaya geçer")
	eq(Array(copy.pending), Array(r.pending), "aynı dalga planı (RNG durumu taşındı)")

func test_bot_gate_choice_policies() -> void:
	var r := _run()
	var table := r.gate_defs()
	var opts := ["repair", "salvage", "overload"]
	eq(RunStateScript.bot_gate_choice(opts, table, 0.3, "auto"), "repair", "canı düşük bot güvenliyi seçer")
	eq(RunStateScript.bot_gate_choice(opts, table, 0.9, "auto"), "overload", "canı yüksek bot en ödüllüyü seçer")
	eq(RunStateScript.bot_gate_choice(opts, table, 0.9, "safe"), "repair", "güvenli politika")
	eq(RunStateScript.bot_gate_choice([], table, 0.9, "auto"), "", "seçenek yoksa atla")

func test_reward_endless_is_legacy_formula_capped() -> void:
	var r := _mode_run("endless")
	r.score = 3000
	r.wave = 8
	r.bosses = 1
	eq(r.reward_total(1.0), MetaProgress.run_reward(3000, 8, 1, 1.0), "sınır altında eski formül")
	eq(r.reward_total(1.5), MetaProgress.run_reward(3000, 8, 1, 1.5), "atölye çarpanı aynı")
	r.score = 900000
	r.wave = 60
	r.bosses = 11
	var cap := int((r.mode_def["reward"] as Dictionary)["cap"])
	eq(r.reward_total(1.0), cap, "uzun koşu ödülü sınırlı")

func test_reward_standard_curve() -> void:
	var dead := _mode_run("standard")
	dead.score = 6000
	dead.wave = 10
	dead.bosses = 1
	var rd := dead.reward(1.0)
	eq(int(rd["victory"]), 0, "ölümde zafer payı yok")
	var won := _mode_run("standard")
	won.jump_to(15)
	won.score = 40000
	won.bosses = 2
	_finish_sector(won)
	var rw := won.reward(1.0)
	gt(float(rw["total"]), float(rd["total"]), "zafer ölümden çok öder")
	var r_def: Dictionary = won.mode_def["reward"]
	check(int(rw["base"]) <= int(r_def["cap"]), "taban sınırı aşmaz")
	won.continue_endless()
	var before := int(won.reward(1.0)["total"])
	won.wave = 80
	won.bosses = 15
	won.score = 5000000
	var after := won.reward(1.0)
	eq(int(after["base"]), int(rw["base"]), "devamda taban zafer anında donar")
	eq(int(after["extra"]), int(r_def["extra_cap"]), "devam ödülü sınırlı")
	check(int(after["total"]) <= int(r_def["cap"]) + int(r_def["extra_cap"]), "toplam üst sınır")
	gt(float(after["total"]), float(before) - 0.5, "devam ödülü azaltmaz")

func test_reward_mult_and_bank() -> void:
	var r := _mode_run("standard")
	r.score = 3000
	r.wave = 6
	r.bosses = 1
	var plain := r.reward_total(1.0)
	r.reward_mult = 1.4
	r.banked_cores = 30
	eq(r.reward_total(1.0), int(round(float(r.reward(1.0)["base"]) * 1.4)) + 30, "çarpan tabana, kasa sonradan")
	gt(float(r.reward_total(1.0)), float(plain), "risk ödülü artırır")

func test_debug_end_sector_opens_screens() -> void:
	var r := _mode_run("standard")
	check(r.debug_end_sector(1), "kapı açılır")
	eq(r.phase, RunStateScript.PHASE_GATE, "kapı aşaması")
	var v := _mode_run("standard")
	check(v.debug_end_sector(3), "zafer açılır")
	eq(v.phase, RunStateScript.PHASE_VICTORY, "zafer aşaması")
	check(not _mode_run("endless").debug_end_sector(1), "sonsuzda ekran yok")

func test_run_records_per_mode() -> void:
	var flags := {}
	eq(RunRecords.selected_mode(flags, ["standard", "endless"], "standard"), "standard", "varsayılan mod")
	RunRecords.select_mode(flags, "endless")
	eq(RunRecords.selected_mode(flags, ["standard", "endless"], "standard"), "endless", "seçim saklanır")
	flags["run_mode"] = "silinmis"
	eq(RunRecords.selected_mode(flags, ["standard", "endless"], "standard"), "standard", "bilinmeyen seçim → varsayılan")
	eq(RunRecords.next_mode("standard", ["standard", "quick", "endless"]), "quick", "döngüsel sıradaki")
	eq(RunRecords.next_mode("endless", ["standard", "quick", "endless"]), "standard", "başa döner")
	var a := RunRecords.record(flags, "standard", {"score": 5000, "wave": 9, "won": false, "time": 300.0})
	check(a["best"], "ilk puan rekordur")
	var b := RunRecords.record(flags, "standard", {"score": 4000, "wave": 15, "won": true, "time": 600.0})
	check(not b["best"], "düşük puan rekor değil")
	check(b["first_win"], "ilk zafer")
	var c := RunRecords.record(flags, "standard", {"score": 9000, "wave": 15, "won": true, "time": 540.0})
	check(c["fastest"] and not c["first_win"], "daha hızlı zafer")
	var rec := RunRecords.get_record(flags, "standard")
	eq(rec, {"best": 9000, "wave": 15, "runs": 3, "wins": 2, "fastest": 540}, "standart rekor")
	eq(RunRecords.get_record(flags, "endless")["runs"], 0, "modlar ayrı")
	for k in flags:
		check(str(k).length() <= 48, "bayrak anahtarı kayıt sınırında: " + str(k))
		check(typeof(flags[k]) in [TYPE_INT, TYPE_STRING], "bayrak değeri basit tür (Settings korur): " + str(k))

func test_run_data_valid_and_translated() -> void:
	var defs := _defs()
	var run: Dictionary = defs["run"]
	var en: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lang/en_c1.json"))
	check(en is Dictionary, "en_c1.json okunmalı")
	check((run["modes"] as Dictionary).has(str(run["default_mode"])), "varsayılan mod tanımlı")
	var known := Loadout._defaults()
	for id in run["modes"]:
		var m: Dictionary = run["modes"][id]
		check((en as Dictionary).has(str(m["name"])) and (en as Dictionary).has(str(m["desc"])), "mod adı/açıklaması çevrilmiş: " + str(id))
		var wps := int(m.get("waves_per_sector", 0))
		check(wps == 0 or wps >= 2, "sektör en az 2 dalga: " + str(id))
		check(float(m.get("wave_scale", 1.0)) > 0.0, "etkin dalga çarpanı pozitif: " + str(id))
		check((m["reward"] as Dictionary).has("per_wave") and (m["reward"] as Dictionary).has("cap"), "ödül eğrisi: " + str(id))
	var gates: Dictionary = run["gates"]["options"]
	for id in run["gates"]["always"]:
		check(gates.has(str(id)), "her zaman sunulan seçenek tanımlı: " + str(id))
		eq(int(gates[str(id)].get("risk", 0)), 0, "her zaman sunulan seçenek güvenli: " + str(id))
	for id in gates:
		var g: Dictionary = gates[id]
		check((en as Dictionary).has(str(g["name"])), "kapı adı çevrilmiş: " + str(id))
		check(not GateScreenScript.describe(g).is_empty(), "kapı açıklaması boş değil: " + str(id))
		for key in g.get("effect", {}):
			check(known.has(key), "kapı etkisi Loadout'ta bilinen anahtar: %s.%s" % [id, key])
		check(float(g.get("enemy_hp_mult", 1.0)) >= 1.0 and float(g.get("enemy_damage_mult", 1.0)) >= 1.0, "zor sektör çarpanı ≥ 1: " + str(id))
	var src := FileAccess.get_file_as_string("res://scripts/ui/screens/gate.gd")
	var re := RegEx.new()
	re.compile("translate\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	for m in re.search_all(src):
		check((en as Dictionary).has(m.get_string(1)), "kapı satırı çevrilmiş: " + m.get_string(1))
	for name in GateScreenScript.RISK_NAME:
		check((en as Dictionary).has(name), "risk adı çevrilmiş: " + name)
