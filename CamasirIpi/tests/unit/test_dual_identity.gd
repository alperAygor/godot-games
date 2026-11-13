extends TestCase

## Kasıtlı kimlik testi (çift renk + mevsim olayları sonrası): 1..15 birebir aynı (test_level_curve);
## 16..63 YALNIZ çift renkli parça yerleşen seviyelerde ve mevsim tanıtım seviyelerinde (22, 31, 61)
## değişebilir. Diğer seviyelerde mevsim olayı yalnız EKLENİR (yaprak/polen anahtarı, güneş/don
## işareti): bunlar çıkarılınca seviye eski üreticinin çıktısıyla birebir aynıdır.

const FIRST: int = 16
const LAST: int = 63
## Mevsim olayının seviyeye eklediği anahtarlar (çıkarılınca eski seviye kalır).
const SEASON_LEVEL_KEYS: Array[String] = ["leaves", "pollen"]
const SEASON_ITEM_KEYS: Array[String] = ["sun", "frost"]
## Eski üreticinin (çift renk ve mevsimler öncesi) seviye özetleri: md5(JSON, sıralı anahtarlar).
const LEGACY_MD5: Dictionary = {
	16: "3f75ee1479ed371e47a6d53e846d0349",
	17: "721a0e9712cedf915305a1876c767860",
	18: "a7523e388ff0036aeda8f5078b267f4c",
	19: "8f45e678e5cca0b1114e4198f37c7791",
	20: "cf5c54127a6e07600d25d1c5e5bf635d",
	21: "2502dbdce5f922e0e6cf96333e2151de",
	22: "81f00fa170d77e5e68434b03dcd12b53",
	23: "c758dbce28d0af47fb9782e23698260c",
	24: "f2cc96d8184ee8ad07c8829e5c2f09ed",
	25: "0af9446ef698529530da73836084c563",
	26: "c82a596744ef2e3634169a6cb7782de3",
	27: "a088fa05415b1969b7abd87b3f83488c",
	28: "4762f333185348c0391cb96a5103bc04",
	29: "11cacc59e9a1ba440f6cc41c4431b9fd",
	30: "a52136b2645f5663297b1303c5f05f06",
	31: "d81f878adfae0530030b8694dfa710cd",
	32: "b7e80ea2f46c7a94d3bed259bc8ad2d7",
	33: "ddc3b870948c41210e0ad491d2dfd37b",
	34: "9c53421907d882a2e5d466dad087e1a5",
	35: "9d825c1ffb0d4d15ce84083a150d259f",
	36: "e92717dfa05991ac7b0c35471133bb7e",
	37: "7f82dd7fd8574c2fb5ba4a727c21eb1b",
	38: "382f3c77224e7af7846b82c311f271d6",
	39: "73559807fae4a83141d6513e8f480968",
	40: "d1befb8b0875e620dd237778139510db",
	41: "a7559cf03465eafb7542921e4b8c9012",
	42: "5b26b11d82fa298f52ebc9f2f4794050",
	43: "5f61f4ad4f8271147f6c9647e4e5e7a6",
	44: "a525bb600c06af71f63d72ea79536883",
	45: "aec8190b22f66c7924b71ffb5e222668",
	46: "2803fac40d3a460744ce6199d5a8bb68",
	47: "fa5f697b2a3c5b32ab8c7347cf1ca93d",
	48: "6e1273c7ac4b63a195cd5e422e636dfb",
	49: "1aa284c4bc69cccb239372594865d543",
	50: "19736eff3ba8942bf64fbb6c3affe7b6",
	51: "af702c3c7eb304d9e85e9e672bef58fc",
	52: "922c5ef2d27c8b7dfaa808060969c08d",
	53: "0d98714eb98ddaa57333c2f5def6b3cb",
	54: "3e0c0c1cc2a4b9f2a0b85637f8da3543",
	55: "de2649f8880813d8ee8c8ba01ea3d1ea",
	56: "cd6122b702172b0623a85471a5a245f8",
	57: "7a1d5b61b9b56976bc448c066c4d16bf",
	58: "679a6f5697246e1c3c65cfb69c1fd14e",
	59: "1614814131327edfc733b4e357e03a88",
	60: "a7147656f5e46c302117c7a5e1d98eb8",
	61: "7d14fe3c564d66e45d608de5eb04a4f7",
	62: "e2316cab66b2d74d2dc8bed2b4d91b8a",
	63: "29871052df6171bed18e31ee72e46b50",
}


static func strip_season(level: Dictionary) -> Dictionary:
	var copy: Dictionary = level.duplicate(true)
	for key: String in SEASON_LEVEL_KEYS:
		copy.erase(key)
	for entry: Variant in copy["items"] as Array:
		for key: String in SEASON_ITEM_KEYS:
			(entry as Dictionary).erase(key)
	return copy


static func has_dual(level: Dictionary) -> bool:
	for entry: Variant in level["items"] as Array:
		if (entry as Dictionary).has("twin"):
			return true
	return false


func test_only_dual_and_season_intro_levels_change() -> void:
	var intros: Array[int] = [LevelGenerator.SUN_FROM_LEVEL, LevelGenerator.LEAVES_FROM_LEVEL,
		LevelGenerator.FROST_FROM_LEVEL]
	var changed: Array[int] = []
	for number: int in range(FIRST, LAST + 1):
		var level: Dictionary = LevelCache.level(number)
		var same: bool = JSON.stringify(strip_season(level), "", true).md5_text() == String(LEGACY_MD5[number])
		if not same:
			changed.append(number)
			assert_true(has_dual(level) or intros.has(number),
				"seviye %d yalnız çift renk/mevsim tanıtımı nedeniyle değişebilir" % number)
	print("        16..63 değişen seviyeler: %s" % str(changed))
	assert_true(changed.has(LevelGenerator.DUAL_FROM_LEVEL), "çift renk tanıtımı değişti")
