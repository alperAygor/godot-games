extends TestCase

## AdmobAdsProvider durum makinesi (sahte köprüyle) ve kimlik seçimi. Eklenti gerekmez.

const TEST_REWARDED: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_APP: String = "ca-app-pub-3940256099942544~3347511713"


class FakeBridge extends AdmobBridge:
	var present: bool = true
	var load_rewarded_calls: int = 0
	var load_interstitial_calls: int = 0
	var rewarded_loaded: Callable = Callable()
	var rewarded_load_failed: Callable = Callable()
	var interstitial_loaded: Callable = Callable()
	var interstitial_load_failed: Callable = Callable()
	var rewarded_handlers: Array[Callable] = []
	var interstitial_handlers: Array[Callable] = []
	var consent_calls: int = 0
	var init_calls: int = 0

	func is_present() -> bool:
		return present

	func request_consent(_config: Dictionary, on_done: Callable) -> void:
		consent_calls += 1
		on_done.call(true)

	func initialize(_config: Dictionary, on_done: Callable) -> void:
		init_calls += 1
		on_done.call()

	func load_rewarded(_unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
		load_rewarded_calls += 1
		rewarded_loaded = on_loaded
		rewarded_load_failed = on_failed

	func load_interstitial(_unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
		load_interstitial_calls += 1
		interstitial_loaded = on_loaded
		interstitial_load_failed = on_failed

	func show_rewarded(on_shown: Callable, on_earned: Callable, on_dismissed: Callable, on_failed: Callable) -> void:
		rewarded_handlers = [on_shown, on_earned, on_dismissed, on_failed]

	func show_interstitial(on_shown: Callable, on_dismissed: Callable, on_failed: Callable) -> void:
		interstitial_handlers = [on_shown, on_dismissed, on_failed]


var _bridge: FakeBridge = null
var _provider: AdmobAdsProvider = null
var _events: Array[String] = []


func before_each() -> void:
	_bridge = FakeBridge.new()
	_events.clear()
	_provider = _make_provider({"request_consent": true})


func _make_provider(config: Dictionary) -> AdmobAdsProvider:
	var provider: AdmobAdsProvider = AdmobAdsProvider.new(_bridge, config, true)
	provider.shown.connect(func() -> void: _events.append("shown"))
	provider.rewarded.connect(func() -> void: _events.append("rewarded"))
	provider.dismissed.connect(func() -> void: _events.append("dismissed"))
	provider.failed.connect(func(reason: String) -> void: _events.append("failed:" + reason))
	return provider


func test_default_ids_are_google_test_ids() -> void:
	var ids: Dictionary = AdmobAdsProvider.resolve_ids(AdmobAdsProvider.load_admob_config(), false)
	assert_eq(String(ids["rewarded_unit_id"]), TEST_REWARDED)
	assert_eq(String(ids["interstitial_unit_id"]), TEST_INTERSTITIAL)
	assert_eq(String(ids["app_id"]), TEST_APP)


func test_production_ids_only_when_real_release() -> void:
	var production: Dictionary = {"app_id": "ca-app-pub-1~2", "rewarded_unit_id": "ca-app-pub-1/3",
		"interstitial_unit_id": "ca-app-pub-1/4"}
	var config: Dictionary = {"mode": "production", "production": production}
	assert_eq(String(AdmobAdsProvider.resolve_ids(config, true)["rewarded_unit_id"]), TEST_REWARDED, "debug = test")
	assert_eq(String(AdmobAdsProvider.resolve_ids(config, false)["rewarded_unit_id"]), "ca-app-pub-1/3")
	config["mode"] = "test"
	assert_eq(String(AdmobAdsProvider.resolve_ids(config, false)["rewarded_unit_id"]), TEST_REWARDED)


func test_placeholders_never_reach_the_sdk() -> void:
	var config: Dictionary = {"mode": "production", "production": {"app_id": "ca-app-pub-1~2",
		"rewarded_unit_id": "REPLACE_WITH_REAL_REWARDED_UNIT_ID", "interstitial_unit_id": "ca-app-pub-1/4"}}
	var ids: Dictionary = AdmobAdsProvider.resolve_ids(config, false)
	assert_eq(String(ids["rewarded_unit_id"]), TEST_REWARDED, "yer tutucu varsa tümü test kimliği")
	assert_eq(String(ids["app_id"]), TEST_APP)


func test_ads_json_ships_placeholders_and_test_mode() -> void:
	var config: Dictionary = AdmobAdsProvider.load_admob_config()
	assert_eq(String(config["mode"]), "test")
	assert_true(String((config["production"] as Dictionary)["rewarded_unit_id"]).begins_with("REPLACE_"))


func test_not_ready_before_initialize_and_without_plugin() -> void:
	assert_false(_provider.is_ready(0))
	_bridge.present = false
	_provider.initialize()
	assert_eq(_bridge.init_calls, 0, "eklenti yoksa hiçbir şey başlamaz")
	assert_false(_provider.is_ready(0))


func test_initialize_runs_consent_then_preloads_both() -> void:
	_provider.initialize()
	assert_eq(_bridge.consent_calls, 1)
	assert_eq(_bridge.init_calls, 1)
	assert_eq(_bridge.load_rewarded_calls, 1)
	assert_eq(_bridge.load_interstitial_calls, 1)
	assert_false(_provider.is_ready(0), "yükleme bitmeden hazır değil")
	_bridge.rewarded_loaded.call()
	_bridge.interstitial_loaded.call()
	assert_true(_provider.is_ready(0))
	assert_true(_provider.is_ready(AdsProvider.INTERSTITIAL_PLACEMENT))


func test_consent_can_be_disabled() -> void:
	var provider: AdmobAdsProvider = _make_provider({"request_consent": false})
	provider.initialize()
	assert_eq(_bridge.consent_calls, 0)
	assert_eq(_bridge.init_calls, 1)


func _ready_provider() -> void:
	_provider.initialize()
	_bridge.rewarded_loaded.call()
	_bridge.interstitial_loaded.call()


func test_rewarded_earned_then_dismissed_emits_rewarded_and_preloads_next() -> void:
	_ready_provider()
	var loads_before: int = _bridge.load_rewarded_calls
	_provider.show(0)
	assert_false(_provider.is_ready(0), "gösterim sırasında hazır değil")
	_bridge.rewarded_handlers[0].call()
	_bridge.rewarded_handlers[1].call()
	assert_false(_events.has("rewarded"), "ödül, reklam kapanınca verilir")
	_bridge.rewarded_handlers[2].call()
	assert_eq(_events, ["shown", "rewarded"])
	assert_eq(_bridge.load_rewarded_calls, loads_before + 1, "sonraki reklam hemen yüklenir")


func test_rewarded_dismissed_early_fails() -> void:
	_ready_provider()
	_provider.show(0)
	_bridge.rewarded_handlers[2].call()
	assert_eq(_events, ["failed:dismissed_early"])


func test_interstitial_dismiss_completes() -> void:
	_ready_provider()
	var loads_before: int = _bridge.load_interstitial_calls
	_provider.show(AdsProvider.INTERSTITIAL_PLACEMENT)
	_bridge.interstitial_handlers[0].call()
	_bridge.interstitial_handlers[1].call()
	assert_eq(_events, ["shown", "dismissed"])
	assert_eq(_bridge.load_interstitial_calls, loads_before + 1)


func test_show_failure_reports_and_reloads() -> void:
	_ready_provider()
	_provider.show(AdsProvider.INTERSTITIAL_PLACEMENT)
	_bridge.interstitial_handlers[2].call("boom")
	assert_eq(_events, ["failed:boom"])
	assert_true(_bridge.load_interstitial_calls >= 2)


func test_show_when_not_ready_fails_fast() -> void:
	_provider.initialize()
	_provider.show(0)
	assert_eq(_events, ["failed:not_ready"], "yüklü değilse beklemeden başarısız")


func test_load_failure_keeps_not_ready() -> void:
	_provider.initialize()
	_bridge.rewarded_load_failed.call("no_fill")
	assert_false(_provider.is_ready(0))
