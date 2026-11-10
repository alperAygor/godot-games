extends TestCase

## LevelScoring: 3/2/1 yildiz esikleri + puan (sure bonusu, kisa devre ve tepe cezasi).

const PAR: float = 60.0


func test_three_stars_when_clean_and_in_par() -> void:
	assert_eq(LevelScoring.stars(30.0, PAR, 0, 0.2), 3)
	assert_eq(LevelScoring.stars(59.9, PAR, 0, 0.2), 3)


func test_three_stars_boundary_is_inclusive() -> void:
	assert_eq(LevelScoring.stars(PAR, PAR, 0, 0.0), 3)


func test_two_stars_just_over_par() -> void:
	assert_eq(LevelScoring.stars(60.01, PAR, 0, 0.2), 2)


func test_two_stars_with_short_circuits_in_par() -> void:
	assert_eq(LevelScoring.stars(40.0, PAR, 1, 0.2), 2)


func test_two_stars_boundary_factor_and_shorts() -> void:
	assert_eq(LevelScoring.stars(PAR * 1.6, PAR, 2, 0.2), 2)
	assert_eq(LevelScoring.stars(PAR * 1.6, PAR, 3, 0.2), 1, "3+ kisa devre 2 yildiz olamaz")


func test_one_star_when_far_over_par() -> void:
	assert_eq(LevelScoring.stars(PAR * 1.61, PAR, 0, 0.2), 1)


func test_negative_inputs_are_sanitized() -> void:
	var result: Dictionary = LevelScoring.compute(-5.0, PAR, -3, 2.0)
	assert_almost_eq(float(result["elapsed"]), 0.0, 0.0001)
	assert_eq(int(result["shorts"]), 0)
	assert_almost_eq(float(result["peak"]), 1.0, 0.0001, "tepe 0..1 kirpilir")
	assert_eq(int(result["stars"]), 3)


func test_score_base_and_time_bonus() -> void:
	var result: Dictionary = LevelScoring.compute(30.0, PAR, 0, 0.0)
	assert_eq(int(result["time_bonus"]), 300, "30 sn kaldi = 300 puan")
	assert_eq(int(result["score"]), 1300)


func test_score_penalizes_shorts_and_peak() -> void:
	var result: Dictionary = LevelScoring.compute(PAR, PAR, 2, 0.5)
	# 1000 + 0 - 2*50 - 0.5*200 = 800
	assert_eq(int(result["score"]), 800)
	assert_eq(int(result["stars"]), 2)


func test_score_never_negative() -> void:
	var result: Dictionary = LevelScoring.compute(1000.0, PAR, 30, 1.0)
	assert_eq(int(result["score"]), 0, "puan tabani 0")


func test_no_time_bonus_after_par() -> void:
	var result: Dictionary = LevelScoring.compute(PAR * 2.0, PAR, 0, 0.2)
	assert_eq(int(result["time_bonus"]), 0)
	assert_eq(int(result["score"]), 1000 - 40)


func test_compute_returns_expected_keys() -> void:
	var result: Dictionary = LevelScoring.compute(10.0, PAR, 1, 0.1)
	assert_true(result.has("stars"))
	assert_true(result.has("score"))
	assert_true(result.has("time_bonus"))
	assert_true(result.has("elapsed"))
	assert_true(result.has("shorts"))
	assert_true(result.has("peak"))
	assert_almost_eq(float(result["elapsed"]), 10.0, 0.0001)
	assert_eq(int(result["shorts"]), 1)
	assert_almost_eq(float(result["peak"]), 0.1, 0.0001)
