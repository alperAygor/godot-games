extends TestCase

## Günlük bulmaca mantığı: tarihe göre belirlilik, çözülebilirlik, seri ve ödül kuralları.

const START_DATE: String = "2026-11-13"
const SPAN_DAYS: int = 30
const LEVELS: Array[int] = [1, 12, 40]
const SOLVE_BUDGET: int = 200000


func test_date_math_roundtrip() -> void:
	assert_eq(DailyDate.day_index("1970-01-01"), 0, "epoch")
	assert_eq(DailyDate.days_between("2026-02-28", "2026-03-01"), 1, "şubat sonu (artık değil)")
	assert_eq(DailyDate.days_between("2028-02-28", "2028-03-01"), 2, "artık yıl")
	assert_eq(DailyDate.days_between("2026-12-31", "2027-01-01"), 1, "yıl sonu")
	for offset: int in range(0, 800, 7):
		var key: String = DailyDate.add_days(START_DATE, offset)
		assert_eq(DailyDate.day_index(key) - DailyDate.day_index(START_DATE), offset, "gidiş-dönüş " + key)


func test_same_date_same_level() -> void:
	var a: Dictionary = DailyPuzzle.build_level(START_DATE, 12)
	var b: Dictionary = DailyPuzzle.build_level(START_DATE, 12)
	assert_eq(var_to_str(a), var_to_str(b), "aynı tarih+kova aynı seviye")
	assert_eq(DailyPuzzle.build_level(START_DATE, 12)["daily_date"], START_DATE, "tarih işareti")


func test_same_bucket_same_level() -> void:
	var a: Dictionary = DailyPuzzle.build_level(START_DATE, 11)
	var b: Dictionary = DailyPuzzle.build_level(START_DATE, 20)
	assert_eq(var_to_str(a), var_to_str(b), "aynı kovadaki oyuncular aynı bulmacayı görür")


func test_different_dates_differ() -> void:
	var seen: Dictionary = {}
	for offset: int in range(SPAN_DAYS):
		var key: String = DailyDate.add_days(START_DATE, offset)
		var level: Dictionary = DailyPuzzle.build_level(key, 12)
		level.erase("daily_date")
		seen[var_to_str(level)] = true
	assert_greater(seen.size(), SPAN_DAYS - 3, "günler birbirinden farklı olmalı")
	assert_true(DailyPuzzle.seed_for("2026-11-13") != DailyPuzzle.seed_for("2026-11-14"), "tohum günle değişir")


func test_solvable_for_30_consecutive_dates() -> void:
	for player_level: int in LEVELS:
		for offset: int in range(SPAN_DAYS):
			var key: String = DailyDate.add_days(START_DATE, offset)
			var level: Dictionary = DailyPuzzle.build_level(key, player_level)
			assert_true(LevelSolver.is_solvable(level, SOLVE_BUDGET),
				"çözülebilir: %s seviye %d" % [key, player_level])


func test_harder_than_current_level() -> void:
	# "Daha zor": taban seviye oyuncunun kovasının üstünde; ek sepet kaydırması da var.
	assert_greater(DailyPuzzle.base_level_for(1), 1, "yeni oyuncu için de bir üst seviye")
	assert_greater(DailyPuzzle.base_level_for(25), 25, "taban oyuncunun seviyesinden yüksek")
	assert_true(DailyPuzzle.base_level_for(1) <= 12, "yeni oyuncu ezilmez")
	assert_greater(DailyPuzzle.extra_twists_for(45), DailyPuzzle.extra_twists_for(1) - 1, "kovayla artar")


func test_streak_consecutive_missed_and_replay() -> void:
	var state: Dictionary = {}
	state = DailyPuzzle.state_after_win(state, "2026-11-13")
	assert_eq(int(state["streak"]), 1, "ilk kazanım")
	state = DailyPuzzle.state_after_win(state, "2026-11-14")
	assert_eq(int(state["streak"]), 2, "ertesi gün +1")
	var replay: Dictionary = DailyPuzzle.state_after_win(state, "2026-11-14")
	assert_eq(int(replay["streak"]), 2, "aynı gün tekrar seriyi artırmaz")
	assert_eq(DailyPuzzle.streak_after_win(state, "2026-11-14"), 2, "aynı gün değişmez")
	assert_eq(DailyPuzzle.display_streak(state, "2026-11-15"), 2, "dün kazanıldı: seri yaşıyor")
	assert_eq(DailyPuzzle.display_streak(state, "2026-11-16"), 0, "bir gün kaçtı: seri koptu")
	state = DailyPuzzle.state_after_win(state, "2026-11-17")
	assert_eq(int(state["streak"]), 1, "kaçırılan gün seriyi 1'e döndürür")
	assert_eq(int(state["best"]), 2, "en iyi seri korunur")


func test_availability() -> void:
	var state: Dictionary = {"last_won": START_DATE, "streak": 1, "best": 1}
	assert_false(DailyPuzzle.is_available(state, START_DATE, 50), "bugün kazanıldıysa yok")
	assert_true(DailyPuzzle.is_available(state, "2026-11-14", 50), "ertesi gün yeniden açık")
	assert_false(DailyPuzzle.is_available({}, START_DATE, 1), "açılış seviyesinden önce kapalı")


func test_reward_table() -> void:
	var first: Dictionary = DailyPuzzle.reward_for(1, 30)
	var third: Dictionary = DailyPuzzle.reward_for(3, 30)
	assert_greater(float(first["coins"]), 0.0, "jeton var")
	assert_eq(String(first["booster"]), "", "ilk gün güçlendirici yok")
	assert_greater(float(third["coins"]), float(first["coins"]) - 1.0, "seri arttıkça ödül artar")
	assert_eq(int(third["booster_count"]), 1, "3. seri günü güçlendirici")
	assert_eq(String(DailyPuzzle.reward_for(3, 4)["booster"]), "", "açılmamış güçlendirici verilmez")
	assert_eq(int(DailyPuzzle.reward_for(100, 30)["coins"]), int(DailyPuzzle.reward_for(50, 30)["coins"]),
		"seri bonusu tavanlı")


func test_take_pending_clears_handoff() -> void:
	DailyPuzzle.pending_level = {"level": 1}
	assert_eq(DailyPuzzle.take_pending().size(), 1, "devir alınır")
	assert_true(DailyPuzzle.pending_level.is_empty(), "devir temizlenir")
