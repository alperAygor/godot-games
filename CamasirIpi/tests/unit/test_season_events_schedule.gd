extends TestCase

## Mevsim olaylarının takvimi ve ölçüsü: yalnız kendi mevsim bandında, tanıtımda tek başına, sonra
## ölçülü karışım; sayaç hapı en fazla iki, aynı parçada iki rozet yok; tanıtım kartları.

const LAST_LEVEL: int = 150
const INTRO_LEVEL_KEYS: Array[String] = ["jokers", "big", "wind", "slide", "washer", "dryer", "typed", "birds",
	"rain", "cat", "leaves", "pollen", "mode"]
const INTRO_ITEM_KEYS: Array[String] = ["wet", "mystery", "lock", "sheet", "sock", "dye", "stain", "chain",
	"dirty", "twin", "sun", "frost"]
## Görünümde rozet taşıyan parça anahtarları: bir parçada en fazla biri.
const BADGE_ITEM_KEYS: Array[String] = ["lock", "sock", "dye", "stain", "chain", "sun", "frost", "twin", "mystery"]


func _count(level: Dictionary, key: String) -> int:
	var total: int = 0
	for entry: Variant in level["items"] as Array:
		var value: Variant = (entry as Dictionary).get(key, null)
		if value is bool:
			total += 1 if bool(value) else 0
		elif value != null:
			total += 1
	return total


func _has(level: Dictionary, mechanic: String) -> bool:
	match mechanic:
		"sun", "frost":
			return _count(level, mechanic) > 0
		_:
			return level.has(mechanic)


func test_seasonal_mechanics_only_in_their_band() -> void:
	for number: int in range(1, LAST_LEVEL + 1):
		var level: Dictionary = LevelCache.level(number)
		var season: String = SeasonCycle.season_for(number)
		for mechanic: String in ["sun", "leaves", "frost", "pollen"]:
			if _has(level, mechanic):
				assert_eq(LevelGenerator.season_mechanic(number), mechanic,
					"seviye %d (%s): %s yalnız kendi mevsiminde" % [number, season, mechanic])


func test_intro_levels_are_first_and_alone() -> void:
	var intros: Dictionary = {
		"sun": LevelGenerator.SUN_FROM_LEVEL, "leaves": LevelGenerator.LEAVES_FROM_LEVEL,
		"frost": LevelGenerator.FROST_FROM_LEVEL, "pollen": LevelGenerator.POLLEN_FROM_LEVEL,
	}
	assert_eq(SeasonCycle.season_for(LevelGenerator.SUN_FROM_LEVEL), SeasonCycle.SUMMER)
	assert_eq(SeasonCycle.season_for(LevelGenerator.LEAVES_FROM_LEVEL), SeasonCycle.AUTUMN)
	assert_eq(SeasonCycle.season_for(LevelGenerator.FROST_FROM_LEVEL), SeasonCycle.WINTER)
	assert_eq(SeasonCycle.season_for(LevelGenerator.POLLEN_FROM_LEVEL), SeasonCycle.SPRING)
	for mechanic: String in intros.keys():
		var number: int = int(intros[mechanic])
		for before: int in range(1, number):
			assert_false(_has(LevelCache.level(before), mechanic), "%s %d'den önce yok (seviye %d)" % [mechanic, number, before])
		var level: Dictionary = LevelCache.level(number)
		assert_true(_has(level, mechanic), "%s tanıtımda var (seviye %d)" % [mechanic, number])
		for key: String in INTRO_LEVEL_KEYS:
			if key != mechanic:
				assert_false(level.has(key), "seviye %d yalnız %s öğretir (%s var)" % [number, mechanic, key])
		for key: String in INTRO_ITEM_KEYS:
			if key != mechanic:
				assert_eq(_count(level, key), 0, "seviye %d'de %s yok" % [number, key])
		assert_false(bool(level["hard"]), "tanıtım seviyesi zor değil")
	assert_eq(_count(LevelCache.level(LevelGenerator.SUN_FROM_LEVEL), "sun"), 1)
	assert_eq(_count(LevelCache.level(LevelGenerator.FROST_FROM_LEVEL), "frost"), 1)
	var dual: Dictionary = LevelCache.level(LevelGenerator.DUAL_FROM_LEVEL)
	assert_eq(_count(dual, "twin"), 2, "çift renk tanıtımı tek çift")
	for key: String in INTRO_ITEM_KEYS:
		if key != "twin":
			assert_eq(_count(dual, key), 0, "seviye 18 yalnız çift renk öğretir (%s var)" % key)


func test_mixed_in_with_mild_ramp() -> void:
	var seen: Dictionary = {}
	for number: int in range(1, LAST_LEVEL + 1):
		var level: Dictionary = LevelCache.level(number)
		for mechanic: String in ["sun", "leaves", "frost", "pollen"]:
			if _has(level, mechanic):
				seen[mechanic] = int(seen.get(mechanic, 0)) + 1
		assert_true(_count(level, "sun") <= int(LevelGenerator.SEASON_MAX["sun"]))
		assert_true(_count(level, "frost") <= int(LevelGenerator.SEASON_MAX["frost"]))
	for mechanic: String in ["sun", "leaves", "frost", "pollen"]:
		assert_greater(float(seen.get(mechanic, 0)), 4.0, "%s mevsiminde karışır (%d)" % [mechanic, int(seen.get(mechanic, 0))])
		assert_true(int(seen.get(mechanic, 0)) < 45, "%s her seviyede değil" % mechanic)


func test_at_most_two_countdown_pills() -> void:
	for number: int in range(1, LAST_LEVEL + 1):
		var level: Dictionary = LevelCache.level(number)
		var timed: int = 0
		for key: String in LevelGenerator.TIMED_LEVEL_KEYS:
			if level.has(key):
				timed += 1
		assert_true(timed <= LevelGenerator.MAX_TIMED_MECHANICS, "seviye %d en fazla iki sayaç hapı (%d)" % [number, timed])


func test_seasonal_badges_never_stack() -> void:
	for number: int in range(LevelGenerator.DUAL_FROM_LEVEL, LAST_LEVEL + 1):
		var level: Dictionary = LevelCache.level(number)
		var guests: Dictionary = {}
		for target: Variant in (level.get("leaves", {}) as Dictionary).get("targets", []) as Array:
			guests[int(target)] = true
		for entry: Variant in level["items"] as Array:
			var item: Dictionary = entry as Dictionary
			var badges: int = 0
			for key: String in BADGE_ITEM_KEYS:
				if item.has(key) and not (item[key] is bool and not bool(item[key])):
					badges += 1
			var seasonal: bool = item.has("sun") or item.has("frost") or item.has("twin") or guests.has(int(item["id"]))
			if seasonal:
				assert_true(badges <= 1, "seviye %d parça %d: tek rozet" % [number, int(item["id"])])


func test_season_counts_are_deterministic() -> void:
	for number: int in [22, 27, 40, 70, 100, 125, 140]:
		var name: String = LevelGenerator.season_mechanic(number)
		assert_eq(LevelGenerator.season_count(number, name), LevelGenerator.season_count(number, name))


func test_tutorial_cards_for_new_features() -> void:
	var cards: Dictionary = {"dual": LevelGenerator.DUAL_FROM_LEVEL, "sun_fade": LevelGenerator.SUN_FROM_LEVEL,
		"leaves": LevelGenerator.LEAVES_FROM_LEVEL, "frost": LevelGenerator.FROST_FROM_LEVEL,
		"pollen": LevelGenerator.POLLEN_FROM_LEVEL}
	for feature: String in cards.keys():
		var found: Array[String] = TutorialFeatures.detect(LevelCache.level(int(cards[feature])))
		assert_true(found.has(feature), "%s kartı tanıtımda" % feature)
		assert_false(TutorialStrings.card_line(feature).is_empty(), "%s kart metni" % feature)
		var keys: Dictionary = TutorialStrings.CARDS[feature] as Dictionary
		var before: String = Loc.language()
		for lang: String in Loc.LANGUAGES:
			Loc.set_language(lang)
			for field: String in ["title", "line"]:
				var key: String = String(keys[field])
				assert_true(Loc.t(key) != key and not Loc.t(key).is_empty(), "%s %s metni (%s)" % [feature, field, lang])
		Loc.set_language(before)
