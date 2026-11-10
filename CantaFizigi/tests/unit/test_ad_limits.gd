extends TestCase

## Reklam kancaları: limitler, idempotent ödül, oturum/tur sıfırlama.
## Sahte sağlayıcı anında `rewarded` yayar; böylece test zamanlayıcıya bağlı kalmaz.

const EXTRA_POCKET: int = 0
const TAPE_RESCUE: int = 1

var _ads: Node = null
var _rewarded: Array = []
var _failed: Array = []


## Sağlayıcı arayüzünün en basit hâli — gerçek SDK'nın yerine geçer.
class InstantAdsProvider extends AdsProvider:
	func is_ready(_placement: int) -> bool:
		return true

	func show(_placement: int) -> void:
		rewarded.emit()


func before_each() -> void:
	_rewarded.clear()
	_failed.clear()
	_ads = autoload_node("AdManager")
	assert_not_null(_ads, "AdManager autoload'u yok")
	if _ads == null:
		return
	_ads.call("set_provider", InstantAdsProvider.new())
	_ads.call("reset_session_limits")
	_ads.rewarded_finished.connect(_on_rewarded)
	_ads.ad_failed.connect(_on_failed)


func after_each() -> void:
	if _ads == null:
		return
	_ads.rewarded_finished.disconnect(_on_rewarded)
	_ads.ad_failed.disconnect(_on_failed)
	_ads.call("set_provider", MockAdsProvider.new())
	_ads.call("reset_session_limits")


func _on_rewarded(placement: int, success: bool) -> void:
	_rewarded.append([placement, success])


func _on_failed(placement: int, reason: String) -> void:
	_failed.append([placement, reason])


func test_offer_available_initially() -> void:
	assert_true(_ads.call("can_offer", EXTRA_POCKET), "ilk kullanım önerilebilir olmalı")
	assert_true(_ads.call("can_offer", TAPE_RESCUE), "bant ilk kullanımda önerilebilir")


func test_reward_fires_once_per_show() -> void:
	_ads.call("show_rewarded", EXTRA_POCKET)
	assert_eq(_rewarded.size(), 1, "rewarded_finished bir kez yayılmalı")
	assert_eq(_rewarded[0], [EXTRA_POCKET, true])


func test_per_run_limit_blocks_second_offer() -> void:
	_ads.call("show_rewarded", EXTRA_POCKET)
	assert_false(_ads.call("can_offer", EXTRA_POCKET), "tur limiti dolunca teklif kapanmalı")
	_ads.call("show_rewarded", EXTRA_POCKET)
	assert_eq(_rewarded.size(), 1, "limitli ikinci istek ödül vermemeli")
	assert_eq(_failed.size(), 1)
	assert_eq(_failed[0][1], "not_available")


func test_reward_is_idempotent() -> void:
	var provider: AdsProvider = _ads.get("provider") as AdsProvider
	assert_not_null(provider)
	_ads.call("show_rewarded", EXTRA_POCKET)
	provider.rewarded.emit()  # sağlayıcı ikinci kez yayarsa
	assert_eq(_rewarded.size(), 1, "ödül iki kez verilmemeli")
	assert_eq(_ads.call("used_in_run", EXTRA_POCKET), 1)


func test_reset_run_limits_reopens_offer() -> void:
	_ads.call("show_rewarded", EXTRA_POCKET)
	assert_false(_ads.call("can_offer", EXTRA_POCKET))
	_ads.call("reset_run_limits")
	assert_true(_ads.call("can_offer", EXTRA_POCKET), "tur sıfırlanınca teklif geri gelmeli")


func test_placements_are_limited_independently() -> void:
	_ads.call("show_rewarded", EXTRA_POCKET)
	assert_true(_ads.call("can_offer", TAPE_RESCUE), "diğer yerleşim etkilenmemeli")
