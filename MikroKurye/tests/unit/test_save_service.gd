extends TestCase

## SaveService dosya IO'su ve profil akışı (ARCHITECTURE §5.4).
## Gerçek kayıt dosyasına dokunmamak için her test kendi geçici yolunu kullanır.
## `user://` yazılamıyorsa (kısıtlı CI ortamı) proje içindeki geçici yol kullanılır;
## böylece dosya IO'su yine gerçekten sınanır, test sessizce atlanmaz.

const USER_TEST_PATH: String = "user://test_save_service.json"
const FALLBACK_TEST_PATH: String = "res://tests/unit/.tmp_test_save_service.json"
const DEFAULT_PATH: String = "user://save.json"

var _save: Node = null
var _test_path: String = USER_TEST_PATH


func before_each() -> void:
	_save = autoload_node("SaveService")
	_remove_all_test_files()
	_test_path = _pick_writable_path()
	if _save != null:
		_save.call("set_save_path", _test_path)
		_save.call("load_profile")


func after_each() -> void:
	_remove_all_test_files()
	if _save != null:
		# Diğer testlerin gerçek kaydı ezmemesi için varsayılan yola dön.
		_save.call("set_save_path", DEFAULT_PATH)
		_save.call("load_profile")


func _pick_writable_path() -> String:
	if _can_write(USER_TEST_PATH):
		return USER_TEST_PATH
	return FALLBACK_TEST_PATH


func _can_write(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("")
	file.close()
	_remove(path)
	return true


func _remove_all_test_files() -> void:
	for base: String in [USER_TEST_PATH, FALLBACK_TEST_PATH]:
		_remove(base)
		_remove(base + ".corrupt")
		_remove(base + ".tmp")


func _remove(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _corrupt_path() -> String:
	return _test_path + ".corrupt"


func _temp_path() -> String:
	return _test_path + ".tmp"


func _service() -> Node:
	if _save == null:
		fail("SaveService autoload yok")
	return _save


func _wallet(save: Node) -> Dictionary:
	var profile: ProfileData = save.call("profile") as ProfileData
	if profile == null:
		return {}
	return profile.wallet().to_dict()


func _level(save: Node, category: String) -> int:
	var profile: ProfileData = save.call("profile") as ProfileData
	if profile == null:
		return -1
	return profile.level(category)


func _success(gold: int, scrap: int, stars: int = 3,
		cargo_id: String = "pencil_battery") -> Dictionary:
	return {"success": true, "gold": gold, "scrap": scrap,
		"stars": stars, "cargo_id": cargo_id}


func _write_corrupt_file() -> void:
	var file: FileAccess = FileAccess.open(_test_path, FileAccess.WRITE)
	if file == null:
		fail("bozuk test kaydı yazılamadı: %s" % _test_path)
		return
	file.store_string("{bu json degil")
	file.close()


func test_missing_file_loads_default_profile() -> void:
	var save: Node = _service()
	if save == null:
		return
	save.call("load_profile")
	var profile: ProfileData = save.call("profile") as ProfileData
	assert_not_null(profile)
	assert_eq(_wallet(save), {"gold": 0, "scrap": 0})
	assert_eq(profile.levels(), {"chassis": 0, "wheels": 0, "battery": 0, "shock_gel": 0})
	assert_false(FileAccess.file_exists(_corrupt_path()), "eksik dosya bozuk sayılmamalı")


func test_apply_result_persists_to_disk_atomically() -> void:
	var save: Node = _service()
	if save == null:
		return
	save.call("apply_result", _success(100, 6))
	assert_eq(_wallet(save), {"gold": 100, "scrap": 6})
	assert_true(FileAccess.file_exists(_test_path), "apply_result kaydı yazmalı")
	assert_false(FileAccess.file_exists(_temp_path()), "geçici dosya kalmamalı")

	save.call("load_profile")   # oyunu kapatıp açmak
	assert_eq(_wallet(save), {"gold": 100, "scrap": 6}, "cüzdan diskten korunmalı")
	assert_eq(_level(save, "battery"), 0)


func test_apply_result_twice_is_idempotent() -> void:
	var save: Node = _service()
	if save == null:
		return
	var result: Dictionary = _success(100, 6)
	save.call("apply_result", result)
	save.call("apply_result", result)   # aynı sözlük ikinci kez
	assert_eq(_wallet(save), {"gold": 100, "scrap": 6}, "aynı sonuç iki kez ödenmemeli")
	var profile: ProfileData = save.call("profile") as ProfileData
	assert_eq(profile.stats().get("deliveries"), 1, "teslimat bir kez sayılmalı")


func test_corrupt_file_is_backed_up_and_recovers() -> void:
	var save: Node = _service()
	if save == null:
		return
	_write_corrupt_file()
	save.call("load_profile")
	assert_eq(_wallet(save), {"gold": 0, "scrap": 0}, "bozuk kayıt varsayılana dönmeli")
	assert_true(FileAccess.file_exists(_corrupt_path()), "bozuk dosya .corrupt yedeği almalı")
	assert_true(FileAccess.file_exists(_test_path), "temiz kayıt yeniden yazılmalı")
	assert_false(FileAccess.file_exists(_temp_path()), "geçici dosya kalmamalı")

	save.call("load_profile")
	assert_eq(_wallet(save), {"gold": 0, "scrap": 0}, "temiz kayıt çökmeden yüklenmeli")


func test_upgrade_cost_matches_table() -> void:
	var save: Node = _service()
	if save == null:
		return
	assert_eq(save.call("upgrade_cost", "battery"), {"gold": 80, "scrap": 3})
	assert_eq(save.call("upgrade_cost", "chassis"), {"gold": 100, "scrap": 5})
	assert_eq(save.call("upgrade_cost", "wheels"), {"gold": 80, "scrap": 4})
	assert_eq(save.call("upgrade_cost", "yok_boyle_kategori"), {})


func test_purchase_deducts_cost_and_persists() -> void:
	var save: Node = _service()
	if save == null:
		return
	save.call("apply_result", _success(100, 6))
	assert_true(bool(save.call("purchase", "battery")))
	assert_eq(_wallet(save), {"gold": 20, "scrap": 3})
	assert_eq(_level(save, "battery"), 1)
	assert_eq(save.call("upgrade_cost", "battery"), {"gold": 160, "scrap": 7})

	save.call("load_profile")
	assert_eq(_wallet(save), {"gold": 20, "scrap": 3}, "satın alma kalıcı olmalı")
	assert_eq(_level(save, "battery"), 1)


func test_purchase_without_funds_changes_nothing() -> void:
	var save: Node = _service()
	if save == null:
		return
	save.call("apply_result", _success(10, 0))
	assert_false(bool(save.call("purchase", "chassis")), "yetersiz bakiye false dönmeli")
	assert_eq(_wallet(save), {"gold": 10, "scrap": 0}, "yetersiz bakiyede cüzdan değişmemeli")
	assert_eq(_level(save, "chassis"), 0, "yetersiz bakiyede seviye artmamalı")


func test_purchase_unknown_and_max_level_rejected() -> void:
	var save: Node = _service()
	if save == null:
		return
	assert_false(bool(save.call("purchase", "yok_boyle_kategori")))
	var profile: ProfileData = save.call("profile") as ProfileData
	profile.set_level("battery", 5)
	save.call("save_profile")
	assert_eq(save.call("upgrade_cost", "battery"), {}, "maksimumda bedel boş olmalı")
	assert_false(bool(save.call("purchase", "battery")), "maksimumda satın alma reddedilmeli")
	assert_eq(_level(save, "battery"), 5, "maksimum seviye değişmemeli")
	assert_eq(_wallet(save), {"gold": 0, "scrap": 0}, "maksimumda cüzdan değişmemeli")


func test_mods_sum_owned_levels() -> void:
	var save: Node = _service()
	if save == null:
		return
	save.call("apply_result", _success(80, 3))
	assert_true(bool(save.call("purchase", "battery")))
	var mods: Dictionary = save.call("mods") as Dictionary
	assert_almost_eq(float(mods.get("battery_capacity_bonus", -1.0)), 15.0)
	assert_false(mods.has("cargo_damping_bonus"),
		"satın alınmayan kategori mod üretmemeli")


func test_settings_default_persist_and_unknown_ignored() -> void:
	var save: Node = _service()
	if save == null:
		return
	assert_true(bool(save.call("setting", "sound_on")), "varsayılan ses açık olmalı")
	assert_false(bool(save.call("setting", "tutorial_done")), "varsayılan rehber gösterilmemiş olmalı")

	save.call("set_setting", "sound_on", false)
	assert_false(bool(save.call("setting", "sound_on")))
	save.call("load_profile")
	assert_false(bool(save.call("setting", "sound_on")), "ses ayarı diskten korunmalı")

	save.call("set_setting", "tutorial_done", true)
	save.call("load_profile")
	assert_true(bool(save.call("setting", "tutorial_done")), "rehber işareti diskten korunmalı")

	save.call("set_setting", "bilinmeyen", true)
	assert_false(bool(save.call("setting", "bilinmeyen")), "bilinmeyen ayar okunmamalı")
