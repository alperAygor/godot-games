extends "res://tests/test_case.gd"
## Kayıt sağlamlığı: atomik yazma, yedek, bozuk/kesik/boş dosyadan kurtarma, yaşam döngüsü yazması.
## Gerçek SaveManager autoload'una dokunmaz: kendi örneğini sandbox klasöründeki dosyalarla kullanır.

const SAVE_SCRIPT := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://_sandbox/rec_save.json"
const BAK := PATH + ".bak"

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
		if file_name.begins_with("rec_save"):
			DirAccess.remove_absolute(JsonIO.SANDBOX_DIR.path_join(file_name))


func _manager() -> Node:
	var manager: Node = SAVE_SCRIPT.new()
	manager.save_path = PATH
	_managers.append(manager)
	return manager


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_raw(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## İki kez kaydedilmiş sağlam bir çift (ana + yedek) kurar: ana = {"coins": 2}, yedek = {"coins": 1}.
func _make_good_pair() -> void:
	var writer := _manager()
	writer.data = {"coins": 1}
	assert_eq(writer.save_game(), OK)
	writer.data = {"coins": 2}
	assert_eq(writer.save_game(), OK)


func test_no_files_is_a_fresh_start() -> void:
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_FRESH)
	assert_eq(manager.data, {})


func test_second_save_keeps_the_previous_good_file_as_backup() -> void:
	_make_good_pair()
	assert_true(FileAccess.file_exists(BAK))
	assert_eq(JsonIO.inspect(BAK)["data"]["data"]["coins"], 1)
	assert_eq(JsonIO.inspect(PATH)["data"]["data"]["coins"], 2)
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "geçici dosya kalmamalı")


func test_saved_file_has_version_and_valid_checksum() -> void:
	_make_good_pair()
	var payload: Dictionary = JsonIO.inspect(PATH)["data"]
	assert_eq(int(payload["version"]), SAVE_SCRIPT.SAVE_VERSION)
	assert_true(SAVE_SCRIPT.is_valid_payload(payload))
	payload["data"]["coins"] = 999  # içerik elle değiştirildi, sağlama toplamı tutmaz
	assert_false(SAVE_SCRIPT.is_valid_payload(payload))


func test_roundtrip_keeps_ints_and_floats_stable_for_checksum() -> void:
	var writer := _manager()
	writer.data = {"cash": 123456, "ratio": 0.5, "list": [1, 2, 3], "nested": {"a": 7}}
	writer.save_game()
	var reader := _manager()
	assert_eq(reader.load_game(), SAVE_SCRIPT.LOAD_OK, "tamsayı/ondalık gidiş-dönüşte sağlama bozulmamalı")
	assert_eq(reader.data["cash"], 123456)


func test_corrupt_main_with_good_backup_recovers_silently() -> void:
	_make_good_pair()
	_write_raw(PATH, "{ bozuk json ")
	var manager := _manager()
	var issues: Array[String] = []
	manager.load_issue.connect(func(status: String) -> void: issues.append(status))
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_RECOVERED)
	assert_eq(manager.data["coins"], 1, "yedekteki içerik geri geldi")
	assert_eq(issues, ["recovered_backup"])
	assert_eq(JsonIO.inspect(PATH)["status"], JsonIO.READ_OK, "ana dosya yedekten yeniden yazıldı")
	assert_eq(JsonIO.corrupt_copies(PATH).size(), 1, "bozuk dosya silinmedi, kenara alındı")
	assert_eq(_read_raw(JsonIO.corrupt_copies(PATH)[0]), "{ bozuk json ")
	var again := _manager()
	assert_eq(again.load_game(), SAVE_SCRIPT.LOAD_OK, "bir sonraki açılış normal")


func test_truncated_main_recovers_from_backup() -> void:
	_make_good_pair()
	var whole := _read_raw(PATH)
	_write_raw(PATH, whole.substr(0, whole.length() / 2))  # yazma yarıda kesilmiş gibi
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_RECOVERED)
	assert_eq(manager.data["coins"], 1)


func test_empty_main_recovers_from_backup() -> void:
	_make_good_pair()
	_write_raw(PATH, "")
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_RECOVERED)
	assert_eq(manager.data["coins"], 1)


func test_tampered_checksum_is_treated_as_corrupt() -> void:
	_make_good_pair()
	var payload: Dictionary = JsonIO.inspect(PATH)["data"]
	payload["data"]["coins"] = 999
	JsonIO.write_dict(PATH, payload)
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_RECOVERED)
	assert_eq(manager.data["coins"], 1)


func test_wrong_shape_payloads_are_corrupt() -> void:
	for text: String in ["[]", "{}", "{\"version\": 2}", "{\"version\": 2, \"data\": 5}", "{\"version\": 0, \"data\": {}}",
			"{\"version\": \"x\", \"data\": {}}", "{\"data\": {}}", "null", "42"]:
		_cleanup()
		_write_raw(PATH, text)
		var manager := _manager()
		assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_UNRECOVERABLE, "geçersiz zarf: %s" % text)
		assert_eq(manager.data, {})


func test_missing_main_with_good_backup_recovers() -> void:
	_make_good_pair()
	DirAccess.remove_absolute(PATH)  # rename öncesi/sonrası kesinti
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_RECOVERED)
	assert_eq(manager.data["coins"], 1)
	assert_true(FileAccess.file_exists(PATH), "ana dosya yeniden oluşturuldu")


func test_both_corrupt_keeps_the_corrupt_copy_and_never_overwrites_it() -> void:
	_make_good_pair()
	_write_raw(PATH, "{ ana bozuk")
	_write_raw(BAK, "{ yedek de bozuk")
	var manager := _manager()
	var issues: Array[String] = []
	manager.load_issue.connect(func(status: String) -> void: issues.append(status))
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_UNRECOVERABLE)
	assert_eq(manager.data, {}, "kurtarılamayınca boş kayıt, çökme yok")
	assert_eq(issues, ["unrecoverable"])
	var copies := JsonIO.corrupt_copies(PATH)
	assert_eq(copies.size(), 1)
	assert_eq(_read_raw(copies[0]), "{ ana bozuk", "bozuk kopya bayt bayt duruyor")
	# Oyun devam edip kaydederse bozuk kopya yerinde kalır, bozuk yedek sağlam dosyayı ezmez.
	manager.data = {"coins": 5}
	assert_eq(manager.save_game(), OK)
	assert_eq(JsonIO.corrupt_copies(PATH).size(), 1)
	assert_eq(_read_raw(JsonIO.corrupt_copies(PATH)[0]), "{ ana bozuk")
	var again := _manager()
	assert_eq(again.load_game(), SAVE_SCRIPT.LOAD_OK)
	assert_eq(again.data["coins"], 5)


func test_corrupt_main_without_backup_is_quarantined_not_deleted() -> void:
	_write_raw(PATH, "yarım")
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_UNRECOVERABLE)
	assert_false(FileAccess.file_exists(PATH), "bozuk dosya yolundan çekildi")
	assert_eq(JsonIO.corrupt_copies(PATH).size(), 1)


func test_corrupt_main_does_not_overwrite_the_good_backup_on_next_save() -> void:
	_make_good_pair()
	_write_raw(PATH, "{ bozuk")
	# Yükleme yapılmadan doğrudan kaydedilirse bile bozuk dosya yedeğe kopyalanmaz.
	var writer := _manager()
	writer.data = {"coins": 3}
	assert_eq(writer.save_game(), OK)
	assert_eq(JsonIO.inspect(BAK)["data"]["data"]["coins"], 1, "sağlam yedek bozuk dosyayla ezilmedi")


func test_leftover_tmp_from_interrupted_write_is_ignored() -> void:
	_make_good_pair()
	_write_raw(PATH + ".tmp", "{ \"version\": 2, \"da")  # yazma sırasında süreç öldürülmüş
	var manager := _manager()
	assert_eq(manager.load_game(), SAVE_SCRIPT.LOAD_OK)
	assert_eq(manager.data["coins"], 2, "ana dosya sağlam, geçici dosya yok sayıldı")
	manager.data = {"coins": 9}
	assert_eq(manager.save_game(), OK)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func test_failed_write_leaves_the_existing_file_untouched() -> void:
	_make_good_pair()
	var before := _read_raw(PATH)
	var err := JsonIO.write_text(PATH, "bu bir JSON nesnesi değil", true)
	assert_ne(err, OK, "geçersiz içerik yazılmaz")
	assert_eq(_read_raw(PATH), before)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func test_corrupt_copies_are_limited() -> void:
	for i in 5:
		_write_raw(PATH, "bozuk %d" % i)
		JsonIO.quarantine(PATH)
	assert_eq(JsonIO.corrupt_copies(PATH).size(), JsonIO.MAX_CORRUPT_COPIES)


func test_reset_game_clears_data_and_backup() -> void:
	_make_good_pair()
	var manager := _manager()
	manager.load_game()
	assert_eq(manager.reset_game(), OK)
	assert_eq(manager.data, {})
	assert_false(FileAccess.file_exists(BAK), "bilerek sıfırlanan ilerleme yedekten geri gelmesin")
	var again := _manager()
	assert_eq(again.load_game(), SAVE_SCRIPT.LOAD_OK)
	assert_eq(again.data, {})


func test_flush_asks_owners_then_writes_only_when_changed() -> void:
	var manager := _manager()
	var saves := [0]
	var requests := [0]
	manager.saved.connect(func() -> void: saves[0] += 1)
	manager.lifecycle_flush_requested.connect(func() -> void:
		requests[0] += 1
		manager.data["pulled"] = true)
	manager.data = {"coins": 1}
	assert_eq(manager.flush(), OK)
	assert_eq(requests[0], 1)
	assert_eq(saves[0], 1, "ilk flush yazar (sahip veri ekledi)")
	manager.flush()
	manager.flush()
	assert_eq(saves[0], 1, "değişiklik yoksa diske yazılmaz")
	manager.data["coins"] = 2
	manager.flush()
	assert_eq(saves[0], 2)
	assert_eq(JsonIO.inspect(PATH)["data"]["data"]["coins"], 2)


func test_pause_focus_out_and_close_notifications_flush() -> void:
	for what: int in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_CLOSE_REQUEST]:
		_cleanup()
		var manager := _manager()
		manager.data = {"marker": what}
		manager.notification(what)
		assert_eq(JsonIO.inspect(PATH)["data"]["data"].get("marker"), what, "bildirim %d kaydetmeli" % what)


func test_flush_recreates_a_deleted_file_even_if_unchanged() -> void:
	var manager := _manager()
	manager.data = {"coins": 1}
	manager.flush()
	DirAccess.remove_absolute(PATH)
	manager.flush()
	assert_true(FileAccess.file_exists(PATH))
