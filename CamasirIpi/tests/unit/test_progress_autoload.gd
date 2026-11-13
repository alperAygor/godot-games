extends TestCase

## Progress autoload'unun disk davranışı: atomik kayıt, bozuk dosya, eski .cfg göçü.
## Gerçek kayıt dosyasına dokunmamak için ayrı test yolları kullanılır.

const TEST_PATH: String = "user://test_progress.json"
const TEST_LEGACY: String = "user://test_progress.cfg"

var _progress: Node = null


func before_each() -> void:
	_cleanup()
	var script: GDScript = load("res://scripts/autoload/Progress.gd") as GDScript
	_progress = script.new()
	_progress.set("save_path", TEST_PATH)
	_progress.set("legacy_path", TEST_LEGACY)
	_progress.set("balance", ProgressData.load_balance())


func after_each() -> void:
	_progress.free()
	_cleanup()


func test_save_and_reload() -> void:
	_progress.call("add_coins", 75)
	_progress.call("complete_level", false)
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "geçici dosya kalmamalı")
	var again: Node = (load("res://scripts/autoload/Progress.gd") as GDScript).new()
	again.set("save_path", TEST_PATH)
	again.set("legacy_path", TEST_LEGACY)
	again.set("balance", ProgressData.load_balance())
	again.call("load_from_disk")
	assert_eq(int(again.call("coins")), 95)
	assert_eq(int(again.call("level")), 2)
	assert_eq(int(again.call("streak")), 1)
	again.free()


func test_persist_false_writes_nothing() -> void:
	_progress.set("persist", false)
	_progress.call("add_coins", 10)
	assert_false(FileAccess.file_exists(TEST_PATH))


func test_corrupt_file_falls_back_and_keeps_backup() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{bozuk json")
	file.close()
	_progress.call("load_from_disk")
	assert_eq(int(_progress.call("level")), 1)
	assert_eq(int(_progress.call("coins")), 0)
	assert_true(FileAccess.file_exists(TEST_PATH + ".bak"))
	assert_eq(FileAccess.get_file_as_string(TEST_PATH + ".bak"), "{bozuk json")


func test_legacy_cfg_migrates_once() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("progress", "level", 7)
	config.set_value("progress", "coins", 140)
	config.save(TEST_LEGACY)
	_progress.call("load_from_disk")
	assert_eq(int(_progress.call("level")), 7)
	assert_eq(int(_progress.call("coins")), 140)
	assert_true(FileAccess.file_exists(TEST_LEGACY), "kayıt yazılana dek eski dosya durur")
	_progress.call("add_coins", 0)
	assert_true(FileAccess.file_exists(TEST_PATH))
	assert_false(FileAccess.file_exists(TEST_LEGACY), "göç sonrası eski dosya işaretlenir")
	assert_true(FileAccess.file_exists(TEST_LEGACY + ".migrated"))
	# Eski seviye 7 olduğundan geriye dönük yalnız geçmiş açılışların hediyesi verilmiş olmalı.
	assert_eq(int(_progress.call("booster_count", "undo")), 2)


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(TEST_PATH + suffix)
	for suffix: String in ["", ".migrated"]:
		DirAccess.remove_absolute(TEST_LEGACY + suffix)
