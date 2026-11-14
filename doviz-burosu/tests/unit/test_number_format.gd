extends "res://tests/test_case.gd"
## NumberFormat.short: büyük sayıları kısaltma.


func test_small_numbers() -> void:
	assert_eq(NumberFormat.short(0), "0")
	assert_eq(NumberFormat.short(2.0), "2")
	assert_eq(NumberFormat.short(1.94), "1.9")
	assert_eq(NumberFormat.short(950.7), "950")


func test_suffixes() -> void:
	assert_eq(NumberFormat.short(1234), "1.23K")
	assert_eq(NumberFormat.short(45600), "45.6K")
	assert_eq(NumberFormat.short(999999), "999K")
	assert_eq(NumberFormat.short(5600000), "5.60M")
	assert_eq(NumberFormat.short(2.5e9), "2.50B")


func test_negative() -> void:
	assert_eq(NumberFormat.short(-1500), "-1.50K")
