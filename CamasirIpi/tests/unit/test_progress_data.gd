extends TestCase

## ProgressData: ekonomi kuralları (jeton, seri, hediye güçlendirici) ve bozuk kayıt toleransı.

var _balance: Dictionary = {}


func before_each() -> void:
	_balance = ProgressData.DEFAULT_BALANCE.duplicate(true)


func test_win_pays_normal_and_hard_reward() -> void:
	var data: ProgressData = ProgressData.new()
	var normal: Dictionary = data.complete_level(false, _balance)
	assert_eq(int(normal["coins"]), 20)
	assert_eq(int(normal["stars"]), 1)
	var hard: Dictionary = data.complete_level(true, _balance)
	assert_eq(int(hard["coins"]), 40)
	assert_eq(data.coins, 60)
	assert_eq(data.stars, 2)
	assert_eq(data.level, 3)


func test_balance_file_matches_spec() -> void:
	var loaded: Dictionary = ProgressData.load_balance()
	assert_eq(int(loaded["win_coins"]), 20)
	assert_eq(int(loaded["hard_win_coins"]), 40)
	assert_eq(int(loaded["continue_cost"]), 100)
	var cost: Dictionary = loaded["booster_cost"] as Dictionary
	assert_eq([int(cost["undo"]), int(cost["pin_remover"]), int(cost["extra_slot"])], [60, 80, 100])
	var unlock: Dictionary = loaded["booster_unlock_level"] as Dictionary
	assert_eq([int(unlock["undo"]), int(unlock["pin_remover"]), int(unlock["extra_slot"])], [6, 12, 18])
	assert_eq(int(loaded["booster_unlock_grant"]), 2)


func test_streak_grants_extra_slot_after_three_wins_until_loss() -> void:
	var data: ProgressData = ProgressData.new()
	data.complete_level(false, _balance)
	data.complete_level(false, _balance)
	assert_false(data.streak_extra_slot(_balance))
	var third: Dictionary = data.complete_level(false, _balance)
	assert_true(bool(third["streak_bonus"]))
	assert_true(data.streak_extra_slot(_balance))
	data.complete_level(false, _balance)
	assert_true(data.streak_extra_slot(_balance), "kayba dek sürer")
	data.fail_level()
	assert_false(data.streak_extra_slot(_balance))
	assert_eq(data.streak, 0)
	assert_eq(data.best_streak, 4)


func test_spend_coins_refuses_overdraft() -> void:
	var data: ProgressData = ProgressData.new()
	data.add_coins(50)
	assert_false(data.spend_coins(60))
	assert_eq(data.coins, 50)
	assert_true(data.spend_coins(50))
	assert_eq(data.coins, 0)
	assert_false(data.spend_coins(-5))


func test_booster_unlock_grants_two_once() -> void:
	var data: ProgressData = ProgressData.new()
	data.level = 5
	data.complete_level(false, _balance)  # seviye 6'ya ulaşır
	assert_eq(data.booster_count("undo"), 2)
	assert_eq(data.booster_count("pin_remover"), 0)
	assert_false(data.grant_unlocked_boosters(_balance), "ikinci kez verilmez")
	assert_eq(data.booster_count("undo"), 2)
	data.level = 18
	data.grant_unlocked_boosters(_balance)
	assert_eq(data.booster_count("pin_remover"), 2)
	assert_eq(data.booster_count("extra_slot"), 2)


func test_use_booster_and_unknown_id() -> void:
	var data: ProgressData = ProgressData.new()
	assert_false(data.use_booster("undo"))
	data.add_booster("undo", 1)
	data.add_booster("bogus", 5)
	assert_true(data.use_booster("undo"))
	assert_false(data.use_booster("undo"))
	assert_eq(data.booster_count("bogus"), 0)


func test_round_trip_preserves_everything() -> void:
	var data: ProgressData = ProgressData.new()
	data.level = 9
	data.coins = 330
	data.stars = 8
	data.streak = 2
	data.best_streak = 5
	data.add_booster("undo", 3)
	data.set_setting("music", false)
	data.mark_seen("tutorial")
	data.levels_since_interstitial = 1
	data.last_interstitial_time = 1700000000.5
	var text: String = JSON.stringify(data.to_dict())
	var copy: ProgressData = ProgressData.from_dict(JSON.parse_string(text))
	assert_eq(copy.to_dict(), data.to_dict())
	assert_eq(copy.level, 9)
	assert_false(copy.setting("music"))
	assert_true(copy.setting("sound"))
	assert_true(copy.seen("tutorial"))
	assert_almost_eq(copy.last_interstitial_time, 1700000000.5)


func test_from_dict_tolerates_garbage() -> void:
	assert_eq(ProgressData.from_dict("bozuk").level, 1)
	assert_eq(ProgressData.from_dict(null).coins, 0)
	var data: ProgressData = ProgressData.from_dict({
		"level": "abc", "coins": -50, "stars": 3.0, "streak": NAN,
		"boosters": [1, 2], "settings": {"sound": "evet", "music": false},
		"seen": [1, "a", ""], "last_interstitial_time": "dün"})
	assert_eq(data.level, 1)
	assert_eq(data.coins, 0)
	assert_eq(data.stars, 3)
	assert_eq(data.streak, 0)
	assert_eq(data.booster_count("undo"), 0)
	assert_true(data.setting("sound"))
	assert_false(data.setting("music"))
	assert_true(data.seen("a"))
	assert_false(data.seen(""))
	assert_almost_eq(data.last_interstitial_time, 0.0)


func test_json_floats_become_ints() -> void:
	var data: ProgressData = ProgressData.from_dict({"level": 12.0, "coins": 90.0})
	assert_eq(data.level, 12)
	assert_eq(data.coins, 90)
