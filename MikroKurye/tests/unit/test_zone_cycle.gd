extends TestCase

## ZoneCycle: level -> çevre bölgesi.


func test_first_five_levels_share_zone_zero() -> void:
	for level: int in range(1, 6):
		assert_eq(ZoneCycle.zone_for(level, 5), 0, "level %d" % level)


func test_zone_advances_every_five_levels() -> void:
	assert_eq(ZoneCycle.zone_for(6, 5), 1)
	assert_eq(ZoneCycle.zone_for(10, 5), 1)
	assert_eq(ZoneCycle.zone_for(11, 5), 2)
	assert_eq(ZoneCycle.zone_for(21, 5), 4)


func test_zones_wrap_around() -> void:
	assert_eq(ZoneCycle.zone_for(26, 5), 0)
	assert_eq(ZoneCycle.zone_for(31, 5), 1)
	assert_eq(ZoneCycle.zone_for(100, 2), 1)


func test_invalid_input_is_safe() -> void:
	assert_eq(ZoneCycle.zone_for(0, 5), 0)
	assert_eq(ZoneCycle.zone_for(-4, 5), 0)
	assert_eq(ZoneCycle.zone_for(12, 0), 0)


func test_zone_start_detection() -> void:
	assert_false(ZoneCycle.is_zone_start(1))
	assert_false(ZoneCycle.is_zone_start(5))
	assert_true(ZoneCycle.is_zone_start(6))
	assert_true(ZoneCycle.is_zone_start(11))
	assert_false(ZoneCycle.is_zone_start(12))
