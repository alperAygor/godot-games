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


# --- Priz eklemeleri: yıldız, seri, sigorta hakkı, kalite, geçiş reklamı sayaçları --------------

func test_stars_are_recorded_per_level_and_keep_the_best() -> void:
	var data: ProgressData = ProgressData.new()
	var result: Dictionary = data.complete_level(_balance, 2)
	assert_eq(int(result["finished_level"]), 1)
	assert_eq(data.stars_for(1), 2)
	data.set_stars(1, 1)
	assert_eq(data.stars_for(1), 2, "daha düşük yıldız eskisini ezmez")
	data.set_stars(1, 9)
	assert_eq(data.stars_for(1), ProgressData.MAX_STARS, "üst sınır 3")
	data.set_stars(0, 3)
	assert_eq(data.stars_for(0), 0, "geçersiz seviye yok sayılır")
	data.complete_level(_balance, 0)
	assert_eq(data.stars_for(2), 0)
	assert_eq(data.total_stars(), 3)


func test_win_streak_grows_on_win_and_resets_on_loss() -> void:
	var data: ProgressData = ProgressData.new()
	data.complete_level(_balance)
	var second: Dictionary = data.complete_level(_balance)
	assert_eq(data.win_streak, 2)
	assert_eq(int(second["streak"]), 2)
	data.record_loss()
	assert_eq(data.win_streak, 0)
	assert_eq(data.level, 3, "kayıp seviyeyi ve jetonu değiştirmez")
	assert_eq(data.coins, 40)


func test_fuses_are_per_level_and_never_saved() -> void:
	var data: ProgressData = ProgressData.new()
	data.begin_level_fuses(3)
	assert_eq(data.lose_fuse(), 2)
	assert_eq(data.lose_fuse(), 1)
	assert_eq(data.lose_fuse(), 0)
	assert_eq(data.lose_fuse(), 0, "sıfırın altına inmez")
	data.grant_extra_fuse()
	assert_eq(data.fuses_left, 1, "ödüllü ek hak +1")
	var saved: Dictionary = data.to_dict()
	assert_false(saved.has("fuses_left") or saved.has("fuses"), "sigorta hakkı kaydedilmez")
	assert_eq(ProgressData.from_dict(saved).fuses_left, 0)


func test_quality_tier_validates_and_persists() -> void:
	var data: ProgressData = ProgressData.new()
	assert_eq(data.quality_tier, "high")
	data.set_quality_tier("low")
	data.set_quality_tier("ultra")
	assert_eq(data.quality_tier, "low", "geçersiz kademe yok sayılır")
	assert_eq(ProgressData.from_dict(data.to_dict()).quality_tier, "low")
	assert_eq(ProgressData.from_dict({"quality_tier": "x"}).quality_tier, "high")


func test_round_trip_keeps_stars_streak_and_interstitial_counters() -> void:
	var data: ProgressData = ProgressData.new()
	data.complete_level(_balance, 3)
	data.complete_level(_balance, 1)
	data.note_interstitial(777.0)
	data.mark_seen("intro_room")
	data.modules["neighbourhood"] = {"windows": [1, 2]}
	var again: ProgressData = ProgressData.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	assert_eq(again.stars_for(1), 3)
	assert_eq(again.stars_for(2), 1)
	assert_eq(again.win_streak, 2)
	assert_eq(again.interstitials_shown, 1)
	assert_eq(again.levels_since_interstitial, 0)
	assert_almost_eq(again.last_interstitial_time, 777.0)
	assert_true(again.seen("intro_room"))
	assert_true(again.modules.has("neighbourhood"))


func test_corrupt_stars_are_sanitised() -> void:
	var data: ProgressData = ProgressData.from_dict({"stars": {"1": 7, "x": 3, "-2": 1, "3": "çöp"}, "win_streak": -4})
	assert_eq(data.stars_for(1), 3)
	assert_eq(data.level_stars.size(), 2, "yalnız geçerli seviye anahtarları kalır")
	assert_eq(data.win_streak, 0)


func test_balance_defaults_cover_display_blocks() -> void:
	var loaded: Dictionary = ProgressData.load_balance()
	for key: String in ["coin_display", "level_pips", "haptics", "fuses_per_level"]:
		assert_true(loaded.has(key), key)
