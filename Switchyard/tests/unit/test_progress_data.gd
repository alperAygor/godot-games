extends TestCase

## ProgressData: ayar/bayrak/modül, zaman damgaları ve bozuk kayıt toleransı (jeton ekonomisi yok).

func test_balance_file_matches_defaults() -> void:
	var loaded: Dictionary = ProgressData.load_balance()
	assert_eq(int(loaded["three_star_slack"]), int(ProgressData.DEFAULT_BALANCE["three_star_slack"]))
	assert_eq(int(loaded["three_star_slack"]), 0, "varsayılan: 3 yıldız = par")
	assert_true(bool(loaded["require_online"]), "varsayılan: çevrimdışı oynamak yasak")
	assert_false(loaded.has("win_coins"), "jeton ekonomisi yok")


func test_no_coin_or_level_fields_remain() -> void:
	var dict: Dictionary = ProgressData.new().to_dict()
	for key: String in ["coins", "level", "levels_since_interstitial"]:
		assert_false(dict.has(key), "%s kayıtta olmamalı" % key)


func test_settings_default_on_and_ignore_unknown_keys() -> void:
	var data: ProgressData = ProgressData.new()
	for key: String in ProgressData.SETTING_KEYS:
		assert_true(data.setting(key), "%s varsayılan açık" % key)
	data.set_setting("music", false)
	assert_false(data.setting("music"))
	data.set_setting("yok_boyle_ayar", false)
	assert_false(data.settings.has("yok_boyle_ayar"))


func test_seen_flags() -> void:
	var data: ProgressData = ProgressData.new()
	assert_false(data.seen("tutorial"))
	data.mark_seen("tutorial")
	data.mark_seen("")
	assert_true(data.seen("tutorial"))
	assert_eq(data.seen_flags.size(), 1, "boş bayrak yok sayılır")


func test_round_trip_keeps_everything() -> void:
	var data: ProgressData = ProgressData.new()
	data.set_setting("sound", false)
	data.mark_seen("hello")
	data.modules["shop"] = {"remove_ads": true}
	data.last_rewarded_time = 1234.5
	var json: String = JSON.stringify(data.to_dict())
	var again: ProgressData = ProgressData.from_dict(JSON.parse_string(json))
	assert_false(again.setting("sound"))
	assert_true(again.seen("hello"))
	assert_eq((again.modules["shop"] as Dictionary)["remove_ads"], true)
	assert_almost_eq(again.last_rewarded_time, 1234.5)


func test_corrupt_values_fall_back_to_safe_defaults() -> void:
	var data: ProgressData = ProgressData.from_dict({
		"settings": {"sound": "evet", "music": false},
		"seen": [1, "", "ok"], "modules": {"x": 5, "y": {"a": 1}}, "last_rewarded_time": -3})
	assert_true(data.setting("sound"), "bool olmayan ayar varsayılana düşer")
	assert_false(data.setting("music"))
	assert_eq(data.seen_flags.keys(), ["ok"])
	assert_false(data.modules.has("x"), "sözlük olmayan modül atılır")
	assert_true(data.modules.has("y"))
	assert_eq(data.last_rewarded_time, 0.0)
	assert_true(ProgressData.from_dict("çöp").setting("sound"), "sözlük olmayan kayıt varsayılandır")


func test_to_count_handles_json_floats_and_nan() -> void:
	assert_eq(ProgressData.to_count(3.0), 3)
	assert_eq(ProgressData.to_count(NAN, 7), 7)
	assert_eq(ProgressData.to_count("5", 2), 2)
	assert_eq(ProgressData.to_count(-4), 0)
