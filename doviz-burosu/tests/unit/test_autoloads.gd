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
	save_manager.save_path = "user://test_save.json"
	save_manager.data = {"coins": 123}
	assert_eq(save_manager.save_game(), OK)
	save_manager.data = {}
	save_manager.load_game()
	assert_eq(save_manager.data.get("coins"), 123)
	save_manager.save_path = original_path


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
