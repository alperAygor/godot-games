extends "res://tests/engine_case.gd"
## Newspaper: sabah gazetesinin içeriği.

var career: Career


func before_each() -> void:
	super.before_each()
	career = Career.load_default("news-test")


func _paper(day: int) -> Dictionary:
	career.day = day
	return Newspaper.build(career)


func test_every_story_day_has_a_headline_and_body_in_the_translations() -> void:
	var csv := FileAccess.get_file_as_string("res://assets/translations/strings.csv")
	for day in range(1, 16):
		var paper := _paper(day)
		assert_true(csv.contains("\n%s," % paper["head_key"]), paper["head_key"])
		assert_true(csv.contains("\n%s," % paper["body_key"]), paper["body_key"])
	assert_eq(_paper(40)["head_key"], "NEWS_15_HEAD", "15. günden sonrası son manşeti kullanır")


func test_rates_follow_the_open_currencies() -> void:
	var codes := func(day: int) -> Array:
		return _paper(day)["rates"].map(func(r: Dictionary) -> String: return r["code"])
	assert_eq(codes.call(1), ["FED"])
	assert_eq(codes.call(2), ["FED", "AVR"])
	assert_eq(codes.call(15).size(), 5)


func test_rates_match_what_the_shift_will_use() -> void:
	career.day = 3
	var paper := Newspaper.build(career)
	var ctx := career.new_shift().ctx
	for entry in paper["rates"]:
		var today := ctx.rates.rates(entry["code"], 3)
		assert_eq(entry["buy"], today["buy"])
		assert_eq(entry["sell"], today["sell"])
		assert_true(entry["buy"] < entry["sell"])
	assert_eq(_paper(1)["rates"][0]["change_bp"], 0, "ilk gün değişim yok")
	assert_true(_paper(5)["rates"][0]["change_bp"] > 0, "enflasyon: kur yükseldi")


func test_new_rule_box_shows_only_todays_rules() -> void:
	assert_eq(_paper(1)["new_rules"], ["R_EXCHANGE"] as Array[String])
	assert_eq(_paper(2)["new_rules"], ["R_CATALOG"] as Array[String])
	assert_eq(_paper(7)["new_rules"], ["R_STOLEN"] as Array[String])
	assert_eq(_paper(14)["new_rules"], [] as Array[String], "14. günde yeni kural yok")
	assert_eq(_paper(15)["new_rules"], [] as Array[String])


func test_new_tools_are_announced_on_the_day_they_are_given() -> void:
	assert_eq(_paper(2)["new_tools"], [] as Array[String])
	assert_eq(_paper(3)["new_tools"], ["uv"] as Array[String])
	assert_eq(_paper(4)["new_tools"], [] as Array[String])


func test_bulletin_matches_the_shifts_bulletin() -> void:
	assert_true(_paper(6)["stolen"].is_empty(), "çalıntı listesi 7. günde başlar")
	assert_true(_paper(11)["wanted_faces"].is_empty(), "aranan listesi 12. günde başlar")
	career.day = 9
	var paper := Newspaper.build(career)
	var ctx := career.new_shift().ctx
	assert_eq(paper["stolen"].size(), ctx.bulletin.stolen_ranges.size())
	for i in paper["stolen"].size():
		var range_def := ctx.bulletin.stolen_ranges[i]
		assert_eq(paper["stolen"][i]["from_serial"], ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["from"])))
		assert_true(str(paper["stolen"][i]["from_serial"]) < str(paper["stolen"][i]["to_serial"]))
	career.day = 12
	assert_eq(Newspaper.build(career)["wanted_faces"], career.new_shift().ctx.bulletin.wanted_faces)


func test_family_line_follows_the_mood() -> void:
	assert_eq(Newspaper.family_key(100), "NEWS_FAMILY_GOOD")
	assert_eq(Newspaper.family_key(80), "NEWS_FAMILY_GOOD")
	assert_eq(Newspaper.family_key(79), "NEWS_FAMILY_WORRIED")
	assert_eq(Newspaper.family_key(50), "NEWS_FAMILY_WORRIED")
	assert_eq(Newspaper.family_key(49), "NEWS_FAMILY_BAD")
	career.household.mood = 40
	assert_eq(_paper(2)["family_key"], "NEWS_FAMILY_BAD")


func test_rent_day_and_last_unpaid_expenses() -> void:
	assert_eq(_paper(4)["rent_today_minor"], 0)
	assert_eq(_paper(5)["rent_today_minor"], career.household.amount_minor("rent", 5))
	assert_eq(_paper(1)["last_unpaid"], [] as Array[String])
	career.household.cash_minor = Money.units(5000)
	career.day = 3
	var shift := career.new_shift()
	shift.start()
	shift.advance(400.0)
	career.finish_day(shift, ["food"])  # ısınma ödenmedi
	assert_eq(Newspaper.build(career)["last_unpaid"], ["heating"] as Array[String])
	assert_eq(Newspaper.build(career)["cash_minor"], career.household.cash_minor)
