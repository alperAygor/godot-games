extends TestCase
## Dalga akışı, boss, harita geçişi, XP/seviye.

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _defs() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))

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
