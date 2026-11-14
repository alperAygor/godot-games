extends "res://tests/engine_case.gd"
## Günün Kuru ve Sonsuz çekirdeği: tarih tohumu, puan, deneme hakkı, kilitler, can ve kural ekleme.

const DATE := "2026-10-26"


func _signature(run: DailyChallenge) -> String:
	var parts: PackedStringArray = []
	for customer in run.shift.queue:
		parts.append("%s:%s:%d" % [customer.holder_name, customer.scenario, customer.notes.size()])
		for note in customer.notes:
			parts.append(note.serial)
	return "|".join(parts)


func _play(run: ModeRun, think := 8.0, profile := "perfect") -> void:
	var bot := ClerkBot.new(profile, "mode-test")
	bot.profile = bot.profile.duplicate()
	bot.profile["think_seconds"] = think
	var shift := run.career.new_shift()
	shift.start()
	var guard := 0
	while not shift.is_closed() and guard < 5000:
		guard += 1
		if shift.current == null:
			shift.advance(1.0)
			continue
		shift.advance(bot.think_seconds())
		var verdict := shift.current_verdict
		var customer := shift.current
		var result := shift.submit(bot.move_for(customer, verdict))
		run.on_submit(result)


# --- Günün Kuru ----------------------------------------------------------------------

func test_date_key_and_share_text() -> void:
	assert_eq(DailyChallenge.date_key(1793000000.0), "2026-10-26")
	assert_eq(DailyChallenge.short_date(DATE), "26.10")
	assert_eq(DailyChallenge.share_text(DATE, 1840, "tr"), "Günün Kuru 26.10 — 1840 puan 💱")
	assert_eq(DailyChallenge.share_text(DATE, 1840, "en"), "Daily Rate 26.10 — 1840 pts 💱")
	assert_eq(DailyChallenge.seed_text(DATE), "daily-2026-10-26")


func test_same_date_gives_the_same_customers_and_rates() -> void:
	var first := DailyChallenge.new(DATE)
	var second := DailyChallenge.new(DATE)
	assert_eq(first.shift.queue.size(), 12)
	assert_eq(_signature(first), _signature(second))
	assert_eq(first.shift.ctx.rates.rates("FED", 10), second.shift.ctx.rates.rates("FED", 10), "kurlar da aynı")
	assert_eq(first.shift.ctx.bulletin.wanted_faces, second.shift.ctx.bulletin.wanted_faces)


func test_different_dates_give_different_customers() -> void:
	var seen := {}
	for date in ["2026-10-26", "2026-10-27", "2026-10-28", "2026-11-01"]:
		seen[_signature(DailyChallenge.new(date))] = true
	assert_eq(seen.size(), 4)
	var rates := {}
	for date in ["2026-10-26", "2026-10-27", "2026-10-28"]:
		rates[str(DailyChallenge.new(date).shift.ctx.rates.rates("FED", 10))] = true
	assert_eq(rates.size(), 3, "kurlar da tarihe göre değişir")


func test_building_the_shift_twice_does_not_change_the_day() -> void:
	var run := DailyChallenge.new(DATE)
	var sig := _signature(run)
	run.career.new_shift()
	assert_eq(_signature(run), sig, "masa ekranı vardiyayı yeniden kursa bile aynı müşteriler")


func test_daily_uses_day_ten_rules_all_tools_and_no_story() -> void:
	var run := DailyChallenge.new(DATE)
	assert_eq(run.career.day, 10)
	assert_false(run.career.story_enabled)
	assert_true(run.career.has_tool("magnifier") and run.career.has_tool("uv"))
	assert_true(run.shift.ctx.rule_active("R_SOURCE"))
	assert_false(run.shift.ctx.rule_active("R_MIDDAY_RATE"), "11. günün kuralı yok")


func test_perfect_play_scores_full_marks_on_many_dates() -> void:
	for day in range(1, 13):
		var date := "2026-11-%02d" % day
		var run := DailyChallenge.new(date)
		_play(run)
		var stats := run.shift.stats
		assert_eq(stats["served"], 12, date)
		assert_eq(stats["mistake_transactions"], 0, "kusursuz oynanabilmeli: %s" % date)
		assert_eq(run.score_value(), 1200 + int(run.shift.seconds_left()) * 2, date)
		assert_true(run.shift.is_closed())


func test_score_formula_rewards_time_and_punishes_mistakes() -> void:
	var run := DailyChallenge.new(DATE)
	run.shift.start()
	run.shift.stats["correct"] = 9
	run.shift.stats["mistake_transactions"] = 2
	run.shift.elapsed = 150.0
	assert_eq(run.score_value(), 9 * 100 - 2 * 150 + 30 * 2)
	run.shift.stats["correct"] = 0
	run.shift.stats["mistake_transactions"] = 12
	assert_eq(run.score_value(), 0, "puan 0'ın altına inmez")


func test_a_careless_player_scores_less_than_a_perfect_one() -> void:
	var perfect := DailyChallenge.new(DATE)
	_play(perfect)
	var careless := DailyChallenge.new(DATE)
	_play(careless, 8.0, "careless")
	assert_true(careless.score_value() < perfect.score_value())


func test_time_running_out_ends_the_run_early() -> void:
	var run := DailyChallenge.new(DATE)
	_play(run, 60.0)  # çok yavaş: 180 sn'de ancak birkaç müşteri
	assert_true(int(run.shift.stats["served"]) < 12)
	assert_eq(int(run.shift.seconds_left()), 0)


# --- Kayıt ve deneme hakkı ---------------------------------------------------------------

func test_attempts_one_official_then_practice_then_bonus() -> void:
	var store := ModeStore.new({})
	assert_eq(store.official_attempts_left(DATE), 1)
	assert_true(store.start_daily_attempt(DATE), "ilk deneme resmi")
	assert_eq(store.official_attempts_left(DATE), 0)
	assert_false(store.start_daily_attempt(DATE), "sonrası puansız alıştırma")
	assert_eq(store.official_attempts_left("2026-10-27"), 1, "başka tarih bağımsız")
	store.grant_bonus_attempt(DATE)
	assert_eq(store.official_attempts_left(DATE), 1, "reklamla +1")
	assert_true(store.start_daily_attempt(DATE))
	assert_eq(store.official_attempts_left(DATE), 0)


func test_best_score_is_kept_per_date() -> void:
	var store := ModeStore.new({})
	assert_eq(store.best_daily(DATE), -1)
	assert_true(store.record_daily(DATE, 900))
	assert_false(store.record_daily(DATE, 700))
	assert_true(store.record_daily(DATE, 1300))
	assert_eq(store.best_daily(DATE), 1300)
	assert_eq(store.best_daily("2026-10-27"), -1)
	assert_false(store.data["daily"].has("2026-10-27"), "okuma kayıt oluşturmaz")


func test_old_dates_are_pruned() -> void:
	var store := ModeStore.new({})
	for i in 70:
		store.record_daily("2026-%02d-%02d" % [1 + i / 28, 1 + i % 28], 100)
	assert_true(store.data["daily"].size() <= 60)


func test_modes_unlock_after_the_story_days() -> void:
	var store := ModeStore.new({})
	assert_true(store.is_unlocked("daily"), "iki mod da baştan açık")
	assert_true(store.is_unlocked("endless"))
	var gated := ModeStore.new({}, {"daily": {"unlock_after_day": 5}})
	assert_false(gated.is_unlocked("daily"))
	gated.note_day_reached(5)
	assert_false(gated.is_unlocked("daily"), "5. gün sabahı: henüz geçilmedi")
	gated.note_day_reached(6)
	assert_true(gated.is_unlocked("daily"))
	gated.note_day_reached(3)
	assert_eq(gated.max_day(), 6, "en ileri gün geri gitmez")


func test_endless_records_best_and_runs() -> void:
	var store := ModeStore.new({})
	assert_true(store.record_endless(14))
	assert_false(store.record_endless(9))
	assert_eq(store.endless_best(), 14)
	assert_eq(store.data["endless"]["runs"], 2)


# --- Sonsuz ----------------------------------------------------------------------------------

func test_endless_starts_with_three_rules() -> void:
	var run := EndlessRun.new("t1")
	assert_eq(run.active_rules, ["R_EXCHANGE", "R_CATALOG", "R_UV"] as Array[String])
	assert_eq(run.lives, 3)
	assert_true(run.shift.ctx.rule_active("R_UV"))
	assert_false(run.shift.ctx.rule_active("R_ID_LIMIT"))


func test_endless_adds_a_rule_every_five_customers() -> void:
	var run := EndlessRun.new("t2")
	var shift := run.career.new_shift()
	shift.start()
	var bot := ClerkBot.new("perfect", "e")
	var added: Array[String] = []
	for i in 20:
		shift.advance(5.0)
		var outcome := run.on_submit(shift.submit(bot.move_for(shift.current, shift.current_verdict)))
		assert_false(outcome["life_lost"], "kusursuz oyuncu can kaybetmez (müşteri %d)" % (i + 1))
		if str(outcome["rule_added"]) != "":
			added.append(str(outcome["rule_added"]))
			assert_eq(run.served % 5, 0)
			assert_true(shift.ctx.rule_active(str(outcome["rule_added"])))
	assert_eq(added.size(), 4)
	assert_eq(run.active_rules.size(), 7)
	var unique := {}
	for rule_id in added:
		unique[rule_id] = true
	assert_eq(unique.size(), 4, "aynı kural iki kez eklenmez")


func test_endless_rule_order_is_deterministic_per_seed() -> void:
	var orders: Array = []
	var lives_left: Array = []
	for seed_key in ["same", "same", "other"]:
		var run := EndlessRun.new(seed_key)
		var shift := run.career.new_shift()
		shift.start()
		var bot := ClerkBot.new("perfect", "e")
		for i in 40:
			shift.advance(5.0)
			run.on_submit(shift.submit(bot.move_for(shift.current, shift.current_verdict)))
		orders.append(run.added_rules)
		lives_left.append(run.lives)
	assert_eq(lives_left, [3, 3, 3], "kusursuz oynayan 40 müşteride can kaybetmez (tüm kurallar açıkken de)")
	assert_eq(orders[0], orders[1])
	assert_ne(orders[0], orders[2])
	assert_eq(orders[0].size(), 8, "havuz 9 kural; 40 müşteride 8 ekleme")


func test_endless_loses_a_life_per_mistake_and_ends_at_zero() -> void:
	var run := EndlessRun.new("t3")
	var shift := run.career.new_shift()
	shift.start()
	var wrong := {"correct": false}
	assert_false(run.on_submit(wrong)["over"])
	assert_eq(run.lives, 2)
	run.on_submit({"correct": true})
	assert_eq(run.lives, 2, "doğru işlem can kaybettirmez")
	run.on_submit(wrong)
	var outcome := run.on_submit(wrong)
	assert_true(outcome["over"])
	assert_true(run.is_over() and run.finished)
	assert_true(shift.is_closed() and shift.current == null)
	assert_eq(run.score_value(), 4, "puan = hizmet verilen müşteri")


func test_endless_continue_gives_one_life_once() -> void:
	var run := EndlessRun.new("t4")
	var shift := run.career.new_shift()
	shift.start()
	assert_false(run.continue_with_life(), "can varken devam edilmez")
	for i in 3:
		run.on_submit({"correct": false})
	assert_true(run.continue_with_life())
	assert_eq(run.lives, 1)
	assert_false(shift.is_closed())
	run.on_submit({"correct": false})
	assert_false(run.continue_with_life(), "koşu başına bir kez")


func test_endless_stolen_and_wanted_rules_bring_a_bulletin() -> void:
	var run := EndlessRun.new("t5")
	assert_true(run.shift.ctx.bulletin.stolen_ranges.is_empty())
	run.active_rules.append("R_STOLEN")
	run._apply_rules()
	assert_false(run.ctx.bulletin.stolen_ranges.is_empty())
