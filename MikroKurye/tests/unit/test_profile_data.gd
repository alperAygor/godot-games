extends TestCase

## ProfileData: kayıt veri modeli (cüzdan, seviyeler, istatistikler). Sözleşme: ARCHITECTURE.md §4.8.
## Sınıf henüz YOK — testler sözleşmeden türetildi (kırmızı aşama).
##
## Varsayımlar (sözleşmede açık değil):
## - `stats()` dönen sözlüğün `best_stars` iç sözlüğünü de kopyalar; döneni değiştirmek
##   profili etkilemez (KOPYA sözleşmesinin güvenli yorumu).
## - `from_dict` negatif sayıları 0'a kırpar, küsuratlı sayıları geçersiz sayıp 0 yapar.
## - Yüksek/bilinmeyen sürüm tanıdık alanları okur; bilinmeyen anahtarlar yok sayılır.
## - `record_result` içinde `success` anahtarı eksikse başarısız tur sayılır.
## - Başarılı turda negatif ödül 0 ekler; teslimat ve yıldız yine işlenir.

const DEFAULT_DICT: Dictionary = {
	"version": 1,
	"wallet": {"gold": 0, "scrap": 0},
	"levels": {"chassis": 0, "wheels": 0, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0},
	"stats": {"deliveries": 0, "breaks": 0, "best_stars": {}},
	"settings": {"sound_on": true, "tutorial_done": false},
	"records": {"best_level": 0, "best_distance": 0, "best_score": 0, "runs": 0},
}


func _success(gold: int = 10, scrap: int = 2, stars: int = 2,
		cargo_id: String = "pencil_battery") -> Dictionary:
	return {"success": true, "gold": gold, "scrap": scrap, "stars": stars, "cargo_id": cargo_id}


func _failure(gold: int = 10, scrap: int = 2, stars: int = 2,
		cargo_id: String = "pencil_battery") -> Dictionary:
	return {"success": false, "gold": gold, "scrap": scrap, "stars": stars, "cargo_id": cargo_id}


func _from_parsed(raw: Dictionary) -> ProfileData:
	var parsed: Variant = JSON.parse_string(JSON.stringify(raw))
	if not parsed is Dictionary:
		fail("test sözlüğü JSON'a çevrilemedi")
		return ProfileData.new()
	return ProfileData.from_dict(parsed as Dictionary)


func test_new_profile_defaults() -> void:
	var profile: ProfileData = ProfileData.new()
	assert_eq(ProfileData.VERSION, 1, "kayıt sürümü 1 olmalı")
	assert_eq(profile.wallet().gold(), 0)
	assert_eq(profile.wallet().scrap(), 0)
	assert_eq(profile.level("chassis"), 0)
	assert_eq(profile.level("wheels"), 0)
	assert_eq(profile.level("battery"), 0)
	assert_eq(profile.levels(), {"chassis": 0, "wheels": 0, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0})
	assert_eq(profile.stats(), {"deliveries": 0, "breaks": 0, "best_stars": {}})
	assert_eq(profile.to_dict(), DEFAULT_DICT)


func test_wallet_is_live_reference() -> void:
	var profile: ProfileData = ProfileData.new()
	var wallet: Wallet = profile.wallet()
	wallet.add(5, 3)

	assert_eq(profile.wallet().gold(), 5, "cüzdan canlı referans olmalı")
	assert_eq(profile.wallet().scrap(), 3)
	assert_eq(profile.to_dict().get("wallet"), {"gold": 5, "scrap": 3},
		"cüzdan değişikliği kayda yansımalı")


func test_set_level_and_accessor() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.set_level("chassis", 2)
	profile.set_level("wheels", 1)

	assert_eq(profile.level("chassis"), 2)
	assert_eq(profile.level("wheels"), 1)
	assert_eq(profile.level("battery"), 0)
	assert_eq(profile.levels(), {"chassis": 2, "wheels": 1, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0})


func test_set_level_negative_clamps_to_zero() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.set_level("chassis", 3)
	profile.set_level("chassis", -1)

	assert_eq(profile.level("chassis"), 0, "negatif seviye 0'a kırpılmalı")


func test_level_unknown_category_is_zero() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.set_level("chassis", 2)

	assert_eq(profile.level("wings"), 0, "bilinmeyen kategori seviyesi 0")


func test_levels_returns_copy() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.set_level("chassis", 1)
	var levels: Dictionary = profile.levels()
	levels["chassis"] = 4
	levels["wings"] = 9

	assert_eq(profile.level("chassis"), 1, "dönen seviyeleri değiştirmek profili etkilememeli")
	assert_false(profile.levels().has("wings"), "dönen kopyaya eklenen kategori profile girmez")
	assert_eq(profile.levels(), {"chassis": 1, "wheels": 0, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0})


func test_record_result_success_adds_reward_and_delivery() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result(_success(40, 2, 2, "pencil_battery"))

	assert_eq(profile.wallet().gold(), 40)
	assert_eq(profile.wallet().scrap(), 2)
	assert_eq(profile.stats().get("deliveries"), 1)
	assert_eq(profile.stats().get("breaks"), 0)
	assert_eq(profile.stats().get("best_stars"), {"pencil_battery": 2})


func test_record_result_failure_counts_break_without_money_or_stars() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result(_failure(40, 2, 3, "pencil_battery"))

	assert_eq(profile.wallet().gold(), 0, "başarısız turda para eklenmemeli")
	assert_eq(profile.wallet().scrap(), 0)
	assert_eq(profile.stats().get("deliveries"), 0)
	assert_eq(profile.stats().get("breaks"), 1)
	assert_eq(profile.stats().get("best_stars"), {}, "başarısız tur yıldız kaydetmemeli")


func test_record_result_missing_success_counts_break() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result({"gold": 40, "scrap": 2, "stars": 3, "cargo_id": "pencil_battery"})

	assert_eq(profile.wallet().gold(), 0, "success eksikse para eklenmemeli")
	assert_eq(profile.stats().get("deliveries"), 0)
	assert_eq(profile.stats().get("breaks"), 1)


func test_record_result_success_negative_rewards_are_zero() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result(_success(-40, -2, 1, "sd_card"))

	assert_eq(profile.wallet().gold(), 0, "negatif gold 0 sayılmalı")
	assert_eq(profile.wallet().scrap(), 0, "negatif scrap 0 sayılmalı")
	assert_eq(profile.stats().get("deliveries"), 1, "başarılı tur yine sayılmalı")
	assert_eq(profile.stats().get("best_stars"), {"sd_card": 1})


func test_record_result_best_stars_keeps_maximum() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result(_success(10, 1, 2, "pencil_battery"))
	profile.record_result(_success(10, 1, 1, "pencil_battery"))
	assert_eq(profile.stats().get("best_stars"), {"pencil_battery": 2},
		"daha düşük yıldız en iyiyi düşürmemeli")

	profile.record_result(_success(10, 1, 3, "pencil_battery"))
	assert_eq(profile.stats().get("best_stars"), {"pencil_battery": 3},
		"daha yüksek yıldız en iyiyi güncellemeli")
	assert_eq(profile.stats().get("deliveries"), 3)


func test_record_result_best_stars_are_per_cargo() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result(_success(10, 1, 1, "pencil_battery"))
	profile.record_result(_success(10, 1, 3, "espresso_capsule"))
	profile.record_result(_success(10, 1, 2, "pencil_battery"))

	assert_eq(profile.stats().get("best_stars"),
		{"pencil_battery": 2, "espresso_capsule": 3}, "her kargo kendi en iyisini tutmalı")


func test_stats_returns_copy_including_nested_best_stars() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result(_success(40, 2, 2, "pencil_battery"))
	var stats: Dictionary = profile.stats()
	stats["deliveries"] = 99
	stats["best_stars"]["pencil_battery"] = 99

	assert_eq(profile.stats().get("deliveries"), 1, "dönen stats kopyası profili etkilememeli")
	assert_eq(profile.stats().get("best_stars"), {"pencil_battery": 2},
		"dönen best_stars kopyası profili etkilememeli")


func test_to_dict_snapshot() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.wallet().add(120, 7)
	profile.set_level("chassis", 2)
	profile.set_level("wheels", 1)
	profile.record_result(_success(40, 2, 3, "sd_card"))
	profile.record_result(_failure(100, 10, 3, "sd_card"))

	var expected: Dictionary = {
		"version": 1,
		"wallet": {"gold": 160, "scrap": 9},
		"levels": {"chassis": 2, "wheels": 1, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0},
		"stats": {"deliveries": 1, "breaks": 1, "best_stars": {"sd_card": 3}},
		"settings": {"sound_on": true, "tutorial_done": false},
		"records": {"best_level": 0, "best_distance": 0, "best_score": 0, "runs": 0},
	}
	assert_eq(profile.to_dict(), expected)


func test_to_dict_round_trips_through_json() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.wallet().add(120, 7)
	profile.set_level("chassis", 2)
	profile.set_level("wheels", 1)
	profile.record_result(_success(40, 2, 3, "sd_card"))
	profile.record_result(_failure(10, 1, 1, "pencil_battery"))

	var parsed: Variant = JSON.parse_string(JSON.stringify(profile.to_dict()))
	if not parsed is Dictionary:
		fail("to_dict çıktısı JSON olarak ayrıştırılamadı")
		return
	var restored: ProfileData = ProfileData.from_dict(parsed as Dictionary)

	assert_eq(restored.to_dict(), profile.to_dict(), "JSON gidiş-dönüş aynı veriyi vermeli")
	assert_eq(restored.wallet().gold(), 160)
	assert_eq(restored.wallet().scrap(), 9)
	assert_eq(restored.level("chassis"), 2)
	assert_eq(restored.stats().get("best_stars"), {"sd_card": 3})


func test_from_dict_empty_returns_defaults() -> void:
	var profile: ProfileData = ProfileData.from_dict({})
	assert_eq(profile.to_dict(), DEFAULT_DICT, "boş kayıt varsayılan profile dönmeli")


func test_from_dict_missing_fields_use_defaults() -> void:
	var profile: ProfileData = ProfileData.from_dict({"version": 1, "wallet": {"gold": 10}})

	assert_eq(profile.wallet().gold(), 10)
	assert_eq(profile.wallet().scrap(), 0)
	assert_eq(profile.levels(), {"chassis": 0, "wheels": 0, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0})
	assert_eq(profile.stats(), {"deliveries": 0, "breaks": 0, "best_stars": {}})
	assert_eq(profile.to_dict().get("version"), 1)


func test_from_dict_wrong_types_use_defaults() -> void:
	var all_wrong: ProfileData = ProfileData.from_dict({
		"version": 1, "wallet": "broken", "levels": [], "stats": 42,
	})
	assert_eq(all_wrong.to_dict(), DEFAULT_DICT, "yanlış kapsayıcı tipi varsayılana dönmeli")

	var field_wrong: ProfileData = ProfileData.from_dict({
		"version": 1,
		"wallet": {"gold": "10", "scrap": true},
		"levels": {"chassis": "2", "wheels": 1},
		"stats": {"deliveries": "3", "breaks": 1, "best_stars": {}},
	})
	assert_eq(field_wrong.wallet().gold(), 0, "metin gold geçersiz")
	assert_eq(field_wrong.wallet().scrap(), 0, "bool scrap geçersiz")
	assert_eq(field_wrong.level("chassis"), 0, "metin seviye geçersiz")
	assert_eq(field_wrong.level("wheels"), 1)
	assert_eq(field_wrong.stats().get("deliveries"), 0, "metin teslimat geçersiz")
	assert_eq(field_wrong.stats().get("breaks"), 1)


func test_from_dict_negative_values_are_zero() -> void:
	var profile: ProfileData = ProfileData.from_dict({
		"version": 1,
		"wallet": {"gold": -10, "scrap": -5},
		"levels": {"chassis": -2, "wheels": 3},
		"stats": {"deliveries": -1, "breaks": -4, "best_stars": {}},
	})

	assert_eq(profile.wallet().gold(), 0)
	assert_eq(profile.wallet().scrap(), 0)
	assert_eq(profile.level("chassis"), 0)
	assert_eq(profile.level("wheels"), 3)
	assert_eq(profile.stats().get("deliveries"), 0)
	assert_eq(profile.stats().get("breaks"), 0)


func test_from_dict_accepts_whole_floats_from_json() -> void:
	var profile: ProfileData = _from_parsed({
		"version": 1.0,
		"wallet": {"gold": 120.0, "scrap": 7.0},
		"levels": {"chassis": 2.0, "wheels": 1.0, "battery": 0.0},
		"stats": {"deliveries": 3.0, "breaks": 1.0, "best_stars": {"sd_card": 3.0}},
	})
	var expected: Dictionary = {
		"version": 1,
		"wallet": {"gold": 120, "scrap": 7},
		"levels": {"chassis": 2, "wheels": 1, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0},
		"stats": {"deliveries": 3, "breaks": 1, "best_stars": {"sd_card": 3}},
		"settings": {"sound_on": true, "tutorial_done": false},
		"records": {"best_level": 0, "best_distance": 0, "best_score": 0, "runs": 0},
	}
	assert_eq(profile.to_dict(), expected, "küsuratsız JSON float tamsayı sayılmalı")
	assert_eq(typeof(profile.wallet().gold()), TYPE_INT)
	assert_eq(typeof(profile.level("chassis")), TYPE_INT)
	assert_eq(typeof(profile.stats().get("deliveries")), TYPE_INT)
	var best: Dictionary = profile.stats().get("best_stars", {})
	assert_eq(typeof(best.get("sd_card")), TYPE_INT)


func test_from_dict_fractional_values_are_invalid() -> void:
	var profile: ProfileData = _from_parsed({
		"version": 1,
		"wallet": {"gold": 10.5, "scrap": 5.0},
		"levels": {"chassis": 1.5, "wheels": 2.0},
		"stats": {"deliveries": 2.5, "breaks": 1.0, "best_stars": {}},
	})

	assert_eq(profile.wallet().gold(), 0, "küsuratlı gold geçersiz")
	assert_eq(profile.wallet().scrap(), 5, "küsuratsız scrap geçerli")
	assert_eq(profile.level("chassis"), 0, "küsuratlı seviye geçersiz")
	assert_eq(profile.level("wheels"), 2)
	assert_eq(profile.stats().get("deliveries"), 0, "küsuratlı teslimat geçersiz")
	assert_eq(profile.stats().get("breaks"), 1)


func test_from_dict_ignores_unknown_level_category() -> void:
	var profile: ProfileData = ProfileData.from_dict({
		"version": 1,
		"levels": {"chassis": 2, "wings": 5},
	})

	assert_eq(profile.levels(), {"chassis": 2, "wheels": 0, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0},
		"yalnız tanıdık kategoriler okunmalı")
	assert_false(profile.levels().has("wings"))
	assert_eq(profile.level("wings"), 0)


func test_from_dict_high_version_reads_known_fields() -> void:
	var profile: ProfileData = ProfileData.from_dict({
		"version": 99,
		"wallet": {"gold": 50, "scrap": 3},
		"levels": {"wheels": 1},
		"stats": {"deliveries": 2, "breaks": 1, "best_stars": {"sd_card": 2}},
		"unknown_key": true,
	})
	var expected: Dictionary = {
		"version": 1,
		"wallet": {"gold": 50, "scrap": 3},
		"levels": {"chassis": 0, "wheels": 1, "battery": 0, "shock_gel": 0, "insurance": 0, "contract": 0},
		"stats": {"deliveries": 2, "breaks": 1, "best_stars": {"sd_card": 2}},
		"settings": {"sound_on": true, "tutorial_done": false},
		"records": {"best_level": 0, "best_distance": 0, "best_score": 0, "runs": 0},
	}
	assert_eq(profile.to_dict(), expected, "yüksek sürümde tanıdık alanlar okunmalı")
	assert_false(profile.to_dict().has("unknown_key"), "bilinmeyen anahtar kayda yazılmamalı")


func test_settings_defaults() -> void:
	var profile: ProfileData = ProfileData.new()
	assert_eq(profile.settings(), {"sound_on": true, "tutorial_done": false})


func test_set_setting_known_keys_and_unknown_ignored() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.set_setting("sound_on", false)
	profile.set_setting("tutorial_done", true)
	profile.set_setting("bilinmeyen", true)

	assert_eq(profile.settings(), {"sound_on": false, "tutorial_done": true},
		"bilinmeyen ayar anahtarı kayda girmemeli")


func test_settings_returns_copy() -> void:
	var profile: ProfileData = ProfileData.new()
	var settings: Dictionary = profile.settings()
	settings["sound_on"] = false
	settings["yeni"] = true

	assert_eq(profile.settings(), {"sound_on": true, "tutorial_done": false},
		"dönen ayar kopyası profili etkilememeli")


func test_settings_round_trips_through_json() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.set_setting("sound_on", false)
	profile.set_setting("tutorial_done", true)
	var parsed: Variant = JSON.parse_string(JSON.stringify(profile.to_dict()))
	if not parsed is Dictionary:
		fail("ayarlı profil JSON'a çevrilemedi")
		return
	var restored: ProfileData = ProfileData.from_dict(parsed as Dictionary)
	assert_eq(restored.settings(), {"sound_on": false, "tutorial_done": true})


func test_settings_missing_and_wrong_types_use_defaults() -> void:
	var missing: ProfileData = ProfileData.from_dict({"settings": {"sound_on": false}})
	assert_eq(missing.settings(), {"sound_on": false, "tutorial_done": false},
		"eksik anahtar varsayılanı korumalı")

	var wrong: ProfileData = ProfileData.from_dict({
		"settings": {"sound_on": "kapali", "tutorial_done": 1},
	})
	assert_eq(wrong.settings(), {"sound_on": true, "tutorial_done": false},
		"bool olmayan ayar varsayılana dönmeli")

	var wrong_container: ProfileData = ProfileData.from_dict({"settings": []})
	assert_eq(wrong_container.settings(), {"sound_on": true, "tutorial_done": false})


func test_endless_result_pays_wallet_and_updates_records() -> void:
	var profile: ProfileData = ProfileData.new()
	var result: Dictionary = {
		"endless": true, "reason": "broken", "success": false,
		"gold": 50, "scrap": 3, "levels_delivered": 2, "level": 3, "distance": 150.0, "score": 220,
	}
	profile.record_result(result)
	assert_eq(profile.wallet().gold(), 50)
	assert_eq(profile.wallet().scrap(), 3)
	assert_eq(int(profile.stats()["deliveries"]), 2)
	assert_eq(int(profile.stats()["breaks"]), 1)
	assert_eq(profile.records().best_level(), 3)
	assert_eq(profile.records().best_distance(), 150)
	assert_true(bool((result["new_records"] as Dictionary)["new_level"]))


func test_endless_non_broken_end_does_not_count_a_break() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result({"endless": true, "reason": "battery", "success": true, "gold": 10, "scrap": 1,
		"levels_delivered": 1, "level": 2, "distance": 70.0, "score": 70})
	assert_eq(int(profile.stats()["breaks"]), 0)
	assert_eq(profile.wallet().gold(), 10)


func test_classic_result_path_is_unchanged_by_endless_branch() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.record_result({"success": false, "gold": 99})
	assert_eq(profile.wallet().gold(), 0)
	assert_eq(int(profile.stats()["breaks"]), 1)
