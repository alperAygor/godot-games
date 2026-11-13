extends TestCase

## Makineler ve misafirlerin üretimi: takvim, tanıtım seviyesinde tek başına gelme, sonra ölçülü
## karışım, tutarlılık (türlü sepet sayıları, yağmur ipi, kuş hedefi), yardımsız ve yükseltmeli
## çözülebilirlik; 1..63 seviyelerinin değişmediği.

## 1..63 (makineler öncesi) seviyelerin birebir aynı kaldığının kanıtı.
const LEGACY_LEVELS: int = 63
const LEGACY_HASH: String = "ae5acd083668ec4bb2b9a2a50c7b2d5d"
const LAST_LEVEL: int = 150
const ITEM_KEYS: Array[String] = ["wet", "mystery", "lock", "sheet", "sock", "dye", "stain", "chain", "dirty"]
const LEVEL_KEYS: Array[String] = ["jokers", "big", "wind", "slide", "washer", "dryer", "typed", "birds", "rain", "cat"]
const MAX_UPGRADES: Dictionary = {"washer_capacity": 4, "washer_moves": 1, "dryer_capacity": 4, "dryer_moves": 1}


func _count(level: Dictionary, key: String) -> int:
	var total: int = 0
	for entry: Variant in level["items"] as Array:
		var value: Variant = (entry as Dictionary).get(key, null)
		if value is bool:
			total += 1 if bool(value) else 0
		elif value != null:
			total += 1
	return total


func _intros() -> Dictionary:
	return {
		"washer": LevelGenerator.WASHER_FROM_LEVEL, "dryer": LevelGenerator.DRYER_FROM_LEVEL,
		"typed": LevelGenerator.TYPED_FROM_LEVEL, "birds": LevelGenerator.BIRDS_FROM_LEVEL,
		"rain": LevelGenerator.RAIN_FROM_LEVEL, "cat": LevelGenerator.CAT_FROM_LEVEL,
	}


func test_legacy_levels_are_byte_identical() -> void:
	var text: String = ""
	for number: int in range(1, LEGACY_LEVELS + 1):
		text += JSON.stringify(LevelCache.level(number), "", true)
	assert_eq(text.md5_text(), LEGACY_HASH, "1..63 seviyeleri değişmemeli")


func test_unlock_schedule() -> void:
	assert_eq(LevelGenerator.WASHER_FROM_LEVEL, 64)
	assert_eq(LevelGenerator.DRYER_FROM_LEVEL, 70)
	assert_eq(LevelGenerator.TYPED_FROM_LEVEL, 76)
	assert_eq(LevelGenerator.BIRDS_FROM_LEVEL, 82)
	assert_eq(LevelGenerator.RAIN_FROM_LEVEL, 88)
	assert_eq(LevelGenerator.CAT_FROM_LEVEL, 94)
	for key: String in _intros().keys():
		var number: int = int(_intros()[key])
		for before: int in range(LevelGenerator.WASHER_FROM_LEVEL, number):
			assert_false(LevelCache.level(before).has(key) and key != "washer", "%s %d'den önce yok" % [key, before])


func test_each_is_introduced_alone() -> void:
	for key: String in _intros().keys():
		var number: int = int(_intros()[key])
		var level: Dictionary = LevelCache.level(number)
		assert_true(level.has(key), "%s tanıtımda var (seviye %d)" % [key, number])
		for other: String in LEVEL_KEYS:
			# Kuş lekesi makine ister: kuş tanıtımında yıkama makinesi araç olarak durur.
			if other == key or (key == "birds" and other == "washer"):
				continue
			assert_false(level.has(other), "seviye %d yalnız %s öğretir (%s var)" % [number, key, other])
		for item_key: String in ITEM_KEYS:
			var allowed: bool = (key == "washer" and item_key == "dirty") or (key == "dryer" and item_key == "wet")
			if not allowed:
				assert_eq(_count(level, item_key), 0, "seviye %d'de %s yok" % [number, item_key])
		assert_false(level.has("mode"), "tanıtımda kip yok")
		assert_false(bool(level["hard"]), "tanıtım seviyesi zor olmaz")
	assert_eq(_count(LevelCache.level(LevelGenerator.WASHER_FROM_LEVEL), "dirty"), LevelGenerator.WASHER_INTRO_DIRTY)
	assert_eq(_count(LevelCache.level(LevelGenerator.DRYER_FROM_LEVEL), "wet"), LevelGenerator.DRYER_INTRO_WET)


func test_mixed_in_later_but_not_overloaded() -> void:
	var seen: Dictionary = {}
	for number: int in range(LevelGenerator.CAT_FROM_LEVEL + 1, LAST_LEVEL + 1):
		var level: Dictionary = LevelCache.level(number)
		var fresh: int = 0
		for key: String in ["dryer", "typed", "birds", "rain", "cat"]:
			if level.has(key):
				fresh += 1
				seen[key] = int(seen.get(key, 0)) + 1
		if _count(level, "dirty") > 0:
			fresh += 1
			seen["washer"] = int(seen.get("washer", 0)) + 1
		assert_true(fresh <= LevelGenerator.MAX_NEW_MECHANICS, "seviye %d en fazla iki yeni mekanik (%d)" % [number, fresh])
		var timed: int = 0
		for key: String in ["wind", "slide", "birds", "rain", "cat"]:
			if level.has(key):
				timed += 1
		assert_true(timed <= LevelGenerator.MAX_TIMED_MECHANICS, "seviye %d en fazla iki sayaç" % number)
	for key: String in ["washer", "dryer", "typed", "birds", "rain", "cat"]:
		assert_greater(int(seen.get(key, 0)), 3, "%s geç seviyelerde karışır (%d)" % [key, int(seen.get(key, 0))])


func test_new_data_is_consistent() -> void:
	for number: int in range(LevelGenerator.WASHER_FROM_LEVEL, LAST_LEVEL + 1):
		var level: Dictionary = LevelCache.level(number)
		var by_id: Dictionary = {}
		for entry: Variant in level["items"] as Array:
			by_id[int((entry as Dictionary)["id"])] = entry
		if level.has("birds") or _count(level, "dirty") > 0:
			assert_true(level.has("washer"), "seviye %d: çamur/kuş varsa yıkama makinesi var" % number)
		for target: Variant in (level.get("birds", {}) as Dictionary).get("targets", []) as Array:
			assert_true(by_id.has(int(target)), "kuş hedefi parça")
		for step: Variant in (level.get("rain", {}) as Dictionary).get("steps", []) as Array:
			var line: int = int((by_id[int((step as Array)[0])] as Dictionary)["line"])
			for id: Variant in step as Array:
				assert_eq(int((by_id[int(id)] as Dictionary)["line"]), line, "yağmur adımı tek ip")
		for pair: Variant in level.get("typed", []) as Array:
			var index: int = int((pair as Array)[0])
			var kind: int = int((pair as Array)[1])
			var color: int = int((level["queue"] as Array)[index])
			var matching: int = 0
			for entry: Variant in level["items"] as Array:
				var item: Dictionary = entry as Dictionary
				if int(item["color"]) == color and int(item["kind"]) == kind:
					matching += 1
			assert_eq(matching, LaundryBoard.BASKET_CAPACITY, "seviye %d: türlü sepete tam üç parça" % number)
			assert_false((level.get("jokers", []) as Array).has(index), "türlü sepet joker değil")
			assert_false((level.get("big", []) as Array).has(index), "türlü sepet büyük değil")
		for slot: Variant in (level.get("cat", {}) as Dictionary).get("baskets", []) as Array:
			assert_true(int(slot) >= 0 and int(slot) < int(level["active_baskets"]), "kedi aktif yuvaya yatar")


## Kuş/kedili seviyeler oyuncu hiç kovalamasa/sevmese de kazanılır; makineli seviyeler en üst
## yükseltmelerle de kazanılır (yükseltme yalnız kolaylaştırır).
func test_unhelped_and_upgraded_play_stays_winnable() -> void:
	for number: int in range(LevelGenerator.WASHER_FROM_LEVEL, LAST_LEVEL + 1):
		var level: Dictionary = LevelCache.level(number)
		if level.has("birds") or level.has("cat"):
			assert_true(LevelSolver.is_solvable(level, LevelCache.SOLVE_LIMIT, false),
				"seviye %d yardımsız da çözülür" % number)
		if level.has("washer") or level.has("dryer"):
			var upgraded: Dictionary = level.duplicate()
			upgraded["upgrades"] = MAX_UPGRADES
			assert_true(LevelSolver.is_solvable(upgraded, LevelCache.SOLVE_LIMIT),
				"seviye %d yükseltmeyle de çözülür" % number)


func test_tutorial_cards_follow_the_schedule() -> void:
	var cards: Dictionary = {"washer": LevelGenerator.WASHER_FROM_LEVEL, "dryer": LevelGenerator.DRYER_FROM_LEVEL,
		"typed_basket": LevelGenerator.TYPED_FROM_LEVEL, "birds": LevelGenerator.BIRDS_FROM_LEVEL,
		"rain": LevelGenerator.RAIN_FROM_LEVEL, "cat": LevelGenerator.CAT_FROM_LEVEL}
	for feature: String in cards.keys():
		var found: Array[String] = TutorialFeatures.detect(LevelCache.level(int(cards[feature])))
		assert_true(found.has(feature), "%s kartı tanıtımda" % feature)
		assert_false(TutorialStrings.card_line(feature).is_empty(), "%s kart metni" % feature)
