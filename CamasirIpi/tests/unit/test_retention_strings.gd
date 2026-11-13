extends TestCase

## Tutundurma metinleri: her görev/tema/bildirim anahtarı üç dilde çevrili ve biçimli çıkıyor.


func after_each() -> void:
	Loc.set_language(Loc.LANG_TR)


func test_all_languages_render_without_raw_keys() -> void:
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		for def: Variant in RetentionData.missions()["pool"] as Array:
			for target: int in [1, 3, 8]:
				var text: String = RetentionStrings.mission_text(def as Dictionary, target)
				assert_false(text.begins_with("RET_") or text.is_empty(), "%s/%s/%d" % [lang, String((def as Dictionary)["id"]), target])
		for theme: Variant in RetentionData.weekly()["themes"] as Array:
			var id: String = String((theme as Dictionary)["id"])
			assert_false(RetentionStrings.theme_title(id).begins_with("RET_"), "%s başlık %s" % [lang, id])
			assert_false(RetentionStrings.theme_goal(id).begins_with("RET_"), "%s hedef %s" % [lang, id])
		for key: String in ["RET_N_GIFT_T", "RET_N_GIFT_B", "RET_N_MISS_T", "RET_N_MISS_B", "RET_N_WEEK_T", "RET_N_WEEK_B"]:
			assert_false(Loc.t(key) == key, "%s %s" % [lang, key])
		assert_false(RetentionStrings.to_go(1).begins_with("RET_"), "%s tekil kaldı" % lang)
		assert_false(RetentionStrings.to_go(4).begins_with("RET_"), "%s çoğul kaldı" % lang)


func test_singular_wording_differs_in_english() -> void:
	Loc.set_language(Loc.LANG_EN)
	var def: Dictionary = Missions.definition(RetentionData.missions(), "booster")
	assert_eq(RetentionStrings.mission_text(def, 1), "Use a booster", "tekil")
	assert_eq(RetentionStrings.mission_text(def, 2), "Use 2 boosters", "çoğul")
