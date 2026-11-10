extends TestCase

## PlayerProfile: atomik kayit, bozuk kayit toleransi, yalnizca iyilestirme,
## kilit acma sirasi ve toplam yildiz. Testler user:// altinda gecici dosya
## kullanir ve after_each'te siler (kalici iz birakmaz).

var _profile: PlayerProfile = null
var _save_path: String = ""


func before_each() -> void:
	_save_path = "user://test_profile_%d_%d.save" % [Time.get_ticks_usec(), randi() % 100000]
	_remove_file(_save_path)
	_remove_file(_save_path + ".tmp")
	_profile = PlayerProfile.new()
	_profile.save_path = _save_path


func after_each() -> void:
	_remove_file(_save_path)
	_remove_file(_save_path + ".tmp")
	_profile = null


func _remove_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir != null:
		dir.remove(path.get_file())


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "gecici kayit dosyasi acilmali")
	if file == null:
		return
	file.store_string(text)
	file.close()


func test_new_profile_defaults() -> void:
	assert_eq(_profile.stars(1), 0)
	assert_almost_eq(_profile.best_time(1), 0.0, 0.0001)
	assert_eq(_profile.total_stars(), 0)
	assert_eq(_profile.highest_unlocked(), 1)
	assert_true(_profile.is_unlocked(1), "ilk bolum her zaman acik")
	assert_false(_profile.is_unlocked(2))


func test_record_keeps_best_stars_only() -> void:
	_profile.record(3, 2, 40.0)
	assert_eq(_profile.stars(3), 2)
	_profile.record(3, 1, 30.0)
	assert_eq(_profile.stars(3), 2, "daha az yildiz ezmez")
	_profile.record(3, 3, 50.0)
	assert_eq(_profile.stars(3), 3)
	assert_almost_eq(_profile.best_time(3), 30.0, 0.0001, "en iyi sure korunur")


func test_record_keeps_best_time_only() -> void:
	_profile.record(2, 1, 50.0)
	_profile.record(2, 1, 40.0)
	assert_almost_eq(_profile.best_time(2), 40.0, 0.0001)
	_profile.record(2, 2, 60.0)
	assert_almost_eq(_profile.best_time(2), 40.0, 0.0001, "daha yavas sure ezmez")
	assert_eq(_profile.stars(2), 2)


func test_record_ignores_invalid_level_and_values() -> void:
	_profile.record(0, 3, 10.0)
	_profile.record(13, 3, 10.0)
	_profile.record(-1, 3, 10.0)
	assert_eq(_profile.total_stars(), 0)
	_profile.record(1, 9, 10.0)
	assert_eq(_profile.stars(1), 3, "yildiz 0..3 kirpilir")
	assert_almost_eq(_profile.best_time(1), 10.0, 0.0001)
	_profile.record(2, 1, -5.0)
	assert_almost_eq(_profile.best_time(2), 0.0, 0.0001, "gecersiz sure yazilmaz")


func test_save_and_load_roundtrip() -> void:
	_profile.record(1, 3, 21.5)
	_profile.record(2, 2, 44.0)
	_profile.record(5, 1, 90.25)
	_profile.save()
	assert_true(FileAccess.file_exists(_save_path), "kayit dosyasi olusmali")
	var loaded: PlayerProfile = PlayerProfile.new()
	loaded.save_path = _save_path
	loaded.load_save()
	assert_eq(loaded.stars(1), 3)
	assert_eq(loaded.stars(2), 2)
	assert_eq(loaded.stars(5), 1)
	assert_almost_eq(loaded.best_time(1), 21.5, 0.0001)
	assert_almost_eq(loaded.best_time(2), 44.0, 0.0001)
	assert_almost_eq(loaded.best_time(5), 90.25, 0.0001)
	assert_eq(loaded.total_stars(), 6)


func test_save_is_atomic_and_leaves_no_tmp() -> void:
	_profile.record(1, 3, 10.0)
	_profile.save()
	_profile.save()
	assert_false(FileAccess.file_exists(_save_path + ".tmp"), "gecici dosya kalmamali")
	assert_true(FileAccess.file_exists(_save_path))


func test_load_missing_file_resets_quietly() -> void:
	_profile.record(1, 3, 10.0)
	_profile.load_save()
	assert_eq(_profile.total_stars(), 0, "dosya yoksa sifirlanir")
	assert_eq(_profile.highest_unlocked(), 1)


func test_load_corrupt_file_is_tolerated() -> void:
	_write_raw(_save_path, "{bozuk json!!!")
	_profile.load_save()
	assert_eq(_profile.total_stars(), 0)
	assert_eq(_profile.highest_unlocked(), 1)


func test_load_empty_file_is_tolerated() -> void:
	_write_raw(_save_path, "")
	_profile.load_save()
	assert_eq(_profile.total_stars(), 0)


func test_load_wrong_types_are_tolerated() -> void:
	_write_raw(_save_path, "{\"best_stars\": [1, 2], \"best_times\": \"abc\"}")
	_profile.load_save()
	assert_eq(_profile.total_stars(), 0)
	assert_almost_eq(_profile.best_time(1), 0.0, 0.0001)


func test_out_of_range_values_are_sanitized() -> void:
	_write_raw(_save_path,
		"{\"best_stars\": {\"1\": 7, \"99\": 3, \"2\": \"x\", \"3\": 2.0},"
		+ " \"best_times\": {\"1\": -5, \"3\": 42.5, \"99\": 10, \"4\": \"y\"}}")
	_profile.load_save()
	assert_eq(_profile.stars(1), 3, "7 -> 3 kirpilir")
	assert_eq(_profile.stars(99), 0, "bolum araligi disi yok sayilir")
	assert_eq(_profile.stars(2), 0, "metin deger yok sayilir")
	assert_eq(_profile.stars(3), 2, "float yildiz tam sayiya cevrilir")
	assert_almost_eq(_profile.best_time(1), 0.0, 0.0001, "negatif sure yok sayilir")
	assert_almost_eq(_profile.best_time(3), 42.5, 0.0001)
	assert_almost_eq(_profile.best_time(99), 0.0, 0.0001)
	assert_almost_eq(_profile.best_time(4), 0.0, 0.0001)


func test_unlock_progression_is_sequential() -> void:
	assert_eq(_profile.highest_unlocked(), 1)
	_profile.record(1, 3, 10.0)
	assert_eq(_profile.highest_unlocked(), 2)
	assert_true(_profile.is_unlocked(2))
	assert_false(_profile.is_unlocked(3))
	_profile.record(2, 1, 30.0)
	assert_eq(_profile.highest_unlocked(), 3)
	assert_true(_profile.is_unlocked(3))
	_profile.record(4, 3, 10.0)
	assert_eq(_profile.highest_unlocked(), 3, "bosluk atlanmaz")


func test_total_stars_sums_all_levels() -> void:
	_profile.record(1, 3, 10.0)
	_profile.record(2, 2, 10.0)
	_profile.record(3, 1, 10.0)
	assert_eq(_profile.total_stars(), 6)


func test_record_still_works_after_load() -> void:
	_profile.record(1, 2, 30.0)
	_profile.save()
	var reloaded: PlayerProfile = PlayerProfile.new()
	reloaded.save_path = _save_path
	reloaded.load_save()
	reloaded.record(1, 3, 20.0)
	reloaded.save()
	var again: PlayerProfile = PlayerProfile.new()
	again.save_path = _save_path
	again.load_save()
	assert_eq(again.stars(1), 3)
	assert_almost_eq(again.best_time(1), 20.0, 0.0001)
