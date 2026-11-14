extends "res://tests/test_case.gd"
## CurrencyBook ve data/currencies.json tutarlılığı.

var book: CurrencyBook


func before_each() -> void:
	book = CurrencyBook.load_default()


func test_all_six_currencies_with_local_pl() -> void:
	assert_eq(book.codes().size(), 6)
	assert_eq(book.local_code, "PL")
	for code in ["PL", "FED", "AVR", "STR", "DNR", "KRN"]:
		assert_true(book.has(code), code)
	assert_true(book.is_local("PL"))
	assert_false(book.is_local("FED"))


func test_unlock_days_match_plan() -> void:
	assert_eq(book.from_day("FED"), 1)
	assert_eq(book.from_day("AVR"), 2)
	assert_eq(book.from_day("STR"), 6)
	assert_eq(book.from_day("DNR"), 9)
	assert_eq(book.from_day("KRN"), 13)
	assert_eq(book.foreign_codes(1), ["FED"] as Array[String])
	assert_eq(book.foreign_codes(2), ["FED", "AVR"] as Array[String])
	assert_eq(book.foreign_codes(15).size(), 5)
	assert_eq(book.foreign_codes().size(), 5)


func test_denominations_follow_plan_and_are_ascending() -> void:
	assert_eq(book.denominations("PL"), [5, 10, 20, 50, 100, 200] as Array[int])
	assert_eq(book.denominations("FED"), [1, 5, 10, 20, 50, 100] as Array[int])
	assert_eq(book.denominations("KRN"), [50, 100, 200, 500] as Array[int])
	for code in book.codes():
		var denoms := book.denominations(code)
		for i in range(1, denoms.size()):
			assert_true(denoms[i] > denoms[i - 1], "%s kupürleri artan olmalı" % code)


func test_each_currency_data_is_complete() -> void:
	for code in book.codes():
		var denoms := book.denominations(code)
		for denom in denoms:
			var spec := book.spec(code, denom)
			assert_true(str(spec["color"]).begins_with("#") and str(spec["color"]).length() == 7, "%s %d renk" % [code, denom])
			assert_true(spec["size_mm"].x > spec["size_mm"].y, "%s %d genişlik > yükseklik" % [code, denom])
			assert_false(str(spec["microtext"]).is_empty())
			assert_true(str(spec["watermark_shape"]) in book.watermark_shapes, "%s filigran şekli listede" % code)
		assert_false(book.series_ids(code).is_empty(), "%s en az bir seri" % code)
		assert_true(book.base_rate(code) > 0)
		assert_true(book.serial_digits(code) > 0)


func test_colors_and_portraits_unique_within_currency() -> void:
	for code in book.codes():
		var colors := {}
		var portraits := {}
		for denom in book.denominations(code):
			colors[book.spec(code, denom)["color"]] = true
			portraits[book.portrait_id(code, denom)] = true
		assert_eq(colors.size(), book.denominations(code).size(), "%s: kupür renkleri benzersiz" % code)
		assert_eq(portraits.size(), book.denominations(code).size(), "%s: portreler benzersiz" % code)


func test_sizes_grow_with_denomination() -> void:
	for code in book.codes():
		var denoms := book.denominations(code)
		var previous := book.size_mm(code, denoms[0])
		for i in range(1, denoms.size()):
			var current := book.size_mm(code, denoms[i])
			assert_true(current.x > previous.x, "%s: genişlik büyür" % code)
			previous = current


func test_series_validity_days() -> void:
	# AVR: eski seri 2..5, yeni seri 4'ten itibaren; 6. günde eski seri geçersiz.
	assert_false(book.series_valid_on("AVR", "AV1", 1))
	assert_true(book.series_valid_on("AVR", "AV1", 2))
	assert_true(book.series_valid_on("AVR", "AV1", 5))
	assert_false(book.series_valid_on("AVR", "AV1", 6))
	assert_false(book.series_valid_on("AVR", "AV2", 3))
	assert_true(book.series_valid_on("AVR", "AV2", 4))
	assert_true(book.series_valid_on("AVR", "AV2", 99))
	assert_eq(book.valid_series("AVR", 5), ["AV1", "AV2"] as Array[String])
	assert_eq(book.valid_series("AVR", 6), ["AV2"] as Array[String])
	assert_eq(book.valid_series("STR", 5), [] as Array[String])
	assert_false(book.series_valid_on("AVR", "YOK", 5))


func test_serial_format() -> void:
	var serial := book.make_serial("FED", "FD1", 42)
	assert_eq(serial, "FA0000042")
	assert_true(book.is_serial_valid("FED", "FD1", serial))
	assert_false(book.is_serial_valid("FED", "FD1", "FB0000042"), "yanlış önek")
	assert_false(book.is_serial_valid("FED", "FD1", "FA000042"), "kısa")
	assert_false(book.is_serial_valid("FED", "FD1", "FA00000X2"), "rakam olmayan")
	assert_eq(book.make_serial("AVR", "AV2", 9999999), "AF9999999")


func test_value_minor() -> void:
	assert_eq(book.value_minor(5), 500)
	assert_eq(book.value_minor(200), 20000)


func test_names_exist_in_translations() -> void:
	var csv := FileAccess.get_file_as_string("res://assets/translations/strings.csv")
	for code in book.codes():
		assert_true(csv.contains("\n%s," % book.name_key(code)), "%s anahtarı CSV'de" % book.name_key(code))
		assert_true(csv.contains("\n%s," % book.country_key(code)), "%s anahtarı CSV'de" % book.country_key(code))


func test_series_validity_ranges() -> void:
	assert_eq(book.series_valid_from("AVR", "AV1"), 2)
	assert_eq(book.series_valid_until("AVR", "AV1"), 5)
	assert_eq(book.series_valid_from("AVR", "AV2"), 4)
	assert_eq(book.series_valid_until("AVR", "AV2"), -1, "süresiz seri -1")
	assert_eq(book.series_valid_until("FED", "FD1"), -1)
	assert_eq(book.series_valid_from("YOK" if false else "FED", "FD1"), 1)
