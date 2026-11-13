extends TestCase

## DayCycle: seviye -> gün aşaması eşlemesi ve palet verisi.


func test_level_one_is_dawn() -> void:
	assert_eq(DayCycle.phase_for(1), 0)
	assert_eq(DayCycle.phase_name(0), "dawn")


func test_invalid_levels_clamp_to_first_phase() -> void:
	assert_eq(DayCycle.phase_for(0), 0)
	assert_eq(DayCycle.phase_for(-5), 0)


func test_phase_wraps_after_full_cycle() -> void:
	var cycle_levels: int = DayCycle.PHASE_COUNT * DayCycle.LEVELS_PER_PHASE
	assert_eq(DayCycle.phase_for(1 + cycle_levels), 0)
	assert_eq(DayCycle.phase_for(1 + cycle_levels * 7), 0)
	assert_eq(DayCycle.phase_for(cycle_levels), DayCycle.PHASE_COUNT - 1)


func test_phase_is_monotonic_within_a_cycle() -> void:
	var previous: int = -1
	for level: int in range(1, DayCycle.PHASE_COUNT * DayCycle.LEVELS_PER_PHASE + 1):
		var phase: int = DayCycle.phase_for(level)
		assert_true(phase >= previous, "level %d geriye gitti" % level)
		previous = phase
	assert_eq(previous, DayCycle.PHASE_COUNT - 1)


func test_blend_is_in_unit_range() -> void:
	for level: int in range(1, 40):
		var blend: float = DayCycle.blend_for(level)
		assert_true(blend >= 0.0 and blend < 1.0)


func test_data_has_one_look_per_phase() -> void:
	var names: Dictionary = {}
	for phase: int in range(DayCycle.PHASE_COUNT):
		names[DayCycle.phase_name(phase)] = true
	assert_eq(names.size(), DayCycle.PHASE_COUNT, "her aşamanın ayrı adı olmalı")


func test_night_is_darker_than_noon_and_has_stars() -> void:
	var noon: DayLook = DayCycle.look_for_phase(2)
	var night: DayLook = DayCycle.look_for_phase(7)
	assert_true(night.sky_top.get_luminance() < noon.sky_top.get_luminance())
	assert_true(night.star_amount > 0.5 and noon.star_amount == 0.0)


func test_garment_tint_never_darkens_more_than_ten_percent() -> void:
	for phase: int in range(DayCycle.PHASE_COUNT):
		var tint: Color = DayCycle.look_for_phase(phase).garment_tint
		assert_true(minf(tint.r, minf(tint.g, tint.b)) >= 0.9, "aşama %d çamaşırı çok koyultuyor" % phase)


func test_ambience_switches_from_birds_to_crickets() -> void:
	assert_eq(DayCycle.ambience_for(2), "birds")
	assert_eq(DayCycle.ambience_for(8), "crickets")


func test_blend_writes_in_place() -> void:
	var mixed: DayLook = DayLook.new()
	mixed.blend(DayCycle.look_for_phase(2), DayCycle.look_for_phase(7), 1.0)
	assert_true(mixed.sky_top.is_equal_approx(DayCycle.look_for_phase(7).sky_top))
