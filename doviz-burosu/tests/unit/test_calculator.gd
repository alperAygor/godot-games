extends "res://tests/test_case.gd"
## Calculator: masadaki dört işlem makinesi.


func _keys(calc: Calculator, keys: String) -> Calculator:
	for key in keys:
		calc.press(key)
	return calc


func test_basic_operations() -> void:
	assert_eq(_keys(Calculator.new(), "12+30=").display, "42")
	assert_eq(_keys(Calculator.new(), "100-25=").display, "75")
	assert_eq(_keys(Calculator.new(), "7*6=").display, "42")
	assert_eq(_keys(Calculator.new(), "84/4=").display, "21")


func test_decimals_and_formatting() -> void:
	assert_eq(_keys(Calculator.new(), "29.7*100=").display, "2970")
	assert_eq(_keys(Calculator.new(), "1/4=").display, "0.25")
	assert_eq(_keys(Calculator.new(), "10/3=").display, "3.333333")
	assert_eq(_keys(Calculator.new(), ".5+.5=").display, "1")
	assert_eq(_keys(Calculator.new(), "1.2.3").display, "1.23", "ikinci nokta yok sayılır")


func test_chaining_and_continuing_after_equals() -> void:
	assert_eq(_keys(Calculator.new(), "2+3*4=").display, "20", "soldan sağa anında işlem")
	var calc := _keys(Calculator.new(), "5+5=")
	calc.press("*")
	calc.press("3")
	calc.press("=")
	assert_eq(calc.display, "30", "sonuçla devam edilir")
	_keys(calc, "9")
	assert_eq(calc.display, "9", "= sonrası rakam yeni sayı başlatır")


func test_clear_backspace_and_leading_zero() -> void:
	var calc := _keys(Calculator.new(), "123<")
	assert_eq(calc.display, "12")
	_keys(calc, "<<<")
	assert_eq(calc.display, "0")
	assert_eq(_keys(Calculator.new(), "007").display, "7")
	var cleared := _keys(Calculator.new(), "99+1C")
	assert_eq(cleared.display, "0")
	assert_eq(_keys(cleared, "2+2=").display, "4")


func test_division_by_zero_shows_error_and_recovers() -> void:
	var calc := _keys(Calculator.new(), "5/0=")
	assert_eq(calc.display, Calculator.ERROR_TEXT)
	calc.press("4")
	assert_eq(calc.display, "4", "hatadan sonra tuş yeni hesabı başlatır")


func test_unicode_operator_aliases_and_digit_limit() -> void:
	assert_eq(_keys(Calculator.new(), "6×7=").display, "42")
	assert_eq(_keys(Calculator.new(), "9÷3=").display, "3")
	assert_eq(_keys(Calculator.new(), "9−3=").display, "6")
	assert_eq(_keys(Calculator.new(), "12345678901234567").display.length(), Calculator.MAX_DIGITS)


func test_operator_without_input_keeps_the_last_value() -> void:
	var calc := _keys(Calculator.new(), "8+")
	calc.press("*")
	calc.press("2")
	calc.press("=")
	assert_eq(calc.display, "16", "art arda operatör sonuncusu geçerli")
