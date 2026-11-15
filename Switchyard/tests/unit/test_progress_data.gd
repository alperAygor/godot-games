extends TestCase

## ProgressData: ekonomi kuralları (jeton, seviye), ayar/bayrak/modül ve bozuk kayıt toleransı.

var _balance: Dictionary = {}


func before_each() -> void:
	_balance = ProgressData.DEFAULT_BALANCE.duplicate(true)


func test_win_pays_reward_and_advances_level() -> void:
	var data: ProgressData = ProgressData.new()
	var first: Dictionary = data.complete_level(_balance)
	assert_eq(int(first["coins"]), 20)
	assert_eq(int(first["level"]), 2)
	data.complete_level(_balance)
	assert_eq(data.coins, 40)
	assert_eq(data.level, 3)
	assert_eq(data.levels_since_interstitial, 2)


func test_balance_file_matches_defaults() -> void:
	var loaded: Dictionary = ProgressData.load_balance()
	assert_eq(int(loaded["win_coins"]), int(ProgressData.DEFAULT_BALANCE["win_coins"]))
	assert_eq(int(loaded["double_coins_multiplier"]), 2)
	assert_true(bool(loaded["require_online"]), "varsayılan: çevrimdışı oynamak yasak")


func test_spend_coins_refuses_overdraft() -> void:
	var data: ProgressData = ProgressData.new()
	data.add_coins(50)
	assert_false(data.spend_coins(60))
	assert_eq(data.coins, 50)
	assert_true(data.spend_coins(50))
	assert_eq(data.coins, 0)
	assert_false(data.spend_coins(-5))


func test_coins_are_clamped() -> void:
	var data: ProgressData = ProgressData.new()
	data.add_coins(ProgressData.MAX_VALUE + 10)
	assert_eq(data.coins, ProgressData.MAX_VALUE)
	data.add_coins(-ProgressData.MAX_VALUE * 2)
	assert_eq(data.coins, 0)


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
	data.complete_level(_balance)
	data.set_setting("sound", false)
	data.mark_seen("hello")
	data.modules["shop"] = {"remove_ads": true}
	data.last_rewarded_time = 1234.5
	var json: String = JSON.stringify(data.to_dict())
	var again: ProgressData = ProgressData.from_dict(JSON.parse_string(json))
	assert_eq(again.level, 2)
	assert_eq(again.coins, 20)
	assert_false(again.setting("sound"))
	assert_true(again.seen("hello"))
	assert_eq((again.modules["shop"] as Dictionary)["remove_ads"], true)
	assert_almost_eq(again.last_rewarded_time, 1234.5)
	assert_eq(again.levels_since_interstitial, 1)


func test_corrupt_values_fall_back_to_safe_defaults() -> void:
	var data: ProgressData = ProgressData.from_dict({
		"level": "kırık", "coins": -50, "settings": {"sound": "evet", "music": false},
		"seen": [1, "", "ok"], "modules": {"x": 5, "y": {"a": 1}}, "last_rewarded_time": -3})
	assert_eq(data.level, 1)
	assert_eq(data.coins, 0)
	assert_true(data.setting("sound"), "bool olmayan ayar varsayılana düşer")
	assert_false(data.setting("music"))
	assert_eq(data.seen_flags.keys(), ["ok"])
	assert_false(data.modules.has("x"), "sözlük olmayan modül atılır")
	assert_true(data.modules.has("y"))
	assert_eq(data.last_rewarded_time, 0.0)
	assert_eq(ProgressData.from_dict("çöp").level, 1, "sözlük olmayan kayıt varsayılandır")


func test_to_count_handles_json_floats_and_nan() -> void:
	assert_eq(ProgressData.to_count(3.0), 3)
	assert_eq(ProgressData.to_count(NAN, 7), 7)
	assert_eq(ProgressData.to_count("5", 2), 2)
	assert_eq(ProgressData.to_count(-4), 0)
