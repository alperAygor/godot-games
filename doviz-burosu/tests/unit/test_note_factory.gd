extends "res://tests/test_case.gd"
## Banknote ve NoteFactory: gerçek banknotta fark yok, sahtede tam istenen fark var, aynı tohum aynı sonuç.

var book: CurrencyBook


func before_each() -> void:
	book = CurrencyBook.load_default()


func _factory(key := "test") -> NoteFactory:
	return NoteFactory.new(book, Seed.rng(key), {})


func _channel_distance(a: String, b: String) -> int:
	var best := 0
	for i in 3:
		var ca := a.substr(1 + i * 2, 2).hex_to_int()
		var cb := b.substr(1 + i * 2, 2).hex_to_int()
		best = maxi(best, absi(ca - cb))
	return best


func test_genuine_notes_have_no_discrepancies() -> void:
	var factory := _factory("genuine")
	for code in book.codes():
		for denom in book.denominations(code):
			for series_id in book.series_ids(code):
				var note := factory.make_genuine(code, denom, 0, {"series_id": series_id})
				assert_true(note.is_genuine(), "%s %d" % [code, denom])
				assert_eq(note.discrepancies(book), [] as Array[String], "%s %d" % [code, denom])
				assert_true(book.is_serial_valid(code, series_id, note.serial), note.serial)
				assert_eq(note.value_minor(), denom * 100)


func test_random_genuine_notes_respect_day_and_series() -> void:
	var factory := _factory("days")
	for day in range(1, 16):
		for code in book.foreign_codes(day) + [book.local_code]:
			var note := factory.make_genuine(code, 0, day)
			assert_true(book.series_valid_on(code, note.series_id, day), "%s gün %d seri %s" % [code, day, note.series_id])
			assert_true(note.denom in book.denominations(code))
	# 6. günde AVR'nin eski serisi çıkmaz.
	for i in 40:
		assert_eq(factory.make_genuine("AVR", 0, 6).series_id, "AV2")


func test_currency_not_yet_available_returns_null() -> void:
	assert_eq(_factory().make_genuine("STR", 5, 3), null)
	assert_eq(_factory().make_genuine("KRN", 0, 12), null)


func test_every_fake_type_is_detected_exactly() -> void:
	var factory := _factory("fakes")
	for fake in Banknote.FAKE_TYPES:
		for code in book.codes():
			for denom in book.denominations(code):
				var note := factory.make(code, denom, 0, [fake])
				assert_false(note.is_genuine(), fake)
				assert_eq(note.fakes, [fake] as Array[String], "%s %s %d" % [fake, code, denom])
				assert_eq(note.discrepancies(book), [fake] as Array[String], "%s %s %d" % [fake, code, denom])


func test_multiple_fakes_all_detected() -> void:
	var factory := _factory("combo")
	var wanted := [Banknote.FAKE_MICROTEXT, Banknote.FAKE_COLOR, Banknote.FAKE_WM_SHAPE, Banknote.FAKE_SIZE]
	var note := factory.make("FED", 20, 5, wanted)
	var expected: Array[String] = [Banknote.FAKE_COLOR, Banknote.FAKE_SIZE, Banknote.FAKE_WM_SHAPE, Banknote.FAKE_MICROTEXT]
	assert_eq(note.fakes, expected)
	assert_eq(note.discrepancies(book), expected)


func test_conflicting_fakes_missing_wins() -> void:
	var factory := _factory("conflict")
	var uv := factory.make("PL", 10, 0, [Banknote.FAKE_UV_COLOR, Banknote.FAKE_UV_MISSING])
	assert_eq(uv.fakes, [Banknote.FAKE_UV_MISSING] as Array[String])
	assert_eq(uv.discrepancies(book), [Banknote.FAKE_UV_MISSING] as Array[String])
	var watermark := factory.make("PL", 10, 0, [Banknote.FAKE_WM_SHAPE, Banknote.FAKE_WM_MISSING, Banknote.FAKE_WM_MISSING])
	assert_eq(watermark.fakes, [Banknote.FAKE_WM_MISSING] as Array[String])


func test_fake_magnitudes_are_noticeable() -> void:
	var factory := _factory("magnitude")
	for i in 60:
		var color_note := factory.make("AVR", 20, 0, [Banknote.FAKE_COLOR, Banknote.FAKE_UV_COLOR])
		var spec := book.spec("AVR", 20)
		assert_true(_channel_distance(color_note.color, spec["color"]) >= 20, "renk farkı yeterli")
		assert_true(_channel_distance(color_note.uv_color, spec["uv_color"]) >= 20, "UV rengi farkı yeterli")
		var size_note := factory.make("AVR", 20, 0, [Banknote.FAKE_SIZE])
		var diff: Vector2i = size_note.size_mm - spec["size_mm"]
		assert_true(absi(diff.x) + absi(diff.y) >= 3 and absi(diff.x) + absi(diff.y) <= 6, "boyut farkı 3-6 mm: %s" % diff)
		assert_true(diff.x == 0 or diff.y == 0, "tek boyut değişir")


func test_portrait_and_watermark_fakes_use_valid_alternatives() -> void:
	var factory := _factory("alts")
	for i in 30:
		var note := factory.make("DNR", 5, 0, [Banknote.FAKE_PORTRAIT, Banknote.FAKE_WM_SHAPE])
		var other_portraits: Array[String] = []
		for denom in book.denominations("DNR"):
			if denom != 5:
				other_portraits.append(book.portrait_id("DNR", denom))
		assert_true(note.portrait in other_portraits)
		assert_true(note.watermark_shape in book.watermark_shapes)
		assert_ne(note.watermark_shape, "moon")


func test_microtext_typo_changes_one_letter() -> void:
	var factory := _factory("typo")
	var original := str(book.spec("PL", 5)["microtext"])
	for i in 50:
		var note := factory.make("PL", 5, 0, [Banknote.FAKE_MICROTEXT])
		assert_eq(note.microtext.length(), original.length())
		var changed := 0
		for j in original.length():
			if note.microtext[j] != original[j]:
				changed += 1
		assert_eq(changed, 1)
		assert_eq(note.microtext.count(" "), original.count(" "), "boşluklar korunur")


func test_same_seed_same_notes_and_different_seed_differs() -> void:
	var a := _factory("daily-2026-10-26")
	var b := _factory("daily-2026-10-26")
	var c := _factory("daily-2026-10-27")
	var any_difference := false
	for i in 25:
		var fake: Array = [Banknote.FAKE_COLOR] if i % 3 == 0 else []
		var note_a := a.make("FED", 0, 4, fake)
		var note_b := b.make("FED", 0, 4, fake)
		var note_c := c.make("FED", 0, 4, fake)
		assert_eq(note_a.to_dict(), note_b.to_dict())
		if note_a.to_dict() != note_c.to_dict():
			any_difference = true
	assert_true(any_difference)


func test_forced_old_series_and_serial_number() -> void:
	var factory := _factory("old")
	var note := factory.make_genuine("AVR", 10, 6, {"series_id": "AV1", "serial_number": 1234})
	assert_eq(note.series_id, "AV1")
	assert_eq(note.serial, "AE0001234")
	assert_false(book.series_valid_on("AVR", note.series_id, 6), "6. günde eski seri geçersiz")
	assert_true(note.is_genuine(), "eski seri fiziksel sahtecilik değildir")


func test_torn_and_taped_condition() -> void:
	var factory := _factory("condition")
	for i in 30:
		var torn := factory.make_genuine("PL", 20, 0, {"torn": true})
		assert_true(torn.remaining_percent >= 20 and torn.remaining_percent <= 45)
		assert_true(torn.is_unfit(50))
		assert_true(torn.is_genuine(), "yırtık banknot sahte değildir")
	var taped := factory.make_genuine("PL", 20, 0, {"taped": true})
	assert_true(taped.taped)
	assert_eq(taped.remaining_percent, 100)
	assert_false(taped.is_unfit(50))
	var half := factory.make_genuine("PL", 20, 0, {"remaining_percent": 50})
	assert_false(half.is_unfit(50), "tam yarısı kalan geçerli")
	assert_true(factory.make_genuine("PL", 20, 0, {"remaining_percent": 49}).is_unfit(50))


func test_dict_roundtrip() -> void:
	var factory := _factory("dict")
	var note := factory.make("STR", 20, 7, [Banknote.FAKE_UV_MISSING, Banknote.FAKE_SIZE], {"taped": true, "remaining_percent": 90})
	var copy := Banknote.from_dict(JSON.parse_string(JSON.stringify(note.to_dict())))
	assert_eq(copy.to_dict(), note.to_dict())
	assert_eq(copy.discrepancies(book), note.discrepancies(book))


func test_pick_fake_from_available_list() -> void:
	var factory := _factory("pick")
	assert_eq(factory.pick_fake([]), "")
	var seen := {}
	for i in 100:
		seen[factory.pick_fake([Banknote.FAKE_COLOR, Banknote.FAKE_SIZE])] = true
	assert_eq(seen.size(), 2)
