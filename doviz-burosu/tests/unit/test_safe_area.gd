extends "res://tests/test_case.gd"
## Güvenli alan hesabı (saf mantık).


func test_notch_and_home_bar_become_margins() -> void:
	# 1080x2400 ekran, üstte 120 px çentik, altta 90 px gezinme çubuğu, viewport/piksel = 0.5
	var m := SafeAreaMath.margins(Vector2(1080, 2400), Rect2(0, 120, 1080, 2190), 0.5)
	assert_almost_eq(m.x, 0.0, 0.001, "sol")
	assert_almost_eq(m.y, 60.0, 0.001, "üst")
	assert_almost_eq(m.z, 0.0, 0.001, "sağ")
	assert_almost_eq(m.w, 45.0, 0.001, "alt")


func test_landscape_side_cutout() -> void:
	var m := SafeAreaMath.margins(Vector2(2400, 1080), Rect2(100, 0, 2300, 1080), 1.0)
	assert_almost_eq(m.x, 100.0)
	assert_almost_eq(m.z, 0.0)


func test_empty_inputs_give_zero() -> void:
	assert_eq(SafeAreaMath.margins(Vector2.ZERO, Rect2(), 1.0), Vector4.ZERO)


func test_parse_simulated_argument() -> void:
	var m: Variant = SafeAreaMath.parse_simulated(PackedStringArray(["--x", "--simulate-safe-area=88,4,68,2"]))
	assert_eq(m, Vector4(2, 88, 4, 68))
	assert_eq(SafeAreaMath.parse_simulated(PackedStringArray(["--simulate-safe-area=1,2"])), null)
	assert_eq(SafeAreaMath.parse_simulated(PackedStringArray()), null)
