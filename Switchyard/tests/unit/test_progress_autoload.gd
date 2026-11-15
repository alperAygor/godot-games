extends TestCase

## Progress autoload'unun disk davranışı: atomik kayıt, bozuk dosya, persist=false.
## Gerçek kayıt dosyasına dokunmamak için ayrı test yolları kullanılır.

const TEST_PATH: String = "user://test_progress.json"

var _progress: Node = null


func before_each() -> void:
	_cleanup()
	_progress = _make()


func after_each() -> void:
	_progress.free()
	_cleanup()


func _make() -> Node:
	var node: Node = (load("res://scripts/autoload/Progress.gd") as GDScript).new()
	node.set("save_path", TEST_PATH)
	node.set("balance", ProgressData.load_balance())
	return node


func test_save_and_reload() -> void:
	_progress.call("add_coins", 75)
	_progress.call("complete_level")
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "geçici dosya kalmamalı")
	var again: Node = _make()
	again.call("load_from_disk")
	assert_eq(int(again.call("coins")), 95)
	assert_eq(int(again.call("level")), 2)
	again.free()


func test_persist_false_writes_nothing() -> void:
	_progress.set("persist", false)
	_progress.call("add_coins", 10)
	_progress.call("complete_level")
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


func test_module_values_and_remove_ads_flag_persist() -> void:
	assert_false(bool(_progress.call("remove_ads_owned")))
	_progress.call("set_module_value", "daily", "streak", 3)
	_progress.call("set_remove_ads_owned", true)
	var again: Node = _make()
	again.call("load_from_disk")
	assert_eq(int(again.call("module_value", "daily", "streak", 0)), 3)
	assert_true(bool(again.call("remove_ads_owned")))
	assert_eq(again.call("module_value", "daily", "yok", "varsayilan"), "varsayilan")
	again.free()


func test_purchase_is_one_atomic_write() -> void:
	_progress.call("add_coins", 100)
	assert_false(bool(_progress.call("purchase_module_value", 150, "shop", "x", 1)), "yetersiz jeton")
	assert_eq(_progress.call("module_value", "shop", "x"), null)
	assert_true(bool(_progress.call("purchase_module_value", 60, "shop", "x", 1)))
	assert_eq(int(_progress.call("coins")), 40)
	assert_eq(int(_progress.call("module_value", "shop", "x")), 1)


func test_changed_signal_fires_on_commit() -> void:
	var hits: Array[int] = [0]
	_progress.connect("changed", func() -> void: hits[0] += 1)
	_progress.call("add_coins", 1)
	_progress.call("set_setting", "sound", false)
	assert_eq(hits[0], 2)


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(TEST_PATH + suffix)
