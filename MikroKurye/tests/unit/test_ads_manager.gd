extends TestCase

## Reklam yerleşim limitleri ve deneme/ödül akışı (ARCHITECTURE §5.5).
## Gerçek ağ/SDK yok: `InstantProvider` ödülü aynı çağrıda verir, böylece
## `show_rewarded` sözleşmesi kare beklemeden sınanır.
##
## Varsayımlar (sözleşmede açık değil):
## - Başarısız `show_rewarded` per_run sayacını artırmaz.
## - `set_trial` bilinmeyen kategoriyi yok sayar; `trial()` boş kalır.
## - `grant` negatif değerleri eklemez (Wallet.add kuralı).

const ADS_PATH: String = "res://data/ads.json"
const SAVE_PATH: String = "res://tests/unit/.tmp_test_ads_manager.json"
const REAL_SAVE_PATH: String = "user://save.json"


class InstantProvider extends AdsProvider:
	func initialize() -> void:
		pass

	func is_ready(_placement: int) -> bool:
		return true

	func show(_placement: int) -> void:
		rewarded.emit()


class PendingProvider extends AdsProvider:
	func is_ready(_placement: int) -> bool:
		return true

	func show(_placement: int) -> void:
		shown.emit()


var _ad: Node = null
var _save: Node = null


func before_each() -> void:
	_ad = autoload_node("AdManager")
	_save = autoload_node("SaveService")
	_remove_save()
	if _save != null:
		_save.call("set_save_path", SAVE_PATH)
		_save.call("load_profile")
		_save.call("clear_trial")
	if _ad != null:
		_ad.call("set_provider", InstantProvider.new())
		_ad.call("reset_session_limits")


func after_each() -> void:
	if _ad != null:
		_ad.call("set_provider", MockAdsProvider.new())
		_ad.call("reset_session_limits")
	if _save != null:
		_remove_save()
		_save.call("set_save_path", REAL_SAVE_PATH)
		_save.call("load_profile")
		_save.call("clear_trial")


func _remove_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _wallet() -> Dictionary:
	var profile: ProfileData = _save.call("profile") as ProfileData
	if profile == null:
		return {}
	return profile.wallet().to_dict()


## Enum ve limit tablosunu çalışma anında okur: probe gibi `-s` modunda da
## `AdManager` kimliğine derleme anında ihtiyaç duymayız.
func _constants() -> Dictionary:
	if _ad == null:
		return {}
	var script: GDScript = _ad.get_script() as GDScript
	if script == null:
		return {}
	return script.get_script_constant_map()


func _placement_id(name: String) -> int:
	var constants: Dictionary = _constants()
	var placements: Dictionary = constants.get("Placement", {}) as Dictionary
	return int(placements.get(name, -1))


func test_ads_json_matches_contract() -> void:
	var text: String = FileAccess.get_file_as_string(ADS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary, "data/ads.json ayrıştırılabilmeli")
	if not parsed is Dictionary:
		return
	var limits: Dictionary = parsed as Dictionary
	var expected: Dictionary = {
		"CARGO_INSURANCE": [1, 5],
		"BATTERY_RECHARGE": [1, 5],
		"DOUBLE_REWARD": [1, 3],
		"TRY_BEFORE_BUY": [1, 3],
		"GOLDEN_BOX": [1, 3],
	}
	for key: String in expected.keys():
		var want: Array = expected[key]
		var entry: Variant = limits.get(key)
		assert_true(entry is Dictionary, "%s limiti eksik" % key)
		if entry is Dictionary:
			var row: Dictionary = entry as Dictionary
			assert_eq(int(row.get("per_run", -1)), int(want[0]), "%s per_run" % key)
			assert_eq(int(row.get("per_session", -1)), int(want[1]), "%s per_session" % key)
	assert_false(limits.has("EXTRA_POCKET"), "şablon kalıntısı EXTRA_POCKET kalmamalı")
	assert_false(limits.has("TAPE_RESCUE"), "şablon kalıntısı TAPE_RESCUE kalmamalı")

	# Enum da aynı sözleşmeyi taşımalı: 5 yerleşim, şablon adları yok.
	var constants: Dictionary = _constants()
	var placements: Dictionary = constants.get("Placement", {}) as Dictionary
	assert_eq(placements.size(), 5, "Placement 5 yerleşim içermeli")
	assert_false(placements.has("EXTRA_POCKET"), "Placement'ta EXTRA_POCKET olmamalı")
	assert_false(placements.has("TAPE_RESCUE"), "Placement'ta TAPE_RESCUE olmamalı")
	var keys: Dictionary = constants.get("PLACEMENT_KEYS", {}) as Dictionary
	assert_eq(keys.size(), 5, "PLACEMENT_KEYS 5 anahtar içermeli")


func test_per_run_limit_blocks_second_offer_and_reset_restores() -> void:
	if _ad == null:
		fail("AdManager autoload yok")
		return
	for name: String in ["CARGO_INSURANCE", "BATTERY_RECHARGE", "DOUBLE_REWARD",
			"TRY_BEFORE_BUY", "GOLDEN_BOX"]:
		var placement: int = _placement_id(name)
		assert_greater(float(placement), -1.0, "%s enum değeri yok" % name)
		_ad.call("reset_run_limits")
		assert_true(bool(_ad.call("can_offer", placement)), "%s ilk teklif açık olmalı" % name)
		_ad.call("show_rewarded", placement)
		assert_eq(int(_ad.call("used_in_run", placement)), 1, "%s tur sayacı" % name)
		assert_false(bool(_ad.call("can_offer", placement)),
			"%s per_run=1 ikinci teklifi engellemeli" % name)
		_ad.call("reset_run_limits")
		assert_true(bool(_ad.call("can_offer", placement)),
			"%s tur limiti sıfırlanınca yeniden açılmalı" % name)
		_ad.call("reset_session_limits")


func test_session_limit_blocks_after_three_double_rewards() -> void:
	if _ad == null:
		fail("AdManager autoload yok")
		return
	var placement: int = _placement_id("DOUBLE_REWARD")
	for i: int in range(3):
		_ad.call("reset_run_limits")
		assert_true(bool(_ad.call("can_offer", placement)), "deneme %d açık olmalı" % i)
		_ad.call("show_rewarded", placement)
	assert_false(bool(_ad.call("can_offer", placement)),
		"per_session=3 sonrası teklif kapanmalı")
	_ad.call("reset_session_limits")
	assert_true(bool(_ad.call("can_offer", placement)),
		"oturum limiti sıfırlanınca teklif açılmalı")


func test_grant_adds_to_wallet_and_ignores_negative() -> void:
	if _save == null:
		fail("SaveService autoload yok")
		return
	_save.call("grant", 12, 3)
	assert_eq(_wallet(), {"gold": 12, "scrap": 3}, "grant cüzdana eklemeli")
	_save.call("grant", -5, -2)
	assert_eq(_wallet(), {"gold": 12, "scrap": 3}, "negatif grant eklememeli")


func test_trial_adds_next_level_mods_and_is_one_shot_source() -> void:
	if _save == null:
		fail("SaveService autoload yok")
		return
	_save.call("set_trial", "chassis")
	assert_eq(str(_save.call("trial")), "chassis", "trial kategoriyi saklamalı")
	var mods: Dictionary = _save.call("mods") as Dictionary
	assert_almost_eq(float(mods.get("cargo_damping_bonus", -1.0)), 1.0,
		0.001, "deneme sonraki seviyenin modunu eklemeli")
	_save.call("clear_trial")
	assert_eq(str(_save.call("trial")), "", "clear_trial temizlemeli")
	var cleared: Dictionary = _save.call("mods") as Dictionary
	assert_false(cleared.has("cargo_damping_bonus"),
		"deneme temizlenince mod kalmamalı")


func test_failed_and_dismissed_ads_preserve_limits() -> void:
	var pending: PendingProvider = PendingProvider.new()
	_ad.call("set_provider", pending)
	var placement: int = _placement_id("CARGO_INSURANCE")
	_ad.call("show_rewarded", placement)
	assert_false(bool(_ad.call("can_offer", placement)), "bekleyen reklam ikinci isteği engellemeli")
	pending.failed.emit("no_fill")
	assert_eq(int(_ad.call("used_in_run", placement)), 0, "başarısızlık hakkı tüketmez")
	assert_true(bool(_ad.call("can_offer", placement)), "başarısız reklam tekrar teklif edilebilir")
	_ad.call("show_rewarded", placement)
	pending.dismissed.emit()
	assert_eq(int(_ad.call("used_in_run", placement)), 0, "erken kapatma ödül değildir")
	assert_true(bool(_ad.call("can_offer", placement)), "erken kapanış pending kilidini açmalı")


func test_run_reset_does_not_assign_old_reward_to_new_run() -> void:
	var pending: PendingProvider = PendingProvider.new()
	_ad.call("set_provider", pending)
	var placement: int = _placement_id("BATTERY_RECHARGE")
	_ad.call("show_rewarded", placement)
	_ad.call("reset_run_limits")
	assert_false(bool(_ad.call("can_offer", placement)), "eski callback bitmeden yeni istek açılmaz")
	pending.rewarded.emit()
	assert_eq(int(_ad.call("used_in_run", placement)), 0, "eski ödül yeni turun hakkını tüketmez")
	assert_true(bool(_ad.call("can_offer", placement)), "eski callback sonrası yeni tur açılmalı")


func test_provider_change_closes_pending_and_ignores_old_callbacks() -> void:
	var old: PendingProvider = PendingProvider.new()
	_ad.call("set_provider", old)
	var placement: int = _placement_id("DOUBLE_REWARD")
	_ad.call("show_rewarded", placement)
	_ad.call("set_provider", InstantProvider.new())
	old.rewarded.emit()
	assert_eq(int(_ad.call("used_in_run", placement)), 0, "eski provider ödülü işlenmez")
	assert_true(bool(_ad.call("can_offer", placement)), "provider değişimi pending'i kapatmalı")


func test_duplicate_provider_reward_only_counts_once() -> void:
	var pending: PendingProvider = PendingProvider.new()
	_ad.call("set_provider", pending)
	var placement: int = _placement_id("GOLDEN_BOX")
	_ad.call("show_rewarded", placement)
	pending.rewarded.emit()
	pending.rewarded.emit()
	pending.dismissed.emit()
	assert_eq(int(_ad.call("used_in_run", placement)), 1, "yinelenen callback hak tüketmez")


func test_trial_is_removed_on_same_controller_restart() -> void:
	_save.call("set_trial", "chassis")
	var packed: PackedScene = load("res://scenes/Game.tscn") as PackedScene
	var game: Node = packed.instantiate()
	tree.root.add_child(game)
	var initial: Dictionary = game.call("state") as Dictionary
	var initial_mods: Dictionary = initial.get("mods", {}) as Dictionary
	assert_almost_eq(float(initial_mods.get("cargo_damping_bonus", 0.0)), 1.0,
		0.001, "deneme ilk koşuda uygulanmalı")
	assert_eq(str(_save.call("trial")), "", "uygulanan deneme kaynağı hemen tüketilmeli")
	game.call("restart")
	var restarted: Dictionary = game.call("state") as Dictionary
	var restart_mods: Dictionary = restarted.get("mods", {}) as Dictionary
	assert_almost_eq(float(restart_mods.get("cargo_damping_bonus", 0.0)), 0.0,
		0.001, "aynı controller restart denemeyi ikinci kez kullanamaz")
	game.free()


func test_success_with_zero_stars_can_double_and_claims_survive_reopen() -> void:
	var manager: Node = autoload_node("GameManager")
	var previous: Dictionary = manager.get("last_result") as Dictionary
	var previous_phase: int = int(manager.get("phase"))
	var result: Dictionary = {"success": true, "stars": 0, "gold": 10,
		"scrap": 1, "golden_box": true}
	manager.set("last_result", result)
	var packed: PackedScene = load("res://scenes/Result.tscn") as PackedScene
	var screen: Node = packed.instantiate()
	tree.root.add_child(screen)
	var double_button: Button = screen.find_child("DoubleRewardButton", true, false) as Button
	var golden_button: Button = screen.find_child("GoldenBoxButton", true, false) as Button
	assert_true(double_button.visible, "başarılı sıfır yıldızlı sonuç da 2× teklif almalı")
	double_button.pressed.emit()
	golden_button.pressed.emit()
	assert_true(bool(result.get("doubled", false)), "2× alındı işareti sonuçta saklanmalı")
	assert_true(bool(result.get("golden_box_claimed", false)), "kutu alındı işareti sonuçta saklanmalı")
	var claimed_wallet: Dictionary = _wallet()
	double_button.pressed.emit()
	golden_button.pressed.emit()
	assert_eq(_wallet(), claimed_wallet, "programatik ikinci pressed ödül veremez")
	screen.free()
	_ad.call("reset_run_limits")
	screen = packed.instantiate()
	tree.root.add_child(screen)
	double_button = screen.find_child("DoubleRewardButton", true, false) as Button
	golden_button = screen.find_child("GoldenBoxButton", true, false) as Button
	assert_false(double_button.visible, "yeniden açılan sonuç 2× teklifini yineleyemez")
	assert_false(golden_button.visible, "yeniden açılan sonuç kutu teklifini yineleyemez")
	double_button.pressed.emit()
	golden_button.pressed.emit()
	assert_eq(_wallet(), claimed_wallet, "ekran yeniden açılınca ödül değişmemeli")
	screen.free()
	manager.set("last_result", previous)
	manager.call("set_phase", previous_phase)


func test_trial_unknown_category_is_ignored() -> void:
	if _save == null:
		fail("SaveService autoload yok")
		return
	_save.call("set_trial", "kanatlar")
	assert_eq(str(_save.call("trial")), "", "bilinmeyen kategori deneme açmamalı")
