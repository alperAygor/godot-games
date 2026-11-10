extends TestCase

## Kayit/yukleme: round-trip, bozuk dosya kurtarma, para API'si.
## Gercek kaydi bozmamak icin save_path gecici dosyaya cekilir.

const TEST_PATH: String = "user://test_profile.save"

var _manager: Node = null


func before_each() -> void:
	_manager = autoload_node("GameManager")
	_cleanup()
	_manager.set("save_path", TEST_PATH)
	_manager.set("profile", PlayerProfile.create_default())


func after_each() -> void:
	_cleanup()
	_manager.set("save_path", "user://profile.save")
	_manager.set("profile", PlayerProfile.create_default())


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(TEST_PATH + suffix)


func test_save_then_load_round_trip() -> void:
	_manager.call("add_currency", 500)
	_manager.call("add_reputation", 1)
	assert_true(bool(_manager.call("save_profile")), "kayit yazilmali")

	_manager.set("profile", PlayerProfile.create_default())
	_manager.call("load_profile")

	var profile: PlayerProfile = _manager.get("profile") as PlayerProfile
	assert_eq(profile.currency, 500)
	assert_eq(profile.reputation, 4)


func test_spend_respects_balance() -> void:
	_manager.call("add_currency", 100)
	assert_false(bool(_manager.call("spend_currency", 150)), "yetersiz bakiyede harcama olmaz")
	assert_eq((_manager.get("profile") as PlayerProfile).currency, 100)
	assert_true(bool(_manager.call("spend_currency", 40)))
	assert_eq((_manager.get("profile") as PlayerProfile).currency, 60)


func test_corrupt_save_falls_back_and_backs_up() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{bozuk json!!")
	file.close()

	_manager.call("load_profile")

	var profile: PlayerProfile = _manager.get("profile") as PlayerProfile
	assert_eq(profile.currency, int(GameData.value("balance", "starting_currency", 0)),
		"bozuk kayit ilk acilis gibi ele alinmali")
	assert_true(FileAccess.file_exists(TEST_PATH + ".bak"), "bozuk dosya yedeklenmeli")
	assert_false(FileAccess.file_exists(TEST_PATH), "bozuk dosya kaldirilmali")


func test_atomic_write_leaves_no_temp_file() -> void:
	_manager.call("add_currency", 10)
	_manager.call("save_profile")
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), ".tmp kalmamali")
	assert_true(FileAccess.file_exists(TEST_PATH))


func test_missing_save_grants_starting_currency() -> void:
	_manager.call("load_profile")
	var profile: PlayerProfile = _manager.get("profile") as PlayerProfile
	var expected: int = int(GameData.value("balance", "starting_currency", 0))
	assert_eq(expected, 500, "data/balance.json baslangic sermayesi tanimli olmali")
	assert_eq(profile.currency, expected, "ilk acilis sermayeyle gelmeli")
	assert_eq(profile.reputation, 3)
