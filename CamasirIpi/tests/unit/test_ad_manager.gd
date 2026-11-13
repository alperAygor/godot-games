extends TestCase

## AdManager: gösterim zaman aşımı, geçiş reklamı tamamlanması, sağlayıcı sözleşmesi.

var _ads: Node = null
var _log: Array[String] = []


class ScriptedProvider extends AdsProvider:
	var mode: String = "silent"

	func is_ready(_placement: int) -> bool:
		return true

	func show(_placement: int) -> void:
		match mode:
			"shown_then_dismissed":
				shown.emit()
				dismissed.emit()
			"shown_then_reward":
				shown.emit()
				rewarded.emit()
			_:
				pass


func before_each() -> void:
	_log.clear()
	_ads = (load("res://scripts/autoload/AdManager.gd") as GDScript).new()
	add_node(_ads)
	_ads.connect("interstitial_finished", func(success: bool) -> void: _log.append("inter:%s" % success))
	_ads.connect("rewarded_finished", func(_placement: int, success: bool) -> void: _log.append("rew:%s" % success))


func after_each() -> void:
	_ads.queue_free()


func _placement(name: String) -> int:
	return int(((_ads.get_script() as GDScript).get_script_constant_map()["Placement"] as Dictionary)[name])


func test_placement_enum_matches_provider_constant() -> void:
	assert_eq(_placement("INTERSTITIAL"), AdsProvider.INTERSTITIAL_PLACEMENT)


func test_interstitial_completes_on_dismiss() -> void:
	var provider: ScriptedProvider = ScriptedProvider.new()
	provider.mode = "shown_then_dismissed"
	_ads.call("set_provider", provider)
	assert_true(bool(_ads.call("show_interstitial")))
	assert_eq(_log, ["inter:true"])


func test_silent_interstitial_times_out_and_unblocks_flow() -> void:
	var provider: ScriptedProvider = ScriptedProvider.new()
	_ads.call("set_provider", provider)
	assert_true(bool(_ads.call("show_interstitial")))
	assert_eq(_log, [], "reklam hiç gelmedi: bekliyor")
	_ads.call("_on_show_timeout", int(_ads.get("_pending_ticket")))
	assert_eq(_log, ["inter:false"], "zaman aşımı akışı reklamsız devam ettirir")
	assert_true(bool(_ads.call("show_interstitial")), "sonraki gösterim engellenmez")


func test_shown_ad_is_not_cut_by_timeout() -> void:
	var provider: ScriptedProvider = ScriptedProvider.new()
	_ads.call("set_provider", provider)
	_ads.call("show_interstitial")
	provider.shown.emit()
	_ads.call("_on_show_timeout", int(_ads.get("_pending_ticket")))
	assert_eq(_log, [], "ekrandaki reklam kesilmez")
	provider.dismissed.emit()
	assert_eq(_log, ["inter:true"])


func test_stale_timeout_is_ignored() -> void:
	var provider: ScriptedProvider = ScriptedProvider.new()
	provider.mode = "shown_then_dismissed"
	_ads.call("set_provider", provider)
	_ads.call("show_interstitial")
	var old_ticket: int = int(_ads.get("_pending_ticket"))
	provider.mode = "silent"
	_ads.call("show_interstitial")
	_ads.call("_on_show_timeout", old_ticket)
	assert_eq(_log, ["inter:true"], "eski ters sayım yeni gösterimi bozmaz")


func test_rewarded_failure_when_ad_never_appears() -> void:
	var provider: ScriptedProvider = ScriptedProvider.new()
	_ads.call("set_provider", provider)
	_ads.call("show_rewarded", _placement("REVIVE_EXTRA_SLOT"))
	_ads.call("_on_show_timeout", int(_ads.get("_pending_ticket")))
	assert_eq(_log, ["rew:false"])


func test_rewarded_reward_flow_unchanged() -> void:
	var provider: ScriptedProvider = ScriptedProvider.new()
	provider.mode = "shown_then_reward"
	_ads.call("set_provider", provider)
	_ads.call("show_rewarded", _placement("DOUBLE_COINS"))
	assert_eq(_log, ["rew:true"])


func test_default_provider_has_no_plugin_on_desktop() -> void:
	var provider: AdsProvider = (_ads.get_script() as GDScript).call("make_default_provider") as AdsProvider
	if OS.is_debug_build():
		assert_true(provider is MockAdsProvider)
	else:
		assert_true(provider is NoAdsProvider)
