extends "res://tests/test_case.gd"
## Autoload iskeletlerinin bağlı ve çalışır olduğunu doğrular.

const AUTOLOADS := ["SettingsManager", "SaveManager", "AudioManager", "GameData", "Analytics", "Ads", "IAP", "Monetization"]


func _autoload(autoload_name: String) -> Node:
	return tree.root.get_node_or_null(autoload_name)


func test_all_autoloads_present() -> void:
	for autoload_name in AUTOLOADS:
		assert_true(_autoload(autoload_name) != null, "%s autoload'u yüklenmeli" % autoload_name)


func test_game_data_reads_balance_from_data_folder() -> void:
	var game_data := _autoload("GameData")
	assert_true(game_data.has_table("balance"), "data/balance.json yüklenmeli")
	assert_true(game_data.get_value("balance", "shift.shift_seconds", 0) > 0)


func test_save_manager_roundtrip() -> void:
	var save_manager := _autoload("SaveManager")
	var original_path: String = save_manager.save_path
	var original_data: Dictionary = save_manager.data
	save_manager.save_path = "user://_sandbox/test_save.json"
	save_manager.data = {"coins": 123}
	assert_eq(save_manager.save_game(), OK)
	save_manager.data = {}
	save_manager.load_game()
	assert_eq(save_manager.data.get("coins"), 123)
	save_manager.save_path = original_path
	save_manager.data = original_data
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://_sandbox/test_save.json" + suffix)


func test_audio_buses_exist() -> void:
	assert_ne(AudioServer.get_bus_index(&"Music"), -1, "Music bus'ı olmalı")
	assert_ne(AudioServer.get_bus_index(&"SFX"), -1, "SFX bus'ı olmalı")


func test_ads_default_provider_gives_no_reward() -> void:
	var ads := _autoload("Ads")
	var original: AdsProvider = ads.provider
	ads.set_provider(AdsProvider.new())  # debug sürümde Monetization sahte sağlayıcı koyar; temel sınıfı elle seç
	assert_false(ads.is_rewarded_ready("test"))
	ads.set_provider(original)


func test_ads_mock_provider_rewards() -> void:
	var ads := _autoload("Ads")
	var original: AdsProvider = ads.provider
	ads.set_provider(MockAdsProvider.new())
	ads.show_rewarded("test")
	var result: Array = await ads.rewarded_finished
	assert_eq(result[0], "test")
	assert_true(result[1], "sahte sağlayıcı ödül vermeli")
	ads.set_provider(original)


func test_iap_reads_products_from_data() -> void:
	var iap := _autoload("IAP")
	assert_true("no_ads" in iap.get_product_ids())
	var original: IapProvider = iap.provider
	iap.set_provider(IapProvider.new())
	assert_false(iap.is_available(), "gerçek SDK yokken mağaza kapalı olmalı")
	iap.set_provider(original)


# --- Ayar kalıcılığı ve test yalıtımı -------------------------------------------------------------------------

const SETTINGS_SCRIPT := preload("res://scripts/autoload/settings_manager.gd")
const SETTINGS_PATH := "user://_sandbox/test_settings.cfg"


func _clean_settings_files() -> void:
	for file_name in DirAccess.get_files_at(JsonIO.SANDBOX_DIR):
		if file_name.begins_with("test_settings"):
			DirAccess.remove_absolute(JsonIO.SANDBOX_DIR.path_join(file_name))


func _new_settings() -> Node:
	DirAccess.make_dir_recursive_absolute(JsonIO.SANDBOX_DIR)
	var settings: Node = SETTINGS_SCRIPT.new()
	settings.settings_path = SETTINGS_PATH
	return settings


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_autoload_settings_use_the_sandbox_not_the_real_file() -> void:
	var settings := _autoload("SettingsManager")
	assert_true(settings.settings_path.begins_with(JsonIO.SANDBOX_DIR), "testte ayarlar sandbox'ta")
	assert_true(_autoload("SaveManager").save_path.begins_with(JsonIO.SANDBOX_DIR), "testte kayıt sandbox'ta")


func test_settings_roundtrip_atomic_with_backup() -> void:
	_clean_settings_files()
	var settings := _new_settings()
	settings.set_value("audio", "music", 0.25)
	settings.set_value("audio", "music", 0.5)
	assert_false(FileAccess.file_exists(SETTINGS_PATH + ".tmp"))
	assert_true(FileAccess.file_exists(SETTINGS_PATH + ".bak"), "önceki geçerli dosya yedekte")
	var reader := _new_settings()
	reader.load_settings()
	assert_almost_eq(reader.get_value("audio", "music"), 0.5)
	assert_eq(int(ConfigFile.new().load(SETTINGS_PATH + ".bak")), OK)
	settings.free()
	reader.free()
	_clean_settings_files()


func test_corrupt_settings_recover_from_backup_and_keep_a_copy() -> void:
	_clean_settings_files()
	var settings := _new_settings()
	settings.set_value("audio", "music", 0.25)
	settings.set_value("audio", "music", 0.5)
	_write_text(SETTINGS_PATH, "[audio\nmusic")
	var reader := _new_settings()
	reader.load_settings()
	assert_almost_eq(reader.get_value("audio", "music"), 0.25, 0.0001, "yedekten kurtarıldı")
	assert_eq(JsonIO.corrupt_copies(SETTINGS_PATH).size(), 1, "bozuk dosya kenara alındı")
	var again := _new_settings()
	again.load_settings()
	assert_almost_eq(again.get_value("audio", "music"), 0.25, 0.0001, "ana dosya yeniden yazıldı")
	settings.free()
	reader.free()
	again.free()
	_clean_settings_files()


func test_corrupt_settings_without_backup_fall_back_to_defaults() -> void:
	_clean_settings_files()
	_write_text(SETTINGS_PATH, "[[[ bozuk")
	var reader := _new_settings()
	reader.load_settings()
	assert_almost_eq(reader.get_value("audio", "music"), 0.8)
	assert_true(reader.get_value("game", "pixel_filter"))
	reader.free()
	_clean_settings_files()


func test_wrongly_typed_or_out_of_range_settings_are_sanitized() -> void:
	_clean_settings_files()
	_write_text(SETTINGS_PATH, "[audio]\nmusic=\"yüksek\"\nsfx=7.5\n[game]\nvibration=\"evet\"\nlanguage=3\npixel_filter=false\n")
	var reader := _new_settings()
	reader.load_settings()
	assert_almost_eq(reader.get_value("audio", "music"), 0.8, 0.0001, "yanlış tip varsayılana döner")
	assert_almost_eq(reader.get_value("audio", "sfx"), 1.0, 0.0001, "aralık dışı 0..1'e kırpılır")
	assert_true(reader.get_value("game", "vibration"))
	assert_eq(reader.get_value("game", "language"), "")
	assert_false(reader.get_value("game", "pixel_filter"), "geçerli değer korunur")
	reader.free()
	_clean_settings_files()


func test_settings_without_persist_never_touch_the_disk() -> void:
	_clean_settings_files()
	var settings := _new_settings()
	settings.persist = false
	settings.set_value("audio", "master", 0.1)
	assert_false(FileAccess.file_exists(SETTINGS_PATH))
	assert_almost_eq(settings.get_value("audio", "master"), 0.1)
	settings.free()


func test_settings_file_gets_a_version_stamp() -> void:
	_clean_settings_files()
	var settings := _new_settings()
	settings.set_value("game", "vibration", false)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	assert_eq(int(config.get_value("meta", "version", 0)), SETTINGS_SCRIPT.SETTINGS_VERSION)
	settings.free()
	_clean_settings_files()


# --- Ses yaşam döngüsü ------------------------------------------------------------------------------------------

func test_audio_pauses_on_background_and_resumes_on_return() -> void:
	var audio := _autoload("AudioManager")
	assert_false(audio.is_suspended())
	audio.notification(Node.NOTIFICATION_APPLICATION_PAUSED)  # telefon araması / ana ekrana dönüş
	assert_true(audio.is_suspended())
	audio.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_false(audio.is_suspended())
	audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(audio.is_suspended())
	audio.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(audio.is_suspended())
	# Duraklatılmışken yeni ses başlatılmaz ve müzik duraklatılmış başlar; dönünce her şey açılır.
	audio.suspend()
	audio.play_sfx(audio.blip_stream(0.5))
	for player: AudioStreamPlayer in audio._sfx_players:
		assert_false(player.playing, "arka planda efekt çalmamalı")
	audio.resume()
