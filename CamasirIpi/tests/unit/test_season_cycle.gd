extends TestCase

## Mevsim bantları: 1-30 yaz, 31-60 sonbahar, 61-90 kış, 91-120 ilkbahar, sonra döngü.


func test_bands() -> void:
	assert_eq(SeasonCycle.season_for(1), SeasonCycle.SUMMER)
	assert_eq(SeasonCycle.season_for(30), SeasonCycle.SUMMER)
	assert_eq(SeasonCycle.season_for(31), SeasonCycle.AUTUMN)
	assert_eq(SeasonCycle.season_for(60), SeasonCycle.AUTUMN)
	assert_eq(SeasonCycle.season_for(61), SeasonCycle.WINTER)
	assert_eq(SeasonCycle.season_for(91), SeasonCycle.SPRING)
	assert_eq(SeasonCycle.season_for(121), SeasonCycle.SUMMER, "120'den sonra döngü başa döner")


func test_first_level_of_season() -> void:
	assert_false(SeasonCycle.is_first_level_of_season(1), "oyun yazla başlar; duyuru yok")
	assert_true(SeasonCycle.is_first_level_of_season(31))
	assert_false(SeasonCycle.is_first_level_of_season(32))
	assert_true(SeasonCycle.is_first_level_of_season(121))


func test_bad_input_is_safe() -> void:
	assert_eq(SeasonCycle.season_for(0), SeasonCycle.SUMMER)
	assert_eq(SeasonCycle.season_for(-5), SeasonCycle.SUMMER)
	assert_eq(SeasonCycle.step_in_season(31), 0)
	assert_eq(SeasonCycle.step_in_season(60), 29)
