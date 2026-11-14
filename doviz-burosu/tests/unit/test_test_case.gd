extends "res://tests/test_case.gd"
## Test altyapısının kendisini doğrular: başarısız assert'ler gerçekten kaydediliyor mu?

const TestCase := preload("res://tests/test_case.gd")


func test_failed_assert_is_recorded() -> void:
	var inner := TestCase.new()
	inner.assert_eq(1, 2)
	inner.assert_true(false)
	assert_eq(inner._failures.size(), 2, "iki başarısızlık kaydedilmeli")


func test_int_and_float_compare_equal() -> void:
	var inner := TestCase.new()
	inner.assert_eq(10, 10.0)
	assert_eq(inner._failures.size(), 0)


func test_different_types_are_not_equal() -> void:
	var inner := TestCase.new()
	inner.assert_eq("10", 10)
	assert_eq(inner._failures.size(), 1)
