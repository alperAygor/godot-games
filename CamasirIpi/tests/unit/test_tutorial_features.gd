extends TestCase

## Öğretici özellik tespiti: seviye sözlüğünden hangi tanıtım kartlarının gerektiği.

func _level(number: int, items: Array[Dictionary]) -> Dictionary:
	return {"level": number, "items": items}


func test_plain_level_has_no_features() -> void:
	var level: Dictionary = _level(1, [{"id": 0, "color": 0, "blockers": []}])
	assert_eq(TutorialFeatures.detect(level).size(), 0, "düz seviyede özellik yok")


func test_detects_existing_obstacles() -> void:
	var level: Dictionary = _level(4, [
		{"id": 0, "wet": true}, {"id": 1, "mystery": true}, {"id": 2, "lock": 0}])
	var found: Array[String] = TutorialFeatures.detect(level)
	assert_eq(found, ["wet", "mystery", "lock"] as Array[String], "ıslak, gizemli, kilit sırayla")


func test_false_flags_do_not_count() -> void:
	var level: Dictionary = _level(4, [{"id": 0, "wet": false, "mystery": false}])
	assert_eq(TutorialFeatures.detect(level).size(), 0, "false alan sayılmaz")


func test_detects_features_from_other_branch_generically() -> void:
	var level: Dictionary = _level(30, [
		{"id": 0, "sheet": true}, {"id": 1, "pair": 0}, {"id": 2, "dye": true}])
	var found: Array[String] = TutorialFeatures.detect(level)
	assert_true(found.has("sheet"), "çarşaf")
	assert_true(found.has("sock_pair"), "çift kimliği 0 olsa da çorap çifti")
	assert_true(found.has("dye"), "boya")


func test_boosters_follow_unlock_levels() -> void:
	var items: Array[Dictionary] = []
	assert_false(TutorialFeatures.detect(_level(5, items)).has("undo"), "5'te geri al yok")
	assert_true(TutorialFeatures.detect(_level(6, items)).has("undo"), "6'da geri al")
	assert_true(TutorialFeatures.detect(_level(12, items)).has("pin_remover"), "12'de mandal çıkarıcı")
	assert_true(TutorialFeatures.detect(_level(18, items)).has("extra_slot"), "18'de +1 askı")


func test_custom_table_and_unknown_cards() -> void:
	var table: Dictionary = {"card_order": ["x", "missing"], "cards": {"x": {"item_key": "glow"}}}
	var level: Dictionary = _level(1, [{"id": 0, "glow": 1}])
	assert_eq(TutorialFeatures.detect(level, table), ["x"] as Array[String], "tabloda olmayan kart yok sayılır")


func test_generated_levels_introduce_obstacles_at_their_levels() -> void:
	assert_true(TutorialFeatures.detect(LevelGenerator.generate(8)).has("wet"), "8: ıslak")
	assert_true(TutorialFeatures.detect(LevelGenerator.generate(14)).has("mystery"), "14: gizemli")
	assert_true(TutorialFeatures.detect(LevelGenerator.generate(20)).has("lock"), "20: kilit")
	assert_false(TutorialFeatures.detect(LevelGenerator.generate(3)).has("wet"), "3: ıslak yok")


func test_every_card_has_text() -> void:
	for feature: Variant in TutorialFeatures.table().get("card_order", []) as Array:
		assert_false(TutorialStrings.card_line(String(feature)).is_empty(), "%s için metin" % feature)
