extends "res://tests/test_case.gd"
## Money: tam sayı para hesabı ve yuvarlama.


func test_units() -> void:
	assert_eq(Money.units(5), 500)
	assert_eq(Money.units(0), 0)


func test_mul_div_floor_and_ceil() -> void:
	assert_eq(Money.mul_div_floor(10, 3, 4), 7)
	assert_eq(Money.mul_div_ceil(10, 3, 4), 8)
	assert_eq(Money.mul_div_floor(10, 4, 4), 10)
	assert_eq(Money.mul_div_ceil(10, 4, 4), 10)


func test_floor_to_and_ceil_to() -> void:
	assert_eq(Money.floor_to(1234, 500), 1000)
	assert_eq(Money.floor_to(1000, 500), 1000)
	assert_eq(Money.ceil_to(1001, 500), 1500)
	assert_eq(Money.ceil_to(1000, 500), 1000)
	assert_eq(Money.floor_to(1234, 1), 1234)
	assert_eq(Money.ceil_to(1234, 0), 1234)


func test_format_en() -> void:
	assert_eq(Money.format(0, "PL"), "0 PL")
	assert_eq(Money.format(500, "PL"), "5 PL")
	assert_eq(Money.format(125050, "PL"), "1,250.50 PL")
	assert_eq(Money.format(5, ""), "0.05")
	assert_eq(Money.format(123456789, "FED"), "1,234,567.89 FED")
	assert_eq(Money.format(-2500, "PL"), "-25 PL")


func test_format_tr() -> void:
	assert_eq(Money.format(125050, "PL", "tr"), "1.250,50 PL")
	assert_eq(Money.format(100000000, "", "tr"), "1.000.000")
