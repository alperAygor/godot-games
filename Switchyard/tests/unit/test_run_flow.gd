extends TestCase

## RunFlow: ödüllü reklam (ipucu/atlama) yalnız başarıda ödül verir, nedenini bildirir; geçiş reklamı AdPacing'e uyar
## (sıra, kaldırıldı, ödüllü izlendi, en az aralık). AdManager autoload'u sahte sağlayıcıyla sürülür ve test sonunda
## eski sağlayıcı geri konur. Kayıt diske YAZILMAZ (persist=false).

const HINT: int = 0
const SKIP: int = 1

var _flow: RunFlow = null
var _ads: Node = null
var _progress: Node = null
var _old_provider: AdsProvider = null
var _old_persist: bool = true
var _reasons: Array[String] = []
var _clock: Array[float] = [1000000.0]


## Anında biten sağlayıcı: ödüllü -> rewarded, geçiş -> dismissed. `fail_reason` doluysa ödülsüz hata.
class InstantProvider extends AdsProvider:
	var fail_reason: String = ""
	var ready: bool = true
	var shown_count: int = 0

	func is_ready(_placement: int) -> bool:
		return ready

	func show(placement: int) -> void:
		shown_count += 1
		shown.emit()
		if not fail_reason.is_empty():
			failed.emit(fail_reason)
		elif placement == INTERSTITIAL_PLACEMENT:
			dismissed.emit()
		else:
			rewarded.emit()


func before_each() -> void:
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	_ads = autoload_node("AdManager")
	_progress = autoload_node("Progress")
	_old_provider = _ads.get("provider") as AdsProvider
	_old_persist = bool(_progress.get("persist"))
	_progress.set("persist", false)
	_progress.call("reset_state")
	_ads.call("reset_session_limits")
	_reasons.clear()
	_clock[0] = 1000000.0
	_flow = RunFlow.new()
	_flow.time_source = func() -> float: return _clock[0]
	add_node(_flow)
	_flow.ad_unavailable.connect(func(_placement: int, reason: String) -> void: _reasons.append(reason))


func after_each() -> void:
	_flow.queue_free()
	_ads.call("set_provider", _old_provider)
	_ads.call("reset_session_limits")
	_progress.call("reset_state")
	_progress.set("persist", _old_persist)


func _use(provider: InstantProvider) -> void:
	_ads.call("set_provider", provider)


func test_win_is_logged_and_nothing_pays_coins() -> void:
	_flow.on_level_start(1)
	_flow.on_solved(1)
	assert_eq(AnalyticsLog.count("level_start"), 1)
	assert_eq(AnalyticsLog.count("level_win"), 1)


func test_rewarded_ad_grants_only_on_success() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	var granted: Array[int] = [0]
	var failed: Array[int] = [0]
	_flow.on_level_start(4)
	assert_true(_flow.watch(HINT, func() -> void: granted[0] += 1, func() -> void: failed[0] += 1))
	assert_eq([granted[0], failed[0]], [1, 0])
	assert_eq(AnalyticsLog.count("rewarded_watched"), 1)
	assert_true(_flow.rewarded_this_level())
	# Her ipucu bir reklam: aynı seviyede yine sunulur.
	assert_true(_flow.can_watch(HINT))
	provider.fail_reason = "no_fill"
	_flow.watch(HINT, func() -> void: granted[0] += 1, func() -> void: failed[0] += 1)
	assert_eq([granted[0], failed[0]], [1, 1], "başarısız reklamda ödül yok")
	assert_eq(AnalyticsLog.count("rewarded_skipped"), 1)


func test_skip_is_once_per_level() -> void:
	_use(InstantProvider.new())
	_flow.on_level_start(4)
	var granted: Array[int] = [0]
	_flow.watch(SKIP, func() -> void: granted[0] += 1)
	assert_false(_flow.can_watch(SKIP))
	_flow.on_level_start(5)
	assert_true(_flow.can_watch(SKIP), "yeni seviyede yine sunulur")


func test_unavailable_ad_explains_and_never_stalls() -> void:
	var provider: InstantProvider = InstantProvider.new()
	provider.ready = false
	_use(provider)
	var failed: Array[int] = [0]
	_flow.on_level_start(4)
	assert_false(_flow.watch(HINT, func() -> void: pass, func() -> void: failed[0] += 1))
	assert_eq(failed[0], 1)
	assert_eq(_reasons, [RunFlow.REASON_NOT_READY] as Array[String])
	assert_false(_flow.can_watch(HINT), "hazır olmayan sağlayıcı: sunulmaz")
	provider.ready = true
	assert_true(_flow.can_watch(HINT), "bekleyen reklam kalmadı: sonraki deneme açık")


func test_failure_reasons_are_reported() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	_flow.on_level_start(4)
	provider.fail_reason = "dismissed_early"
	_flow.watch(HINT, func() -> void: pass)
	provider.fail_reason = "no_fill"
	_flow.watch(HINT, func() -> void: pass)
	assert_eq(_reasons, [RunFlow.REASON_NOT_FINISHED, RunFlow.REASON_NOT_READY] as Array[String])


func test_timeout_is_reported_and_unblocks() -> void:
	# Hiç yanıt vermeyen sağlayıcı: AdManager zaman aşımı ödülsüz bitirir.
	var quiet: SilentProvider = SilentProvider.new()
	_ads.call("set_provider", quiet)
	_flow.on_level_start(4)
	var failed: Array[int] = [0]
	_flow.watch(HINT, func() -> void: pass, func() -> void: failed[0] += 1)
	assert_eq(failed[0], 0, "reklam bekleniyor")
	_ads.call("_on_show_timeout", int(_ads.get("_pending_ticket")))
	assert_eq(failed[0], 1)
	assert_eq(_reasons, [RunFlow.REASON_TIMEOUT] as Array[String])


class SilentProvider extends AdsProvider:
	func is_ready(_placement: int) -> bool:
		return true

	func show(_placement: int) -> void:
		pass


func _run_interstitial(completed: int, first: bool) -> Array[int]:
	var continued: Array[int] = [0]
	_flow.maybe_interstitial(completed, first, func() -> void: continued[0] += 1)
	return continued


func test_interstitial_follows_pacing_and_always_continues() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	_flow.on_level_start(1)
	assert_eq(_run_interstitial(1, true)[0], 1)
	assert_eq(provider.shown_count, 0, "1. seviye bitişinde reklam yok")
	assert_eq(_run_interstitial(3, true)[0], 1)
	assert_eq(provider.shown_count, 1, "3. seviye bitince ilk reklam")
	assert_eq(AnalyticsLog.count("interstitial_shown"), 1)


func test_minimum_gap_blocks_a_second_interstitial() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	_flow.on_level_start(3)
	_run_interstitial(3, true)
	assert_eq(provider.shown_count, 1)
	_clock[0] += 30.0
	_run_interstitial(6, true)
	assert_eq(provider.shown_count, 1, "30 sn sonra: en az aralık dolmadı")
	_clock[0] += 31.0
	_run_interstitial(9, true)
	assert_eq(provider.shown_count, 2, "61 sn sonra: gelir")


func test_no_interstitial_when_ads_removed() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	_progress.call("set_remove_ads_owned", true)
	_flow.on_level_start(5)
	assert_eq(_run_interstitial(6, true)[0], 1)
	assert_eq(provider.shown_count, 0)


func test_no_interstitial_after_rewarded_on_that_level() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	_flow.on_level_start(6)
	_flow.watch(HINT, func() -> void: pass)
	var after_rewarded: int = provider.shown_count
	assert_eq(_run_interstitial(6, true)[0], 1)
	assert_eq(provider.shown_count, after_rewarded, "ödüllü izlenen seviyede geçiş reklamı yok")
	_flow.on_level_start(9)
	_run_interstitial(9, true)
	assert_eq(provider.shown_count, after_rewarded + 1, "sonraki seviyede yine gelir")


func test_replaying_a_level_never_triggers_interstitial() -> void:
	var provider: InstantProvider = InstantProvider.new()
	_use(provider)
	_flow.on_level_start(3)
	assert_eq(_run_interstitial(3, false)[0], 1)
	assert_eq(provider.shown_count, 0)


func test_interstitial_failure_never_blocks_flow() -> void:
	var provider: InstantProvider = InstantProvider.new()
	provider.fail_reason = "no_fill"
	_use(provider)
	_flow.on_level_start(6)
	assert_eq(_run_interstitial(6, true)[0], 1, "reklam gösterilemese de akış devam eder")
	assert_eq(AnalyticsLog.count("interstitial_shown"), 0)
	provider.fail_reason = ""
	provider.ready = false
	assert_eq(_run_interstitial(6, true)[0], 1, "hazır değilken de")
