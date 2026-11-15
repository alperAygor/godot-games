extends "res://tests/test_case.gd"
## Kayıt sürümleri ve göç: v1 -> v2, eski/yeni sürüm kuralları, kariyer bloğu göçü.
## Gerçek SaveManager autoload'una dokunmaz: kendi örneğini sandbox klasöründeki dosyalarla kullanır.

const SAVE_SCRIPT := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://_sandbox/mig_save.json"

var _managers: Array[Node] = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(JsonIO.SANDBOX_DIR)
	_cleanup()


func after_each() -> void:
	for manager in _managers:
		manager.free()
	_managers.clear()
	_cleanup()


func _cleanup() -> void:
	for file_name in DirAccess.get_files_at(JsonIO.SANDBOX_DIR):
		if file_name.begins_with("mig_save"):
			DirAccess.remove_absolute(JsonIO.SANDBOX_DIR.path_join(file_name))


func _manager() -> Node:
	var manager: Node = SAVE_SCRIPT.new()
	manager.save_path = PATH
	_managers.append(manager)
	return manager


## JSON'dan geçen sayılar ondalık gelir (1 -> 1.0); sözlük eşitliği tip duyarlı olduğundan metne çevirip karşılaştırırız.
func _norm(value: Variant) -> String:
	return JSON.stringify(JsonIO.parse_quiet(JSON.stringify(value)), "", true)


## Sürüm 1'in yazdığı biçim: sağlama toplamı yok.
func _write_v1(body: Dictionary) -> void:
	JsonIO.write_dict(PATH, {"version": 1, "saved_at": 1.0, "data": body})


func test_current_version_is_two_and_career_block_is_versioned() -> void:
	assert_eq(SAVE_SCRIPT.SAVE_VERSION, 2)
	assert_eq(Career.SAVE_VERSION, 1)


func test_v1_file_migrates_to_current_and_keeps_all_data() -> void:
	var career_block := Career.load_default("story").to_dict()
	career_block.erase("version")  # sürüm damgasından önceki kariyer bloğu
	career_block["day"] = 4
	_write_v1({"career": career_block, "endings_seen": ["a"], "modes": {"x": 1}})
	var manager := _manager()
	var issues: Array[String] = []
	manager.load_issue.connect(func(status: String) -> void: issues.append(status))
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_MIGRATED)
	assert_eq(issues, ["migrated"])
	assert_eq(int(manager.data["career"]["day"]), 4)
	assert_eq(int(manager.data["career"]["version"]), Career.SAVE_VERSION, "kariyer bloğuna sürüm damgalandı")
	assert_eq(manager.data["endings_seen"], ["a"])
	assert_eq(_norm(manager.data["modes"]), _norm({"x": 1}))
	assert_false(FileAccess.file_exists(PATH.get_basename() + ".v1.json"), "yüklemek diske dokunmaz")
	# Bir sonraki kayıt güncel biçimde yazılır; öncesinde eski dosyanın kopyası alınır.
	assert_eq(manager.save_game(), OK)
	assert_true(FileAccess.file_exists(PATH.get_basename() + ".v1.json"), "göç öncesi dosya kopyası")
	assert_eq(int(JsonIO.inspect(PATH.get_basename() + ".v1.json")["data"]["version"]), 1)
	var payload: Dictionary = JsonIO.inspect(PATH)["data"]
	assert_eq(int(payload["version"]), SAVE_SCRIPT.SAVE_VERSION)
	assert_true(SAVE_SCRIPT.is_valid_payload(payload))
	var again := _manager()
	assert_eq(again.load_game(), SAVE_SCRIPT.LOAD_OK)


func test_real_world_empty_v1_save_loads() -> void:
	JsonIO.write_dict(PATH, {"data": {}, "saved_at": 1793039121.71055, "version": 1})
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_MIGRATED)
	assert_eq(manager.data, {})


func test_migrated_career_still_loads_into_career() -> void:
	var original := Career.load_default("story")
	original.day = 3
	original.household.cash_minor = Money.units(321)
	var block := original.to_dict()
	block.erase("version")
	_write_v1({"career": block})
	var manager := _manager()
	manager.load_game()
	var restored := Career.load_default("story")
	restored.load_dict(manager.data["career"])
	assert_eq(restored.day, 3)
	assert_eq(restored.household.cash_minor, Money.units(321))


func test_migration_does_not_mutate_its_input() -> void:
	var manager := _manager()
	var payload := {"version": 1, "data": {"career": {"day": 2}}}
	var snapshot := payload.duplicate(true)
	var migrated: Dictionary = manager.migrate(payload)
	assert_eq(payload, snapshot)
	assert_eq(int(migrated["version"]), 2)


func test_current_version_payload_is_unchanged_by_migrate() -> void:
	var manager := _manager()
	var payload := {"version": SAVE_SCRIPT.SAVE_VERSION, "data": {"a": 1}, "checksum": "x"}
	assert_eq(manager.migrate(payload), payload)


func test_future_version_is_read_as_is_and_preserved() -> void:
	var body := {"career": {"day": 7}, "new_feature": {"deep": [1, 2, 3]}}
	JsonIO.write_dict(PATH, {"version": 3, "saved_at": 1.0, "checksum": "başka-algoritma", "data": body})
	var manager := _manager()
	var issues: Array[String] = []
	manager.load_issue.connect(func(status: String) -> void: issues.append(status))
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_FUTURE)
	assert_eq(issues, ["future_version"])
	assert_eq(int(manager.data["career"]["day"]), 7)
	assert_eq(_norm(manager.data["new_feature"]), _norm({"deep": [1, 2, 3]}), "bilinmeyen alanlar korunur")
	var kept := PATH.get_basename() + ".v3.json"
	assert_false(FileAccess.file_exists(kept), "yüklemek diske dokunmaz")
	# İlk kayıt yeni sürüm dosyasının kopyasını bırakır ve bilinmeyen alanları kaybetmez.
	assert_eq(manager.save_game(), OK)
	assert_true(FileAccess.file_exists(kept), "yeni sürüm dosyasının kopyası bırakıldı")
	assert_eq(_norm(JsonIO.inspect(kept)["data"]["data"]["new_feature"]), _norm({"deep": [1, 2, 3]}))
	manager.data["coins"] = 1
	assert_eq(manager.save_game(), OK)
	assert_true(manager.data.has("new_feature"))
	assert_true(FileAccess.file_exists(kept))
	assert_eq(JsonIO.inspect(kept)["data"]["version"], 3)


func test_invalid_versions_are_corrupt_not_migrated() -> void:
	for version: Variant in [0, -1, "abc", null]:
		_cleanup()
		JsonIO.write_dict(PATH, {"version": version, "data": {"a": 1}})
		var manager := _manager()
		assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_UNRECOVERABLE, "sürüm %s" % [version])


func test_corrupt_v1_main_recovers_from_a_v1_backup_and_migrates() -> void:
	_write_v1({"a": 1})
	DirAccess.copy_absolute(PATH, PATH + ".bak")
	var raw := FileAccess.open(PATH, FileAccess.WRITE)
	raw.store_string("{ kesik")
	raw.close()
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_RECOVERED)
	assert_eq(_norm(manager.data), _norm({"a": 1}))


func test_career_migrate_dict_stamps_missing_version_and_keeps_unknown_keys() -> void:
	var old := {"day": 3, "mystery": [1]}
	var migrated := Career.migrate_dict(old)
	assert_eq(migrated["version"], 1)
	assert_eq(migrated["mystery"], [1])
	assert_false(old.has("version"), "girdi değişmez")
	var future := {"version": 9, "day": 2}
	assert_eq(Career.migrate_dict(future)["version"], 9, "gelecek sürüm değişmeden kalır")


func test_career_block_validation() -> void:
	assert_true(Career.is_valid_dict(Career.load_default("story").to_dict()))
	assert_true(Career.is_valid_dict({"day": 2}))
	assert_false(Career.is_valid_dict("metin"))
	assert_false(Career.is_valid_dict({"day": "iki"}))
	assert_false(Career.is_valid_dict({"day": 0}))
	assert_false(Career.is_valid_dict({"day": 2, "household": []}))
	assert_false(Career.is_valid_dict({"day": 2, "tools": {}}))
	assert_false(Career.is_valid_dict({"day": 2, "morning_snapshot": 5}))
