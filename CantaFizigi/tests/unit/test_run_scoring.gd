extends TestCase

## RunScoring: hasar -> yildiz/odul. Esikler PROJECT_SPEC.md §2'den; testle sabit.

const BASE_FEE: int = 120


func test_perfect_run_gets_three_stars_and_bonus() -> void:
	var result: Dictionary = RunScoring.compute(0.0, BASE_FEE)
	assert_eq(int(result["stars"]), 3)
	assert_almost_eq(float(result["multiplier"]), 1.2, 0.0001)
	assert_eq(int(result["fee"]), 144)
	assert_eq(int(result["reputation"]), 0)


func test_two_star_band_pays_full_fee() -> void:
	var result: Dictionary = RunScoring.compute(0.25, BASE_FEE)
	assert_eq(int(result["stars"]), 2)
	assert_eq(int(result["fee"]), 120)


func test_one_star_band_pays_sixty_percent() -> void:
	var result: Dictionary = RunScoring.compute(0.6, BASE_FEE)
	assert_eq(int(result["stars"]), 1)
	assert_eq(int(result["fee"]), 72)


func test_zero_star_band_pays_twenty_percent() -> void:
	var result: Dictionary = RunScoring.compute(0.61, BASE_FEE)
	assert_eq(int(result["stars"]), 0)
	assert_eq(int(result["fee"]), 24)
	assert_eq(int(result["reputation"]), -1)


func test_fully_broken_pays_nothing() -> void:
	var result: Dictionary = RunScoring.compute(1.0, BASE_FEE)
	assert_eq(int(result["stars"]), 0)
	assert_eq(int(result["fee"]), 0)
	assert_eq(int(result["reputation"]), -2)


func test_damage_is_clamped_to_unit_range() -> void:
	assert_eq(int(RunScoring.compute(-1.0, BASE_FEE)["stars"]), 3)
	assert_eq(int(RunScoring.compute(5.0, BASE_FEE)["fee"]), 0)


func test_band_boundaries() -> void:
	assert_eq(int(RunScoring.compute(0.26, BASE_FEE)["stars"]), 1)
	assert_almost_eq(float(RunScoring.compute(0.99, BASE_FEE)["multiplier"]), 0.2, 0.0001)
