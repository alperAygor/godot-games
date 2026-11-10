extends TestCase

## PlayerProfile: varsayilanlar, round-trip ve v0 -> v1 migrasyonu.

func test_default_profile_has_settings() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default()
	assert_eq(profile.version, PlayerProfile.SAVE_VERSION)
	assert_eq(profile.currency, 0)
	assert_true(profile.setting("haptics", false) == true, "varsayilan haptik acik olmali")


func test_round_trip_preserves_values() -> void:
	var profile: PlayerProfile = PlayerProfile.create_default()
	profile.currency = 1234
	profile.reputation = 5
	profile.set_upgrade_level("bag_capacity", 2)
	profile.bump_stat("deliveries", 3)
	profile.settings["sfx"] = 0.25

	var restored: PlayerProfile = PlayerProfile.from_dictionary(profile.to_dictionary())
	assert_eq(restored.currency, 1234)
	assert_eq(restored.reputation, 5)
	assert_eq(restored.upgrade_level("bag_capacity"), 2)
	assert_eq(int(restored.stats.get("deliveries", 0)), 3)
	assert_almost_eq(float(restored.setting("sfx", 1.0)), 0.25, 0.0001)


func test_migrates_v0_coins_to_currency() -> void:
	var legacy: Dictionary = {"coins": 750, "reputation": 4}
	var profile: PlayerProfile = PlayerProfile.from_dictionary(legacy)
	assert_eq(profile.version, PlayerProfile.SAVE_VERSION, "surum yukseltilmeli")
	assert_eq(profile.currency, 750, "coins -> currency tasinmali")
	assert_eq(profile.reputation, 4)
	assert_true(profile.setting("music", -1.0) == 0.7, "eksik ayarlar varsayilana donmeli")


func test_missing_fields_fall_back_to_defaults() -> void:
	var profile: PlayerProfile = PlayerProfile.from_dictionary({})
	assert_eq(profile.currency, 0)
	assert_eq(profile.reputation, 3)
	assert_eq(profile.upgrade_level("bilinmeyen"), 0)


func test_wrong_types_do_not_crash() -> void:
	var messy: Dictionary = {"currency": "abc", "upgrades": 5, "settings": "x"}
	var profile: PlayerProfile = PlayerProfile.from_dictionary(messy)
	assert_eq(profile.currency, 0, "gecersiz sayi 0 olmali")
	assert_eq(profile.upgrade_level("bag_capacity"), 0)
	assert_true(profile.setting("sfx", -1.0) == 1.0)
